/** Server-side scoring: level base points + speed bonus (up to 50%) + streak bonus (up to +50). */
public without sharing class ScoreCalculationService {

    public static Integer points(String level, Long msLeft, Integer totalMs, Integer streakAfter) {
        Integer base = level == 'Advanced' ? 200 : (level == 'Intermediate' ? 150 : 100);
        Double ratio = Math.max(0.0, Math.min(1.0, Double.valueOf(msLeft) / Double.valueOf(totalMs)));
        Integer speed = Math.round(base * 0.5 * ratio);
        Integer streak = Math.min(Math.max(streakAfter - 1, 0), 5) * 10;
        return base + speed + streak;
    }
}