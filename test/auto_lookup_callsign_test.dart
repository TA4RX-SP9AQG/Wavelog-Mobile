import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/core/utils/validators.dart';

void main() {
  test('complete callsigns trigger the automatic lookup', () {
    for (final cs in ['SP9AQG', 'W1AW', 'K1A', 'SV5/SP9AQG', 'SP9AQG/P']) {
      expect(isAutoLookupCallsign(cs), isTrue, reason: cs);
    }
  });

  test('partial input and band/mode quick commands do not', () {
    for (final cs in ['', 'SP', 'SP9', 'SP9AQG/', '20M', '20m', 'FT8', 'SSB']) {
      expect(isAutoLookupCallsign(cs), isFalse, reason: cs);
    }
  });
}
