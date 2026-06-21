import 'package:flutter_test/flutter_test.dart';
import 'package:incremat/core/utils/rep_segmenter.dart';

void main() {
  test('counts up from a fresh start', () {
    final s = RepSegmenter();
    expect(s.onCount(1), 1);
    expect(s.onCount(2), 2);
    expect(s.onCount(3), 3);
  });

  test('a carried-over counter on reconnect does NOT inflate', () {
    // The mat reattaches already at 12; the first reading must count as 1 rep,
    // not a phantom 12-rep session.
    final s = RepSegmenter();
    expect(s.onCount(12), 1);
    expect(s.onCount(13), 2);
  });

  test('counter going backwards (mat reset) re-baselines', () {
    final s = RepSegmenter();
    s.onCount(12);
    s.onCount(13);
    expect(s.onCount(1), 1); // reset to 1 → counts as 1
    expect(s.onCount(2), 2);
  });

  test('establish() restarts counting from zero (user switch / flush)', () {
    final s = RepSegmenter();
    s.onCount(5);
    s.onCount(6); // 2 reps so far
    s.establish(); // new user takes over at count 6
    expect(s.onCount(7), 1);
    expect(s.onCount(8), 2);
  });

  test('establish(at) ignores test reps then resumes', () {
    final s = RepSegmenter();
    s.onCount(3); // 3 reps logged
    // A test runs and the counter advances to 18 while suppressed:
    s.establish(18);
    expect(s.onCount(19), 1); // normal logging resumes from after the test
  });
}
