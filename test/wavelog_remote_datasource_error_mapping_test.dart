import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/core/errors/app_exception.dart';
import 'package:wavelog_mobile/data/datasources/remote/wavelog_remote_datasource.dart';

/// A minimal [HttpClientAdapter] that always answers with a canned status
/// code + JSON body, regardless of the request, enough to drive
/// WavelogRemoteDatasource's private _mapDioException through a real Dio
/// error path without hitting the network.
class _CannedAdapter implements HttpClientAdapter {
  final int statusCode;
  final Map<String, dynamic> body;

  _CannedAdapter(this.statusCode, this.body);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final bytes = utf8.encode(jsonEncode(body));
    return ResponseBody.fromBytes(bytes, statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

WavelogRemoteDatasource _remoteFor(int statusCode, Map<String, dynamic> body) {
  // Default validateStatus (2xx only) so Dio raises a DioException with the
  // canned status code, exercising the same badResponse path a real
  // 401/403 from the server would.
  final dio = Dio()..httpClientAdapter = _CannedAdapter(statusCode, body);
  return WavelogRemoteDatasource(dio: dio);
}

void main() {
  group('WavelogRemoteDatasource 401/403 mapping', () {
    test('401 maps to UnauthorizedException with the generic "invalid key" '
        'message, regardless of the response body', () async {
      final remote = _remoteFor(401, {
        'error': {'code': 'unauthorized', 'message': 'Invalid token'}
      });

      await expectLater(
        remote.setActiveLogbook(1),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test(
        '403 maps to ForbiddenException and surfaces the server\'s actual '
        'reason (e.g. the missing scope) instead of the generic '
        '"invalid key" text', () async {
      final remote = _remoteFor(403, {
        'error': {
          'code': 'insufficient_scope',
          'message': 'Token is missing the required scope: logbook:write',
        }
      });

      try {
        await remote.setActiveLogbook(1);
        fail('expected ForbiddenException');
      } on ForbiddenException catch (e) {
        expect(e.message, 'Token is missing the required scope: logbook:write');
      }
    });

    test('403 with no parseable server message still throws '
        'ForbiddenException (not UnauthorizedException), with a fallback '
        'message', () async {
      final remote = _remoteFor(403, {'unexpected': 'shape'});

      try {
        await remote.setActiveLogbook(1);
        fail('expected ForbiddenException');
      } on ForbiddenException catch (e) {
        expect(e.message, isNotEmpty);
      }
    });
  });
}
