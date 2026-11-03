import '../../data/models/qso_model.dart';

/// QSOs needed from one park on one UTC day for a valid POTA activation.
const kPotaActivationQsos = 10;

/// The park references in an ADIF POTA_REF / MY_POTA_REF value, which is
/// comma-separated for a contact with several parks ("PL-0001,PL-0002").
List<String> potaRefsOf(String? value) => [
      for (final r in (value ?? '').split(','))
        if (r.trim().isNotEmpty) r.trim().toUpperCase(),
    ];

/// The parks [qso] was logged from: its MY_POTA_REF, else the park of its
/// station location ([stationPotaRefs], by station id), as QSOs downloaded
/// without MY_POTA_REF still belong to their location's park.
List<String> activatedParksOf(QsoModel qso, Map<int, String> stationPotaRefs) {
  final own = potaRefsOf(qso.myPota);
  return own.isNotEmpty
      ? own
      : potaRefsOf(stationPotaRefs[qso.stationProfileId]);
}

/// QSOs logged from [park] on [day]'s UTC date.
int potaActivationCount({
  required Iterable<QsoModel> log,
  required String park,
  required Map<int, String> stationPotaRefs,
  required DateTime day,
}) {
  final d = day.toUtc();
  final p = park.trim().toUpperCase();
  var n = 0;
  for (final q in log) {
    final t = q.dateTimeOn.toUtc();
    if (t.year != d.year || t.month != d.month || t.day != d.day) continue;
    if (activatedParksOf(q, stationPotaRefs).contains(p)) n++;
  }
  return n;
}

/// Every park worked from the other side (the QSOs' POTA_REF): the parks
/// hunted so far.
Set<String> huntedParks(Iterable<QsoModel> log) =>
    {for (final q in log) ...potaRefsOf(q.potaRef)};
