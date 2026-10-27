/**
 * Factory for question sources.
 *   getProvider(false) -> DbQuestionProvider       (approved questions already in Quiz_Question__c)
 *   getProvider(true)  -> EinsteinQuestionProvider (Einstein / Agentforce generation, wired up later)
 */
public without sharing class QuestionProviderFactory {
    public static QuestionProvider getProvider(Boolean useEinstein) {
        if (useEinstein == true) return new EinsteinQuestionProvider();
        return new DbQuestionProvider();
    }
}