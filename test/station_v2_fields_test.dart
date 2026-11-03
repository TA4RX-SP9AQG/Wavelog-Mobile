import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/data/datasources/remote/wavelog_remote_datasource.dart';
import 'package:wavelog_mobile/data/models/station_model.dart';

/// Records the body of each request and answers 200.
class _RecordingAdapter implements HttpClientAdapter {
  final List<dynamic> bodies = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    bodies.add(options.data);
    return ResponseBody.fromString(jsonEncode({'data': {}}), 200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  // As GET /api/v2/station returns it.
  final v2Json = {
    'id': 3,
    'name': 'Home',
    'callsign': 'SP4BL',
    'gridsquare': 'KO13AE',
    'eqsl_qth_nickname': 'SP4BL Lomza',
  };

  test('the eQSL QTH nickname is read from the v2 station JSON', () {
    expect(StationModel.fromJson(v2Json).eqslQthNickname, 'SP4BL Lomza');
    // The legacy API's column name still works.
    expect(
        StationModel.fromJson({'station_id': '3', 'eqslqthnickname': 'X'})
            .eqslQthNickname,
        'X');
  });

  test('saving a station sends the nickname, only when it is set', () async {
    final adapter = _RecordingAdapter();
    final remote = WavelogRemoteDatasource(
        dio: Dio(BaseOptions(baseUrl: 'https://log.example'))
          ..httpClientAdapter = adapter);

    final station = StationModel.fromJson(v2Json);
    await remote.updateStation(station);
    expect((adapter.bodies.last as Map)['eqsl_qth_nickname'], 'SP4BL Lomza');

    await remote.updateStation(station.copyWith(eqslQthNickname: ''));
    expect((adapter.bodies.last as Map).containsKey('eqsl_qth_nickname'),
        isFalse);
  });

  test('the ClubLog upload mode round-trips through the v2 clublog_upload',
      () async {
    final adapter = _RecordingAdapter();
    final remote = WavelogRemoteDatasource(
        dio: Dio(BaseOptions(baseUrl: 'https://log.example'))
          ..httpClientAdapter = adapter);
    for (final mode in ['live', 'on', 'disabled']) {
      final station =
          StationModel.fromJson({...v2Json, 'clublog_upload': mode});
      expect(station.clublogRealtime, mode == 'live');
      expect(station.clublogIgnore, mode == 'disabled');
      await remote.updateStation(station);
      expect((adapter.bodies.last as Map)['clublog_upload'], mode);
    }
  });
}
