/** Reads approved questions from Quiz_Question__c. Games never wait on AI. */
public without sharing class DbQuestionProvider implements QuestionProvider {

    public List<AstroDTOs.QuestionData> getQuestions(AstroDTOs.QuestionCriteria c, Set<Id> excludeIds) {
        Set<Id> unseen = excludeIds == null ? new Set<Id>() : excludeIds;
        Boolean byTopic = c.topic != 'Any';
        Map<Id, Quiz_Question__c> picked = new Map<Id, Quiz_Question__c>();

        // 1. same topic, unseen  2. any topic, unseen  3. same topic, seen ok  4. any topic, seen ok
        take(picked, fetch(c, byTopic, unseen), c.count);
        if (picked.size() < c.count) take(picked, fetch(c, false, unseen), c.count);
        if (picked.size() < c.count) take(picked, fetch(c, byTopic, new Set<Id>()), c.count);
        if (picked.size() < c.count) take(picked, fetch(c, false, new Set<Id>()), c.count);

        List<Quiz_Question__c> all = new List<Quiz_Question__c>(picked.values());
        shuffle(all);
        List<AstroDTOs.QuestionData> out = new List<AstroDTOs.QuestionData>();
        for (Quiz_Question__c q : all) out.add(toData(q));
        return out;
    }

    List<Quiz_Question__c> fetch(AstroDTOs.QuestionCriteria c, Boolean useTopic, Set<Id> exclude) {
        String soql = 'SELECT Id, Level__c, Topic__c, Question_Type__c, Question_Text__c, Code_Snippet__c, '
            + 'Options_JSON__c, Correct_Answer__c, Explanation__c FROM Quiz_Question__c '
            + 'WHERE Status__c = \'Approved\' AND Level__c = :level AND Question_Type__c IN :types AND Id NOT IN :exclude';
        if (useTopic) soql += ' AND Topic__c = :topic';
        soql += ' LIMIT 300';
        Map<String, Object> binds = new Map<String, Object>{
            'level' => c.level, 'types' => c.types, 'topic' => c.topic, 'exclude' => exclude
        };
        return (List<Quiz_Question__c>) Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);
    }

    void take(Map<Id, Quiz_Question__c> picked, List<Quiz_Question__c> source, Integer cap) {
        shuffle(source);
        for (Quiz_Question__c q : source) {
            if (picked.size() >= cap) return;
            if (!picked.containsKey(q.Id)) picked.put(q.Id, q);
        }
    }

    void shuffle(List<Quiz_Question__c> items) {
        for (Integer i = items.size() - 1; i > 0; i--) {
            Integer j = Math.floor(Math.random() * (i + 1)).intValue();
            Quiz_Question__c tmp = items[i];
            items[i] = items[j];
            items[j] = tmp;
        }
    }

    AstroDTOs.QuestionData toData(Quiz_Question__c q) {
        AstroDTOs.QuestionData d = new AstroDTOs.QuestionData();
        d.id = q.Id;
        d.type = q.Question_Type__c;
        d.level = q.Level__c;
        d.topic = q.Topic__c;
        d.text = q.Question_Text__c;
        d.code = q.Code_Snippet__c;
        d.explanation = q.Explanation__c;
        d.correct = QuestionEngineService.normalize(q.Correct_Answer__c);
        if (q.Question_Type__c == 'TRUE_FALSE') {
            d.options = QuestionEngineService.trueFalseOptions();
        } else if (String.isNotBlank(q.Options_JSON__c)) {
            d.options = (List<AstroDTOs.Option>) JSON.deserialize(q.Options_JSON__c, List<AstroDTOs.Option>.class);
            for (AstroDTOs.Option o : d.options) o.key = String.valueOf(o.key).trim().toUpperCase();
        } else {
            d.options = new List<AstroDTOs.Option>();
        }
        return d;
    }
}