/**
 * Room lifecycle + the game clock.
 * The game is a pure function of time: question i runs for N seconds, then a short reveal, then question i+1.
 * No per-tick DML; every poll just recomputes the phase from Game_Started_At__c.
 */
public without sharing class GameRoomService {
    public static final String REJOIN = 'REJOIN_REQUIRED';
    static final Integer MAX_PLAYERS = 20;
    static final Integer REVEAL_SECS = 6;
    static final Integer START_DELAY_SECS = 4;
    static final Integer ROOM_HOURS = 4;
    static final String CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    static final Set<String> LEVELS = new Set<String>{ 'Beginner', 'Intermediate', 'Advanced' };
    static final Set<String> TOPICS = new Set<String>{ 'Any', 'Apex', 'LWC', 'SOQL', 'Flows', 'Integration', 'Security', 'Data Modeling', 'Admin' };
    static final Set<String> TYPES = new Set<String>{ 'MCQ_SINGLE', 'MCQ_MULTI', 'TRUE_FALSE', 'CODE_OUTPUT', 'SCENARIO' };

    class Timing {
        Integer index;
        String phase;
        Long endsAt;
    }

    // ------------------------------------------------------------------ create
 public static AstroDTOs.JoinResult createRoom(Id contactId, AstroDTOs.CreateRoomRequest req, Boolean useEinstein) {
    if (req == null || !LEVELS.contains(req.level) || !TOPICS.contains(req.topic)) {
        throw new AstroException('Please choose a valid level and topic.');
    }
    List<String> chosenTypes = new List<String>();
    if (req.types != null) {
        for (String t : req.types) {
            if (TYPES.contains(t) && !chosenTypes.contains(t)) chosenTypes.add(t);
        }
    }
    if (chosenTypes.isEmpty()) throw new AstroException('Pick at least one question type.');

    Integer count = Math.min(Math.max(req.count == null ? 10 : req.count, 3), 30);
    Integer secs = Math.min(Math.max(req.secondsPerQuestion == null ? 20 : req.secondsPerQuestion, 10), 60);
    Boolean solo = req.solo == true;
    String nick = resolveNickname(contactId, req.nickname);

    AstroDTOs.QuestionCriteria c = new AstroDTOs.QuestionCriteria();
    c.level = req.level;
    c.topic = req.topic;
    c.types = chosenTypes;
    c.count = count;
        List<AstroDTOs.QuestionData> questions = QuestionEngineService.pick(c, contactId, useEinstein);

        Game_Room__c room = new Game_Room__c(
            Room_Code__c = newCode(), Status__c = solo ? 'Active' : 'Lobby',
Level__c = req.level, Topic__c = req.topic, Types__c = String.join(chosenTypes, ','),            Question_Count__c = questions.size(), Seconds_Per_Question__c = secs, Is_Solo__c = solo,
            Questions_JSON__c = JSON.serialize(questions), Expires_At__c = System.now().addHours(ROOM_HOURS)
        );
        if (solo) room.Game_Started_At__c = System.now().addSeconds(START_DELAY_SECS);
        insert room;
        return addPlayer(room, contactId, nick, true);
    }

    // -------------------------------------------------------------------- join
    public static AstroDTOs.JoinResult joinRoom(Id contactId, String code, String nickname, String existingToken) {
        Game_Room__c room = loadRoom(code, false);
        if (room.Status__c == 'Finished') throw new AstroException('This game has already finished.');

        // Reconnect with a known player token
        if (String.isNotBlank(existingToken)) {
            List<Player__c> known = [
                SELECT Id, Nickname__c FROM Player__c
                WHERE Game_Room__c = :room.Id AND Token_Hash__c = :AuthService.sha256(existingToken) LIMIT 1
            ];
            if (!known.isEmpty()) return joinResult(room.Room_Code__c, existingToken, known[0]);
        }
        // A logged-in contact reconnects as the same player (token is rotated)
        if (contactId != null) {
            List<Player__c> mine = [SELECT Id, Nickname__c FROM Player__c WHERE Game_Room__c = :room.Id AND Contact__c = :contactId LIMIT 1];
            if (!mine.isEmpty()) {
                String fresh = AuthService.randomHex();
                mine[0].Token_Hash__c = AuthService.sha256(fresh);
                update mine[0];
                return joinResult(room.Room_Code__c, fresh, mine[0]);
            }
        }
        if (room.Status__c != 'Lobby') throw new AstroException('This game has already started.');
        if (room.Is_Solo__c) throw new AstroException('That is a solo game.');

        String nick = resolveNickname(contactId, nickname);
        List<Player__c> players = [SELECT Nickname__c FROM Player__c WHERE Game_Room__c = :room.Id];
        if (players.size() >= MAX_PLAYERS) throw new AstroException('This room is full.');
        for (Player__c p : players) {
            if (p.Nickname__c.toLowerCase() == nick.toLowerCase()) throw new AstroException('That nickname is taken in this room.');
        }
        return addPlayer(room, contactId, nick, false);
    }

    // ------------------------------------------------------------------- start
    public static void startGame(String code, String playerToken) {
        Game_Room__c room = loadRoom(code, true);
        Player__c me = authPlayer(room, playerToken);
        if (me.Is_Host__c != true) throw new AstroException('Only the host can start the game.');
        if (room.Status__c != 'Lobby') return;
        room.Status__c = 'Active';
        room.Game_Started_At__c = System.now().addSeconds(START_DELAY_SECS);
        update room;
    }

    // ------------------------------------------------------------------- state
    public static AstroDTOs.RoomState getState(String code, String playerToken) {
        Game_Room__c room = loadRoom(code, false);
        Player__c me = authPlayer(room, playerToken);
        List<AstroDTOs.QuestionData> qs = parseQuestions(room);
        Integer total = qs.size();

        AstroDTOs.RoomState s = new AstroDTOs.RoomState();
        s.code = room.Room_Code__c;
        s.total = total;
        s.secondsPerQuestion = room.Seconds_Per_Question__c.intValue();
        s.level = room.Level__c;
        s.topic = room.Topic__c;
        s.isSolo = room.Is_Solo__c;
        s.isHost = me.Is_Host__c;
        s.myPlayerId = me.Id;
        s.serverNow = System.now().getTime();
        s.index = 0;
        s.phaseEndsAt = 0;

        String status = room.Status__c;
        Timing t;
        if (status == 'Active') {
            t = timing(room, total);
            if (t.phase == 'FINISHED') {
                finishRoom(room.Room_Code__c);
                status = 'Finished';
            }
        }
        s.status = status;
        if (status == 'Lobby') {
            s.phase = 'LOBBY';
        } else if (status == 'Finished') {
            s.phase = 'FINISHED';
            s.index = total;
        } else {
            s.phase = t.phase;
            s.index = t.index;
            s.phaseEndsAt = t.endsAt;
        }

        // Current question
        Set<Id> answered = new Set<Id>();
        if (s.phase == 'QUESTION' || s.phase == 'REVEAL') {
            Answer__c mine;
            for (Answer__c a : [
                SELECT Player__c, Answer_Value__c, Is_Correct__c, Points__c FROM Answer__c
                WHERE Game_Room__c = :room.Id AND Question_Index__c = :s.index
            ]) {
                answered.add(a.Player__c);
                if (a.Player__c == me.Id) mine = a;
            }
            AstroDTOs.QuestionData q = qs[s.index];
            s.question = toView(q);
            if (s.phase == 'REVEAL') { // correct answer is never sent before reveal
                s.correctAnswer = q.correct;
                s.explanation = q.explanation;
            }
            if (mine != null) {
                s.myAnswer = mine.Answer_Value__c;
                s.myIsCorrect = mine.Is_Correct__c;
                s.myPoints = AstroUtil.nz(mine.Points__c).intValue();
            }
        }

        // Scoreboard
        s.players = new List<AstroDTOs.PlayerView>();
        for (Player__c p : [
            SELECT Id, Nickname__c, Score__c, Streak__c, Is_Host__c FROM Player__c
            WHERE Game_Room__c = :room.Id ORDER BY Score__c DESC, CreatedDate ASC LIMIT 50
        ]) {
            AstroDTOs.PlayerView v = new AstroDTOs.PlayerView();
            v.id = p.Id;
            v.nickname = p.Nickname__c;
            v.score = AstroUtil.nz(p.Score__c).intValue();
            v.streak = AstroUtil.nz(p.Streak__c).intValue();
            v.isHost = p.Is_Host__c;
            v.isMe = p.Id == me.Id;
            v.answered = answered.contains(p.Id);
            s.players.add(v);
        }

        // Review (only after the game)
        if (s.phase == 'FINISHED') {
            Map<Integer, Answer__c> byIndex = new Map<Integer, Answer__c>();
            for (Answer__c a : [
                SELECT Question_Index__c, Answer_Value__c, Is_Correct__c, Points__c FROM Answer__c WHERE Player__c = :me.Id
            ]) byIndex.put(a.Question_Index__c.intValue(), a);
            s.reviews = new List<AstroDTOs.ReviewItem>();
            for (Integer i = 0; i < total; i++) {
                AstroDTOs.QuestionData q = qs[i];
                Answer__c a = byIndex.get(i);
                AstroDTOs.ReviewItem r = new AstroDTOs.ReviewItem();
                r.index = i;
                r.text = q.text;
                r.code = q.code;
                r.options = q.options;
                r.correct = q.correct;
                r.explanation = q.explanation;
                r.myAnswer = a == null ? null : a.Answer_Value__c;
                r.isCorrect = a != null && a.Is_Correct__c == true;
                r.points = a == null ? 0 : AstroUtil.nz(a.Points__c).intValue();
                s.reviews.add(r);
            }
        }
        return s;
    }

    // ------------------------------------------------------------------ answer
    public static Boolean submitAnswer(String code, String playerToken, Integer questionIndex, String answer) {
        Game_Room__c room = loadRoom(code, false);
        Player__c me = authPlayer(room, playerToken);
        if (room.Status__c != 'Active') throw new AstroException('The game is not running.');

        List<AstroDTOs.QuestionData> qs = parseQuestions(room);
        Timing t = timing(room, qs.size());
        if (t.phase != 'QUESTION' || t.index != questionIndex) throw new AstroException('Time is up for this question.');

        AstroDTOs.QuestionData q = qs[t.index];
        String given = QuestionEngineService.normalize(answer);
        if (String.isBlank(given)) throw new AstroException('Choose an answer first.');
        Set<String> validKeys = new Set<String>();
        for (AstroDTOs.Option o : q.options) validKeys.add(o.key);
        for (String k : given.split(',')) if (!validKeys.contains(k)) throw new AstroException('Invalid answer.');
        if (q.type != 'MCQ_MULTI' && given.contains(',')) throw new AstroException('Pick one answer.');

        Integer secs = room.Seconds_Per_Question__c.intValue();
        Long msLeft = t.endsAt - System.now().getTime();
        Boolean correct = given == q.correct;
        Integer streakAfter = correct ? AstroUtil.nz(me.Streak__c).intValue() + 1 : 0;
        Integer points = correct ? ScoreCalculationService.points(q.level, msLeft, secs * 1000, streakAfter) : 0;

        try {
            insert new Answer__c(
                Game_Room__c = room.Id, Player__c = me.Id, Question_Index__c = questionIndex,
                Answer_Key__c = me.Id + '-' + questionIndex, Answer_Value__c = given,
                Is_Correct__c = correct, Points__c = points, Time_Ms__c = (secs * 1000) - msLeft
            );
        } catch (DmlException e) {
            throw new AstroException('You already answered this question.');
        }
        me.Score__c = AstroUtil.nz(me.Score__c) + points;
        me.Streak__c = streakAfter;
        me.Best_Streak__c = Math.max(AstroUtil.nz(me.Best_Streak__c).intValue(), streakAfter);
        update me;

        // Everyone has answered -> jump straight to the reveal (solo players never wait out the timer)
        Integer answers = [SELECT COUNT() FROM Answer__c WHERE Game_Room__c = :room.Id AND Question_Index__c = :questionIndex];
        Integer players = [SELECT COUNT() FROM Player__c WHERE Game_Room__c = :room.Id];
        if (answers >= players) {
            Long cycle = (secs + REVEAL_SECS) * 1000L;
            Long newStart = System.now().getTime() - (questionIndex * cycle + secs * 1000L);
            room.Game_Started_At__c = Datetime.newInstance(newStart);
            update room;
        }
        return true;
    }

    // ----------------------------------------------------------------- helpers
    static void finishRoom(String code) {
        Game_Room__c locked = loadRoom(code, true);
        if (locked.Status__c == 'Finished') return;
        locked.Status__c = 'Finished';
        update locked;
        LeaderboardService.finalizeRoom(locked);
    }

    static Timing timing(Game_Room__c room, Integer total) {
        Timing t = new Timing();
        Long now = System.now().getTime();
        Long start = room.Game_Started_At__c.getTime();
        Integer secs = room.Seconds_Per_Question__c.intValue();
        Long cycle = (secs + REVEAL_SECS) * 1000L;

        if (now < start) {
            t.index = 0;
            t.phase = 'STARTING';
            t.endsAt = start;
            return t;
        }
        Long elapsed = now - start;
        Integer idx = AstroUtil.floorDiv(elapsed, cycle).intValue();
        if (idx >= total) {
            t.index = total;
            t.phase = 'FINISHED';
            t.endsAt = 0;
            return t;
        }
        Long within = elapsed - (idx * cycle);
        t.index = idx;
        if (within < secs * 1000L) {
            t.phase = 'QUESTION';
            t.endsAt = start + (idx * cycle) + (secs * 1000L);
        } else {
            t.phase = 'REVEAL';
            t.endsAt = start + ((idx + 1) * cycle);
        }
        return t;
    }

    static Game_Room__c loadRoom(String code, Boolean lock) {
        String c = String.isBlank(code) ? '' : code.trim().toUpperCase();
        List<Game_Room__c> rows;
        if (lock) {
            rows = [
                SELECT Id, Room_Code__c, Status__c, Level__c, Topic__c, Seconds_Per_Question__c, Is_Solo__c,
                       Questions_JSON__c, Game_Started_At__c, Expires_At__c
                FROM Game_Room__c WHERE Room_Code__c = :c LIMIT 1 FOR UPDATE
            ];
        } else {
            rows = [
                SELECT Id, Room_Code__c, Status__c, Level__c, Topic__c, Seconds_Per_Question__c, Is_Solo__c,
                       Questions_JSON__c, Game_Started_At__c, Expires_At__c
                FROM Game_Room__c WHERE Room_Code__c = :c LIMIT 1
            ];
        }
        if (rows.isEmpty() || rows[0].Expires_At__c < System.now()) throw new AstroException('Room not found or expired.');
        return rows[0];
    }

    static Player__c authPlayer(Game_Room__c room, String token) {
        if (String.isBlank(token)) throw new AstroException(REJOIN);
        String hash = AuthService.sha256(token);
        List<Player__c> rows = [
            SELECT Id, Contact__c, Nickname__c, Score__c, Streak__c, Best_Streak__c, Is_Host__c
            FROM Player__c WHERE Game_Room__c = :room.Id AND Token_Hash__c = :hash LIMIT 1
        ];
        if (rows.isEmpty()) throw new AstroException(REJOIN);
        return rows[0];
    }

    static AstroDTOs.JoinResult addPlayer(Game_Room__c room, Id contactId, String nick, Boolean host) {
        String token = AuthService.randomHex();
        Player__c p = new Player__c(
            Game_Room__c = room.Id, Contact__c = contactId, Nickname__c = nick,
            Token_Hash__c = AuthService.sha256(token), Score__c = 0, Streak__c = 0, Best_Streak__c = 0, Is_Host__c = host
        );
        insert p;
        return joinResult(room.Room_Code__c, token, p);
    }

    static AstroDTOs.JoinResult joinResult(String code, String token, Player__c p) {
        AstroDTOs.JoinResult r = new AstroDTOs.JoinResult();
        r.code = code;
        r.playerToken = token;
        r.playerId = p.Id;
        r.nickname = p.Nickname__c;
        return r;
    }

    static String resolveNickname(Id contactId, String raw) {
        String n = String.isBlank(raw) ? null : raw.trim();
        if (n == null && contactId != null) {
            Contact c = [SELECT Display_Name__c, Username__c FROM Contact WHERE Id = :contactId LIMIT 1];
            n = String.isBlank(c.Display_Name__c) ? c.Username__c : c.Display_Name__c;
            if (n != null && n.length() > 20) n = n.substring(0, 20).trim();
        }
        if (!AstroUtil.isSafeName(n, 20)) {
            throw new AstroException('Nickname must be 2-20 characters (letters, numbers, spaces, _ . -).');
        }
        return n;
    }

    static String newCode() {
        for (Integer attempt = 0; attempt < 6; attempt++) {
            String code = '';
            for (Integer i = 0; i < 6; i++) {
                Integer idx = Math.mod(Math.abs(Crypto.getRandomLong()), CODE_CHARS.length()).intValue();
                code += CODE_CHARS.substring(idx, idx + 1);
            }
            if ([SELECT COUNT() FROM Game_Room__c WHERE Room_Code__c = :code] == 0) return code;
        }
        throw new AstroException('Could not create a room right now. Please try again.');
    }

    static List<AstroDTOs.QuestionData> parseQuestions(Game_Room__c room) {
        return (List<AstroDTOs.QuestionData>) JSON.deserialize(room.Questions_JSON__c, List<AstroDTOs.QuestionData>.class);
    }

    static AstroDTOs.QuestionView toView(AstroDTOs.QuestionData q) {
        AstroDTOs.QuestionView v = new AstroDTOs.QuestionView();
        v.type = q.type;
        v.level = q.level;
        v.topic = q.topic;
        v.text = q.text;
        v.code = q.code;
        v.multi = q.type == 'MCQ_MULTI';
        v.options = q.options;
        return v;
    }
}