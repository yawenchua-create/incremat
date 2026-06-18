/// Clinical reference for the 30-Second Chair Stand Test (30CST), part of the
/// Rikli & Jones Senior Fitness Test.
///
/// Protocol: seated, arms crossed over the chest, count the number of full
/// sit-to-stands completed in 30 seconds. MORE reps = better (a measure of
/// lower-body strength). Scoring below the age/sex-typical range indicates
/// below-average strength and a higher fall risk.
enum ChairStandRating { belowAverage, average, aboveAverage }

/// Biological sex, used to pick the correct 30CST norm band. [unspecified]
/// falls back to a gender-neutral average of the male/female ranges.
enum Sex { male, female, unspecified }

Sex sexFromName(String? name) =>
    Sex.values.where((s) => s.name == name).firstOrNull ?? Sex.unspecified;

class ChairStand {
  /// Age/sex-typical "normal" range of stands in 30s (Rikli & Jones norms):
  /// below [low] is below average (higher fall risk); above [high] is above
  /// average.
  // Returns a Dart *record* `({int low, int high})` — a lightweight anonymous
  // struct of two named fields, so callers write `range.low` / `range.high`
  // without us defining a whole class. The nested `if (age >= ...)` ladders read
  // the norm bands top-down; the first matching threshold wins.
  static ({int low, int high}) normalRange(int age, Sex sex) {
    switch (sex) {
      case Sex.male:
        if (age >= 90) return (low: 7, high: 12);
        if (age >= 85) return (low: 8, high: 14);
        if (age >= 80) return (low: 10, high: 15);
        if (age >= 75) return (low: 11, high: 17);
        if (age >= 70) return (low: 12, high: 17);
        if (age >= 65) return (low: 12, high: 18);
        return (low: 14, high: 19);
      case Sex.female:
        if (age >= 90) return (low: 4, high: 11);
        if (age >= 85) return (low: 8, high: 13);
        if (age >= 80) return (low: 9, high: 14);
        if (age >= 75) return (low: 10, high: 15);
        if (age >= 70) return (low: 10, high: 15);
        if (age >= 65) return (low: 11, high: 16);
        return (low: 12, high: 17);
      case Sex.unspecified:
        if (age >= 90) return (low: 6, high: 11);
        if (age >= 85) return (low: 8, high: 13);
        if (age >= 80) return (low: 9, high: 14);
        if (age >= 75) return (low: 10, high: 16);
        if (age >= 70) return (low: 11, high: 16);
        if (age >= 65) return (low: 12, high: 17);
        return (low: 13, high: 18);
    }
  }

  static ChairStandRating rate(int reps, int age, Sex sex) {
    final range = normalRange(age, sex);
    if (reps < range.low) return ChairStandRating.belowAverage;
    if (reps > range.high) return ChairStandRating.aboveAverage;
    return ChairStandRating.average;
  }

  /// A gentle starting daily rep goal derived from 30s capacity: roughly double
  /// the test count (a manageable daily volume spread across the day), rounded
  /// to the nearest 5 and clamped to the app's goal range. A starting
  /// suggestion the caregiver can adjust.
  static int recommendedDailyGoal(int reps) {
    final raw = reps * 2;
    final rounded = (raw / 5).round() * 5;
    return rounded.clamp(10, goalMax);
  }

  /// Daily rep goal bounds used across the app (slider, validators, clamps).
  static const int goalMin = 5;
  static const int goalMax = 100;

  /// How often the test should be repeated.
  static const Duration retestInterval = Duration(days: 30);

  /// Whether a (re)test is due: never tested, or it has been a month.
  static bool isRetestDue(DateTime? lastTestAt) {
    if (lastTestAt == null) return true;
    return DateTime.now().difference(lastTestAt) >= retestInterval;
  }
}
