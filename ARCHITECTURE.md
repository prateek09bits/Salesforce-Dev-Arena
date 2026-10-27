# AstroQuiz — Architecture Document

> **Last updated:** October 2026  
> **Org:** `salesforce-quizorg` (Developer Edition)  
> **Site:** `Salesforce_Dev_Arena1` — Experience Cloud, LWR, "Build Your Own" theme  
> **API version:** 60  

---

## Table of Contents

1. [Overview](#1-overview)
2. [System Diagram](#2-system-diagram)
3. [LWC Layer — Frontend](#3-lwc-layer--frontend)
4. [Apex Controller Layer](#4-apex-controller-layer)
5. [Service Layer](#5-service-layer)
6. [Question Provider Pattern](#6-question-provider-pattern)
7. [Data Model](#7-data-model)
8. [Session & Authentication](#8-session--authentication)
9. [Game Flow & Clock Model](#9-game-flow--clock-model)
10. [Scoring](#10-scoring)
11. [Leaderboard & History](#11-leaderboard--history)
12. [Rate Limiting & Caching](#12-rate-limiting--caching)
13. [Background Jobs](#13-background-jobs)
14. [AI / Agentforce Integration](#14-ai--agentforce-integration)
15. [Security Model](#15-security-model)
16. [Key Design Decisions](#16-key-design-decisions)
17. [Known Constraints & Gotchas](#17-known-constraints--gotchas)
18. [File Inventory](#18-file-inventory)

---

## 1. Overview

AstroQuiz is a **real-time multiplayer and solo quiz game** built entirely on Salesforce:

- **Frontend:** Lightning Web Components (LWC) on an Experience Cloud LWR site. No external JS frameworks.
- **Backend:** Apex classes — no platform-level flows for gameplay, pure Apex services.
- **Player identity:** Registered players are stored as **`Contact` records** (no Salesforce `User` accounts, no Experience Cloud licences needed). Guests leave no permanent records.
- **Questions:** Served from the `Quiz_Question__c` custom object bank. An AI generation path (Einstein / Agentforce) is implemented but currently switched off, ready to be wired up.
- **Clock:** The game is a **pure function of time** — the server derives the current question and phase from `Game_Started_At__c` on every poll. No per-tick DML, no async processes during gameplay.

---

## 2. System Diagram

```
╔══════════════════════════════════════════════════════════════════╗
║              Browser  (Experience Cloud LWR Site)                ║
║                                                                  ║
║  ┌────────────── quizShell (container + router) ──────────────┐  ║
║  │  quizHome   quizSetup   quizArena   quizProfile  quizTheme │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║        │ localStorage / sessionStorage (token cache)             ║
╚════════╪═════════════════════════════════════════════════════════╝
         │  @AuraEnabled imperative calls (session token on every req)
         ▼
╔══════════════════════════════════════════════════════════════════╗
║              Apex Controller Layer  (thin routing)               ║
║                                                                  ║
║  AstroAuthController    AstroGameController                      ║
║  AstroProfileController GuestPlayerController                    ║
║  QuizArenaController    QuizSetupController                      ║
╚═════════╪════════════════════════════════════════════════════════╝
          │  Direct method calls
          ▼
╔══════════════════════════════════════════════════════════════════╗
║                       Service Layer                              ║
║                                                                  ║
║  AuthService        SessionService       GameRoomService         ║
║  QuestionEngineService  LeaderboardService  ProfileService       ║
║  ScoreCalculationService  LLMService                             ║
║  RateLimiter  AstroCache  AstroDTOs  AstroUtil                   ║
╚═════════╪════════════════════════════════════════════════════════╝
          │
          ├── Question Provider (Strategy Pattern)
          │     DbQuestionProvider        ← ACTIVE (reads Quiz_Question__c)
          │     EinsteinQuestionProvider  ← STUB   (Agentforce callout)
          │
          ▼
╔══════════════════════════════════════════════════════════════════╗
║                    Salesforce Data Layer                         ║
║                                                                  ║
║  Contact (extended)   Auth_Session__c    Game_Room__c            ║
║  Player__c            Answer__c          Quiz_Question__c        ║
║  Leaderboard_Entry__c User_Question_History__c                   ║
║  Study_Material__c    AI_Generation_Log__c                       ║
║  Quiz_Config__mdt     Question_Type_Prompt__mdt                  ║
╚══════════════════════════════════════════════════════════════════╝
          │  (future)
          ▼
╔══════════════════════════════════════════════════════════════════╗
║            Agentforce Agent  (to be built)                       ║
║                                                                  ║
║  Action 1: QuestionBankInvocable  (BUILT ✓)                      ║
║  Action 2: Prompt Template → Einstein LLM  (TODO)                ║
║  Action 3: Persist questions Invocable     (TODO)                ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## 3. LWC Layer — Frontend

All LWC components live in `force-app/main/default/lwc/`.

### Component Roles

| Component | Role |
|---|---|
| `quizShell` | **Root container & router.** Owns `sessionToken`, navigation via `lightning/navigation`, auth forms (login / register), toast notifications. Dropped on every LWR page. |
| `quizHome` | Landing page — start solo or multiplayer |
| `quizSetup` | Game configuration (level, topic, types, count), room creation, join by code, lobby waiting screen |
| `quizArena` | **Live gameplay.** Polls `getRoomState` every 2 s, renders question + timer ring, scoreboard, reveals and final results |
| `quizProfile` | Player profile, badges, recent games, global leaderboard |
| `quizTheme` | CSS custom properties / design tokens injected at root |
| `wrapperDemo` | Dev sandbox — not used in production |

### LWR Named Pages

| Page API Name | URL | Component |
|---|---|---|
| `Home` | `/` | quizShell + quizHome |
| `Login__c` | `/login` | quizShell (auth tab) |
| `Play__c` | `/play` | quizShell + quizSetup |
| `Room__c` | `/room?code=XXXXXX` | quizShell + quizArena |
| `Profile__c` | `/profile?u=username` | quizShell + quizProfile |

### State Ownership

```
quizShell owns:
  sessionToken  ← localStorage 'astroquiz.session' (persisted across browser sessions)
  me            ← ContactSummary { username, displayName, avatarKey }
  playerToken   ← sessionStorage 'astroquiz.player.<CODE>' (per tab)
  page          ← derived from CurrentPageReference URL
  params        ← URL state (code, mode, u, tab)

quizArena owns:
  s             ← latest RoomState from server
  selected      ← current answer selection (array of option keys)
  offset        ← clock skew (serverNow - Date.now()) for countdown accuracy
  remainingMs   ← countdown, updated every 200 ms by setInterval
```

### LWC Architecture Rules

- **Never `@import` another component in CSS** — LWR + Locker treats it as a JS class import and crashes with "Class constructor cannot be invoked without 'new'".
- **No platform-scoped imports** (`@salesforce/user/*`, `@salesforce/community/*`, `lightning/navigation`) in game components — breaks LWR guest rendering.
- **All Apex calls are imperative** — no `@wire` to Apex in game components (polling requires manual control).
- **Session token passed on every server call** — no Salesforce user context assumed.
- **Client clock sync** — `offset = serverNow - Date.now()`. All countdowns use `phaseEndsAt - (Date.now() + offset)`.

---

## 4. Apex Controller Layer

Controllers are **thin routing layers**: apply rate limiting, parse inputs, delegate to services, wrap exceptions. Zero business logic.

### Controllers

| Class | Endpoints |
|---|---|
| `AstroAuthController` | `register`, `login`, `logout`, `restoreSession` |
| `AstroGameController` | `createRoom`, `joinRoom`, `startGame`, `getRoomState`, `submitAnswer` |
| `AstroProfileController` | `getProfile`, `updateProfile`, `getLeaderboard` |
| `GuestPlayerController` | Guest-specific endpoints |
| `QuizArenaController` | Arena thin wrapper |
| `QuizSetupController` | Setup thin wrapper |

### The AI Switch

```apex
// AstroGameController.cls — line 14
@TestVisible private static final Boolean USE_EINSTEIN = false;
// false = DbQuestionProvider (reads Quiz_Question__c)
// true  = EinsteinQuestionProvider (HTTP POST to Agentforce via Named Credential)
```

### Error Handling Pattern

```apex
try {
    // business logic
} catch (AuraHandledException e) {
    throw e;               // re-throw: preserves the original message
} catch (Exception e) {
    throw AstroUtil.wrap(e); // wraps as AuraHandledException
}
```

> **Why:** Re-wrapping an `AuraHandledException` replaces its message with a generic one. The double-catch prevents that.

---

## 5. Service Layer

All service classes: `without sharing`, API 60.

### `AuthService`

| Method | Description |
|---|---|
| `register(username, password, displayName)` | Validate, create `Contact` (private, no Account), hash password (SHA-256 × 1500 rounds), open session |
| `login(username, password)` | Find Contact, check lockout, compare hashes, reset fail counter on success |
| `sha256(value)` | Hex SHA-256 via `Crypto.generateDigest` |
| `randomHex()` | 256-bit random hex via `Crypto.generateAesKey(256)` |
| `hashPassword(password, salt)` | `sha256(sha256(salt+pw) + salt)` × 1500 rounds |
| `safeEquals(a, b)` | Constant-time XOR comparison (timing-attack resistant) |
| `summaryFor(contactId)` | Returns `ContactSummary` DTO |

**Lockout:** 5 consecutive bad passwords → locked 15 minutes. Error message never reveals which field was wrong.

---

### `SessionService`

Only SHA-256 hashes are ever stored — the raw token is ephemeral.

| Method | Description |
|---|---|
| `create(contactId)` | Generates random token, stores hash in `Auth_Session__c`, caches in Platform Cache (1 hr), returns raw token |
| `resolve(token)` | Hash → cache lookup → DB lookup → sliding 7-day TTL. Returns `Contact.Id` or `null` |
| `revoke(token)` | Removes from cache + deletes `Auth_Session__c` |

---

### `GameRoomService`

Full room lifecycle. The game clock is **derived on every poll** — no per-tick DML.

| Method | Description |
|---|---|
| `createRoom(contactId, req, useEinstein)` | Validate inputs, pick questions, insert `Game_Room__c` + host `Player__c` |
| `joinRoom(contactId, code, nickname, existingToken)` | Reconnect (token), Contact reconnect (rotate token), or new player |
| `startGame(code, playerToken)` | Host only; `Status → Active`, `Game_Started_At__c = now + 4 s` |
| `getState(code, playerToken)` | Compute phase from clock, populate `RoomState` DTO, trigger `finishRoom` if done |
| `submitAnswer(code, playerToken, index, answer)` | Validate phase/timing, insert `Answer__c` (unique key prevents duplicates), update score/streak, short-circuit phase if all answered |
| `finishRoom(code)` | `Status → Finished`, `LeaderboardService.finalizeRoom()` |

**Room code:** 6 characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`. Up to 6 collision-retry attempts.  
**Callout constraint:** Question picking happens before any DML in `createRoom` (callouts cannot follow uncommitted DML).

---

### `QuestionEngineService`

| Method | Description |
|---|---|
| `pick(criteria, contactId, useEinstein)` | Load seen question IDs → get provider → validate each question → return list |
| `isValid(q)` | text, correct, type non-blank; ≥ 2 options; all correct keys in options; no multi-key for non-MCQ_MULTI |
| `normalize(answer)` | `"b, a"` → `"A,B"` (trim, uppercase, sort, comma-join) |
| `trueFalseOptions()` | Returns `[{key:TRUE, label:True}, {key:FALSE, label:False}]` |

---

### `LeaderboardService`

| Method | Description |
|---|---|
| `finalizeRoom(room)` | Upsert Contact stats, insert `Leaderboard_Entry__c` per logged-in player, write `User_Question_History__c` for DB questions |
| `top(limitCount)` | Top N public Contacts by `Total_Score__c` (max 50) |

---

### `ScoreCalculationService`

```
points = base + speedBonus + streakBonus

base:         Beginner=100  Intermediate=150  Advanced=200
speedBonus:   base × 0.5 × (msLeft / totalMs)   [up to 50/75/100]
streakBonus:  min(streak-1, 5) × 10              [up to +50]
```

---

### `LLMService`

Direct Einstein LLM access (separate from Agentforce provider path):

| Method | Model | Use |
|---|---|---|
| `generateText(prompt)` | `sfdc_ai__DefaultGPT4Omni` | Simple text generation |
| `createChatGenerations(userPrompt, systemPrompt)` | `sfdc_ai__DefaultGPT35Turbo` | Chat-style generation |
| `generateResponseFromPromptTemplate(name, params)` | Via Prompt Builder | Template-driven generation |

---

### `RateLimiter`

Fixed-window counters in Platform Cache. Fails open (no cache = no limiting, no errors).

```apex
RateLimiter.hit('room',     bucketKey, 200, 3600); // guest: 200 rooms/hr
RateLimiter.hit('room',     bucketKey,  20, 3600); // member: 20 rooms/hr
RateLimiter.hit('join',     bucketKey,  60,  600); // 60 joins / 10 min
RateLimiter.hit('poll',     bucketKey, 200,   60); // 200 polls / min
RateLimiter.hit('answer',   bucketKey,  60,   60); // 60 answers / min
RateLimiter.hit('login',    username,   15,  600); // 15 login attempts / 10 min
RateLimiter.hit('register', username,    5, 3600); // 5 registrations / hr per username
```

---

### `AstroCache`

Thin wrapper around `Cache.Org` with partition `local.AstroCache`.

- Requires an **Org Cache partition named `AstroCache`** provisioned in Salesforce Setup.
- Fails open silently — `Auth_Session__c` is the durable fallback for sessions.

---

### Supporting Classes

| Class | Purpose |
|---|---|
| `AstroDTOs` | All `@AuraEnabled` request/response inner classes. Correct answers never appear in client-facing DTOs before REVEAL |
| `AstroException` | Extends `AuraHandledException` — preserves message through re-throws |
| `AstroUtil` | `wrap(e)`, `isSafeName(str, maxLen)`, `nz(decimal)`, `floorDiv(long, long)` |
| `ProfileService` | Contact profile read/write, badge logic, recent game history |

---

## 6. Question Provider Pattern

Strategy pattern. The factory returns one of two implementations based on the `USE_EINSTEIN` flag in `AstroGameController`.

```
QuestionProvider  (interface)
  getQuestions(QuestionCriteria c, Set<Id> excludeIds) : List<QuestionData>
       │
       ├── DbQuestionProvider       ← getProvider(false)  [ACTIVE]
       │     Reads Quiz_Question__c WHERE Status__c = 'Approved'
       │     4-pass fallback waterfall (see below)
       │     Fisher-Yates shuffle on each pass
       │
       └── EinsteinQuestionProvider ← getProvider(true)   [STUB — ready to wire]
             HTTP POST  callout:Astro_Agentforce/generate-questions
             Parses JSON: { "questions": [...] }
             Named Credential not yet created in org
```

### `DbQuestionProvider` Fallback Waterfall

```
Pass 1:  Level=X  Types=[...]  Topic=X  NOT IN seen   (preferred: unseen, same topic)
Pass 2:  Level=X  Types=[...]           NOT IN seen   (any topic, unseen)
Pass 3:  Level=X  Types=[...]  Topic=X                (same topic, repeats ok)
Pass 4:  Level=X  Types=[...]                         (any topic, repeats ok)
```

Each pass queries up to 300 rows and shuffles before adding to the result map.

### `EinsteinQuestionProvider` Contract

**Request body (POST):**
```json
{
  "level": "Intermediate",
  "topic": "SOQL",
  "types": ["MCQ_SINGLE", "TRUE_FALSE"],
  "count": 10,
  "instructions": "Write accurate Salesforce developer quiz questions..."
}
```

**Expected response:**
```json
{
  "questions": [
    {
      "type": "MCQ_SINGLE",
      "level": "Intermediate",
      "topic": "SOQL",
      "text": "Which clause limits SOQL results?",
      "code": null,
      "options": [{"key": "A", "label": "LIMIT"}, {"key": "B", "label": "WHERE"}],
      "correct": "A",
      "explanation": "The LIMIT clause restricts the number of rows returned."
    }
  ]
}
```

---

## 7. Data Model

### Custom Objects

```
Contact  (standard — extended with custom fields)
  Username__c          Text(20), unique
  Display_Name__c      Text(30)
  Avatar_Key__c        Text(20)
  Password_Hash__c     Text(64)  — SHA-256 hash only, never raw password
  Password_Salt__c     Text(64)
  Failed_Login_Count__c  Number
  Locked_Until__c      DateTime
  Total_Score__c       Number
  Games_Played__c      Number
  Games_Won__c         Number
  Best_Streak__c       Number
  Is_Profile_Public__c Checkbox

Auth_Session__c
  Token_Hash__c        Text(64), unique   — SHA-256 of raw token
  Contact__c           Lookup → Contact
  Expires_At__c        DateTime
  Last_Used_At__c      DateTime

Game_Room__c
  Room_Code__c         Text(6), unique, external id
  Status__c            Picklist: Lobby | Active | Finished | Expired
  Level__c             Picklist: Beginner | Intermediate | Advanced
  Topic__c             Picklist: Any | Apex | LWC | SOQL | Flows | Integration | Security | Data Modeling | Admin
  Types__c             Text (comma-separated selected question types)
  Question_Count__c    Number
  Seconds_Per_Question__c  Number
  Is_Solo__c           Checkbox
  Questions_JSON__c    LongTextArea  — serialized List<QuestionData> (includes correct answers)
  Game_Started_At__c   DateTime  — the clock origin; all phase math is relative to this
  Expires_At__c        DateTime  — rooms auto-deleted after 4 hours

Player__c  (MasterDetail → Game_Room__c)
  Contact__c           Lookup → Contact  (null = guest)
  Nickname__c          Text(20)
  Token_Hash__c        Text(64)
  Is_Host__c           Checkbox
  Score__c             Number
  Streak__c            Number
  Best_Streak__c       Number

Answer__c
  Game_Room__c         Lookup → Game_Room__c
  Player__c            Lookup → Player__c
  Question_Index__c    Number
  Answer_Key__c        Text   — "{Player_Id}-{Index}" (unique — prevents duplicate answers)
  Answer_Value__c      Text   — "A" or "A,C" (normalized, sorted)
  Is_Correct__c        Checkbox
  Points__c            Number
  Time_Ms__c           Number  — elapsed ms when submitted

Quiz_Question__c  (the question bank)
  Level__c             Picklist: Beginner | Intermediate | Advanced
  Topic__c             Picklist: Apex | LWC | SOQL | ...
  Question_Type__c     Picklist: MCQ_SINGLE | MCQ_MULTI | TRUE_FALSE | CODE_OUTPUT | SCENARIO
  Status__c            Picklist: Draft | Approved | Retired
  Question_Text__c     LongTextArea
  Code_Snippet__c      LongTextArea
  Options_JSON__c      LongTextArea  — JSON array [{"key":"A","label":"..."},...]
  Correct_Answer__c    LongTextArea  — normalized: "A" or "A,C"
  Explanation__c       LongTextArea
  Source__c            Picklist: AI | Manual

Leaderboard_Entry__c
  Contact__c           Lookup → Contact
  Game_Room__c         Lookup → Game_Room__c
  Score__c             Number
  Topic__c             Picklist
  Level__c             Picklist
  Rank__c              Number

User_Question_History__c  (MasterDetail → Quiz_Question__c)
  Contact__c           Lookup → Contact
  Question__c          MasterDetail → Quiz_Question__c
  (used to avoid repeat questions for registered players)

Study_Material__c
  Topic__c, Source_Type__c, Status__c
  Content_Document_Id__c  — for Files/ContentVersion integration
```

### Custom Metadata Types

| Type | Purpose | Key Record |
|---|---|---|
| `Quiz_Config__mdt` | Game tuning — scoring, timing, limits | `Default` |
| `Question_Type_Prompt__mdt` | AI prompt instructions per question type | One per type (5 records) |

### `Quiz_Config__mdt` — Default Record

| Field | Value |
|---|---|
| `Default_Question_Seconds__c` | 20 |
| `Polling_Interval_Ms__c` | 2500 |
| `Room_TTL_Hours__c` | 4 (rooms expire 4 hours after creation) |
| `Min_Bank_Size_Per_Bucket__c` | 20 |
| `Auto_Approve_AI_Questions__c` | false |
| Scoring | Beginner=100, Intermediate=150, Advanced=200 (in service class) |

---

## 8. Session & Authentication

### Registration Flow

```
1. Browser → AstroAuthController.register(username, password, displayName)
2.         → RateLimiter checks (5/hr per username, 300/hr global)
3.         → AuthService.register():
             - Validate username (regex: 3-20 chars, letters/numbers/underscore)
             - Check reserved names, duplicate username
             - Validate password (8-100 chars)
             - Generate salt (randomHex)
             - Hash: sha256(sha256(salt+pw) + salt) × 1500
             - Insert Contact (no Account, private contact)
             - SessionService.create() → insert Auth_Session__c + Platform Cache
             - Return AuthResult { success:true, token, ContactSummary }
4. Browser → store raw token in localStorage['astroquiz.session']
```

### Login Flow

```
1. Browser → AstroAuthController.login(username, password)
2.         → RateLimiter (15 attempts / 10 min per username)
3.         → AuthService.login():
             - Find Contact by Username__c
             - If not found: dummy hash (keep timing similar) + return fail
             - If Locked_Until__c > now: return lockout message
             - hashPassword(attempt, salt) + safeEquals (constant-time)
             - On success: reset fail counter, create new session
             - On fail: increment counter; after 5 fails, lock 15 min
             - Error never reveals which field was wrong
4. Browser → store raw token in localStorage
```

### Per-Request Auth

```
Browser sends sessionToken with every Apex call
  → SessionService.resolve(token):
      sha256(token) → cache lookup (Platform Cache)
      cache miss → Auth_Session__c WHERE Token_Hash__c = hash
      if expired → delete + return null
      if used > 1 hr ago → slide expiry, refresh cache
      → return Contact.Id (or null = guest)
```

### Token Lifecycle

| Token | Stored Where | Lifetime |
|---|---|---|
| Raw session token | `localStorage['astroquiz.session']` | 7 days (sliding) |
| Session hash | `Auth_Session__c.Token_Hash__c` | 7 days (sliding) |
| Session hash | Platform Cache `local.AstroCache.s<hash>` | 1 hr (refreshed on resolve) |
| Raw player token | `sessionStorage['astroquiz.player.<CODE>']` | Browser tab lifetime |
| Player token hash | `Player__c.Token_Hash__c` | Until room is deleted |

---

## 9. Game Flow & Clock Model

### Room Lifecycle

```
createRoom()
  → QuestionEngineService.pick() — questions serialized into Questions_JSON__c
  → Status = 'Lobby' (multiplayer) | 'Active' (solo, clock starts + 4 s)
  → insert Game_Room__c + host Player__c

joinRoom()  [multiplayer only, Status = 'Lobby']
  → Reconnect paths: token match | Contact match | new player

startGame()  [host only]
  → Status → 'Active'
  → Game_Started_At__c = now + 4 s

getRoomState()  [polled every 2 s by every client]
  → Derive phase from clock (see below)
  → Populate RoomState DTO (question without answer, scoreboard)
  → If phase = FINISHED → call finishRoom()

submitAnswer()
  → Validate phase = QUESTION, index matches, answer is valid option key(s)
  → Insert Answer__c (unique key = Player_Id + '-' + index → prevents duplicates)
  → Update Player__c Score + Streak + Best_Streak
  → If all players answered → rewind Game_Started_At__c to skip remaining question time

finishRoom()
  → Status → 'Finished'
  → LeaderboardService.finalizeRoom()

RoomCleanupBatch  (scheduled hourly)
  → Delete Game_Room__c WHERE Expires_At__c < now
  → Cascades: delete Answer__c + Player__c
```

### Phase Timing

```
Game_Started_At__c = T

          T           T+20s     T+26s         T+46s     T+52s
          │ STARTING  │QUESTION │  REVEAL  │ QUESTION │  REVEAL  │ ...
          │ (4s delay)│         │  (6s)    │          │  (6s)    │

cycle  = secondsPerQuestion + REVEAL_SECS (6)
index  = floor((now - T) / cycle)
within = (now - T) mod cycle
phase  = within < secondsPerQuestion ? QUESTION : REVEAL
done   = index >= total ? FINISHED
```

Client adjusts for server/browser clock skew:
```js
offset = serverNow - Date.now()   // on each poll response
remaining = phaseEndsAt - (Date.now() + offset)
// re-poll 150 ms after phase ends
```

---

## 10. Scoring

```
Total = base + speedBonus + streakBonus

base:         Beginner=100   Intermediate=150   Advanced=200

speedBonus:   base × 0.5 × (msLeft / totalMs)
              range: 0 to 50/75/100 depending on level

streakBonus:  min(consecutiveCorrect - 1, 5) × 10
              range: 0 to +50 (after 6+ consecutive correct)
```

Streak resets to 0 on any wrong answer or timeout. `Player__c.Best_Streak__c` tracks peak per game.

---

## 11. Leaderboard & History

### Game Finalization (`LeaderboardService.finalizeRoom`)

1. Query all `Player__c` for the room, ordered by `Score__c DESC`.
2. For each player with a `Contact__c`:
   - Accumulate: `Total_Score__c`, `Games_Played__c`, `Games_Won__c` (rank 1 in multiplayer = win), `Best_Streak__c`.
   - Insert `Leaderboard_Entry__c` with rank.
3. Insert `User_Question_History__c` for each `(contact, question)` pair — **only for questions from the DB bank** (AI-generated questions have no `Quiz_Question__c` Id).

### Global Leaderboard

```sql
SELECT Username__c, Display_Name__c, Avatar_Key__c, Total_Score__c, Games_Played__c, Games_Won__c
FROM Contact
WHERE Is_Profile_Public__c = true AND Username__c != null AND Total_Score__c > 0
ORDER BY Total_Score__c DESC
LIMIT :n
```

---

## 12. Rate Limiting & Caching

### Rate Limit Table

| Action | Limit | Window | Key |
|---|---|---|---|
| Create room (guest) | 200 | 1 hr | sha256(token)[0:24] |
| Create room (logged in) | 20 | 1 hr | same |
| Join room | 60 | 10 min | same |
| Poll state | 200 | 1 min | same |
| Submit answer | 60 | 1 min | same |
| Register (per username) | 5 | 1 hr | lowercase username |
| Register (global) | 300 | 1 hr | `'global'` |
| Login (per username) | 15 | 10 min | lowercase username |

### Platform Cache

- **Partition:** `AstroCache` (Org Cache) — must be provisioned in Setup
- **Key prefix:** `local.AstroCache.`
- **Fail mode:** Open — any `Cache.Org` exception is silently swallowed. `Auth_Session__c` is always the durable source of truth.

---

## 13. Background Jobs

| Class | Type | Purpose |
|---|---|---|
| `RoomCleanupBatch` | `Batchable + Schedulable` | Deletes expired `Game_Room__c` + cascade to `Answer__c` + `Player__c` |
| `SessionCleanupBatch` | `Batchable + Schedulable` | Deletes expired `Auth_Session__c` rows |

> **⚠️ Neither job is currently scheduled in the org.**

### Schedule Commands (Anonymous Apex)

```apex
System.schedule('AstroQuiz Room Cleanup',    '0 0 * * * ?',  new RoomCleanupBatch());
System.schedule('AstroQuiz Session Cleanup', '0 30 * * * ?', new SessionCleanupBatch());
```

---

## 14. AI / Agentforce Integration

### Current Status

| Component | Status | File |
|---|---|---|
| `QuestionBankInvocable` | ✅ **Built** — `@InvocableMethod` for agent action | `QuestionBankInvocable.cls` |
| `EinsteinQuestionProvider` | ✅ **Written** — blocked only by missing Named Credential | `EinsteinQuestionProvider.cls` |
| `QuestionProviderFactory` | ✅ **Built** | `QuestionProviderFactory.cls` |
| `LLMService` | ✅ **Built** | `LLMService.cls` |
| Named Credential `Astro_Agentforce` | ❌ Not created | Salesforce Setup |
| Agentforce Agent | ❌ Not created | Salesforce Setup → Agents |
| Question persistence `@InvocableMethod` | ❌ Not created | New Apex class needed |

### `QuestionBankInvocable` — Agent Action (Built)

`@InvocableMethod` labeled **"Get Question Bank Context"**, category **"AstroQuiz"**.

| Input | Description |
|---|---|
| `topic` | Filter: Apex, LWC, SOQL, etc. Blank = all. |
| `level` | Beginner / Intermediate / Advanced. Blank = all. |
| `questionType` | MCQ_SINGLE, MCQ_MULTI, etc. Blank = all. |
| `maxQuestions` | Max existing questions to return (default 50, max 200) |
| `includeStudyMaterial` | true = also read Files |
| `contentDocumentIds` | Specific file IDs (comma-separated) |
| `titleKeyword` | Filter files by title |
| `maxStudyChars` | Character limit for study text (default 8000, max 30000) |

| Output | Description |
|---|---|
| `existingQuestions` | Numbered list of question texts (for dedup) |
| `existingCount` | Count of returned questions |
| `studyMaterial` | Study text from Files |
| `studyFileCount` | Number of files read |
| `message` | Warnings or errors |

### What Remains to Build

**Step 1 — Salesforce Setup:**
1. Create External Credential → Named Credential `Astro_Agentforce`
2. Grant Named Credential access to the guest/integration permission set

**Step 2 — Build the Agentforce Agent:**
1. Create agent with topic "Generate Salesforce Quiz Questions"
2. Add action: `QuestionBankInvocable.getContext` (existing)
3. Add action: Prompt Template → Einstein LLM (GPT-4 Omni)
4. Agent must return the JSON shape `EinsteinQuestionProvider.parse()` expects

**Step 3 — New Apex (to build):**
```apex
// Agent calls this to persist generated questions
@InvocableMethod(label='Save Generated Questions' category='AstroQuiz')
public static void saveGeneratedQuestions(List<Request> reqs) {
    // insert Quiz_Question__c with Status__c = 'Draft' (or 'Approved' if auto-approve enabled)
}
```

**Step 4 — Flip the switch:**
```apex
// AstroGameController.cls line 14
private static final Boolean USE_EINSTEIN = true;
```

---

## 15. Security Model

| Layer | Mechanism |
|---|---|
| No raw secrets stored | Only SHA-256 hashes of tokens and passwords are persisted |
| Constant-time comparison | `safeEquals()` XORs chars — prevents timing attacks on login |
| Session isolation | Every call requires session token; server hashes it to find Contact |
| Answer integrity | Correct answer is never sent to the client before the REVEAL phase |
| `QuestionData` vs `QuestionView` | `QuestionData` (server-only, has `correct`); `QuestionView` (`@AuraEnabled`, no `correct`) |
| Lockout | 5 failed logins → 15-minute lockout |
| Rate limiting | Platform Cache fixed-window counters on every mutating endpoint |
| Guest isolation | Guest Contact never written; guest user never stamped as owner/player/leaderboard field |
| Input validation | Server-side: nickname regex, email format, picklist allowlists, count clamping |
| `without sharing` | All classes — required for guest/site user context |
| Answer uniqueness | `Answer__c.Answer_Key__c` is unique — prevents double-submit |

---

## 16. Key Design Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Players are `Contact` records, not `User` | No Experience Cloud licences, no profile/permission juggling, no broken LWR imports (`@salesforce/user/*` crashes LWR) |
| D2 | Custom register/login LWC screens | Full UX control; entire site stays public; no platform login page quirks |
| D3 | Login = username + password | Simple; passwords hashed with salt and 1500 rounds; never stored raw |
| D4 | Guests leave no permanent records | Game rooms deleted after expiry; guest never stamped on any field |
| D5 | Clock-derived game state | No per-tick DML; every `getRoomState` poll is a stateless computation from `Game_Started_At__c` |
| D6 | AI via strategy pattern | Flip one boolean to switch providers; game flow code is unchanged |
| D7 | Questions serialized into room JSON | No per-question queries during gameplay; correct answers safe in server-side JSON, never in client DTOs |
| D8 | Platform Cache with fail-open | Rate limiting and session speed without hard dependency; `Auth_Session__c` is always the durable fallback |

---

## 17. Known Constraints & Gotchas

1. **LWR + Locker + CSS `@import`:** `@import 'c/otherComponent'` resolves to the component's JS class → crash "Class constructor cannot be invoked without 'new'". **Never `@import` another LWC in CSS.**

2. **`AuraHandledException` re-wrapping:** Wrapping an existing `AuraHandledException` replaces its message with a generic one. Always re-throw as-is with `catch (AuraHandledException e) { throw e; }` before the generic catch.

3. **Callouts before DML:** `EinsteinQuestionProvider` makes an HTTP callout. This must complete before any DML in the same transaction. `createRoom` already follows this — picks questions first, then inserts room + player.

4. **`without sharing` is mandatory:** Guest/site user has no record access in any sharing model. All classes must be `without sharing`.

5. **`SYSTEM_MODE` in Anonymous Apex:** `Database.queryWithBinds(..., AccessLevel.SYSTEM_MODE)` cannot be used from Anonymous Apex. Service class methods only.

6. **Platform Cache provisioning required:** The `AstroCache` Org Cache partition must be provisioned in Setup → Platform Cache, otherwise rate limiting and session caching silently no-op.

7. **Background jobs not scheduled:** `RoomCleanupBatch` and `SessionCleanupBatch` are implemented but not scheduled. Old rooms and sessions will accumulate.

8. **`Quiz_Question__c` object name:** The `QuestionBankInvocable` references `Quiz_Question__c`. Verify this matches the actual API name in your org (the data model also references `Question__c` in some older docs).

---

## 18. File Inventory

### Apex Classes (custom)

| Class | Lines | Role |
|---|---|---|
| `AstroAuthController` | 43 | Auth controller (@AuraEnabled) |
| `AstroCache` | 18 | Platform Cache wrapper |
| `AstroDTOs` | 155 | All request/response DTOs |
| `AstroException` | ~5 | Custom AuraHandledException |
| `AstroGameController` | 94 | Game controller; has USE_EINSTEIN switch |
| `AstroProfileController` | ~30 | Profile controller |
| `AstroUtil` | ~20 | Utility helpers |
| `AuthService` | 112 | Registration, login, crypto |
| `DbQuestionProvider` | 71 | DB question fetching (active) |
| `EinsteinQuestionProvider` | 81 | Agentforce callout (stub, ready) |
| `GameRoomService` | 394 | Room lifecycle + game clock |
| `GuestPlayerController` | ~40 | Guest-only endpoints |
| `LeaderboardService` | 67 | Score finalization, leaderboard |
| `LLMService` | 167 | Einstein Models API |
| `ProfileService` | ~100 | Contact profile |
| `QuestionBankInvocable` | 185 | @InvocableMethod for Agentforce |
| `QuestionEngineService` | 56 | Question picking + validation |
| `QuestionProvider` | ~5 | Interface |
| `QuestionProviderFactory` | 11 | Strategy factory |
| `RateLimiter` | 12 | Fixed-window rate limiting |
| `RoomCleanupBatch` | 22 | Expired room cleanup |
| `ScoreCalculationService` | 11 | Points formula |
| `SessionCleanupBatch` | ~15 | Expired session cleanup |
| `SessionService` | 55 | Session token management |

### LWC Components

| Component | Role |
|---|---|
| `quizShell` | Root container, router, auth |
| `quizHome` | Landing page |
| `quizSetup` | Game setup, join, lobby |
| `quizArena` | Live gameplay, results |
| `quizProfile` | Profile, leaderboard |
| `quizTheme` | Design tokens |
| `wrapperDemo` | Dev-only sandbox |

### Custom Objects

| Object | Type |
|---|---|
| `Contact` (extended) | Standard + custom fields |
| `Auth_Session__c` | Custom |
| `Game_Room__c` | Custom |
| `Player__c` | Custom (MasterDetail → Game_Room__c) |
| `Answer__c` | Custom |
| `Quiz_Question__c` | Custom (question bank) |
| `Leaderboard_Entry__c` | Custom |
| `User_Question_History__c` | Custom |
| `Study_Material__c` | Custom |
| `AI_Generation_Log__c` | Custom |

### Custom Metadata Types

`Quiz_Config__mdt` · `Question_Type_Prompt__mdt`

### Permission Sets

| Set | Purpose |
|---|---|
| `Quiz_Admin` | Full admin access (all objects + all classes) |
| `Quiz_Guest_Apex_Support` | Guest user: game objects + all classes |
| `Quiz_Internal_ReadOnly` | Read-only across all objects |

### Custom Permissions

`Quiz_Admin_Access` — gates the Question Admin UI (checked in Apex)
