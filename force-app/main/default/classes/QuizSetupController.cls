// QuizSetupController.apex
public with sharing class QuizSetupController {
    @AuraEnabled
    public static QuizDTOs.ResponseWrapper createRoom(String token, QuizDTOs.RoomConfig config) {
        return QuizGameService.createRoom(token, config);
    }

    @AuraEnabled
    public static QuizDTOs.ResponseWrapper joinRoom(String token, String roomCode) {
        return QuizGameService.joinRoom(token, roomCode);
    }

    @AuraEnabled(cacheable=true)
    public static QuizDTOs.ResponseWrapper getLobbyState(String roomCode) {
        return QuizGameService.getLobbyState(roomCode);
    }

    @AuraEnabled
    public static QuizDTOs.ResponseWrapper startGame(String token, String roomCode) {
        return QuizGameService.startGame(token, roomCode);
    }
}