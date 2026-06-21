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
  // The fields prefixed with `_` are private to this class (Dart's privacy is
  // file-level — `_` means "not visible outside this library").
  int _lastCumulative = 0; // the most recent raw total we saw from the mat
  int _baseline = 0;       // the mat-total at which THIS session's count = 0
  bool _established = false; // have we picked a baseline yet?

  // A getter: read-only access to _lastCumulative from outside.
  int get lastCumulative => _lastCumulative;

  /// Feed a raw cumulative counter value; returns this session's reps (>= 0).
  ///
  /// Core idea: session reps = (mat's running total) − (baseline captured when
  /// the session began). All the branches below just protect that subtraction
  /// from edge cases.
  int onCount(int cumulative) {
    if (cumulative < _lastCumulative) {
      // The total dropped — only possible if the mat rebooted and its counter
      // restarted at 0. Re-baseline at 0 so we count up from here.
      _baseline = 0;
      _established = true;
    }
    _lastCumulative = cumulative;
    if (cumulative == 0) return 0; // nothing done yet
    if (!_established) {
      // First reading after a (re)connect. The mat may have been counting
      // before we connected, so its total could be large. We DON'T want to
      // credit all of that as one giant session, so we set the baseline to
      // (total − 1): this reading counts as exactly 1 rep. The `< 0 ? 0` guard
      // keeps the baseline non-negative.
      _baseline = cumulative - 1 < 0 ? 0 : cumulative - 1;
      _established = true;
    }
    final reps = cumulative - _baseline;
    return reps < 0 ? 0 : reps; // never report a negative count
  }

  /// Re-baseline so subsequent reps start from zero — used on an explicit user
  /// switch, an idle flush, or while a test suppresses logging. Pass [at] to
  /// also set the last-seen count (e.g. when ignoring test reps).
  // `[int? at]` is an OPTIONAL positional parameter (the brackets make it
  // optional; `?` means it can be null). Call `establish()` to re-baseline at
  // the last-seen total, or `establish(123)` to also force the last-seen total.
  void establish([int? at]) {
    if (at != null) _lastCumulative = at;
    // Move the baseline up to "now" → the next reading returns ~0 reps, i.e. the
    // next person starts a fresh session from zero.
    _baseline = _lastCumulative;
    _established = true;
  }
}
