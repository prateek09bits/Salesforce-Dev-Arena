/**
 * Generates questions through Einstein / Agentforce. Built for LATER use: the guest user cannot call a
 * Prompt Template directly, so this class calls an Agentforce agent endpoint through a Named Credential.
 *
 * Switch on by passing true to QuestionProviderFactory.getProvider (see AstroGameController.USE_EINSTEIN).
 *
 * TODO when the agent exists:
 *   1. Create Named Credential "Astro_Agentforce" (+ External Credential) and grant the guest-site integration access.
 *   2. Point ENDPOINT_PATH at the agent action / Agent API and adjust buildBody() to its contract.
 *   3. Make the agent return: { "questions": [ { type, level, topic, text, code, options:[{key,label}], correct, explanation } ] }
 *
 * Note: a callout cannot follow uncommitted DML in the same transaction. Question picking runs before any DML in createRoom.
 */
public without sharing class EinsteinQuestionProvider implements QuestionProvider {
    static final String ENDPOINT = 'callout:Astro_Agentforce';
    static final String ENDPOINT_PATH = '/generate-questions';

    public List<AstroDTOs.QuestionData> getQuestions(AstroDTOs.QuestionCriteria c, Set<Id> excludeIds) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT + ENDPOINT_PATH);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(60000);
        req.setBody(buildBody(c));

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (CalloutException e) {
            throw new AstroException('The AI question service is unavailable right now.');
        }
        if (res.getStatusCode() < 200 || res.getStatusCode() > 299) {
            throw new AstroException('The AI question service is unavailable right now.');
        }
        return parse(res.getBody(), c);
    }

    String buildBody(AstroDTOs.QuestionCriteria c) {
        return JSON.serialize(new Map<String, Object>{
            'level' => c.level,
            'topic' => c.topic,
            'types' => c.types,
            'count' => c.count,
            'instructions' => 'Write accurate Salesforce developer quiz questions. Mark exactly the correct option keys. '
                + 'Return JSON only, shaped as {"questions":[{"type","level","topic","text","code","options":[{"key","label"}],"correct","explanation"}]}.'
        });
    }

    List<AstroDTOs.QuestionData> parse(String body, AstroDTOs.QuestionCriteria c) {
        List<AstroDTOs.QuestionData> out = new List<AstroDTOs.QuestionData>();
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(body);
        List<Object> items = (List<Object>) root.get('questions');
        if (items == null) return out;

        for (Object o : items) {
            Map<String, Object> m = (Map<String, Object>) o;
            AstroDTOs.QuestionData q = new AstroDTOs.QuestionData();
            q.type = (String) m.get('type');
            q.level = m.containsKey('level') ? (String) m.get('level') : c.level;
            q.topic = m.containsKey('topic') ? (String) m.get('topic') : c.topic;
            q.text = (String) m.get('text');
            q.code = (String) m.get('code');
            q.explanation = (String) m.get('explanation');
            q.correct = QuestionEngineService.normalize((String) m.get('correct'));
            q.options = new List<AstroDTOs.Option>();
            if (q.type == 'TRUE_FALSE') {
                q.options = QuestionEngineService.trueFalseOptions();
            } else if (m.get('options') != null) {
                for (Object oo : (List<Object>) m.get('options')) {
                    Map<String, Object> om = (Map<String, Object>) oo;
                    AstroDTOs.Option opt = new AstroDTOs.Option();
                    opt.key = String.valueOf(om.get('key')).trim().toUpperCase();
                    opt.label = String.valueOf(om.get('label'));
                    q.options.add(opt);
                }
            }
            out.add(q); // QuestionEngineService.isValid() filters bad ones
        }
        return out;
    }
}