import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/data/datasources/remote/dx_cluster_datasource.dart';

/// Answers every request with [body] as JSON and records the request paths.
class _JsonAdapter implements HttpClientAdapter {
  final Object body;
  final List<String> paths = [];

  _JsonAdapter(this.body);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    paths.add(options.uri.toString());
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _spot(String call, Duration age) => {
      'spotter': 'LZ1QV',
      'spotted': call,
      'frequency': 3509.9,
      'message': 'CW',
      'when': DateTime.now().toUtc().subtract(age).toIso8601String(),
      'source': 'DXSPOTS',
      'band': '80m',
      'mode': 'cw',
      'submode': 'CW',
      'skimmer': null,
      'dxcc_spotter': {'cont': 'EU', 'dxcc_id': '212'},
      'dxcc_spotted': {'cont': 'EU', 'dxcc_id': '499'},
    };

void main() {
  test('reads Wavelog DXCache and keeps the last 60 minutes, newest first',
      () async {
    final primary = Dio(BaseOptions(baseUrl: 'https://dxc.wavelog.org/dxcache'))
      ..httpClientAdapter = _JsonAdapter([
        _spot('OLD1', const Duration(minutes: 90)),
        _spot('MID1', const Duration(minutes: 30)),
        _spot('NEW1', const Duration(minutes: 1)),
        _spot('EDGE1', const Duration(minutes: 59)),
      ]);
    final fallback = Dio()..httpClientAdapter = _JsonAdapter({'s': {}});

    final spots =
        await DxClusterDatasource(primaryDio: primary, fallbackDio: fallback)
            .getSpots();

    expect((primary.httpClientAdapter as _JsonAdapter).paths,
        ['https://dxc.wavelog.org/dxcache/spots/']);
    expect((fallback.httpClientAdapter as _JsonAdapter).paths, isEmpty);
    expect(spots.map((s) => s.dxCall), ['NEW1', 'MID1', 'EDGE1']);
    expect(spots.first.frequency, '3509.9');
    expect(spots.first.band, '80m');
    expect(spots.first.mode, 'CW');
  });
}
