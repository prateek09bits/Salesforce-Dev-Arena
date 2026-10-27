/** Request / response shapes. No secret fields (hash, salt, correct answers before reveal) ever appear in client-facing DTOs. */
public without sharing class AstroDTOs {

    // ---------- Auth ----------
    public class ContactSummary {
        @AuraEnabled public String username;
        @AuraEnabled public String displayName;
        @AuraEnabled public String avatarKey;
    }
    public class AuthResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String token;
        @AuraEnabled public ContactSummary contact;
    }

    // ---------- Questions ----------
    public class Option {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
    }
    /** Server-side only: includes the correct answer. Serialized into Game_Room__c.Questions_JSON__c. */
    public class QuestionData {
        public String id;
        public String type;
        public String level;
        public String topic;
        public String text;
        public String code;
        public List<Option> options;
        public String correct;
        public String explanation;
    }
    /** Client-safe question (no answer, no explanation). */
    public class QuestionView {
        @AuraEnabled public String type;
        @AuraEnabled public String level;
        @AuraEnabled public String topic;
        @AuraEnabled public String text;
        @AuraEnabled public String code;
        @AuraEnabled public Boolean multi;
        @AuraEnabled public List<Option> options;
    }
    public class QuestionCriteria {
        public String level;
        public String topic;
        public List<String> types;
        public Integer count;
    }

    // ---------- Rooms ----------
    public class CreateRoomRequest {
        @AuraEnabled public String level;
        @AuraEnabled public String topic;
        @AuraEnabled public List<String> types;
        @AuraEnabled public Integer count;
        @AuraEnabled public Integer secondsPerQuestion;
        @AuraEnabled public Boolean solo;
        @AuraEnabled public String nickname;
    }
    public class JoinResult {
        @AuraEnabled public String code;
        @AuraEnabled public String playerToken;
        @AuraEnabled public String playerId;
        @AuraEnabled public String nickname;
    }
    public class PlayerView {
        @AuraEnabled public String id;
        @AuraEnabled public String nickname;
        @AuraEnabled public Integer score;
        @AuraEnabled public Integer streak;
        @AuraEnabled public Boolean isHost;
        @AuraEnabled public Boolean isMe;
        @AuraEnabled public Boolean answered;
    }
    public class ReviewItem {
        @AuraEnabled public Integer index;
        @AuraEnabled public String text;
        @AuraEnabled public String code;
        @AuraEnabled public List<Option> options;
        @AuraEnabled public String correct;
        @AuraEnabled public String explanation;
        @AuraEnabled public String myAnswer;
        @AuraEnabled public Boolean isCorrect;
        @AuraEnabled public Integer points;
    }
    public class RoomState {
        @AuraEnabled public String code;
        @AuraEnabled public String status;      // Lobby | Active | Finished
        @AuraEnabled public String phase;       // LOBBY | STARTING | QUESTION | REVEAL | FINISHED
        @AuraEnabled public Long phaseEndsAt;   // epoch ms (server clock)
        @AuraEnabled public Long serverNow;     // epoch ms (server clock)
        @AuraEnabled public Integer index;
        @AuraEnabled public Integer total;
        @AuraEnabled public Integer secondsPerQuestion;
        @AuraEnabled public String level;
        @AuraEnabled public String topic;
        @AuraEnabled public Boolean isSolo;
        @AuraEnabled public Boolean isHost;
        @AuraEnabled public String myPlayerId;
        @AuraEnabled public QuestionView question;
        @AuraEnabled public String correctAnswer;   // only during REVEAL
        @AuraEnabled public String explanation;     // only during REVEAL
        @AuraEnabled public String myAnswer;
        @AuraEnabled public Boolean myIsCorrect;
        @AuraEnabled public Integer myPoints;
        @AuraEnabled public List<PlayerView> players;
        @AuraEnabled public List<ReviewItem> reviews; // only when finished
    }

    // ---------- Profile ----------
    public class LeaderboardRow {
        @AuraEnabled public Integer rank;
        @AuraEnabled public String username;
        @AuraEnabled public String displayName;
        @AuraEnabled public String avatarKey;
        @AuraEnabled public Integer totalScore;
        @AuraEnabled public Integer gamesPlayed;
        @AuraEnabled public Integer gamesWon;
    }
    public class Badge {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String icon;
    }
    public class RecentGame {
        @AuraEnabled public String topic;
        @AuraEnabled public String level;
        @AuraEnabled public Integer score;
        @AuraEnabled public Integer rank;
        @AuraEnabled public Datetime playedAt;
    }
    public class ProfileView {
        @AuraEnabled public String username;
        @AuraEnabled public String displayName;
        @AuraEnabled public String avatarKey;
        @AuraEnabled public String bio;
        @AuraEnabled public Boolean isPublic;
        @AuraEnabled public Boolean isOwner;
        @AuraEnabled public Integer rank;
        @AuraEnabled public Integer totalScore;
        @AuraEnabled public Integer gamesPlayed;
        @AuraEnabled public Integer gamesWon;
        @AuraEnabled public Integer bestStreak;
        @AuraEnabled public Integer winRate;
        @AuraEnabled public List<Badge> badges;
        @AuraEnabled public List<RecentGame> recentGames;
    }
    public class UpdateProfileRequest {
        @AuraEnabled public String displayName;
        @AuraEnabled public String bio;
        @AuraEnabled public String avatarKey;
        @AuraEnabled public Boolean isPublic;
    }
}