public without sharing class GuestPlayerController {

    @AuraEnabled
    public static Contact registerOrLoginContact(String nickname, String email) {
        // Enforce guest safety checks and query or create Contact record
        List<Contact> existing = [SELECT Id, Name, Email, Nickname__c FROM Contact WHERE Email = :email LIMIT 1];
        Contact c;
        if (!existing.isEmpty()) {
            c = existing[0];
            c.Nickname__c = nickname;
            update c;
        } else {
            c = new Contact(FirstName = 'Quiz', LastName = nickname, Email = email, Nickname__c = nickname);
            insert c;
        }

        // Store Contact Id securely in Session Cache or Platform Cache partition
        Cache.Session.put('local.QuizSession.contactId', c.Id);
        return c;
    }

    @AuraEnabled(cacheable=true)
    public static Contact getSessionPlayer() {
        Id contactId = (Id) Cache.Session.get('local.QuizSession.contactId');
        if (contactId == null) {
            return null;
        }
        return [SELECT Id, Name, Email, Nickname__c FROM Contact WHERE Id = :contactId LIMIT 1];
    }

    @AuraEnabled
    public static void clearSessionPlayer() {
        Cache.Session.remove('local.QuizSession.contactId');
    }

    @AuraEnabled(cacheable=true)
    public static Contact getProfileByUsername(String username) {
        List<Contact> contacts = [SELECT Id, Name, Email, Nickname__c FROM Contact WHERE Nickname__c = :username LIMIT 1];
        return contacts.isEmpty() ? null : contacts[0];
    }
}