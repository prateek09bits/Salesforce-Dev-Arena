/** Builds profile views from whitelisted fields only. Never touches email, hash, salt or Ids. */
public without sharing class ProfileService {
    static final Set<String> AVATARS = new Set<String>{ 'nova', 'comet', 'orbit', 'rocket', 'alien', 'moon', 'sun', 'galaxy' };

    public static AstroDTOs.ProfileView getProfile(String username, Id viewerContactId) {
        String u = String.isBlank(username) ? '' : username.trim().toLowerCase();
        List<Contact> rows = [
            SELECT Id, Username__c, Display_Name__c, Avatar_Key__c, Bio__c, Is_Profile_Public__c,
                   Total_Score__c, Games_Played__c, Games_Won__c, Best_Streak__c
            FROM Contact WHERE Username__c = :u LIMIT 1
        ];
        if (rows.isEmpty()) throw new AstroException('Profile not found.');
        Contact c = rows[0];
        Boolean owner = viewerContactId != null && viewerContactId == c.Id;
        if (c.Is_Profile_Public__c != true && !owner) throw new AstroException('This profile is private.');
        return build(c, owner);
    }

    public static AstroDTOs.ProfileView updateMyProfile(Id contactId, AstroDTOs.UpdateProfileRequest req) {
        if (req == null) throw new AstroException('Nothing to update.');
        String dn = String.isBlank(req.displayName) ? '' : req.displayName.trim();
        if (!AstroUtil.isSafeName(dn, 30)) throw new AstroException('Display name must be 2-30 characters (letters, numbers, spaces, _ . -).');
        String bio = String.isBlank(req.bio) ? '' : req.bio.trim();
        if (bio.length() > 160) throw new AstroException('Bio can be at most 160 characters.');
        String avatar = AVATARS.contains(req.avatarKey) ? req.avatarKey : 'nova';

        Contact c = [
            SELECT Id, Username__c, Display_Name__c, Avatar_Key__c, Bio__c, Is_Profile_Public__c,
                   Total_Score__c, Games_Played__c, Games_Won__c, Best_Streak__c
            FROM Contact WHERE Id = :contactId LIMIT 1
        ];
        c.Display_Name__c = dn;
        c.LastName = dn;
        c.Bio__c = bio;
        c.Avatar_Key__c = avatar;
        c.Is_Profile_Public__c = req.isPublic != false;
        update c;
        return build(c, true);
    }

    static AstroDTOs.ProfileView build(Contact c, Boolean owner) {
        AstroDTOs.ProfileView p = new AstroDTOs.ProfileView();
        p.username = c.Username__c;
        p.displayName = c.Display_Name__c;
        p.avatarKey = c.Avatar_Key__c;
        p.bio = c.Bio__c;
        p.isPublic = c.Is_Profile_Public__c;
        p.isOwner = owner;
        Integer score = AstroUtil.nz(c.Total_Score__c).intValue();
        Integer games = AstroUtil.nz(c.Games_Played__c).intValue();
        Integer wins = AstroUtil.nz(c.Games_Won__c).intValue();
        Integer streak = AstroUtil.nz(c.Best_Streak__c).intValue();
        p.totalScore = score;
        p.gamesPlayed = games;
        p.gamesWon = wins;
        p.bestStreak = streak;
        p.winRate = games == 0 ? 0 : Math.round(100.0 * wins / games);
        p.rank = score <= 0 ? null : [
            SELECT COUNT() FROM Contact WHERE Is_Profile_Public__c = true AND Username__c != null AND Total_Score__c > :score
        ] + 1;

        p.badges = new List<AstroDTOs.Badge>();
        if (games >= 1) p.badges.add(badge('first-game', 'First launch', '🚀'));
        if (wins >= 1) p.badges.add(badge('first-win', 'First win', '🏆'));
        if (games >= 10) p.badges.add(badge('regular', 'Regular', '🔭'));
        if (streak >= 5) p.badges.add(badge('streak', 'Hot streak', '⚡'));
        if (score >= 1000) p.badges.add(badge('rising', 'Rising star', '🌟'));
        if (score >= 5000) p.badges.add(badge('legend', 'Constellation', '👑'));

        p.recentGames = new List<AstroDTOs.RecentGame>();
        for (Leaderboard_Entry__c e : [
            SELECT Topic__c, Level__c, Score__c, Rank__c, CreatedDate FROM Leaderboard_Entry__c
            WHERE Contact__c = :c.Id ORDER BY CreatedDate DESC LIMIT 10
        ]) {
            AstroDTOs.RecentGame g = new AstroDTOs.RecentGame();
            g.topic = e.Topic__c;
            g.level = e.Level__c;
            g.score = AstroUtil.nz(e.Score__c).intValue();
            g.rank = AstroUtil.nz(e.Rank__c).intValue();
            g.playedAt = e.CreatedDate;
            p.recentGames.add(g);
        }
        return p;
    }

    static AstroDTOs.Badge badge(String key, String label, String icon) {
        AstroDTOs.Badge b = new AstroDTOs.Badge();
        b.key = key;
        b.label = label;
        b.icon = icon;
        return b;
    }
}