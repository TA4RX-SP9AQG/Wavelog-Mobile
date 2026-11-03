import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/core/utils/contest_dupe.dart';
import 'package:wavelog_mobile/data/models/qso_model.dart';

QsoModel qso(String call, String band, DateTime at,
        {String? contest, Map<String, String> raw = const {}, int station = 1}) =>
    QsoModel(
      callsign: call,
      dateTimeOn: at,
      band: band,
      mode: 'SSB',
      rstSent: '59',
      rstRcvd: '59',
      stationProfileId: station,
      rawAdif: {if (contest != null) 'CONTEST_ID': contest, ...raw},
    );

void main() {
  final start = DateTime.utc(2026, 10, 24, 12);
  final log = [
    qso('SP1ABC', '40m', start.add(const Duration(hours: 1)),
        contest: 'CQ-WW-SSB'),
    qso('SP1ABC', '20m', start.add(const Duration(hours: 2)),
        contest: 'CQ-WW-SSB'),
    qso('SP2XYZ', '40m', start.add(const Duration(hours: 1))), // no contest
    qso('SP3QQQ', '40m', start.subtract(const Duration(days: 365)),
        contest: 'CQ-WW-SSB'), // last year's edition
  ];

  ContestWorked check(String call, String band) => contestWorked(
      log: log, callsign: call, band: band, contestId: 'cq-ww-ssb', from: start);

  test('the same call on the same band in the contest is a dupe', () {
    final w = check('sp1abc', '40m');
    expect(w.dupeOf?.band, '40m');
    expect(w.otherBands, ['20m']);
  });

  test('another band is no dupe but lists where it was worked', () {
    final w = check('SP1ABC', '80m');
    expect(w.dupeOf, isNull);
    expect(w.otherBands, ['20m', '40m']);
  });

  test('QSOs outside the contest or before it started do not count', () {
    expect(check('SP2XYZ', '40m').isEmpty, isTrue);
    expect(check('SP3QQQ', '40m').isEmpty, isTrue);
  });

  test('without a contest ID there is nothing to check', () {
    expect(
        contestWorked(
                log: log,
                callsign: 'SP1ABC',
                band: '40m',
                contestId: '',
                from: start)
            .isEmpty,
        isTrue);
  });

  test('a QSO refreshed from the server (no CONTEST_ID) counts by its exchange',
      () {
    final at = start.add(const Duration(hours: 3));
    final server = [
      qso('SQ4MK', '20m', at, raw: const {'STX_STRING': '15', 'SRX_STRING': '15'}),
      qso('SQ4MK', '40m', at), // no exchange: an ordinary QSO
      qso('SQ4MK', '15m', at, raw: const {'SRX': '7'}, station: 2),
    ];
    final w = contestWorked(
        log: server,
        callsign: 'SQ4MK',
        band: '20m',
        contestId: 'CQ-WW-SSB',
        from: start,
        stationId: 1);
    expect(w.dupeOf?.band, '20m');
    expect(w.otherBands, isEmpty);
  });
}
