import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/core/utils/pota_activity.dart';
import 'package:wavelog_mobile/data/models/qso_model.dart';

QsoModel qso(DateTime at,
        {int station = 1, String? myPota, String? pota}) =>
    QsoModel(
      callsign: 'SP1ABC',
      dateTimeOn: at,
      band: '40m',
      mode: 'SSB',
      rstSent: '59',
      rstRcvd: '59',
      stationProfileId: station,
      rawAdif: {
        if (myPota != null) 'MY_POTA_REF': myPota,
        if (pota != null) 'POTA_REF': pota,
      },
    );

void main() {
  final today = DateTime.utc(2026, 10, 24, 12);
  final yesterday = DateTime.utc(2026, 10, 23, 23, 59);

  test('a comma-separated POTA value gives each park', () {
    expect(potaRefsOf('pl-0001, PL-0002 ,'), ['PL-0001', 'PL-0002']);
    expect(potaRefsOf(null), isEmpty);
  });

  test("a QSO's park: its MY_POTA_REF, else its station location's", () {
    final refs = {1: 'PL-0341', 2: ''};
    expect(activatedParksOf(qso(today, myPota: 'PL-0001'), refs), ['PL-0001']);
    expect(activatedParksOf(qso(today), refs), ['PL-0341']);
    expect(activatedParksOf(qso(today, station: 2), refs), isEmpty);
  });

  test('the activation counts only that park on the same UTC day', () {
    final log = [
      qso(today), // station 1 is in PL-0341
      qso(today.add(const Duration(hours: 1))),
      qso(yesterday), // the day before, UTC
      qso(today, myPota: 'PL-0001'), // logged from another park
      qso(today, station: 2), // home station
    ];
    expect(
        potaActivationCount(
            log: log,
            park: 'pl-0341',
            stationPotaRefs: {1: 'PL-0341'},
            day: DateTime.utc(2026, 10, 24, 23)),
        2);
  });

  test('hunted parks are the POTA_REF of every QSO', () {
    final log = [
      qso(today, pota: 'PL-0194'),
      qso(today, pota: 'PL-0001,PL-0002'),
      qso(today, myPota: 'PL-0341'), // activated, not hunted
    ];
    expect(huntedParks(log), {'PL-0194', 'PL-0001', 'PL-0002'});
  });
}
