import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/core/utils/connection_diagnostics.dart';

const _token = 'wl2_SECRETTOKEN1234567890';
const _host = 'wavelog.example.org';

/// Answers each request by [behave]: a status, or a thrown error. Records the
/// requests so a test can see what was sent.
class _Adapter implements HttpClientAdapter {
  final FutureOr<int> Function(RequestOptions options, int index) behave;
  final requests = <RequestOptions>[];
  _Adapter(this.behave);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final index = requests.length;
    requests.add(options);
    final status = await behave(options, index);
    return ResponseBody.fromString(
        jsonEncode({'data': {}}), status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        });
  }

  @override
  void close({bool force = false}) {}
}

DioException _refused(RequestOptions o) => DioException(
      requestOptions: o,
      type: DioExceptionType.connectionError,
      error: const SocketException('Connection refused',
          osError: OSError('Connection refused', 111)),
    );

DioException _timeout(RequestOptions o) => DioException(
      requestOptions: o,
      type: DioExceptionType.connectionTimeout,
    );

/// Runs the diagnostics against a fake server. The public and the
/// authenticated client share one adapter, so [behave] sees the whole chain.
Future<(DiagReport, _Adapter)> run(
  FutureOr<int> Function(RequestOptions o, int i) behave, {
  List<InternetAddress>? addresses,
  TcpConnector? connect,
  String serverUrl = 'https://wavelog.example.org/index.php',
}) async {
  final adapter = _Adapter(behave);
  Dio client({bool auth = false}) => Dio(BaseOptions(
        baseUrl: 'https://$_host',
        headers: {if (auth) 'Authorization': 'Bearer $_token'},
      ))
        ..httpClientAdapter = adapter;
  final report = await runConnectionDiagnostics(
    serverUrl: serverUrl,
    callsign: 'TA4RX',
    publicDio: client(),
    authDio: client(auth: true),
    resolve: (_) async =>
        addresses ?? [InternetAddress('203.0.113.45'), InternetAddress('2001:db8::1')],
    connect: connect ?? (_, __, ___) async {},
  );
  return (report, adapter);
}

String text(DiagReport r) => formatDiagnosticReport(r,
    token: _token,
    environment: {'App': '3.3.0+120', 'Network': 'mobile'},
    now: DateTime.utc(2026, 11, 4, 9, 10, 11));

void main() {
  group('the request chain', () {
    test('goes through status, token, every scope check, then the stations again',
        () async {
      final (report, adapter) = await run((_, __) => 200);
      final labels = report.requests.map((s) => s.label).toList();
      expect(labels.first, 'GET /status (no token)');
      expect(labels[1], 'GET /token');
      expect(labels, contains('POST /radio'));
      expect(labels.last, startsWith('GET /station (again'));
      expect(report.requests.every((s) => s.passed), isTrue);
      expect(report.requests, hasLength(labels.length));
      // The status check is sent without the token, the rest with it
      expect(adapter.requests.first.headers['Authorization'], isNull);
      expect(adapter.requests[1].headers['Authorization'], 'Bearer $_token');
    });

    test('a 400 for the empty radio body is the expected answer', () async {
      final (report, _) =
          await run((o, _) => o.path.endsWith('/radio') ? 400 : 200);
      final radio = report.requests.firstWhere((s) => s.label == 'POST /radio');
      expect(radio.outcome, DiagOutcome.http);
      expect(radio.status, 400);
      expect(radio.passed, isTrue);
      expect(text(report), contains('Everything answered'));
    });

    test('three timeouts in a row skip the rest', () async {
      final (report, adapter) =
          await run((o, _) => throw _timeout(o));
      final outcomes = report.requests.map((s) => s.outcome).toList();
      expect(outcomes.take(3), everyElement(DiagOutcome.timeout));
      expect(outcomes.skip(3), everyElement(DiagOutcome.skipped));
      expect(adapter.requests, hasLength(3));
    });
  });

  group('what the report points to', () {
    test('a server that stops answering after some requests: a rate limit',
        () async {
      final (report, _) = await run((o, i) => i >= 5 ? throw _refused(o) : 200);
      final failed = report.requests.where((s) => !s.passed).first;
      expect(failed.outcome, DiagOutcome.refused);
      expect(failed.detail, contains('errno 111'));
      expect(report.requests.take(5).every((s) => s.passed), isTrue);
      final t = text(report);
      expect(t, contains('connection refused'));
      expect(t, contains('answered 5 request(s), then stopped'));
      expect(t, contains('rate limit'));
    });

    test('nothing answers although the addresses connect', () async {
      final (report, _) = await run((o, _) => throw _refused(o));
      expect(text(report), contains('no request got an answer'));
    });

    test('no address connects: one hint about the port, not two', () async {
      final (report, _) = await run(
        (o, _) => throw _refused(o),
        connect: (a, port, _) async => throw const SocketException(
            'Connection refused',
            osError: OSError('Connection refused', 111)),
      );
      final t = text(report);
      expect(t, contains('No server address accepts a connection on port 443'));
      expect(t, isNot(contains('no request got an answer')));
      // The outcome names itself; the detail is only the OS error number
      expect(report.tcp.first.detail, 'errno 111');
      expect(t, contains('connection refused (0 ms) [errno 111]'));
    });

    test('only one address family accepts connections', () async {
      final (report, _) = await run(
        (_, __) => 200,
        connect: (a, port, _) async {
          if (a.type == InternetAddressType.IPv6) {
            throw const SocketException('Connection refused',
                osError: OSError('Connection refused', 111));
          }
        },
      );
      expect(report.tcp.map((s) => s.outcome),
          [DiagOutcome.ok, DiagOutcome.refused]);
      expect(text(report), contains('Only some of the server addresses'));
    });

    test('a rejected token is named', () async {
      final (report, _) =
          await run((o, _) => o.path.endsWith('/token') ? 401 : 200);
      expect(text(report), contains('rejected the token (HTTP 401)'));
    });

    test('a name that does not resolve', () async {
      final adapter = _Adapter((_, __) => 200);
      final report = await runConnectionDiagnostics(
        serverUrl: 'https://$_host',
        callsign: 'TA4RX',
        publicDio: Dio(BaseOptions(baseUrl: 'https://$_host'))
          ..httpClientAdapter = adapter,
        authDio: Dio(BaseOptions(baseUrl: 'https://$_host'))
          ..httpClientAdapter = adapter,
        resolve: (h) async => throw SocketException(
            "Failed host lookup: '$h'",
            osError: const OSError('No address associated with hostname', 7)),
      );
      expect(report.dns.outcome, DiagOutcome.dns);
      expect(report.dns.passed, isFalse);
      expect(text(report), contains('could not be resolved'));
    });
  });

  group('the report is safe to paste', () {
    test('it has no token, no full server name and no full address', () async {
      final (report, _) = await run((o, i) => i >= 4 ? throw _refused(o) : 200);
      final t = text(report);
      expect(t, isNot(contains(_token)));
      expect(t, isNot(contains(_host)));
      expect(t, isNot(contains('203.0.113.45')));
      expect(t, isNot(contains('2001:db8::1')));
      expect(t, contains('w***.org'));
      expect(t, contains('IPv4 203.0.113.x'));
      expect(t, contains('IPv6 2001:db8:x'));
      expect(t, contains('App: 3.3.0+120'));
      expect(t, contains('Time (UTC): 2026-11-04T09:10:11Z'));
    });

    test('a token or server name inside an error detail is hidden too', () {
      const report = DiagReport(
        scheme: 'https',
        host: _host,
        port: 443,
        typedWithIndexPhp: false,
        subfolder: false,
        sslCheckBypassed: false,
        dns: DiagStep('lookup', DiagOutcome.ok, passed: true),
        tcp: [],
        requests: [
          DiagStep('GET /station', DiagOutcome.other,
              detail: "boom $_token $_host 198.51.100.77"),
        ],
      );
      final t = text(report);
      expect(t, isNot(contains(_token)));
      expect(t, isNot(contains(_host)));
      expect(t, isNot(contains('198.51.100.77')));
      expect(t, contains('[token]'));
      expect(t, contains('198.51.100.x'));
    });

    test('it says how the address was typed', () async {
      final (typed, _) = await run((_, __) => 200,
          serverUrl: 'https://wavelog.example.org/index.php');
      expect(text(typed), contains('Typed with /index.php: yes'));
      final (plain, _) =
          await run((_, __) => 200, serverUrl: 'https://wavelog.example.org');
      expect(text(plain), contains('Typed with /index.php: no'));
    });

    test('masking', () {
      expect(maskHost('wavelog.example.org'), 'w***.org');
      expect(maskHost('localhost'), 'l***');
      expect(maskHost('192.168.1.20'), '192.168.1.x');
      expect(maskAddress(InternetAddress('2001:db8:85a3::8a2e:370:7334')),
          '2001:db8:x');
    });
  });

  group('classifying errors', () {
    DiagOutcome of(Object e) => classifyError(e).outcome;

    test('socket errors', () {
      expect(of(const SocketException('x', osError: OSError('Connection refused', 111))),
          DiagOutcome.refused);
      expect(of(const SocketException("Failed host lookup: 'a'")), DiagOutcome.dns);
      expect(of(const SocketException('x', osError: OSError('Network is unreachable', 101))),
          DiagOutcome.unreachable);
      expect(of(const SocketException('x', osError: OSError('Connection reset by peer', 104))),
          DiagOutcome.reset);
      expect(of(TimeoutException('t')), DiagOutcome.timeout);
      expect(of(const HandshakeException('bad cert')), DiagOutcome.tls);
    });

    test('an HTTP answer keeps its status and the API error code', () {
      final c = classifyError(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 403,
          data: {'error': {'code': 'forbidden', 'message': 'Token is missing scope'}},
        ),
      ));
      expect(c.outcome, DiagOutcome.http);
      expect(c.status, 403);
      expect(c.detail, 'forbidden');
    });
  });

  group('the shared scope checks', () {
    Future<bool?> check(ScopeProbe p, FutureOr<int> Function(RequestOptions) f) {
      final dio = Dio(BaseOptions(baseUrl: 'https://$_host'))
        ..httpClientAdapter = _Adapter((o, _) => f(o));
      return runScopeProbe(dio, p);
    }

    final station = scopeProbes('TA4RX').first;
    final radio = scopeProbes('TA4RX').last;

    test('success, a missing scope and an answer that says nothing', () async {
      expect(await check(station, (_) => 200), isTrue);
      expect(await check(station, (_) => 403), isFalse);
      expect(await check(station, (_) => 401), isFalse);
      expect(await check(station, (_) => 500), isNull);
      expect(await check(station, (o) => throw _refused(o)), isNull);
    });

    test('radio:write is reached by the 400 for an empty body', () async {
      expect(radio.scope, 'radio:write');
      expect(await check(radio, (_) => 400), isTrue);
      expect(await check(radio, (_) => 403), isFalse);
      expect(await check(radio, (_) => 500), isNull);
    });
  });
}
