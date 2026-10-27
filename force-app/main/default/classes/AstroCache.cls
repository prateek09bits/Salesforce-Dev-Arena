/**
 * Thin Platform Cache wrapper. Requires an Org Cache partition named "AstroCache".
 * Fails open (returns null / does nothing) so the app still works with no cache capacity;
 * Auth_Session__c is the durable source of truth for sessions.
 */
public without sharing class AstroCache {
    static final String PARTITION = 'local.AstroCache.';

    public static Object get(String key) {
        try { return Cache.Org.get(PARTITION + key); } catch (Exception e) { return null; }
    }
    public static void put(String key, Object val, Integer ttlSecs) {
        try { Cache.Org.put(PARTITION + key, val, Math.max(ttlSecs, 300)); } catch (Exception e) { /* fail open */ }
    }
    public static void remove(String key) {
        try { Cache.Org.remove(PARTITION + key); } catch (Exception e) { /* fail open */ }
    }
}