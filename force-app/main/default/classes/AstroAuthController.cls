public without sharing class AstroAuthController {

    @AuraEnabled
    public static AstroDTOs.AuthResult register(String username, String password, String displayName) {
        try {
            RateLimiter.hit('register-all', 'global', 300, 3600);
            RateLimiter.hit('register', String.valueOf(username).toLowerCase(), 5, 3600);
            return AuthService.register(username, password, displayName);
        } catch (Exception e) {
            throw AstroUtil.wrap(e);
        }
    }

    @AuraEnabled
    public static AstroDTOs.AuthResult login(String username, String password) {
        try {
            RateLimiter.hit('login', String.valueOf(username).toLowerCase(), 15, 600);
            return AuthService.login(username, password);
        } catch (Exception e) {
            throw AstroUtil.wrap(e);
        }
    }

    @AuraEnabled
    public static void logout(String token) {
        try {
            SessionService.revoke(token);
        } catch (Exception e) {
            throw AstroUtil.wrap(e);
        }
    }

    /** Returns null (never throws) when the token is missing or expired. */
    @AuraEnabled
    public static AstroDTOs.ContactSummary restoreSession(String token) {
        try {
            Id contactId = SessionService.resolve(token);
            return contactId == null ? null : AuthService.summaryFor(contactId);
        } catch (Exception e) {
            return null;
        }
    }
}