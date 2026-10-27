/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-15-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public without sharing class AstroProfileController {

    @AuraEnabled
    public static AstroDTOs.ProfileView getProfile(String sessionToken, String username) {
        try {
            RateLimiter.hit('profile', String.isBlank(sessionToken) ? 'anon' : sessionToken.left(16), 120, 60);
            return ProfileService.getProfile(username, SessionService.resolve(sessionToken));
        } catch (Exception e) {
            throw AstroUtil.wrap(e);
        }
    }

   @AuraEnabled
public static AstroDTOs.ProfileView updateMyProfile(String sessionToken, String reqJson) {
    try {
        Id contactId = SessionService.resolve(sessionToken);
        if (contactId == null) throw new AstroException('Please log in to edit your profile.');
        AstroDTOs.UpdateProfileRequest req =
            (AstroDTOs.UpdateProfileRequest) JSON.deserialize(reqJson, AstroDTOs.UpdateProfileRequest.class);
        return ProfileService.updateMyProfile(contactId, req);
    } catch (Exception e) {
        throw AstroUtil.wrap(e);
    }
}

    @AuraEnabled
    public static List<AstroDTOs.LeaderboardRow> getLeaderboard(Integer limitCount) {
        try {
            RateLimiter.hit('board', 'all', 600, 60);
            return LeaderboardService.top(limitCount);
        } catch (Exception e) {
            throw AstroUtil.wrap(e);
        }
    }
}