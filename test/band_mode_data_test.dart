import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/core/constants/band_mode_data.dart';
import 'package:wavelog_mobile/core/utils/keyboard_shortcuts.dart';
import 'package:wavelog_mobile/core/utils/validators.dart';

void main() {
  group('the microwave bands', () {
    test('every band can be chosen, has a calling frequency, and is found '
        'again from it', () {
      for (final b in kCommonBands) {
        final centre = kBandCenterFreqMhz[b];
        expect(centre, isNotNull, reason: '$b has no frequency');
        expect(getBandFromFreq(centre!), b, reason: '$b at $centre MHz');
      }
    });

    test('13cm: 2352 MHz, the frequency of the ATV report, is 13cm', () {
      expect(kCommonBands, contains('13cm'));
      expect(getBandFromFreq(2352), '13cm');
      expect(bandFromKhz(2352000), '13cm');
    });

    test('the bands follow one another, longest wavelength first', () {
      final centres = [for (final b in kCommonBands) kBandCenterFreqMhz[b]!];
      final sorted = [...centres]..sort();
      expect(centres, sorted);
    });

    test('the edges', () {
      expect(getBandFromFreq(1296.2), '23cm');
      expect(getBandFromFreq(2300), '13cm');
      expect(getBandFromFreq(2450), '13cm');
      expect(getBandFromFreq(2451), isNull);
      expect(getBandFromFreq(10368), '3cm');
      expect(getBandFromFreq(24048), '1.25cm');
      expect(getBandFromFreq(70.2), '4m');
      expect(getBandFromFreq(222.1), '1.25m');
      // the old ones are unchanged
      expect(getBandFromFreq(14.2), '20m');
      expect(getBandFromFreq(432.1), '70cm');
    });
  });

  group('typing a frequency without a point', () {
    test('kHz still reads as kHz', () {
      expect(autoFormatFreqInput('14200'), '14.200');
      expect(autoFormatFreqInput('3500'), '3.500');
      expect(autoFormatFreqInput('142005'), '14.2005');
      expect(autoFormatFreqInput('144300'), '144.300');
    });

    test('microwave frequencies typed in MHz are kept', () {
      expect(autoFormatFreqInput('2352'), '2352.000');
      expect(autoFormatFreqInput('1296'), '1296.000');
      expect(autoFormatFreqInput('5760'), '5760.000');
      expect(autoFormatFreqInput('10368'), '10368.000');
      expect(autoFormatFreqInput('24048'), '24048.000');
    });

    test('and typed in kHz', () {
      expect(autoFormatFreqInput('2352000'), '2352.000');
      expect(autoFormatFreqInput('1296200'), '1296.200');
    });

    test('with a point, or too short, nothing is changed', () {
      expect(autoFormatFreqInput('2352.5'), '2352.5');
      expect(autoFormatFreqInput('145'), '145');
      expect(autoFormatFreqInput('abc'), 'abc');
    });
  });

  group('ATV and the other modes', () {
    test('can be chosen', () {
      for (final m in ['ATV', 'SSTV', 'MSK144', 'Q65']) {
        expect(kCommonModes, contains(m));
      }
    });

    test('a report is accepted for ATV', () {
      expect(validateRst('59', 'ATV'), isNull);
      expect(validateRst('P5', 'ATV'), isNull);
      expect(getDefaultRst('ATV'), '59');
    });

    test('the quick commands find them, and they are not looked up as a '
        'callsign', () {
      expect(matchBandCommand('13cm', kCommonBands), '13cm');
      expect(matchBandCommand('23CM', kCommonBands), '23cm');
      expect(matchModeCommand('atv', kCommonModes), 'ATV');
      expect(isAutoLookupCallsign('13cm'), isFalse);
      expect(isAutoLookupCallsign('ATV'), isFalse);
    });
  });
}
