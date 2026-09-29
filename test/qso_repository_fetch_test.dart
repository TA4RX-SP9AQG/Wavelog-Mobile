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

/// Minimal in-memory fake of the local cache, just enough of the surface
/// fetchQsos() touches (no real Hive box needed for this test). Unlike the
/// real datasource, upsert/prune calls here only record what happened; they
/// don't mutate [staleByStation], so [getCachedQsos] always returns exactly
/// what a test seeds it with.
class _FakeCache extends QsoCacheDatasource {
  final Map<int, List<QsoModel>> staleByStation;
  final int maxServerId;
  final List<int> upsertedForStation = [];
  final List<int> prunedForStation = [];
  Set<String>? lastPruneKeepKeys;

  _FakeCache(this.staleByStation, {this.maxServerId = 0});

  @override
  Future<Set<int>> getPendingDeleteServerIds() async => {};

  @override
  int maxServerIdForStation(int stationId) => maxServerId;

  @override
  Future<void> upsertQsosForStation(
      int stationId, List<QsoModel> incoming) async {
    upsertedForStation.add(stationId);
  }

  @override
  Future<void> pruneStaleForStation(
      int stationId, Set<String> keepKeys) async {
    prunedForStation.add(stationId);
    lastPruneKeepKeys = keepKeys;
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
/// succeeding, or to always fail. On success it delivers successResult as a
/// single page via onPage (matching how a real single-page fetch behaves)
/// before returning it.
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
    Future<void> Function(List<QsoModel> page)? onPage,
  }) async {
    calls++;
    lastFetchFromId = fetchFromId;
    if (calls <= failuresBeforeSuccess) throw exceptionToThrow;
    if (onPage != null && successResult.isNotEmpty) await onPage(successResult);
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
        10: fresh, // what getCachedQsos should hand back post-sync
      });
      final repo = QsoRepository(remote: remote, local: cache);

      final result = await repo.fetchQsos(stationId: 10);

      expect(remote.calls, 2); // first call failed, retry succeeded
      expect(result, fresh);
      expect(cache.upsertedForStation, [10]); // page persisted as it arrived
      expect(cache.prunedForStation, [10]); // first-of-session fetch reconciles
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
      // Never completed, must not prune based on a partial/failed fetch.
      expect(cache.prunedForStation, isEmpty);
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

  group('QsoRepository.fetchQsos session-based full resync', () {
    test('the first fetch of a station in a session is always a full, '
        'reconciling resync, even when the cache already has a baseline '
        'from an earlier session', () async {
      final remote = _FakeRemote(
        failuresBeforeSuccess: 0,
        exceptionToThrow: const TimeoutException(),
        successResult: [_qso(1, 10)],
      );
      // maxServerId: 42 simulates a station already synced in a previous
      // app run, but this repo instance (= this session) has never
      // fetched it yet.
      final cache = _FakeCache({10: [_qso(1, 10)]}, maxServerId: 42);
      final repo = QsoRepository(remote: remote, local: cache);

      await repo.fetchQsos(stationId: 10);

      expect(remote.lastFetchFromId, 0); // full fetch, since_id ignored
      expect(cache.prunedForStation, [10]); // reconciled against a full set
    });

    test('a later fetch of the same station in the same session is '
        'incremental (since_id), and does not prune', () async {
      final remote = _FakeRemote(
        failuresBeforeSuccess: 0,
        exceptionToThrow: const TimeoutException(),
        successResult: [_qso(1, 10)],
      );
      final cache = _FakeCache({10: [_qso(1, 10)]}, maxServerId: 42);
      final repo = QsoRepository(remote: remote, local: cache);

      await repo.fetchQsos(stationId: 10); // first: full resync
      await repo.fetchQsos(stationId: 10); // second: same session

      expect(remote.calls, 2);
      expect(remote.lastFetchFromId, 42); // second call went incremental
      expect(cache.prunedForStation, [10]); // only from the first call
    });

    test('a fetch that never completes does not mark the station as '
        'resynced, the next attempt (even same session) tries a full '
        'resync again', () async {
      final remote = _FakeRemote(
        failuresBeforeSuccess: 999, // always times out
        exceptionToThrow: const TimeoutException(),
        successResult: [_qso(1, 10)],
      );
      final cache = _FakeCache({10: []}, maxServerId: 42);
      final repo = QsoRepository(remote: remote, local: cache);

      await repo.fetchQsos(stationId: 10); // fails both attempts
      final callsAfterFirst = remote.calls;
      await repo.fetchQsos(stationId: 10); // should still attempt full resync

      // Both fetchQsos() calls used since_id=0 (full resync), the second
      // one wasn't treated as "already resynced this session" because the
      // first one never actually succeeded.
      expect(remote.lastFetchFromId, 0);
      expect(remote.calls, callsAfterFirst + 2); // second call also retried once
      expect(cache.prunedForStation, isEmpty);
    });
  });
}
