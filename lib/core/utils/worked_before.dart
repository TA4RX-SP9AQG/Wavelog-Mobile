import '../../data/models/qso_model.dart';
import '../dxcc/dxcc_prefix_matcher.dart';

/// What the log already holds for the contact being entered: whether its
/// DXCC entity is new overall, on this band or in this mode, and whether
/// the same contact was already logged today (a dupe).
class WorkedStatus {
  final bool newCountry;
  final bool newBand;
  final bool newMode;
  final bool dupe;

  const WorkedStatus({
    this.newCountry = false,
    this.newBand = false,
    this.newMode = false,
    this.dupe = false,
  });

  bool get isEmpty => !newCountry && !newBand && !newMode && !dupe;
}

/// The DXCC entity (ADIF number) of [callsign]: the QSO's own DXCC field
/// when it has one, else the callsign prefix. QSOs downloaded through the
/// v2 API carry no DXCC (nor country), so the prefix is what usually
/// decides — the same way the statistics screen counts DXCC.
int? dxccEntityOf(String callsign, String? dxcc, DxccPrefixMatcher? matcher) {
  final adif = int.tryParse(dxcc?.trim() ?? '');
  if (adif != null && adif > 0) return adif;
  final call = callsign.trim().toUpperCase().split('/').first;
  return call.isEmpty ? null : matcher?.match(call)?.adif;
}

/// Bands and modes (lower-case / upper-case) worked per DXCC entity.
class WorkedIndex {
  final Map<int, Set<String>> bands;
  final Map<int, Set<String>> modes;

  const WorkedIndex(this.bands, this.modes);

  /// Indexes [log]. Pure and sendable, so it can run on a background
  /// isolate for logs of many thousands of QSOs.
  factory WorkedIndex.build(
    Iterable<({String call, String? dxcc, String band, String mode, String? submode})> log,
    DxccPrefixMatcher? matcher,
  ) {
    final bands = <int, Set<String>>{};
    final modes = <int, Set<String>>{};
    for (final q in log) {
      final entity = dxccEntityOf(q.call, q.dxcc, matcher);
      if (entity == null) continue;
      (bands[entity] ??= {}).add(q.band.toLowerCase());
      final m = (modes[entity] ??= {})..add(q.mode.toUpperCase());
      if (q.submode != null && q.submode!.isNotEmpty) {
        m.add(q.submode!.toUpperCase());
      }
    }
    return WorkedIndex(bands, modes);
  }
}

/// Checks the contact being entered — [callsign] in DXCC [entity] on
/// [band]/[mode] — against the log. Country, band and mode come from
/// [index] and need [entity]; without either only the dupe check runs. A
/// dupe is the same callsign, band and mode (or submode) on the same UTC
/// day as [day].
WorkedStatus workedStatus({
  required List<QsoModel> log,
  required WorkedIndex? index,
  required String callsign,
  required int? entity,
  required String band,
  required String mode,
  required DateTime day,
}) {
  final call = callsign.trim().toUpperCase();
  final b = band.toLowerCase();
  final m = mode.toUpperCase();
  final d = day.toUtc();

  var dupe = false;
  for (final q in log) {
    if (q.band.toLowerCase() != b || q.callsign.toUpperCase() != call) continue;
    if (q.mode.toUpperCase() != m && q.submode?.toUpperCase() != m) continue;
    final t = q.dateTimeOn.toUtc();
    if (t.year == d.year && t.month == d.month && t.day == d.day) {
      dupe = true;
      break;
    }
  }

  final bands = entity == null ? null : index?.bands[entity];
  final worked = bands != null;
  return WorkedStatus(
    newCountry: index != null && entity != null && !worked,
    newBand: worked && !bands.contains(b),
    newMode: worked && !(index!.modes[entity]?.contains(m) ?? false),
    dupe: dupe,
  );
}
