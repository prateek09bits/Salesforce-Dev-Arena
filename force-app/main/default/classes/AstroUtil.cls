public without sharing class AstroUtil {

    public static AuraHandledException aura(String msg) {
        AuraHandledException e = new AuraHandledException(msg);
        e.setMessage(msg);
        return e;
    }

    /** Only AstroException messages are shown to users; everything else is generic. */
    public static AuraHandledException wrap(Exception e) {
        if (e instanceof AstroException) return aura(e.getMessage());
        System.debug(LoggingLevel.ERROR, e.getMessage() + '\n' + e.getStackTraceString());
        return aura('Something went wrong. Please try again.');
    }

    public static Long floorDiv(Long a, Long b) {
        return Math.floor(Double.valueOf(a) / Double.valueOf(b)).longValue();
    }

    public static Decimal nz(Decimal d) {
        if (d == null) return 0;
        return d;
    }

    /** Letters, numbers, space, underscore, dot, hyphen. */
    public static Boolean isSafeName(String s, Integer maxLen) {
        if (String.isBlank(s)) return false;
        return Pattern.matches('^[\\p{L}\\p{N} _.\\-]{2,' + maxLen + '}$', s);
    }
}