/** Deletes expired sessions. Schedule daily: System.schedule('Session cleanup', '0 30 2 * * ?', new SessionCleanupBatch()); */
public without sharing class SessionCleanupBatch implements Database.Batchable<SObject>, Schedulable {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime now = System.now();
        return Database.getQueryLocator([SELECT Id FROM Auth_Session__c WHERE Expires_At__c < :now]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        delete scope;
    }

    public void finish(Database.BatchableContext bc) {}

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new SessionCleanupBatch(), 200);
    }
}