import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/core/utils/keyboard_shortcuts.dart';

void main() {
  group('cycleListValue', () {
    const values = ['a', 'b', 'c'];

    test('forward moves to the next element', () {
      expect(cycleListValue(values, 'a', forward: true), 'b');
      expect(cycleListValue(values, 'b', forward: true), 'c');
    });

    test('forward wraps from the last element back to the first', () {
      expect(cycleListValue(values, 'c', forward: true), 'a');
    });

    test('backward moves to the previous element', () {
      expect(cycleListValue(values, 'c', forward: false), 'b');
      expect(cycleListValue(values, 'b', forward: false), 'a');
    });

    test('backward wraps from the first element back to the last', () {
      expect(cycleListValue(values, 'a', forward: false), 'c');
    });

    test('an unknown current value falls back to first (forward) or last '
        '(backward) instead of throwing', () {
      expect(cycleListValue(values, 'nope', forward: true), 'a');
      expect(cycleListValue(values, 'nope', forward: false), 'c');
    });

    test('a single-element list returns that element either direction', () {
      expect(cycleListValue(['solo'], 'solo', forward: true), 'solo');
      expect(cycleListValue(['solo'], 'solo', forward: false), 'solo');
    });
  });

  group('matchBandCommand / matchModeCommand', () {
    const bands = ['160m', '80m', '40m', '20m', '15m', '10m'];
    const modes = ['SSB', 'CW', 'FM', 'FT8', 'FT4'];

    test('matches case-insensitively, returning the canonical value', () {
      expect(matchBandCommand('20m', bands), '20m');
      expect(matchBandCommand('20M', bands), '20m');
      expect(matchModeCommand('ssb', modes), 'SSB');
      expect(matchModeCommand('Ssb', modes), 'SSB');
    });

    test('tolerates surrounding whitespace', () {
      expect(matchBandCommand('  20m  ', bands), '20m');
      expect(matchModeCommand(' SSB ', modes), 'SSB');
    });

    test('rejects a near-miss rather than fuzzy-matching', () {
      expect(matchBandCommand('20', bands), isNull);
      expect(matchModeCommand('SSBX', modes), isNull);
      expect(matchModeCommand('SS', modes), isNull);
    });

    test('never matches a real callsign (always contains a digit a band/mode '
        'token never has)', () {
      expect(matchBandCommand('TA4RX', bands), isNull);
      expect(matchModeCommand('SP9AQG', modes), isNull);
    });

    test('empty string returns null', () {
      expect(matchBandCommand('', bands), isNull);
      expect(matchModeCommand('   ', modes), isNull);
    });
  });
}
