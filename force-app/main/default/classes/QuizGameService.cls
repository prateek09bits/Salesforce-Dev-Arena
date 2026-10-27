// QuizGameService.apex
public without sharing class QuizGameService {
    public static QuizDTOs.ResponseWrapper getHomeStatsAndLeaderboard() {
        return new QuizDTOs.ResponseWrapper(true, null);
    }

    public static QuizDTOs.ResponseWrapper createRoom(String token, QuizDTOs.RoomConfig config) {
        return new QuizDTOs.ResponseWrapper(true, null);
    }

    public static QuizDTOs.ResponseWrapper joinRoom(String token, String roomCode) {
        return new QuizDTOs.ResponseWrapper(true, null);
    }

    public static QuizDTOs.ResponseWrapper getLobbyState(String roomCode) {
        return new QuizDTOs.ResponseWrapper(true, null);
    }

    public static QuizDTOs.ResponseWrapper startGame(String token, String roomCode) {
        return new QuizDTOs.ResponseWrapper(true, null);
    }

    public static QuizDTOs.ResponseWrapper getRoomState(String token, String roomCode) {
        return new QuizDTOs.ResponseWrapper(true, null);
    }

    public static QuizDTOs.ResponseWrapper submitAnswer(String token, String roomCode, Integer answerIndex) {
        return new QuizDTOs.ResponseWrapper(true, null);
    }

    public static QuizDTOs.ResponseWrapper getResults(String token, String roomCode) {
        return new QuizDTOs.ResponseWrapper(true, null);
    }
}