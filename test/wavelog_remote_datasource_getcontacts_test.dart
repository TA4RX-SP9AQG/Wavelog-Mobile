import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/data/datasources/remote/wavelog_remote_datasource.dart';

/// A scriptable [HttpClientAdapter]: each call records the request's query
/// parameters and either throws a receive-timeout DioException (to simulate
/// a flaky page) or answers with a canned single-page JSON response.
class _ScriptedAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> seenQueries = [];
  final int timeoutsBeforeSuccess;
  int calls = 0;

  _ScriptedAdapter({this.timeoutsBeforeSuccess = 0});

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    seenQueries.add(Map<String, dynamic>.from(options.queryParameters));

    if (calls <= timeoutsBeforeSuccess) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }

    final body = jsonEncode({
      'data': [
        {
          'call': 'K1ABC',
          'qso_date': '2026-09-01 12:00:00',
          'band': '20m',
          'mode': 'SSB',
          'rst_sent': '59',
          'rst_rcvd': '59',
        }
      ],
      'meta': {'has_more': false},
    });
    return ResponseBody.fromBytes(utf8.encode(body), 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

WavelogRemoteDatasource _remoteWith(_ScriptedAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return WavelogRemoteDatasource(dio: dio);
}

void main() {
  group('WavelogRemoteDatasource.getContacts', () {
    test('fetchFromId > 0 is sent as the since_id query parameter',
        () async {
      final adapter = _ScriptedAdapter();
      final remote = _remoteWith(adapter);

      await remote.getContacts(stationId: 1, fetchFromId: 42);

      expect(adapter.seenQueries.single['since_id'], 42);
    });

    test('fetchFromId == 0 omits since_id entirely (full fetch)', () async {
      final adapter = _ScriptedAdapter();
      final remote = _remoteWith(adapter);

      await remote.getContacts(stationId: 1);

      expect(adapter.seenQueries.single.containsKey('since_id'), isFalse);
    });

    test('a single flaky page is retried in place — the fetch still '
        'succeeds without restarting from page 1', () async {
      final adapter = _ScriptedAdapter(timeoutsBeforeSuccess: 1);
      final remote = _remoteWith(adapter);

      final result = await remote.getContacts(stationId: 1);

      expect(result.length, 1);
      expect(adapter.calls, 2); // one failure + one retry, same page
    });
  });
}
