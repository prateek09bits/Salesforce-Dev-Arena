// QuizShellController.apex
public with sharing class QuizShellController {
    @AuraEnabled
    public static QuizDTOs.ResponseWrapper restoreSession(String token) {
        return QuizIdentityService.restoreSession(token);
    }

    @AuraEnabled
    public static QuizDTOs.ResponseWrapper logout(String token) {
        return QuizIdentityService.logout(token);
    }
}