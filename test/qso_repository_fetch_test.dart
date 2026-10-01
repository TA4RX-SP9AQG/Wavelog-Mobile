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
/// fetchQsos()/reconcileIfNeeded() touch (no real Hive box or
/// SharedPreferences needed for this test). Upsert/prune calls here only
/// record what happened, they don't mutate [staleByStation], so
/// [getCachedQsos] always returns exactly what a test seeds it with.
/// [lastFullCheckAt] defaults to "just now" (never due for the periodic
/// edit check), so tests focused on the count-based deletion check aren't
/// also, incidentally, exercising the time-based one, unless a test passes
/// its own value.
class _FakeCache extends QsoCacheDatasource {
  final Map<int, List<QsoModel>> staleByStation;
  final int maxServerId;
  final int localCount;
  final DateTime? lastFullCheckAt;
  final List<int> upsertedForStation = [];
  final List<int> prunedForStation = [];
  final List<int> lastFullCheckSetFor = [];

  // Sentinel so a test can pass lastFullCheckAt: null (genuinely "never
  // checked") and have that stick, distinct from "the parameter wasn't
  // passed at all" (defaults to "just now" below), a plain `??` can't
  // tell those two cases apart.
  static const _unset = Object();

  _FakeCache(
    this.staleByStation, {
    this.maxServerId = 0,
    this.localCount = 0,
    Object? lastFullCheckAt = _unset,
  }) : lastFullCheckAt = identical(lastFullCheckAt, _unset)
            ? DateTime.now()
            : lastFullCheckAt as DateTime?;

  @override
  Future<Set<int>> getPendingDeleteServerIds() async => {};

  @override
  int maxServerIdForStation(int stationId) => maxServerId;

  @override
  int countForStation(int stationId) => localCount;

  @override
  Future<DateTime?> getLastFullCheckAt(int stationId) async => lastFullCheckAt;

  @override
  Future<void> setLastFullCheckAt(int stationId, DateTime time) async {
    lastFullCheckSetFor.add(stationId);
  }

  @override
  Future<void> upsertQsosForStation(
      int stationId, List<QsoModel> incoming) async {
    upsertedForStation.add(stationId);
  }

  @override
  Future<void> pruneStaleForStation(
      int stationId, Set<String> keepKeys) async {
    prunedForStation.add(stationId);
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
/// before returning it. getQsoCount() is separately scriptable.
class _FakeRemote extends WavelogRemoteDatasource {
  final int failuresBeforeSuccess;
  final Object exceptionToThrow;
  final List<QsoModel> successResult;
  final int? qsoCount;
  final Object? qsoCountError;
  int calls = 0;
  int qsoCountCalls = 0;
  int? lastFetchFromId;

  _FakeRemote({
    this.failuresBeforeSuccess = 0,
    this.exceptionToThrow = const TimeoutException(),
    this.successResult = const [],
    this.qsoCount,
    this.qsoCountError,
  }) : super(dio: Dio());

  @override
  Future<List<QsoModel>> getContacts({
    required int stationId,
    int fetchFromId = 0,
    String? band,
    int? stationProfileId,
    Future<void> Function(List<QsoModel> page)? onPage,
    void Function(int pagesDone, int totalPages)? onProgress,
  }) async {
    calls++;
    lastFetchFromId = fetchFromId;
    if (calls <= failuresBeforeSuccess) throw exceptionToThrow;
    if (onPage != null && successResult.isNotEmpty) await onPage(successResult);
    return successResult;
  }

  @override
  Future<int> getQsoCount({required int stationId}) async {
    qsoCountCalls++;
    if (qsoCountError != null) throw qsoCountError!;
    return qsoCount ?? 0;
  }
}

void main() {
  group('QsoRepository.fetchQsos resilience (never-synced station)', () {
    test(
        'a single transient timeout is retried once and succeeds, without '
        'falling back to the stale local cache', () async {
      final fresh = [_qso(1, 10), _qso(2, 10)];
      final remote = _FakeRemote(failuresBeforeSuccess: 1, successResult: fresh);
      final cache = _FakeCache({10: fresh}); // maxServerId: 0 -> never synced
      final repo = QsoRepository(remote: remote, local: cache);

      final result = await repo.fetchQsos(stationId: 10);

      expect(remote.calls, 2); // first call failed, retry succeeded
      expect(result, fresh);
      expect(cache.upsertedForStation, [10]); // page persisted as it arrived
      expect(cache.prunedForStation, [10]); // first-ever fetch is always full
    });

    test(
        'two consecutive timeouts fall back to the local cache (no '
        'exception escapes to the caller)', () async {
      final remote = _FakeRemote(
          failuresBeforeSuccess: 999, successResult: [_qso(1, 10)]);
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

  group('QsoRepository.fetchQsos incremental path (already has a baseline)', () {
    test('a station with any cached baseline always fetches incrementally, '
        'never blocks on a full resync', () async {
      final remote = _FakeRemote(successResult: [_qso(1, 10)]);
      final cache = _FakeCache({10: [_qso(1, 10)]}, maxServerId: 42);
      final repo = QsoRepository(remote: remote, local: cache);

      await repo.fetchQsos(stationId: 10);

      expect(remote.lastFetchFromId, 42); // since_id, not a full fetch
      expect(cache.prunedForStation, isEmpty); // incremental never prunes
    });

    test('a station with no baseline (maxServerId 0) does a full fetch, '
        'and records it as the periodic edit check too', () async {
      final remote = _FakeRemote(successResult: [_qso(1, 10)]);
      final cache = _FakeCache({10: [_qso(1, 10)]}, maxServerId: 0);
      final repo = QsoRepository(remote: remote, local: cache);

      await repo.fetchQsos(stationId: 10);

      expect(remote.lastFetchFromId, 0);
      expect(cache.prunedForStation, [10]);
      expect(cache.lastFullCheckSetFor, [10]);
    });
  });

  group('QsoRepository.reconcileIfNeeded, deletion check (count-based)', () {
    test('returns false without any network call when nothing is cached '
        'yet for the station', () async {
      final remote = _FakeRemote(qsoCount: 0);
      final cache = _FakeCache({}, localCount: 0);
      final repo = QsoRepository(remote: remote, local: cache);

      final changed = await repo.reconcileIfNeeded(10);

      expect(changed, isFalse);
      expect(remote.qsoCountCalls, 0);
      expect(remote.calls, 0);
    });

    test('server count >= local count and the edit check is not due means '
        'nothing changed, no full fetch is attempted', () async {
      final remote = _FakeRemote(qsoCount: 50);
      final cache = _FakeCache({}, localCount: 50); // lastFullCheckAt: now
      final repo = QsoRepository(remote: remote, local: cache);

      final changed = await repo.reconcileIfNeeded(10);

      expect(changed, isFalse);
      expect(remote.qsoCountCalls, 1);
      expect(remote.calls, 0); // no getContacts call, cheap check only
    });

    test('server count < local count means something was deleted, does a '
        'full fetch and prunes even though the edit check is not due',
        () async {
      final remote = _FakeRemote(qsoCount: 48, successResult: [_qso(1, 10)]);
      final cache = _FakeCache({10: [_qso(1, 10)]}, localCount: 50);
      final repo = QsoRepository(remote: remote, local: cache);

      final changed = await repo.reconcileIfNeeded(10);

      expect(changed, isTrue);
      expect(remote.lastFetchFromId, 0); // full fetch, not incremental
      expect(cache.prunedForStation, [10]);
    });

    test('a getQsoCount failure with the edit check not due returns false '
        'without attempting a full fetch, the caller retries next time',
        () async {
      final remote = _FakeRemote(qsoCountError: const NetworkException('offline'));
      final cache = _FakeCache({}, localCount: 50);
      final repo = QsoRepository(remote: remote, local: cache);

      final changed = await repo.reconcileIfNeeded(10);

      expect(changed, isFalse);
      expect(remote.calls, 0);
    });
  });

  group('QsoRepository.reconcileIfNeeded, periodic edit check (content, '
      'not count)', () {
    test('never checked before (null) triggers a full fetch even when the '
        'count matches exactly, an in-place edit changes neither', () async {
      final remote = _FakeRemote(qsoCount: 50, successResult: [_qso(1, 10)]);
      final cache = _FakeCache({10: [_qso(1, 10)]},
          localCount: 50, lastFullCheckAt: null);
      final repo = QsoRepository(remote: remote, local: cache);

      final changed = await repo.reconcileIfNeeded(10);

      expect(changed, isTrue);
      expect(remote.lastFetchFromId, 0);
      expect(cache.lastFullCheckSetFor, [10]);
    });

    test('checked longer ago than the interval triggers a full fetch even '
        'when the count matches exactly', () async {
      final remote = _FakeRemote(qsoCount: 50, successResult: [_qso(1, 10)]);
      final cache = _FakeCache(
        {10: [_qso(1, 10)]},
        localCount: 50,
        lastFullCheckAt: DateTime.now().subtract(const Duration(minutes: 40)),
      );
      final repo = QsoRepository(remote: remote, local: cache);

      final changed = await repo.reconcileIfNeeded(10,
          editCheckInterval: const Duration(minutes: 30));

      expect(changed, isTrue);
    });

    test('checked more recently than the interval and the count matches '
        'skips the full fetch entirely', () async {
      final remote = _FakeRemote(qsoCount: 50);
      final cache = _FakeCache(
        {10: [_qso(1, 10)]},
        localCount: 50,
        lastFullCheckAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      final repo = QsoRepository(remote: remote, local: cache);

      final changed = await repo.reconcileIfNeeded(10,
          editCheckInterval: const Duration(minutes: 30));

      expect(changed, isFalse);
      expect(remote.calls, 0);
    });

    test('a getQsoCount failure still runs the full fetch when the edit '
        'check is independently due', () async {
      final remote = _FakeRemote(
        qsoCountError: const NetworkException('offline'),
        successResult: [_qso(1, 10)],
      );
      final cache = _FakeCache({10: [_qso(1, 10)]},
          localCount: 50, lastFullCheckAt: null);
      final repo = QsoRepository(remote: remote, local: cache);

      final changed = await repo.reconcileIfNeeded(10);

      expect(changed, isTrue);
      expect(remote.lastFetchFromId, 0);
    });
  });
}
