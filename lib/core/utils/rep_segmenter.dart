/// Turns the mat's single cumulative rep counter into per-session reps.
///
/// The mat reports one ever-increasing total. We track a baseline so each
/// person's session counts from zero, and guard the tricky edges:
///  - **Cold start / reconnect:** the first reading adopts the baseline (and
///    counts as a single rep) instead of treating a carried-over counter as a
///    whole phantom session.
///  - **Mat reset:** the counter going backwards re-baselines from zero.
///  - **User switch / idle flush / test suppression:** [establish] re-baselines
///    at the current count so the next reps start from zero.
class RepSegmenter {
  int _lastCumulative = 0;
  int _baseline = 0;
  bool _established = false;

  int get lastCumulative => _lastCumulative;

  /// Feed a raw cumulative counter value; returns this session's reps (>= 0).
  int onCount(int cumulative) {
    if (cumulative < _lastCumulative) {
      // Counter went backwards → mat reset on reconnect.
      _baseline = 0;
      _established = true;
    }
    _lastCumulative = cumulative;
    if (cumulative == 0) return 0;
    if (!_established) {
      // First reading after a (re)connect: count it as one rep, not the
      // counter's absolute (possibly carried-over) value.
      _baseline = cumulative - 1 < 0 ? 0 : cumulative - 1;
      _established = true;
    }
    final reps = cumulative - _baseline;
    return reps < 0 ? 0 : reps;
  }

  /// Re-baseline so subsequent reps start from zero — used on an explicit user
  /// switch, an idle flush, or while a test suppresses logging. Pass [at] to
  /// also set the last-seen count (e.g. when ignoring test reps).
  void establish([int? at]) {
    if (at != null) _lastCumulative = at;
    _baseline = _lastCumulative;
    _established = true;
  }
}
