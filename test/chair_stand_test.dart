import 'package:flutter_test/flutter_test.dart';
import 'package:incremat/core/utils/chair_stand.dart';

void main() {
  group('rating (age 71, unspecified → normal range 11–16)', () {
    test('below the range is below average / higher fall risk', () {
      expect(ChairStand.rate(9, 71, Sex.unspecified),
          ChairStandRating.belowAverage);
    });
    test('inside the range is average', () {
      expect(
          ChairStand.rate(13, 71, Sex.unspecified), ChairStandRating.average);
    });
    test('above the range is above average', () {
      expect(ChairStand.rate(18, 71, Sex.unspecified),
          ChairStandRating.aboveAverage);
    });
  });

  group('sex sharpens the ranges (age 71)', () {
    // Male range 12–17, female range 10–15. 11 reps lands differently.
    test('11 reps is below average for a man', () {
      expect(ChairStand.rate(11, 71, Sex.male), ChairStandRating.belowAverage);
    });
    test('11 reps is average for a woman', () {
      expect(ChairStand.rate(11, 71, Sex.female), ChairStandRating.average);
    });
  });

  group('recommended daily goal', () {
    test('about double the test count, rounded to nearest 5', () {
      expect(ChairStand.recommendedDailyGoal(12), 25);
      expect(ChairStand.recommendedDailyGoal(8), 15);
    });
    test('clamped to the 10–100 range', () {
      expect(ChairStand.recommendedDailyGoal(2), 10);
      expect(ChairStand.recommendedDailyGoal(60), 100);
    });
  });

  group('retest due', () {
    test('never tested → due', () {
      expect(ChairStand.isRetestDue(null), isTrue);
    });
    test('tested today → not due', () {
      expect(ChairStand.isRetestDue(DateTime.now()), isFalse);
    });
    test('tested over a month ago → due', () {
      expect(
        ChairStand.isRetestDue(
            DateTime.now().subtract(const Duration(days: 31))),
        isTrue,
      );
    });
  });
}
