/** Deletes expired rooms (and their players / answers). Schedule e.g. hourly: System.schedule('Room cleanup', '0 0 * * * ?', new RoomCleanupBatch()); */
public without sharing class RoomCleanupBatch implements Database.Batchable<SObject>, Schedulable {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime now = System.now();
        return Database.getQueryLocator([SELECT Id FROM Game_Room__c WHERE Expires_At__c < :now]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Game_Room__c> rooms = (List<Game_Room__c>) scope;
        Set<Id> ids = new Map<Id, Game_Room__c>(rooms).keySet();
        delete [SELECT Id FROM Answer__c WHERE Game_Room__c IN :ids];
        delete [SELECT Id FROM Player__c WHERE Game_Room__c IN :ids];
        delete rooms;
    }

    public void finish(Database.BatchableContext bc) {}

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new RoomCleanupBatch(), 100);
    }
}