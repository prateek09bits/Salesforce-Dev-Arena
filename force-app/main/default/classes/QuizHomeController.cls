// QuizHomeController.apex
public with sharing class QuizHomeController {
    @AuraEnabled(cacheable=true)
    public static QuizDTOs.ResponseWrapper getHomeData() {
        return QuizGameService.getHomeStatsAndLeaderboard();
    }
}