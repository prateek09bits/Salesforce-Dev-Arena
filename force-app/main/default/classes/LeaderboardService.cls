public without sharing class LeaderboardService {

    /** Called once when a room finishes (caller holds the room lock). */
    public static void finalizeRoom(Game_Room__c room) {
        List<Player__c> players = [
            SELECT Id, Contact__c, Score__c, Best_Streak__c FROM Player__c
            WHERE Game_Room__c = :room.Id ORDER BY Score__c DESC, CreatedDate ASC
        ];
        Set<Id> contactIds = new Set<Id>();
        for (Player__c p : players) if (p.Contact__c != null) contactIds.add(p.Contact__c);
        if (contactIds.isEmpty()) return;

        Map<Id, Contact> contacts = new Map<Id, Contact>([
            SELECT Id, Total_Score__c, Games_Played__c, Games_Won__c, Best_Streak__c FROM Contact WHERE Id IN :contactIds
        ]);
        List<Leaderboard_Entry__c> entries = new List<Leaderboard_Entry__c>();
        Boolean multiplayer = players.size() > 1;

        for (Integer i = 0; i < players.size(); i++) {
            Player__c p = players[i];
            Contact c = p.Contact__c == null ? null : contacts.get(p.Contact__c);
            if (c == null) continue;
            Decimal score = AstroUtil.nz(p.Score__c);
            c.Total_Score__c = AstroUtil.nz(c.Total_Score__c) + score;
            c.Games_Played__c = AstroUtil.nz(c.Games_Played__c) + 1;
            if (i == 0 && multiplayer && score > 0) c.Games_Won__c = AstroUtil.nz(c.Games_Won__c) + 1;
            c.Best_Streak__c = Math.max(AstroUtil.nz(c.Best_Streak__c), AstroUtil.nz(p.Best_Streak__c));
            entries.add(new Leaderboard_Entry__c(
                Contact__c = c.Id, Game_Room__c = room.Id, Score__c = score,
                Topic__c = room.Topic__c, Level__c = room.Level__c, Rank__c = i + 1
            ));
        }
        update contacts.values();
        insert entries;

        // Remember which questions each logged-in player has seen
        List<User_Question_History__c> history = new List<User_Question_History__c>();
        for (AstroDTOs.QuestionData q : (List<AstroDTOs.QuestionData>) JSON.deserialize(room.Questions_JSON__c, List<AstroDTOs.QuestionData>.class)) {
            if (String.isBlank(q.id)) continue; // AI-generated questions have no bank record
            for (Id cid : contactIds) history.add(new User_Question_History__c(Contact__c = cid, Question__c = q.id));
        }
        if (!history.isEmpty()) Database.insert(history, false); // best effort
    }

    public static List<AstroDTOs.LeaderboardRow> top(Integer limitCount) {
        Integer n = Math.min(Math.max(limitCount == null ? 10 : limitCount, 1), 50);
        List<AstroDTOs.LeaderboardRow> out = new List<AstroDTOs.LeaderboardRow>();
        Integer rank = 1;
        for (Contact c : [
            SELECT Username__c, Display_Name__c, Avatar_Key__c, Total_Score__c, Games_Played__c, Games_Won__c
            FROM Contact
            WHERE Is_Profile_Public__c = true AND Username__c != null AND Total_Score__c > 0
            ORDER BY Total_Score__c DESC LIMIT :n
        ]) {
            AstroDTOs.LeaderboardRow r = new AstroDTOs.LeaderboardRow();
            r.rank = rank++;
            r.username = c.Username__c;
            r.displayName = c.Display_Name__c;
            r.avatarKey = c.Avatar_Key__c;
            r.totalScore = c.Total_Score__c.intValue();
            r.gamesPlayed = AstroUtil.nz(c.Games_Played__c).intValue();
            r.gamesWon = AstroUtil.nz(c.Games_Won__c).intValue();
            out.add(r);
        }
        return out;
    }
}