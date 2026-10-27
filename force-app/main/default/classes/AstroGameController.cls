/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-15-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public without sharing class AstroGameController {

    /**
     * Question source switch. false = read approved questions from Quiz_Question__c.
     * Flip to true once the Einstein / Agentforce generation is wired (see EinsteinQuestionProvider).
     */
    @TestVisible private static final Boolean USE_EINSTEIN = false;

   @AuraEnabled
public static AstroDTOs.JoinResult createRoom(String sessionToken, String reqJson) {
    try {
        RateLimiter.hit('room', bucketKey(sessionToken), String.isBlank(sessionToken) ? 200 : 20, 3600);
        if (String.isBlank(reqJson)) throw new AstroException('Missing game settings. Please try again.');

        Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(reqJson);
        AstroDTOs.CreateRoomRequest req = new AstroDTOs.CreateRoomRequest();
        req.level = (String) m.get('level');
        req.topic = (String) m.get('topic');
        req.nickname = (String) m.get('nickname');
        req.solo = m.get('solo') == true;
        req.count = m.get('count') == null ? null : Integer.valueOf(String.valueOf(m.get('count')));
        req.secondsPerQuestion = m.get('secondsPerQuestion') == null ? null : Integer.valueOf(String.valueOf(m.get('secondsPerQuestion')));

        req.types = new List<String>();
        Object t = m.get('types');
        if (t instanceof List<Object>) {
            for (Object o : (List<Object>) t) req.types.add(String.valueOf(o));
        } else if (t instanceof String) {
            for (String s : ((String) t).split(',')) req.types.add(s.trim());
        }
        if (req.types.isEmpty()) {
            // TEMPORARY diagnostic: remove once the cause is found
            throw new AstroException('Server received no question types. Payload: ' + reqJson.left(200));
        }

        Id contactId = SessionService.resolve(sessionToken);
        return GameRoomService.createRoom(contactId, req, USE_EINSTEIN);
    } catch (Exception e) {
        throw AstroUtil.wrap(e);
    }
}

    @AuraEnabled
    public static AstroDTOs.JoinResult joinRoom(String sessionToken, String code, String nickname, String playerToken) {
        try {
            RateLimiter.hit('join', bucketKey(sessionToken), 60, 600);
            Id contactId = SessionService.resolve(sessionToken);
            return GameRoomService.joinRoom(contactId, code, nickname, playerToken);
        } catch (Exception e) {
            throw AstroUtil.wrap(e);
        }
    }

    @AuraEnabled
    public static void startGame(String code, String playerToken) {
        try {
            GameRoomService.startGame(code, playerToken);
        } catch (Exception e) {
            throw AstroUtil.wrap(e);
        }
    }

    /** Polled by the lobby and the arena every ~2 seconds. */
    @AuraEnabled
    public static AstroDTOs.RoomState getRoomState(String code, String playerToken) {
        try {
            RateLimiter.hit('poll', bucketKey(playerToken), 200, 60);
            return GameRoomService.getState(code, playerToken);
        } catch (Exception e) {
            throw AstroUtil.wrap(e);
        }
    }

    @AuraEnabled
    public static Boolean submitAnswer(String code, String playerToken, Integer questionIndex, String answer) {
        try {
            RateLimiter.hit('answer', bucketKey(playerToken), 60, 60);
            return GameRoomService.submitAnswer(code, playerToken, questionIndex, answer);
        } catch (Exception e) {
            throw AstroUtil.wrap(e);
        }
    }

    static String bucketKey(String token) {
        return String.isBlank(token) ? 'anon' : AuthService.sha256(token).substring(0, 24);
    }
}