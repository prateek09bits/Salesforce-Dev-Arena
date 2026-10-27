// QuizArenaController.apex
public with sharing class QuizArenaController {
    @AuraEnabled
    public static QuizDTOs.ResponseWrapper getRoomState(String token, String roomCode) {
        return QuizGameService.getRoomState(token, roomCode);
    }

    @AuraEnabled
    public static QuizDTOs.ResponseWrapper submitAnswer(String token, String roomCode, Integer answerIndex) {
        return QuizGameService.submitAnswer(token, roomCode, answerIndex);
    }

    @AuraEnabled
    public static QuizDTOs.ResponseWrapper getResults(String token, String roomCode) {
        return QuizGameService.getResults(token, roomCode);
    }
}