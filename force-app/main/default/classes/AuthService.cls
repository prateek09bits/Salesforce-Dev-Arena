public without sharing class AuthService {
    static final Integer ROUNDS = 1500;
    static final Integer MAX_FAILS = 5;
    static final Integer LOCK_MINUTES = 15;
    static final String BAD_LOGIN = 'Invalid username or password.';
    static final Pattern USERNAME_RX = Pattern.compile('^[A-Za-z0-9_]{3,20}$');
    static final Set<String> RESERVED = new Set<String>{
        'admin', 'administrator', 'root', 'system', 'guest', 'support', 'astro', 'astroquiz', 'moderator', 'null', 'undefined'
    };

    // ---------- crypto helpers ----------
    public static String randomHex() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(256));
    }
    public static String sha256(String v) {
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(v)));
    }
    public static String hashPassword(String password, String salt) {
        String h = sha256(salt + password);
        for (Integer i = 0; i < ROUNDS; i++) h = sha256(h + salt);
        return h;
    }
    static Boolean safeEquals(String a, String b) {
        if (a == null || b == null || a.length() != b.length()) return false;
        Integer diff = 0;
        for (Integer i = 0; i < a.length(); i++) diff = diff | (a.charAt(i) ^ b.charAt(i));
        return diff == 0;
    }

    // ---------- register ----------
    public static AstroDTOs.AuthResult register(String username, String password, String displayName) {
        String u = String.isBlank(username) ? '' : username.trim().toLowerCase();
        if (!USERNAME_RX.matcher(u).matches()) throw new AstroException('Username must be 3-20 characters: letters, numbers or underscore.');
        if (RESERVED.contains(u)) throw new AstroException('That username is reserved.');
        if (String.isBlank(password) || password.length() < 8 || password.length() > 100) throw new AstroException('Password must be at least 8 characters.');
        String dn = String.isBlank(displayName) ? u : displayName.trim();
        if (!AstroUtil.isSafeName(dn, 30)) throw new AstroException('Display name must be 2-30 characters (letters, numbers, spaces, _ . -).');
        if (![SELECT Id FROM Contact WHERE Username__c = :u LIMIT 1].isEmpty()) throw new AstroException('That username is already taken.');

        String salt = randomHex();
        Contact c = new Contact(
            LastName = dn, Username__c = u, Display_Name__c = dn, Avatar_Key__c = 'nova',
            Password_Salt__c = salt, Password_Hash__c = hashPassword(password, salt),
            Is_Profile_Public__c = true, Total_Score__c = 0, Games_Played__c = 0, Games_Won__c = 0, Best_Streak__c = 0,
            Failed_Login_Count__c = 0, Last_Login_At__c = System.now()
        );
        try { insert c; } catch (DmlException e) { throw new AstroException('That username is already taken.'); }
        return ok(c.Id, c);
    }

    // ---------- login ----------
    // Failures are RETURNED (not thrown) so the failed-attempt counter is committed.
    public static AstroDTOs.AuthResult login(String username, String password) {
        String u = String.isBlank(username) ? '' : username.trim().toLowerCase();
        List<Contact> rows = [
            SELECT Id, Username__c, Display_Name__c, Avatar_Key__c, Password_Hash__c, Password_Salt__c,
                   Failed_Login_Count__c, Locked_Until__c
            FROM Contact WHERE Username__c = :u LIMIT 1
        ];
        String pw = password == null ? '' : password;
        if (rows.isEmpty()) {
            hashPassword(pw, 'dummy-salt'); // keep timing similar
            return fail(BAD_LOGIN);
        }
        Contact c = rows[0];
        if (c.Locked_Until__c != null && c.Locked_Until__c > System.now()) {
            return fail('Too many failed attempts. Try again in a few minutes.');
        }
        String attempt = hashPassword(pw, c.Password_Salt__c == null ? '' : c.Password_Salt__c);
        if (!safeEquals(attempt, c.Password_Hash__c)) {
            Integer fails = (c.Failed_Login_Count__c == null ? 0 : c.Failed_Login_Count__c.intValue()) + 1;
            c.Failed_Login_Count__c = fails;
            if (fails >= MAX_FAILS) {
                c.Locked_Until__c = System.now().addMinutes(LOCK_MINUTES);
                c.Failed_Login_Count__c = 0;
            }
            update c;
            return fail(BAD_LOGIN);
        }
        c.Failed_Login_Count__c = 0;
        c.Locked_Until__c = null;
        c.Last_Login_At__c = System.now();
        update c;
        return ok(c.Id, c);
    }

    // ---------- helpers ----------
    public static AstroDTOs.ContactSummary summaryFor(Id contactId) {
        Contact c = [SELECT Username__c, Display_Name__c, Avatar_Key__c FROM Contact WHERE Id = :contactId LIMIT 1];
        return summary(c);
    }
    static AstroDTOs.ContactSummary summary(Contact c) {
        AstroDTOs.ContactSummary s = new AstroDTOs.ContactSummary();
        s.username = c.Username__c;
        s.displayName = c.Display_Name__c;
        s.avatarKey = c.Avatar_Key__c;
        return s;
    }
    static AstroDTOs.AuthResult ok(Id contactId, Contact c) {
        AstroDTOs.AuthResult r = new AstroDTOs.AuthResult();
        r.success = true;
        r.token = SessionService.create(contactId);
        r.contact = summary(c);
        return r;
    }
    static AstroDTOs.AuthResult fail(String msg) {
        AstroDTOs.AuthResult r = new AstroDTOs.AuthResult();
        r.success = false;
        r.message = msg;
        return r;
    }
}