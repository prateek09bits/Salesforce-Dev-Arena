# Custom data model

Everything custom that the AstroQuiz project defines, read from the metadata in `force-app/main/default`. Regenerate it after changing metadata. Sharing, required flags and picklist values are taken straight from the files.

## Summary

| Kind | Count | Names |
|---|---|---|
| Custom objects | 10 | `AI_Generation_Log__c`, `Game_Room__c`, `Leaderboard_Entry__c`, `Material_Chunk__c`, `Player_Answer__c`, `Player__c`, `Question__c`, `Room_Question__c`, `Study_Material__c`, `User_Question_History__c` |
| Custom metadata types | 2 | `Question_Type_Prompt__mdt`, `Quiz_Config__mdt` |
| Standard objects with custom fields | 0 | none |
| Custom fields (all objects above) | 107 | |

# Custom objects

## `AI_Generation_Log__c`

**AI Generation Log** — custom object, sharing: Private, name field: AI Generation Log Name (AutoNumber, format `GL-{000000}`)

Records each AI question generation job, tracking counts, status, duration, and any errors for operational monitoring.

| Field | Label | Type | Details |
|---|---|---|---|
| `Duration_Ms__c` | Duration (ms) | Number | 9,0 |
| `Error__c` | Error | LongTextArea | length 10000 |
| `Inserted_Count__c` | Inserted Count | Number | 5,0 |
| `Level__c` | Level | Picklist | restricted values: Beginner, Intermediate, Advanced |
| `Prompt_Version__c` | Prompt Version | Text | length 30 |
| `Question_Type__c` | Question Type | Picklist | restricted values: MCQ_SINGLE, MCQ_MULTI, TRUE_FALSE, CODE_OUTPUT, SCENARIO |
| `Rejected_Count__c` | Rejected Count | Number | 5,0 |
| `Requested_Count__c` | Requested Count | Number | 5,0 |
| `Status__c` | Status | Picklist | restricted values: Queued, Running, Success, Partial, Failed |
| `Topic__c` | Topic | Picklist | restricted values: Apex, LWC, SOQL, Flows, Integration, Security, Data Modeling, Admin |

## `Game_Room__c`

**Game Room** — custom object, sharing: Private, name field: Game Room Name (AutoNumber, format `GR-{000000}`)

Represents an active or historical quiz game session, holding configuration and state for a multiplayer or solo game.

| Field | Label | Type | Details |
|---|---|---|---|
| `Expires_At__c` | Expires At | DateTime |  |
| `Finished_At__c` | Finished At | DateTime |  |
| `Host_Player__c` | Host Player | Lookup | → Player__c; on delete: SetNull |
| `Level__c` | Level | Picklist | restricted values: Beginner, Intermediate, Advanced |
| `Max_Players__c` | Max Players | Number | 2,0 |
| `Mode__c` | Mode | Picklist | restricted values: Solo, Multiplayer |
| `Question_Count__c` | Question Count | Number | 2,0 |
| `Question_Types__c` | Question Types | MultiselectPicklist | restricted values: MCQ_SINGLE, MCQ_MULTI, TRUE_FALSE, CODE_OUTPUT, SCENARIO |
| `Reveal_Seconds__c` | Reveal Seconds | Number | 2,0 |
| `Room_Code__c` | Room Code | Text | length 6; required; unique; external id |
| `Seconds_Per_Question__c` | Seconds Per Question | Number | 3,0 |
| `Started_At__c` | Started At | DateTime |  |
| `Status__c` | Status | Picklist | restricted values: Lobby, In Progress, Finished, Expired |
| `Topic__c` | Topic | Picklist | restricted values: Apex, LWC, SOQL, Flows, Integration, Security, Data Modeling, Admin |

**Validation rules**

- `Max_Players_Range` (active): Max Players must be between 1 and 20.
- `Question_Count_Range` (active): Question Count must be between 5 and 20.
- `Seconds_Per_Question_Range` (active): Seconds Per Question must be between 5 and 120.
- `Solo_Mode_Max_Players` (active): Solo mode game rooms must have Max Players set to 1.

## `Leaderboard_Entry__c`

**Leaderboard Entry** — custom object, sharing: Private, name field: Leaderboard Entry Name (AutoNumber, format `LB-{000000}`)

Stores a player performance snapshot at game completion for display on the global leaderboard.

| Field | Label | Type | Details |
|---|---|---|---|
| `Correct_Count__c` | Correct Count | Number | 4,0 |
| `Level__c` | Level | Picklist | restricted values: Beginner, Intermediate, Advanced |
| `Mode__c` | Mode | Picklist | restricted values: Solo, Multiplayer |
| `Nickname__c` | Nickname | Text | length 20 |
| `Played_On__c` | Played On | Date |  |
| `Question_Count__c` | Question Count | Number | 4,0 |
| `Room_Code__c` | Room Code | Text | length 10 |
| `Score__c` | Score | Number | 7,0 |
| `Topic__c` | Topic | Picklist | restricted values: Apex, LWC, SOQL, Flows, Integration, Security, Data Modeling, Admin |
| `Unique_Key__c` | Unique Key | Text | length 40; unique; external id |
| `User__c` | User | Lookup | → User; on delete: SetNull |

## `Material_Chunk__c`

**Material Chunk** — custom object, sharing: ControlledByParent, name field: Material Chunk Name (AutoNumber, format `MC-{00000}`)

Stores individual text chunks split from a Study Material record, used as context for AI question generation.

| Field | Label | Type | Details |
|---|---|---|---|
| `Chunk_Index__c` | Chunk Index | Number | 6,0 |
| `Chunk_Text__c` | Chunk Text | LongTextArea | length 32768 |
| `Random_Key__c` | Random Key | Number | 9,8; external id |
| `Study_Material__c` | Study Material | MasterDetail | → Study_Material__c |
| `Use_Count__c` | Use Count | Number | 8,0 |

## `Player_Answer__c`

**Player Answer** — custom object, sharing: ControlledByParent, name field: Player Answer Name (AutoNumber, format `PA-{000000}`)

Stores the answer submitted by a player for a specific question in a game room session. Child of Player__c.

| Field | Label | Type | Details |
|---|---|---|---|
| `Is_Correct__c` | Is Correct | Checkbox | default false |
| `Player__c` | Player | MasterDetail | → Player__c |
| `Points_Awarded__c` | Points Awarded | Number | 5,0 |
| `Response_Time_Ms__c` | Response Time (ms) | Number | 7,0 |
| `Room_Question__c` | Room Question | Lookup | → Room_Question__c; on delete: Restrict; required |
| `Selected_Answer__c` | Selected Answer | LongTextArea | length 1000 |
| `Submitted_At__c` | Submitted At | DateTime |  |
| `Unique_Key__c` | Unique Key | Text | length 100; unique; external id |

## `Player__c`

**Player** — custom object, sharing: ControlledByParent, name field: Player Name (AutoNumber, format `PL-{000000}`)

Represents a participant in a game room session. Child of Game_Room__c via Master-Detail.

| Field | Label | Type | Details |
|---|---|---|---|
| `Correct_Count__c` | Correct Count | Number | 3,0 |
| `Game_Room__c` | Game Room | MasterDetail | → Game_Room__c |
| `Is_Host__c` | Is Host | Checkbox | default false |
| `Last_Seen_At__c` | Last Seen At | DateTime |  |
| `Nickname__c` | Nickname | Text | length 20; required |
| `Score__c` | Score | Number | 7,0 |
| `Status__c` | Status | Picklist | restricted values: Joined, Left, Finished |
| `Streak__c` | Streak | Number | 3,0 |
| `Token_Hash__c` | Token Hash | Text | length 64; required |
| `Unique_Key__c` | Unique Key | Text | length 100; unique; external id |
| `User__c` | User | Lookup | → User |

## `Question__c`

**Question** — custom object, sharing: Private, name field: Question Name (AutoNumber, format `Q-{000000}`)

Stores quiz questions generated by AI or created manually. Each question belongs to a topic and difficulty level.

| Field | Label | Type | Details |
|---|---|---|---|
| `Code_Snippet__c` | Code Snippet | LongTextArea | length 10000 |
| `Correct_Answer__c` | Correct Answer | LongTextArea | length 5000 |
| `Explanation__c` | Explanation | LongTextArea | length 10000 |
| `Level__c` | Level | Picklist | restricted values: Beginner, Intermediate, Advanced |
| `Material_Chunk__c` | Material Chunk | Lookup | → Material_Chunk__c; on delete: SetNull |
| `Options_JSON__c` | Options JSON | LongTextArea | length 10000 |
| `Prompt_Version__c` | Prompt Version | Text | length 30 |
| `Question_Hash__c` | Question Hash | Text | length 64; unique; external id |
| `Question_Text__c` | Question Text | LongTextArea | length 10000 |
| `Question_Type__c` | Question Type | Picklist | restricted values: MCQ_SINGLE, MCQ_MULTI, TRUE_FALSE, CODE_OUTPUT, SCENARIO |
| `Random_Key__c` | Random Key | Number | 9,8; external id |
| `Source__c` | Source | Picklist | restricted values: AI, Manual |
| `Status__c` | Status | Picklist | restricted values: Draft, Approved, Retired |
| `Times_Correct__c` | Times Correct | Number | 9,0 |
| `Times_Served__c` | Times Served | Number | 9,0 |
| `Topic__c` | Topic | Picklist | restricted values: Apex, LWC, SOQL, Flows, Integration, Security, Data Modeling, Admin |

## `Room_Question__c`

**Room Question** — custom object, sharing: ControlledByParent, name field: Room Question Name (AutoNumber, format `RQ-{000000}`)

Represents a question assigned to a specific game room in a particular sequence order. Child of Game_Room__c.

| Field | Label | Type | Details |
|---|---|---|---|
| `Game_Room__c` | Game Room | MasterDetail | → Game_Room__c |
| `Question__c` | Question | Lookup | → Question__c; on delete: Restrict; required |
| `Sequence__c` | Sequence | Number | 2,0; required |
| `Unique_Key__c` | Unique Key | Text | length 100; unique; external id |

## `Study_Material__c`

**Study Material** — custom object, sharing: Private, name field: Study Material Name (Text)

Stores uploaded or pasted study material used as source content for AI question generation.

| Field | Label | Type | Details |
|---|---|---|---|
| `Active__c` | Active | Checkbox | default true |
| `Chunk_Count__c` | Chunk Count | Summary | COUNT of Material_Chunk__c.Study_Material__c |
| `Content_Document_Id__c` | Content Document Id | Text | length 18 |
| `Source_Type__c` | Source Type | Picklist | restricted values: File, Pasted Text |
| `Status__c` | Status | Picklist | restricted values: Uploaded, Processing, Active, Failed |
| `Topic__c` | Topic | Picklist | restricted values: Apex, LWC, SOQL, Flows, Integration, Security, Data Modeling, Admin |

## `User_Question_History__c`

**User Question History** — custom object, sharing: ControlledByParent, name field: History ID (AutoNumber, format `UQH-{00000000}`)

| Field | Label | Type | Details |
|---|---|---|---|
| `Last_Seen_At__c` | Last Seen At | DateTime |  |
| `Question__c` | Question | MasterDetail | → Question__c |
| `Times_Correct__c` | Times Correct | Number | 4,0 |
| `Times_Seen__c` | Times Seen | Number | 4,0 |
| `Unique_Key__c` | Unique Key | Text | length 40; unique; external id |
| `User__c` | User | Lookup | → User; on delete: SetNull |

# Custom metadata types

## `Question_Type_Prompt__mdt`

**Question Type Prompt** — custom metadata type

Stores the AI output-format instructions for each question type, keyed by type identifier. Used by the AI generation Apex class to tailor the prompt per type.

| Field | Label | Type | Details |
|---|---|---|---|
| `Option_Count__c` | Option Count | Number | 2,0 |
| `Output_Instructions__c` | Output Instructions | LongTextArea | length 5000 |
| `Question_Type__c` | Question Type | Text | length 30 |

**Records**

- `CODE_OUTPUT`: Question_Type__c=CODE_OUTPUT; Option_Count__c=4; Output_Instructions__c=Generate a code-output question that shows a snippet of Apex (or SOQL/
- `MCQ_MULTI`: Question_Type__c=MCQ_MULTI; Option_Count__c=5; Output_Instructions__c=Generate a multiple-select question with exactly 5 answer options (A, 
- `MCQ_SINGLE`: Question_Type__c=MCQ_SINGLE; Option_Count__c=4; Output_Instructions__c=Generate a multiple-choice question with exactly 4 answer options (A, 
- `SCENARIO`: Question_Type__c=SCENARIO; Option_Count__c=4; Output_Instructions__c=Generate a scenario-based question that presents a realistic Salesforc
- `TRUE_FALSE`: Question_Type__c=TRUE_FALSE; Option_Count__c=2; Output_Instructions__c=Generate a true/false question with exactly 2 answer options. Return a

## `Quiz_Config__mdt`

**Quiz Config** — custom metadata type

Stores game configuration values (scoring, timing, limits) used by Apex at runtime. Edit the Default record to tune game behaviour without a code deployment.

| Field | Label | Type | Details |
|---|---|---|---|
| `Auto_Approve_AI_Questions__c` | Auto Approve AI Questions | Checkbox | default false |
| `Default_Question_Seconds__c` | Default Question Seconds | Number | 3,0 |
| `Max_Answers_Per_Minute__c` | Max Answers Per Minute | Number | 4,0 |
| `Max_Rooms_Per_Token_Per_Hour__c` | Max Rooms Per Token Per Hour | Number | 3,0 |
| `Min_Bank_Size_Per_Bucket__c` | Min Bank Size Per Bucket | Number | 4,0 |
| `Points_Advanced__c` | Points Advanced | Number | 4,0 |
| `Points_Beginner__c` | Points Beginner | Number | 4,0 |
| `Points_Intermediate__c` | Points Intermediate | Number | 4,0 |
| `Polling_Interval_Ms__c` | Polling Interval (ms) | Number | 5,0 |
| `Room_TTL_Hours__c` | Room TTL Hours | Number | 3,0 |
| `Speed_Bonus_Max__c` | Speed Bonus Max | Number | 4,0 |
| `Streak_Bonus_Cap__c` | Streak Bonus Cap | Number | 4,0 |
| `Streak_Bonus_Per_Step__c` | Streak Bonus Per Step | Number | 3,0 |

**Records**

- `Default`: Points_Beginner__c=10; Points_Intermediate__c=20; Points_Advanced__c=30; Speed_Bonus_Max__c=10; Streak_Bonus_Per_Step__c=2; Streak_Bonus_Cap__c=10; Default_Question_Seconds__c=20; Polling_Interval_Ms__c=2500; Room_TTL_Hours__c=6; Max_Rooms_Per_Token_Per_Hour__c=5; Max_Answers_Per_Minute__c=60; Min_Bank_Size_Per_Bucket__c=20; Auto_Approve_AI_Questions__c=false

# Access

**Custom permissions:** `Quiz_Admin_Access`

- **`Quiz_Admin`** (Quiz Admin): objects: Study_Material__c, Material_Chunk__c, Question__c, AI_Generation_Log__c, User_Question_History__c, Leaderboard_Entry__c, Game_Room__c, Player__c, Room_Question__c, Player_Answer__c; Apex classes: 23
- **`Quiz_Guest_Apex_Support`** (Quiz Guest Apex Support): objects: Game_Room__c, Player__c, Room_Question__c, Player_Answer__c, Question__c; Apex classes: 23
- **`Quiz_Internal_ReadOnly`** (Quiz Internal Read Only): objects: Study_Material__c, Material_Chunk__c, Question__c, AI_Generation_Log__c, User_Question_History__c, Leaderboard_Entry__c, Game_Room__c, Player__c, Room_Question__c, Player_Answer__c; Apex classes: 23

# Other project metadata

- Apex classes (0): 
- LWC bundles (0): 
- Prompt Builder templates: `Generate_Quiz_Question`
