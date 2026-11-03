import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/core/errors/app_exception.dart';
import 'package:wavelog_mobile/core/utils/adif_generator.dart';
import 'package:wavelog_mobile/data/datasources/remote/wavelog_remote_datasource.dart';
import 'package:wavelog_mobile/data/models/qso_model.dart';

/// Answers every request with [status] and [body], recording the requests.
class _Server implements HttpClientAdapter {
  final int status;
  final Object body;
  final requests = <RequestOptions>[];
  _Server(this.status, this.body);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromBytes(utf8.encode(jsonEncode(body)), status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

final _adif = AdifGenerator.generateSingle(QsoModel(
  callsign: 'SQ4MK',
  dateTimeOn: DateTime.utc(2026, 10, 26, 18, 5),
  band: '40m',
  freqMhz: 7.155,
  mode: 'SSB',
  rstSent: '59',
  rstRcvd: '57',
  stationProfileId: 1,
  name: 'Mariusz',
));

WavelogRemoteDatasource _remote(_Server s) =>
    WavelogRemoteDatasource(dio: Dio()..httpClientAdapter = s);

void main() {
  test('a QSO is created as JSON and its id comes back', () async {
    final server = _Server(201, {'data': {'id': 4711}});
    expect(await _remote(server).createQso(_adif, 1), 4711);

    final body = server.requests.single.data as Map<String, dynamic>;
    expect(body['import_type'], 'json');
    expect(body['station_profile_id'], 1);
    expect(body['call'], 'SQ4MK');
    expect(body['name'], 'Mariusz');
    expect(body['rst_rcvd'], '57');
    expect(body['freq'], 7155000); // Hz in the JSON API
  });

  test('a QSO the server already has counts as saved', () async {
    final server = _Server(400, {
      'error': {
        'code': 'validation_error',
        'message': 'Duplicate',
        'details': {'critical': [], 'validation': [], 'duplicate': ['SQ4MK']},
      }
    });
    expect(await _remote(server).createQso(_adif, 1), isNull);
  });

  test('any other rejection is an error', () async {
    final server = _Server(400, {
      'error': {
        'code': 'validation_error',
        'message': 'Missing required field(s): band',
        'details': {'missing': ['band']},
      }
    });
    await expectLater(
        _remote(server).createQso(_adif, 1), throwsA(isA<AppException>()));
  });
}
