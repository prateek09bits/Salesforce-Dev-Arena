/** Strategy interface: where questions come from. */
public interface QuestionProvider {
    List<AstroDTOs.QuestionData> getQuestions(AstroDTOs.QuestionCriteria criteria, Set<Id> excludeIds);
}