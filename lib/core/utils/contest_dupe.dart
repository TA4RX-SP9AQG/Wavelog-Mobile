import '../../data/models/qso_model.dart';

/// What the log already holds for [callsign] in the running contest: the
/// QSO that makes this one a dupe (same band), if any, and the other bands
/// the station was already worked on.
class ContestWorked {
  final QsoModel? dupeOf;
  final List<String> otherBands;

  const ContestWorked({this.dupeOf, this.otherBands = const []});

  bool get isEmpty => dupeOf == null && otherBands.isEmpty;
}

/// How far back a contest without a session (just a contest ID typed in)
/// is taken to reach: covers a 48-hour contest, not last year's edition of
/// the same contest ID.
const kContestWindowWithoutSession = Duration(hours: 48);

/// The exchange fields the v2 QSO list does return, unlike CONTEST_ID.
const _exchangeFields = ['SRX', 'STX', 'SRX_STRING', 'STX_STRING'];

/// Whether [q] belongs to contest [id] (upper-case). The v2 QSO list leaves
/// out CONTEST_ID, so a QSO refreshed from the server has none: such a QSO
/// counts when it carries a contest exchange and, given [stationId], was
/// logged from that station.
bool _inContest(QsoModel q, String id, int? stationId) {
  final qid = q.contestId?.trim().toUpperCase() ?? '';
  if (qid.isNotEmpty) return qid == id;
  if (stationId != null && q.stationProfileId != stationId) return false;
  final raw = q.rawAdif ?? const {};
  return _exchangeFields.any((f) => (raw[f] ?? '').trim().isNotEmpty);
}

/// Checks [callsign] on [band] against the QSOs of contest [contestId]
/// logged from [from] on, from [stationId] when given. One QSO per band is
/// the common contest rule, so the same call on the same band is a dupe;
/// other bands are listed. Calls compare without case.
ContestWorked contestWorked({
  required Iterable<QsoModel> log,
  required String callsign,
  required String band,
  required String contestId,
  required DateTime from,
  int? stationId,
}) {
  final call = callsign.trim().toUpperCase();
  final id = contestId.trim().toUpperCase();
  if (call.isEmpty || id.isEmpty) return const ContestWorked();
  final b = band.toLowerCase();
  final start = from.toUtc();

  QsoModel? dupe;
  final other = <String>{};
  for (final q in log) {
    if (q.callsign.trim().toUpperCase() != call) continue;
    if (!_inContest(q, id, stationId)) continue;
    if (q.dateTimeOn.toUtc().isBefore(start)) continue;
    if (q.band.toLowerCase() == b) {
      if (dupe == null || q.dateTimeOn.isAfter(dupe.dateTimeOn)) dupe = q;
    } else {
      other.add(q.band.toLowerCase());
    }
  }
  return ContestWorked(dupeOf: dupe, otherBands: other.toList()..sort());
}
