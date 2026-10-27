// QuizProfileController.apex
public with sharing class QuizProfileController {
    @AuraEnabled(cacheable=true)
    public static QuizDTOs.ResponseWrapper getProfile(String username) {
        return QuizIdentityService.getPublicProfile(username);
    }

    @AuraEnabled
    public static QuizDTOs.ResponseWrapper updateMyProfile(String token, QuizDTOs.ProfileUpdate profileData) {
        return QuizIdentityService.updateProfile(token, profileData);
    }
}