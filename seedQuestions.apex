// Create dummy questions so games can be played right away
List<Question__c> dummyQuestions = new List<Question__c>();

// 1. Single Choice
Question__c q1 = new Question__c();
q1.Status__c = 'Approved';
q1.Level__c = 'Beginner';
q1.Topic__c = 'Apex';
q1.Question_Type__c = 'MCQ_SINGLE';
q1.Question_Text__c = 'What is the maximum number of DML statements per transaction?';
q1.Options_JSON__c = '[{"id":"A","text":"100"},{"id":"B","text":"150"},{"id":"C","text":"200"},{"id":"D","text":"50"}]';
q1.Correct_Answer__c = 'B';
q1.Explanation__c = 'Salesforce limits DML statements to 150 per transaction.';
q1.Random_Key__c = Math.random();
dummyQuestions.add(q1);

// 2. Multi Select
Question__c q2 = new Question__c();
q2.Status__c = 'Approved';
q2.Level__c = 'Intermediate';
q2.Topic__c = 'Apex';
q2.Question_Type__c = 'MCQ_MULTI';
q2.Question_Text__c = 'Which of the following are valid collections in Apex? (Select 2)';
q2.Options_JSON__c = '[{"id":"A","text":"List"},{"id":"B","text":"Array"},{"id":"C","text":"Map"},{"id":"D","text":"Dictionary"}]';
q2.Correct_Answer__c = 'A,C';
q2.Explanation__c = 'Apex supports List, Set, and Map collections.';
q2.Random_Key__c = Math.random();
dummyQuestions.add(q2);

// 3. True/False
Question__c q3 = new Question__c();
q3.Status__c = 'Approved';
q3.Level__c = 'Beginner';
q3.Topic__c = 'Apex';
q3.Question_Type__c = 'TRUE_FALSE';
q3.Question_Text__c = 'A SOQL for loop can process multiple records in chunks to avoid heap limits.';
q3.Options_JSON__c = '[{"id":"A","text":"True"},{"id":"B","text":"False"}]';
q3.Correct_Answer__c = 'A';
q3.Explanation__c = 'SOQL for loops batch records in chunks of 200 to save memory.';
q3.Random_Key__c = Math.random();
dummyQuestions.add(q3);

// 4. Code Output
Question__c q4 = new Question__c();
q4.Status__c = 'Approved';
q4.Level__c = 'Advanced';
q4.Topic__c = 'Apex';
q4.Question_Type__c = 'CODE_OUTPUT';
q4.Question_Text__c = 'What will be printed to the debug log?';
q4.Code_Snippet__c = 'Integer i = 0;\nwhile(i < 3) {\n  i++;\n}\nSystem.debug(i);';
q4.Options_JSON__c = '[{"id":"A","text":"0"},{"id":"B","text":"2"},{"id":"C","text":"3"},{"id":"D","text":"4"}]';
q4.Correct_Answer__c = 'C';
q4.Explanation__c = 'The loop increments i to 3, fails the condition, and then prints 3.';
q4.Random_Key__c = Math.random();
dummyQuestions.add(q4);

// 5. Scenario
Question__c q5 = new Question__c();
q5.Status__c = 'Approved';
q5.Level__c = 'Advanced';
q5.Topic__c = 'LWC';
q5.Question_Type__c = 'SCENARIO';
q5.Question_Text__c = 'You need a component to fetch data from Salesforce on load without user interaction. What is the best practice?';
q5.Options_JSON__c = '[{"id":"A","text":"Call an Apex method imperatively in connectedCallback"},{"id":"B","text":"Use the @wire adapter with an Apex method"},{"id":"C","text":"Use renderedCallback to trigger the fetch"},{"id":"D","text":"Use a disconnectedCallback"}]';
q5.Correct_Answer__c = 'B';
q5.Explanation__c = '@wire is the standard, reactive, and cached approach for fetching data in LWC.';
q5.Random_Key__c = Math.random();
dummyQuestions.add(q5);

insert dummyQuestions;
System.debug('Inserted ' + dummyQuestions.size() + ' dummy questions!');
