/** Fixed-window counters kept in Platform Cache. Fails open if cache is unavailable. */
public without sharing class RateLimiter {

    public static void hit(String bucket, String key, Integer max, Integer windowSecs) {
        Long window = AstroUtil.floorDiv(System.now().getTime(), windowSecs * 1000L);
        String k = 'r' + AuthService.sha256(bucket + ':' + key + ':' + window).substring(0, 30);
        Object cur = AstroCache.get(k);
        Integer n = cur == null ? 0 : Integer.valueOf(String.valueOf(cur));
        if (n >= max) throw new AstroException('Too many requests. Please slow down and try again shortly.');
        AstroCache.put(k, n + 1, windowSecs);
    }
}