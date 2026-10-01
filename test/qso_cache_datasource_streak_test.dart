import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/data/datasources/local/qso_cache_datasource.dart';
import 'package:wavelog_mobile/data/models/qso_model.dart';

QsoModel _qso(int station, DateTime when) => QsoModel(
      callsign: 'K1ABC',
      dateTimeOn: when,
      band: '20m',
      mode: 'SSB',
      rstSent: '59',
      rstRcvd: '59',
      stationProfileId: station,
    );

void main() {
  group('QsoCacheDatasource.computeStatsFor currentStreakDays', () {
    test('an unbroken streak spans QSOs logged under different stations', () {
      // Mirrors a traveling operator with multiple logbooks/stations: the
      // streak itself doesn't know about scope, callers decide what list to
      // pass it (see detailed_statistics_provider.dart, which now passes the
      // full unscoped cache specifically so a day logged only under a
      // different station isn't mistaken for a gap).
      final today = DateTime.now().toUtc();
      final qsos = [
        _qso(1, today),
        _qso(2, today.subtract(const Duration(days: 1))),
        _qso(1, today.subtract(const Duration(days: 2))),
        _qso(3, today.subtract(const Duration(days: 3))),
      ];
      final stats = QsoCacheDatasource.computeStatsFor(qsos);
      expect(stats.currentStreakDays, 4);
    });

    test('a day with no QSOs at all breaks the streak', () {
      final today = DateTime.now().toUtc();
      final qsos = [
        _qso(1, today),
        _qso(1, today.subtract(const Duration(days: 1))),
        // day 2 missing entirely
        _qso(1, today.subtract(const Duration(days: 3))),
      ];
      final stats = QsoCacheDatasource.computeStatsFor(qsos);
      expect(stats.currentStreakDays, 2);
    });

    test('day boundaries are UTC, not the device local timezone', () {
      final nowUtc = DateTime.now().toUtc();
      final todayMidnightUtc =
          DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      // One minute before today's UTC midnight falls on the previous UTC
      // day, adjacent to today, so the two still form an unbroken streak
      // under UTC boundaries (would also pass under local-day boundaries
      // for a test machine set to UTC, which is exactly why this needs an
      // explicit DateTime.utc construction to be a meaningful assertion).
      final qsos = [
        _qso(1, todayMidnightUtc),
        _qso(1, todayMidnightUtc.subtract(const Duration(minutes: 1))),
      ];
      final stats = QsoCacheDatasource.computeStatsFor(qsos);
      expect(stats.currentStreakDays, 2);
    });

    test('no QSOs today still counts yesterday\'s streak', () {
      final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
      final qsos = [
        _qso(1, yesterday),
        _qso(1, yesterday.subtract(const Duration(days: 1))),
      ];
      final stats = QsoCacheDatasource.computeStatsFor(qsos);
      expect(stats.currentStreakDays, 2);
    });
  });
}
