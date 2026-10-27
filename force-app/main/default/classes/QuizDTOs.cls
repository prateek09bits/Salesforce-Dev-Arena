// QuizDTOs.apex (Optional standalone wrapper or inner classes)
public class QuizDTOs {
    public class ResponseWrapper {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Object data;

        public ResponseWrapper(Boolean success, Object data) {
            this.success = success;
            this.data = data;
        }
    }

    public class RoomConfig {
        @AuraEnabled public String topic;
        @AuraEnabled public String level;
        @AuraEnabled public Integer questionCount;
    }

    public class ProfileUpdate {
        @AuraEnabled public String displayName;
        @AuraEnabled public String bio;
    }
}