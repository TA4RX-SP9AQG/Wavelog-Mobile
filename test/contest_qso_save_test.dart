import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/core/constants/contest_data.dart';
import 'package:wavelog_mobile/core/errors/app_exception.dart';
import 'package:wavelog_mobile/core/utils/adif_generator.dart';
import 'package:wavelog_mobile/data/datasources/local/qso_cache_datasource.dart';
import 'package:wavelog_mobile/data/datasources/remote/wavelog_remote_datasource.dart';
import 'package:wavelog_mobile/data/models/qso_model.dart';
import 'package:wavelog_mobile/data/repositories/qso_repository.dart';

final _qso = QsoModel(
  callsign: 'SV9FBG',
  dateTimeOn: DateTime.utc(2026, 10, 24, 15, 35),
  band: '15m',
  mode: 'SSB',
  rstSent: '59',
  rstRcvd: '59',
  stationProfileId: 1,
  name: 'Giannis',
  qth: 'Ierapetra',
  gridSquare: 'KM25',
  rawAdif: const {'CONTEST_ID': 'CQ-WW-SSB', 'SRX_STRING': '20', 'CQZ': '20'},
);

class _FakeCache extends QsoCacheDatasource {
  final saved = <QsoModel>[];

  @override
  Future<String> saveLocalQso(QsoModel qso) async {
    saved.add(qso);
    return 'id';
  }
}

class _FakeRemote extends WavelogRemoteDatasource {
  final Object? error;
  int creates = 0;
  final contestLogs = <int>[];

  _FakeRemote({this.error}) : super(dio: Dio());

  @override
  Future<int?> createQso(String adifString, int stationProfileId) async {
    creates++;
    if (error != null) throw error!;
    return 42;
  }

  @override
  Future<void> logContestQso({
    required int contestSessionId,
    required int stationProfileId,
    required String adifString,
  }) async {
    if (error != null) throw error!;
    contestLogs.add(contestSessionId);
  }
}

void main() {
  group('saving a contest session QSO', () {
    test('goes to the session once and is cached as synced', () async {
      final remote = _FakeRemote();
      final cache = _FakeCache();
      await QsoRepository(remote: remote, local: cache)
          .addQso(_qso, contestSessionId: 7);

      expect(remote.contestLogs, [7]);
      expect(remote.creates, 0);
      // Synced: the next sync must not upload it a second time.
      expect(cache.saved.single.synced, isTrue);
    });

    test('offline it is kept unsynced for the next sync', () async {
      final remote = _FakeRemote(error: const NetworkException('offline'));
      final cache = _FakeCache();
      await expectLater(
          QsoRepository(remote: remote, local: cache)
              .addQso(_qso, contestSessionId: 7),
          throwsA(isA<NetworkException>()));
      expect(cache.saved.single.synced, isFalse);
    });

    test('without a session it is a single JSON create', () async {
      final remote = _FakeRemote();
      final cache = _FakeCache();
      await QsoRepository(remote: remote, local: cache).addQso(_qso);
      expect(remote.creates, 1);
      expect(remote.contestLogs, isEmpty);
      expect(cache.saved.single.synced, isTrue);
    });
  });

  test('the ADIF carries the lookup data and the exchange', () {
    final adif = AdifGenerator.generateSingle(_qso);
    for (final f in ['<NAME:7>Giannis', '<QTH:9>Ierapetra', '<GRIDSQUARE:4>KM25',
        '<CONTEST_ID:9>CQ-WW-SSB', '<SRX_STRING:2>20', '<CQZ:2>20']) {
      expect(adif, contains(f));
    }
  });

  group('contest exchange', () {
    test('CQ WW and IARU HF exchange a zone', () {
      expect(contestZoneOf('CQ-WW-SSB'), ContestZone.cq);
      expect(contestZoneOf('cq-ww-cw'), ContestZone.cq);
      expect(contestZoneOf('IARU-HF'), ContestZone.itu);
      expect(contestZoneOf('CQ-WPX-SSB'), isNull);
    });

    test('a zone contest defaults to the exchange field', () {
      expect(defaultExchangeFields('CQ-WW-SSB'), ['exchange']);
      expect(defaultExchangeFields('CQ-WPX-SSB'), ['serial']);
    });
  });

  test('the operator is the account callsign, else the base station call', () {
    expect(contestOperator('sp4bl', 'SP4BL/P'), 'SP4BL');
    expect(contestOperator(null, 'SP4BL/P'), 'SP4BL');
    expect(contestOperator(null, 'EA8/SP4BL'), 'SP4BL');
    expect(contestOperator(null, null), isNull);
  });
}
