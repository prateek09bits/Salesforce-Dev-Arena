/** Opaque session tokens. Only a SHA-256 hash is stored (cache + Auth_Session__c). */
public without sharing class SessionService {
    static final Integer TTL_DAYS = 7;
    static final Integer CACHE_TTL_SECS = 3600;

    public static String create(Id contactId) {
        String token = AuthService.randomHex();
        String hash = AuthService.sha256(token);
        insert new Auth_Session__c(
            Token_Hash__c = hash, Contact__c = contactId,
            Expires_At__c = System.now().addDays(TTL_DAYS), Last_Used_At__c = System.now()
        );
        AstroCache.put(cacheKey(hash), String.valueOf(contactId), CACHE_TTL_SECS);
        return token;
    }

    /** Returns the Contact Id for a valid token, else null. Sliding expiry, touched at most hourly. */
    public static Id resolve(String token) {
        if (String.isBlank(token) || token.length() < 32) return null;
        String hash = AuthService.sha256(token);
        String key = cacheKey(hash);

        Object cached = AstroCache.get(key);
        if (cached != null) return (Id) String.valueOf(cached);

        List<Auth_Session__c> rows = [
            SELECT Id, Contact__c, Expires_At__c, Last_Used_At__c
            FROM Auth_Session__c WHERE Token_Hash__c = :hash LIMIT 1
        ];
        if (rows.isEmpty()) return null;
        Auth_Session__c s = rows[0];
        if (s.Expires_At__c < System.now()) {
            delete s;
            return null;
        }
        if (s.Last_Used_At__c == null || s.Last_Used_At__c < System.now().addHours(-1)) {
            s.Last_Used_At__c = System.now();
            s.Expires_At__c = System.now().addDays(TTL_DAYS);
            update s;
        }
        AstroCache.put(key, String.valueOf(s.Contact__c), CACHE_TTL_SECS);
        return s.Contact__c;
    }

    public static void revoke(String token) {
        if (String.isBlank(token)) return;
        String hash = AuthService.sha256(token);
        AstroCache.remove(cacheKey(hash));
        delete [SELECT Id FROM Auth_Session__c WHERE Token_Hash__c = :hash];
    }

    static String cacheKey(String hash) {
        return 's' + hash.substring(0, 40); // cache keys: alphanumeric, max 50 chars
    }
}