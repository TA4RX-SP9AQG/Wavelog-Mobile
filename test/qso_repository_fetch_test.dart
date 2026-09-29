import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/core/errors/app_exception.dart';
import 'package:wavelog_mobile/data/datasources/local/qso_cache_datasource.dart';
import 'package:wavelog_mobile/data/datasources/remote/wavelog_remote_datasource.dart';
import 'package:wavelog_mobile/data/models/qso_model.dart';
import 'package:wavelog_mobile/data/repositories/qso_repository.dart';

QsoModel _qso(int i, int station) => QsoModel(
      localId: 'q$i',
      callsign: 'K$i',
      dateTimeOn: DateTime.utc(2026, 9, 1, 12, 0, i % 60),
      band: '20m',
      mode: 'SSB',
      rstSent: '59',
      rstRcvd: '59',
      stationProfileId: station,
    );

/// Minimal in-memory fake of the local cache — just enough of the surface
/// fetchQsos() touches (no real Hive box needed for this test).
class _FakeCache extends QsoCacheDatasource {
  final Map<int, List<QsoModel>> staleByStation;
  final int maxServerId;
  final List<int> replacedForStation = [];
  final List<int> upsertedForStation = [];

  _FakeCache(this.staleByStation, {this.maxServerId = 0});

  @override
  Future<Set<int>> getPendingDeleteServerIds() async => {};

  // Defaults to 0 (no station synced before), so most tests take
  // fetchQsos()'s full-fetch path — matches what they exercise (retry /
  // fallback around getContacts()). Tests of the incremental merge path
  // override this via the constructor.
  @override
  int maxServerIdForStation(int stationId) => maxServerId;

  @override
  Future<void> replaceSyncedQsosForStation(
      int stationId, List<QsoModel> incoming) async {
    replacedForStation.add(stationId);
  }

  @override
  Future<void> upsertQsosForStation(
      int stationId, List<QsoModel> incoming) async {
    upsertedForStation.add(stationId);
  }

  @override
  Future<List<QsoModel>> getCachedQsos({
    int? stationId,
    String? band,
    String? mode,
    String? callsign,
  }) async =>
      stationId != null ? (staleByStation[stationId] ?? []) : [];
}

/// Fake remote datasource whose getContacts() can be scripted to fail a
/// fixed number of times (with any exception, e.g. the TimeoutException
/// _mapDioException produces for a real Dio receive/connect timeout) before
/// succeeding, or to always fail.
class _FakeRemote extends WavelogRemoteDatasource {
  final int failuresBeforeSuccess;
  final Object exceptionToThrow;
  final List<QsoModel> successResult;
  int calls = 0;
  int? lastFetchFromId;

  _FakeRemote({
    required this.failuresBeforeSuccess,
    required this.exceptionToThrow,
    required this.successResult,
  }) : super(dio: Dio());

  @override
  Future<List<QsoModel>> getContacts({
    required int stationId,
    int fetchFromId = 0,
    String? band,
    int? stationProfileId,
  }) async {
    calls++;
    lastFetchFromId = fetchFromId;
    if (calls <= failuresBeforeSuccess) throw exceptionToThrow;
    return successResult;
  }
}

void main() {
  group('QsoRepository.fetchQsos resilience', () {
    test(
        'a single transient timeout is retried once and succeeds, without '
        'falling back to the stale local cache', () async {
      final fresh = [_qso(1, 10), _qso(2, 10)];
      final remote = _FakeRemote(
        failuresBeforeSuccess: 1,
        exceptionToThrow: const TimeoutException(),
        successResult: fresh,
      );
      final cache = _FakeCache({
        10: [_qso(999, 10)], // old stale entry — must NOT be what we get back
      });
      final repo = QsoRepository(remote: remote, local: cache);

      final result = await repo.fetchQsos(stationId: 10);

      expect(remote.calls, 2); // first call failed, retry succeeded
      expect(result, fresh);
      expect(cache.replacedForStation, [10]); // cache was updated with fresh data
    });

    test(
        'two consecutive timeouts fall back to the local cache (no '
        'exception escapes to the caller)', () async {
      final remote = _FakeRemote(
        failuresBeforeSuccess: 999, // always times out
        exceptionToThrow: const TimeoutException(),
        successResult: [_qso(1, 10)],
      );
      final stale = [_qso(999, 10)];
      final cache = _FakeCache({10: stale});
      final repo = QsoRepository(remote: remote, local: cache);

      final result = await repo.fetchQsos(stationId: 10);

      expect(remote.calls, 2); // one attempt + one retry, then gives up
      expect(result, stale);
    });

    test('a network failure (no connectivity) falls back immediately, '
        'without retrying', () async {
      final remote = _FakeRemote(
        failuresBeforeSuccess: 999,
        exceptionToThrow: const NetworkException('offline'),
        successResult: [_qso(1, 10)],
      );
      final stale = [_qso(999, 10)];
      final cache = _FakeCache({10: stale});
      final repo = QsoRepository(remote: remote, local: cache);

      final result = await repo.fetchQsos(stationId: 10);

      expect(remote.calls, 1); // no retry for a hard network failure
      expect(result, stale);
    });
  });

  group('QsoRepository.fetchQsos incremental sync', () {
    test('a station synced before fetches only newer QSOs (since_id) and '
        'upserts instead of replacing', () async {
      final delta = [_qso(500, 10)];
      final remote = _FakeRemote(
        failuresBeforeSuccess: 0,
        exceptionToThrow: const TimeoutException(),
        successResult: delta,
      );
      // Cache already has a baseline of 2 QSOs for station 10 (highest
      // server id 42) — an incremental fetch merges into that rather than
      // replacing it, so the read-back below should reflect the baseline,
      // not just the 1-item delta the fake remote returns.
      final cache = _FakeCache(
        {10: [_qso(1, 10), _qso(2, 10)]},
        maxServerId: 42,
      );
      final repo = QsoRepository(remote: remote, local: cache);

      final result = await repo.fetchQsos(stationId: 10);

      expect(remote.lastFetchFromId, 42); // asked for only what's newer
      expect(cache.upsertedForStation, [10]); // merged, not replaced
      expect(cache.replacedForStation, isEmpty);
      // Result comes back from the (now merged) cache, not the bare delta.
      expect(result.length, 2);
    });

    test('a station never synced before (max id 0) does a full fetch as '
        'before', () async {
      final full = [_qso(1, 10), _qso(2, 10)];
      final remote = _FakeRemote(
        failuresBeforeSuccess: 0,
        exceptionToThrow: const TimeoutException(),
        successResult: full,
      );
      final cache = _FakeCache({10: []}, maxServerId: 0);
      final repo = QsoRepository(remote: remote, local: cache);

      final result = await repo.fetchQsos(stationId: 10);

      expect(remote.lastFetchFromId, 0);
      expect(cache.replacedForStation, [10]);
      expect(cache.upsertedForStation, isEmpty);
      expect(result, full);
    });
  });
}
