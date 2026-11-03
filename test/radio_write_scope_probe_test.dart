import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/presentation/screens/login/login_screen.dart';

/// Answers every request with [status] (or fails to connect when null) and
/// records what was sent.
class _Adapter implements HttpClientAdapter {
  final int? status;
  final requests = <RequestOptions>[];
  _Adapter(this.status);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (status == null) {
      throw DioException(
          requestOptions: options, type: DioExceptionType.connectionError);
    }
    return ResponseBody.fromString(jsonEncode({'error': {}}), status!,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        });
  }

  @override
  void close({bool force = false}) {}
}

Future<(bool?, _Adapter)> probe(int? status) async {
  final adapter = _Adapter(status);
  final dio = Dio(BaseOptions(baseUrl: 'https://log.example'))
    ..httpClientAdapter = adapter;
  return (await probeRadioWriteScope(dio), adapter);
}

void main() {
  test('a missing scope (403) fails the radio:write check', () async {
    expect((await probe(403)).$1, isFalse);
    expect((await probe(401)).$1, isFalse);
  });

  test('reaching the body validation (400) means the scope is there', () async {
    expect((await probe(400)).$1, isTrue);
    expect((await probe(201)).$1, isTrue);
  });

  test('anything else is inconclusive, not held against the token', () async {
    expect((await probe(500)).$1, isNull);
    expect((await probe(404)).$1, isNull);
    expect((await probe(null)).$1, isNull);
  });

  test('the probe never sends a radio name, so nothing can be written',
      () async {
    final (_, adapter) = await probe(400);
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.data, isEmpty);
  });
}
