public without sharing class QuestionEngineService {
    static final Set<String> TYPES = new Set<String>{ 'MCQ_SINGLE', 'MCQ_MULTI', 'TRUE_FALSE', 'CODE_OUTPUT', 'SCENARIO' };

    /** Picks questions for a game. useEinstein=false reads the Quiz_Question__c bank. */
    public static List<AstroDTOs.QuestionData> pick(AstroDTOs.QuestionCriteria c, Id contactId, Boolean useEinstein) {
        Set<Id> seen = new Set<Id>();
        if (contactId != null) {
            for (User_Question_History__c h : [
                SELECT Question__c FROM User_Question_History__c
                WHERE Contact__c = :contactId ORDER BY CreatedDate DESC LIMIT 1500
            ]) seen.add(h.Question__c);
        }

        QuestionProvider provider = QuestionProviderFactory.getProvider(useEinstein);
        List<AstroDTOs.QuestionData> out = new List<AstroDTOs.QuestionData>();
        for (AstroDTOs.QuestionData q : provider.getQuestions(c, seen)) {
            if (isValid(q)) out.add(q);
            if (out.size() >= c.count) break;
        }
        if (out.isEmpty()) {
            throw new AstroException('No questions are available for that selection yet. Try another topic or level.');
        }
        return out;
    }

    public static Boolean isValid(AstroDTOs.QuestionData q) {
        if (q == null || String.isBlank(q.text) || String.isBlank(q.correct) || !TYPES.contains(q.type)) return false;
        if (q.options == null || q.options.size() < 2) return false;
        Set<String> keys = new Set<String>();
        for (AstroDTOs.Option o : q.options) keys.add(o.key);
        for (String k : q.correct.split(',')) if (!keys.contains(k)) return false;
        if (q.type != 'MCQ_MULTI' && q.correct.contains(',')) return false;
        return true;
    }

    /** "b, a" -> "A,B"  |  "True" -> "TRUE" */
    public static String normalize(String answer) {
        if (String.isBlank(answer)) return '';
        List<String> parts = new List<String>();
        for (String p : answer.split(',')) {
            if (String.isNotBlank(p)) parts.add(p.trim().toUpperCase());
        }
        parts.sort();
        return String.join(parts, ',');
    }

    public static List<AstroDTOs.Option> trueFalseOptions() {
        AstroDTOs.Option t = new AstroDTOs.Option();
        t.key = 'TRUE';
        t.label = 'True';
        AstroDTOs.Option f = new AstroDTOs.Option();
        f.key = 'FALSE';
        f.label = 'False';
        return new List<AstroDTOs.Option>{ t, f };
    }
}