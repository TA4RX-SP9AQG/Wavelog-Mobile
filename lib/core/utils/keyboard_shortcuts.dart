// Pure helpers shared by add_qso_screen.dart and contest_log_screen.dart's
// hardware-keyboard shortcut wiring (GitHub issue #48). No Flutter widget
// dependencies, each function is independently testable.

/// Returns the next (or, if [forward] is false, previous) value in [values]
/// relative to [current], wrapping around at either end. Falls back to the
/// first (forward) or last (backward) element if [current] isn't found in
/// [values] at all, rather than throwing, since callers' band/mode state is
/// plain a `String` that could in principle hold a stale/unknown value.
String cycleListValue(List<String> values, String current,
    {required bool forward}) {
  final i = values.indexOf(current);
  if (i == -1) return forward ? values.first : values.last;
  final next = forward ? i + 1 : i - 1;
  return values[next % values.length < 0
      ? next % values.length + values.length
      : next % values.length];
}

/// Matches [input] against [candidates] as a typed command: trimmed,
/// case-insensitive, exact match only (never a prefix/substring match).
/// Exact matching is the deliberate safety boundary that lets this double as
/// a band/mode "quick command" typed into the Callsign field without ever
/// misfiring on a real callsign — every amateur radio callsign contains at
/// least one digit, and none of the band ("160m".."70cm") or mode ("SSB"
/// etc.) tokens do, so there is no real collision risk as long as the match
/// stays exact.
String? _matchCommand(String input, List<String> candidates) {
  final needle = input.trim().toLowerCase();
  if (needle.isEmpty) return null;
  for (final c in candidates) {
    if (c.toLowerCase() == needle) return c;
  }
  return null;
}

/// Matches [input] against [bands] (expected: `kCommonBands`), see
/// [_matchCommand] for the exact-match rationale.
String? matchBandCommand(String input, List<String> bands) =>
    _matchCommand(input, bands);

/// Matches [input] against [modes] (expected: `kCommonModes`), see
/// [_matchCommand] for the exact-match rationale.
String? matchModeCommand(String input, List<String> modes) =>
    _matchCommand(input, modes);
