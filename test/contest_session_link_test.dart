import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/core/utils/adif_generator.dart';
import 'package:wavelog_mobile/data/datasources/remote/wavelog_remote_datasource.dart';
import 'package:wavelog_mobile/data/models/qso_model.dart';

/// Records each request and answers the QSO create with a new id, the way
/// Wavelog's JSON create does.
class _Server implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final body = options.method == 'POST'
        ? {'data': {'id': 4242}}
        : {'data': {'id': 7, 'linked': 1}};
    return ResponseBody.fromBytes(utf8.encode(jsonEncode(body)), 201,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('a contest QSO is created as JSON and linked to the session by id',
      () async {
    final server = _Server();
    final remote =
        WavelogRemoteDatasource(dio: Dio()..httpClientAdapter = server);
    final qso = QsoModel(
      callsign: 'SV9FBG',
      dateTimeOn: DateTime.utc(2026, 10, 24, 15, 35),
      band: '15m',
      freqMhz: 21.186,
      mode: 'SSB',
      rstSent: '59',
      rstRcvd: '59',
      stationProfileId: 1,
      rawAdif: const {'CONTEST_ID': 'CQ-WW-SSB', 'SRX_STRING': '20'},
    );

    await remote.logContestQso(
      contestSessionId: 7,
      stationProfileId: 1,
      adifString: AdifGenerator.generateSingle(qso),
    );

    final create = server.requests.first;
    final body = create.data as Map<String, dynamic>;
    expect(create.method, 'POST');
    expect(body['import_type'], 'json');
    expect(body['call'], 'SV9FBG');
    expect(body['freq'], 21186000); // Hz in the JSON API
    expect(body['contest_id'], 'CQ-WW-SSB');
    expect(body['srx_string'], '20');

    final link = server.requests[1];
    expect(link.method, 'PATCH');
    expect(link.path, endsWith('/contest/7'));
    expect(link.data, {'link_qso_ids': [4242]});
  });
}
