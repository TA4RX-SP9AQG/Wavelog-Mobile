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

class _FakeCache extends QsoCacheDatasource {
  final List<QsoModel> pending;
  final List<({int serverId, int stationProfileId})> deletes;
  final synced = <String>[];
  final removedDeletes = <int>[];

  _FakeCache(this.pending, {this.deletes = const []});

  @override
  Future<List<QsoModel>> getUnsyncedQsos() async =>
      pending.where((q) => !synced.contains(q.localId)).toList();

  @override
  Future<void> markManySynced(Iterable<String> localIds) async =>
      synced.addAll(localIds);

  @override
  Future<List<({int serverId, int stationProfileId})>>
      getPendingDeletes() async => deletes;

  @override
  Future<void> removePendingDelete(int serverId, int stationProfileId) async =>
      removedDeletes.add(serverId);
}

class _FakeRemote extends WavelogRemoteDatasource {
  /// Number of import calls that succeed before [failure] is thrown.
  final int okCalls;
  final Object? failure;
  final importSizes = <int>[];
  final importStations = <int>[];
  final deleted = <int>[];

  _FakeRemote({this.okCalls = 1 << 30, this.failure}) : super(dio: Dio());

  @override
  Future<bool> importQso(String adifData, int stationProfileId) async {
    if (importSizes.length >= okCalls && failure != null) throw failure!;
    importSizes.add(RegExp('<EOR>', caseSensitive: false)
        .allMatches(adifData)
        .length);
    importStations.add(stationProfileId);
    return true;
  }

  @override
  Future<void> deleteQso(int serverId, int stationProfileId) async =>
      deleted.add(serverId);
}

void main() {
  test('syncs in chunks of 50 per station and reports progress', () async {
    final pending = [
      for (var i = 0; i < 120; i++) _qso(i, 10),
      for (var i = 120; i < 130; i++) _qso(i, 20),
    ];
    final cache = _FakeCache(pending);
    final remote = _FakeRemote();
    final repo = QsoRepository(remote: remote, local: cache);

    final progress = <int>[];
    final report = await repo.syncPending(
        onProgress: (done, failed, total) => progress.add(done));

    expect(remote.importSizes, [50, 50, 20, 10]);
    expect(remote.importStations, [10, 10, 10, 20]);
    expect(report.total, 130);
    expect(report.synced, 130);
    expect(report.failed, 0);
    expect(report.offline, isFalse);
    expect(cache.synced.length, 130);
    // 0 at the start, then monotonically up to the total.
    expect(progress.first, 0);
    expect(progress.last, 130);
    expect(progress, orderedEquals([...progress]..sort()));
  });

  test('stops at the first network failure and keeps the rest queued',
      () async {
    final cache = _FakeCache([for (var i = 0; i < 120; i++) _qso(i, 10)]);
    final remote =
        _FakeRemote(okCalls: 1, failure: const NetworkException());
    final repo = QsoRepository(remote: remote, local: cache);

    final report = await repo.syncPending();

    expect(remote.importSizes, [50]); // the second batch never got through
    expect(report.offline, isTrue);
    expect(report.synced, 50);
    expect(report.failed, 70);
    expect(cache.synced.length, 50);
  });

  test('a rejected batch does not block the remaining stations', () async {
    final cache = _FakeCache([
      for (var i = 0; i < 5; i++) _qso(i, 10),
      for (var i = 5; i < 8; i++) _qso(i, 20),
    ]);
    final remote =
        _FakeRemote(okCalls: 0, failure: const ServerException('nope'));
    final repo = QsoRepository(remote: remote, local: cache);

    final report = await repo.syncPending();

    expect(report.offline, isFalse);
    expect(report.synced, 0);
    expect(report.failed, 8);
    expect(report.error, isNotNull);
  });

  test('queued deletions are sent and cleared', () async {
    final cache = _FakeCache(const [], deletes: [
      (serverId: 7, stationProfileId: 10),
      (serverId: 8, stationProfileId: 10),
    ]);
    final remote = _FakeRemote();
    final repo = QsoRepository(remote: remote, local: cache);

    final report = await repo.syncPending();

    expect(remote.deleted, [7, 8]);
    expect(cache.removedDeletes, [7, 8]);
    expect(report.deletesDone, 2);
    expect(report.deletesLeft, 0);
  });
}
