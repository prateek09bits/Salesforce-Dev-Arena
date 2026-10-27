/**
 * Context provider for the question-generation prompt (Prompt Builder, Flow or Agent action).
 * Returns (1) existing question texts so the model avoids duplicates and
 *         (2) study material text read from Files (ContentVersion).
 *
 * Only plain-text files are read: txt, md, csv, json. Apex cannot extract text from PDF or Word,
 * so convert those to .txt or .md before uploading.
 * Each request runs a few queries, so call it with one request at a time (the normal agent/flow case).
 */
public without sharing class QuestionBankInvocable {
    static final Integer DEFAULT_QUESTIONS = 50;
    static final Integer MAX_QUESTIONS = 200;
    static final Integer DEFAULT_CHARS = 8000;
    static final Integer MAX_CHARS = 30000;
    static final Integer MAX_FILES = 5;
    static final Integer MAX_FILE_BYTES = 500000; // keeps heap small: VersionData is loaded into memory
    static final Set<String> TEXT_EXTENSIONS = new Set<String>{ 'txt', 'md', 'csv', 'json' };

    public class Request {
        @InvocableVariable(label='Topic' description='Apex, LWC, SOQL, Flows, Integration, Security, Data Modeling, Admin. Blank or Any = all topics.')
        public String topic;
        @InvocableVariable(label='Level' description='Beginner, Intermediate or Advanced. Blank = all levels.')
        public String level;
        @InvocableVariable(label='Question Type' description='MCQ_SINGLE, MCQ_MULTI, TRUE_FALSE, CODE_OUTPUT or SCENARIO. Blank = all.')
        public String questionType;
        @InvocableVariable(label='Max Existing Questions' description='Default 50, maximum 200.')
        public Integer maxQuestions;
        @InvocableVariable(label='Include Study Material' description='True to also read text from Files.')
        public Boolean includeStudyMaterial;
        @InvocableVariable(label='Content Document Ids' description='Optional, comma separated. Takes priority over the title filter.')
        public String contentDocumentIds;
        @InvocableVariable(label='File Title Contains' description='Optional. If blank, files whose title contains the topic are used.')
        public String titleKeyword;
        @InvocableVariable(label='Max Study Characters' description='Default 8000, maximum 30000.')
        public Integer maxStudyChars;
    }

    public class Response {
        @InvocableVariable(label='Existing Questions' description='Numbered list of question texts already in the bank.')
        public String existingQuestions;
        @InvocableVariable(label='Existing Question Count')
        public Integer existingCount;
        @InvocableVariable(label='Study Material' description='Text from the matching files, trimmed to the character limit.')
        public String studyMaterial;
        @InvocableVariable(label='Study File Count')
        public Integer studyFileCount;
        @InvocableVariable(label='Message' description='Warnings or errors, blank when everything worked.')
        public String message;
    }

    @InvocableMethod(
        label='Get Question Bank Context'
        description='Returns existing quiz questions (to prevent duplicates) and study material text from Files.'
        category='AstroQuiz'
    )
    public static List<Response> getContext(List<Request> requests) {
        List<Response> out = new List<Response>();
        if (requests == null) return out;

        for (Request r : requests) {
            Response res = new Response();
            res.existingQuestions = '';
            res.existingCount = 0;
            res.studyMaterial = '';
            res.studyFileCount = 0;
            List<String> notes = new List<String>();

            try {
                loadQuestions(r, res);
            } catch (Exception e) {
                notes.add('Could not load existing questions: ' + e.getMessage());
            }

            if (r != null && r.includeStudyMaterial == true) {
                try {
                    loadStudyMaterial(r, res, notes);
                } catch (Exception e) {
                    notes.add('Could not load study material: ' + e.getMessage());
                }
            }
            res.message = String.join(notes, ' ');
            out.add(res);
        }
        return out;
    }

    // ------------------------------------------------------------ existing questions
    static void loadQuestions(Request r, Response res) {
        Integer lim = Math.min(Math.max(r.maxQuestions == null ? DEFAULT_QUESTIONS : r.maxQuestions, 1), MAX_QUESTIONS);

        // Drafts count too, so the model does not regenerate questions that are waiting for approval.
        String soql = 'SELECT Question_Text__c FROM Quiz_Question__c WHERE Status__c IN (\'Approved\', \'Draft\')';
        Map<String, Object> binds = new Map<String, Object>();
        if (isSet(r.topic)) {
            soql += ' AND Topic__c = :topic';
            binds.put('topic', r.topic.trim());
        }
        if (isSet(r.level)) {
            soql += ' AND Level__c = :level';
            binds.put('level', r.level.trim());
        }
        if (isSet(r.questionType)) {
            soql += ' AND Question_Type__c = :qtype';
            binds.put('qtype', r.questionType.trim());
        }
        soql += ' ORDER BY CreatedDate DESC LIMIT ' + lim;

        List<SObject> rows = Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);
        List<String> lines = new List<String>();
        for (SObject so : rows) {
            String text = (String) so.get('Question_Text__c');
            if (String.isBlank(text)) continue;
            lines.add((lines.size() + 1) + '. ' + text.replace('\n', ' ').replace('\r', ' ').abbreviate(200));
        }
        res.existingCount = lines.size();
        res.existingQuestions = lines.isEmpty() ? 'None yet.' : String.join(lines, '\n');
    }

    // ------------------------------------------------------------ study material
    static void loadStudyMaterial(Request r, Response res, List<String> notes) {
        Integer maxChars = Math.min(Math.max(r.maxStudyChars == null ? DEFAULT_CHARS : r.maxStudyChars, 500), MAX_CHARS);

        String soql = 'SELECT Title, VersionData FROM ContentVersion '
            + 'WHERE IsLatest = true AND FileExtension IN :exts AND ContentSize < ' + MAX_FILE_BYTES;
        Map<String, Object> binds = new Map<String, Object>{ 'exts' => TEXT_EXTENSIONS };

        Set<Id> docIds = parseIds(r.contentDocumentIds);
        if (!docIds.isEmpty()) {
            soql += ' AND ContentDocumentId IN :docIds';
            binds.put('docIds', docIds);
        } else {
            String keyword = isSet(r.titleKeyword) ? r.titleKeyword.trim() : (isSet(r.topic) ? r.topic.trim() : null);
            if (keyword != null) {
                String safe = keyword.replace('%', '').replace('_', '');
                soql += ' AND Title LIKE :titleLike';
                binds.put('titleLike', '%' + safe + '%');
            }
        }
        soql += ' ORDER BY LastModifiedDate DESC LIMIT ' + MAX_FILES;

        List<SObject> files = Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);
        if (files.isEmpty()) {
            notes.add('No readable text files found (txt, md, csv, json).');
            return;
        }

        String combined = '';
        Integer used = 0;
        for (SObject f : files) {
            Integer remaining = maxChars - combined.length();
            if (remaining < 50) break;
            String body;
            try {
                body = ((Blob) f.get('VersionData')).toString();
            } catch (Exception e) {
                notes.add('Skipped unreadable file: ' + f.get('Title'));
                continue;
            }
            String block = '--- ' + f.get('Title') + ' ---\n' + body.trim() + '\n\n';
            combined += block.left(remaining);
            used++;
        }
        res.studyMaterial = combined.trim();
        res.studyFileCount = used;
        if (combined.length() >= maxChars) notes.add('Study material was trimmed to ' + maxChars + ' characters.');
    }

    // ------------------------------------------------------------ helpers
    static Boolean isSet(String s) {
        return String.isNotBlank(s) && s.trim().toLowerCase() != 'any';
    }

    static Set<Id> parseIds(String csv) {
        Set<Id> ids = new Set<Id>();
        if (String.isBlank(csv)) return ids;
        for (String part : csv.split(',')) {
            try {
                ids.add(Id.valueOf(part.trim()));
            } catch (Exception e) {
                // ignore anything that is not a valid Id
            }
        }
        return ids;
    }
}