import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/core/dxcc/dxcc_prefix_matcher.dart';
import 'package:wavelog_mobile/core/utils/worked_before.dart';
import 'package:wavelog_mobile/data/models/dxcc_entity_model.dart';
import 'package:wavelog_mobile/data/models/qso_model.dart';

QsoModel qso(String call, String band, String mode, DateTime at,
        {String? dxcc, String? submode}) =>
    QsoModel(
      callsign: call,
      dateTimeOn: at,
      band: band,
      mode: mode,
      submode: submode,
      rstSent: '59',
      rstRcvd: '59',
      dxcc: dxcc,
      stationProfileId: 1,
    );

DxccEntity entity(int adif, String name, String prefix) => DxccEntity(
    adif: adif, name: name, prefix: prefix, cqZone: 0, ituZone: 0);

void main() {
  // The matcher loads the bundled cty.dat table through rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = DateTime.utc(2026, 10, 24, 12);
  final lastYear = DateTime.utc(2025, 5, 1, 10);
  // As downloaded through the v2 API: no DXCC field, only the callsign.
  final log = [
    qso('DL1ABC', '20m', 'SSB', lastYear),
    qso('DL2XYZ', '40m', 'CW', lastYear),
    qso('SQ4DX', '40m', 'SSB', today.subtract(const Duration(hours: 2))),
    qso('OK1AAA', '20m', 'MFSK', lastYear, submode: 'FT4'),
    qso('VK2ABC', '20m', 'SSB', lastYear, dxcc: '150'), // has its own DXCC
  ];
  late DxccPrefixMatcher matcher;
  late WorkedIndex index;

  setUpAll(() async {
    matcher = await DxccPrefixMatcher.build([
      entity(230, 'Fed. Rep. of Germany', 'DL'),
      entity(269, 'Poland', 'SP'),
      entity(503, 'Czech Republic', 'OK'),
      entity(339, 'Japan', 'JA'),
    ]);
    index = WorkedIndex.build([
      for (final q in log)
        (call: q.callsign, dxcc: q.dxcc, band: q.band, mode: q.mode, submode: q.submode),
    ], matcher);
  });

  WorkedStatus check(String call, String band, String mode,
          {String? dxccId, DateTime? day, bool withIndex = true}) =>
      workedStatus(
        log: log,
        index: withIndex ? index : null,
        callsign: call,
        entity: dxccEntityOf(call, dxccId, matcher),
        band: band,
        mode: mode,
        day: day ?? today,
      );

  test('the entity comes from the QSO DXCC field, else the prefix', () {
    expect(dxccEntityOf('SQ4DX', null, matcher), 269);
    expect(dxccEntityOf('sp/dl1abc', null, matcher), 269);
    expect(dxccEntityOf('DL1ABC/P', null, matcher), 230);
    expect(dxccEntityOf('DL1ABC', '269', matcher), 269);
    expect(dxccEntityOf('XX1XX', null, matcher), isNull);
  });

  test('a QSO without a DXCC field still counts for its country', () {
    // Another Polish prefix (SP vs the logged SQ) is not a new country,
    // also when the lookup supplies the entity id.
    expect(check('SP4ABC', '40m', 'SSB').isEmpty, isTrue);
    expect(check('SP4ABC', '40m', 'SSB', dxccId: '269').isEmpty, isTrue);
  });

  test('an entity never worked is a new country', () {
    final s = check('JA1XYZ', '20m', 'SSB');
    expect(s.newCountry, isTrue);
    expect(s.newBand, isFalse);
    expect(s.newMode, isFalse);
    expect(check('VK3XYZ', '20m', 'SSB', dxccId: '150').isEmpty, isTrue);
  });

  test('worked entity: new band and new mode flagged separately', () {
    expect(check('DL5NEW', '15m', 'SSB').newBand, isTrue);
    expect(check('DL5NEW', '15m', 'SSB').newMode, isFalse);
    expect(check('DL5NEW', '20m', 'FM').newMode, isTrue);
    expect(check('DL5NEW', '20m', 'FM').newBand, isFalse);
    expect(check('DL5NEW', '40m', 'CW').isEmpty, isTrue);
  });

  test('a mode stored as the ADIF submode counts (FT4 as MFSK/FT4)', () {
    expect(check('OK2BBB', '20m', 'FT4').isEmpty, isTrue);
  });

  test('without the index (no DXCC catalog yet) only the dupe check runs', () {
    expect(check('JA1XYZ', '20m', 'SSB', withIndex: false).isEmpty, isTrue);
    expect(check('SQ4DX', '40m', 'SSB', withIndex: false).dupe, isTrue);
  });

  test('same call, band and mode on the same UTC day is a dupe', () {
    expect(check('sq4dx', '40m', 'SSB').dupe, isTrue);
    expect(check('SQ4DX', '20m', 'SSB').dupe, isFalse);
    expect(check('SQ4DX', '40m', 'CW').dupe, isFalse);
    expect(
        check('SQ4DX', '40m', 'SSB', day: DateTime.utc(2026, 10, 25, 1)).dupe,
        isFalse);
    expect(check('DL1ABC', '20m', 'SSB').dupe, isFalse); // last year
  });
}
