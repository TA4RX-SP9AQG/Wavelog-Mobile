import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../constants/api_endpoints.dart';
import 'local_network.dart';

// ── The token check requests, shared by sign-in and the diagnostics ──────────

/// One request of the sign-in token check: a call that only works with the
/// scope [scope].
class ScopeProbe {
  final String scope;
  final String method;
  final String path;
  final Map<String, dynamic>? query;
  final Object? body;

  /// Statuses besides success that still show the scope is there: radio:write
  /// is checked with an empty body, which Wavelog rejects (400) only after
  /// it has checked the scope.
  final Set<int> okStatuses;

  const ScopeProbe(
    this.scope,
    this.method,
    this.path, {
    this.query,
    this.body,
    this.okStatuses = const {},
  });

  /// "GET /station", the path without the API prefix.
  String get label => '$method ${path.replaceFirst(ApiEndpoints.apiRoot, '')}';
}

/// The checks sign-in runs on a token, in this order. Only radio:write needs
/// a write call, and that one cannot change anything (see [ScopeProbe]).
List<ScopeProbe> scopeProbes(String callsign) => [
      const ScopeProbe('station:read', 'GET', ApiEndpoints.station),
      const ScopeProbe('logbook:read', 'GET', ApiEndpoints.logbook),
      const ScopeProbe('contest:read', 'GET', ApiEndpoints.contest),
      const ScopeProbe('statistic:read', 'GET', ApiEndpoints.statistics),
      ScopeProbe('lookup:read', 'GET', ApiEndpoints.lookup, query: {
        'callsign': callsign,
        'detail': 'full',
        'callbook': 'true',
      }),
      const ScopeProbe('confirmation:read', 'GET', ApiEndpoints.confirmation,
          query: {'page': 1}),
      const ScopeProbe('qso:read', 'GET', ApiEndpoints.qso,
          query: {'page': 1}),
      const ScopeProbe('radio:write', 'POST', ApiEndpoints.radio,
          body: <String, dynamic>{}, okStatuses: {400, 422}),
    ];

Future<Response<dynamic>> _send(Dio dio, ScopeProbe p) => dio.request<dynamic>(
      p.path,
      data: p.body,
      queryParameters: p.query,
      options: Options(method: p.method),
    );

/// Whether the token has the scope of [p]: true or false, or null when the
/// answer says nothing about it (network error, timeout, a server error).
Future<bool?> runScopeProbe(Dio dio, ScopeProbe p) async {
  try {
    await _send(dio, p);
    return true;
  } on DioException catch (e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return false;
    if (code != null && p.okStatuses.contains(code)) return true;
    return null;
  } catch (_) {
    return null;
  }
}

// ── Diagnostics ──────────────────────────────────────────────────────────────

enum DiagOutcome {
  ok,
  http,
  refused,
  reset,
  timeout,
  dns,
  tls,
  unreachable,
  localNetworkDenied,
  other,
  skipped,
}

/// One connection or request of a diagnostics run.
class DiagStep {
  final String label;
  final DiagOutcome outcome;
  final int? status;
  final int ms;
  final String? detail;

  /// Whether this step went as it should; an HTTP status can be the right
  /// answer (see [ScopeProbe.okStatuses]).
  final bool passed;

  const DiagStep(
    this.label,
    this.outcome, {
    this.status,
    this.ms = 0,
    this.detail,
    this.passed = false,
  });
}

class DiagReport {
  final String scheme;
  final String host;
  final int port;
  final bool typedWithIndexPhp;
  final bool subfolder;
  final bool sslCheckBypassed;
  final DiagStep dns;
  final List<DiagStep> tcp;
  final List<DiagStep> requests;

  const DiagReport({
    required this.scheme,
    required this.host,
    required this.port,
    required this.typedWithIndexPhp,
    required this.subfolder,
    required this.sslCheckBypassed,
    required this.dns,
    required this.tcp,
    required this.requests,
  });
}

typedef HostResolver = Future<List<InternetAddress>> Function(String host);
typedef TcpConnector = Future<void> Function(
    InternetAddress address, int port, Duration timeout);

Future<List<InternetAddress>> _lookup(String host) => InternetAddress.lookup(host);

Future<void> _tcpConnect(InternetAddress a, int port, Duration timeout) async {
  final socket = await Socket.connect(a, port, timeout: timeout);
  socket.destroy();
}

/// Consecutive timeouts after which the rest of the requests are skipped, so
/// an unreachable server does not keep the user waiting.
const _maxConsecutiveTimeouts = 3;

/// Checks the way to the server and the sign-in requests one by one, and
/// records what each came back with. [publicDio] sends no token, [authDio]
/// does. Nothing is written on the server.
Future<DiagReport> runConnectionDiagnostics({
  required String serverUrl,
  required String callsign,
  required Dio publicDio,
  required Dio authDio,
  bool sslCheckBypassed = false,
  HostResolver resolve = _lookup,
  TcpConnector connect = _tcpConnect,
}) async {
  final base = Uri.parse(authDio.options.baseUrl);
  final host = base.host;
  final port = base.hasPort ? base.port : (base.scheme == 'http' ? 80 : 443);
  final typedPath = Uri.tryParse(serverUrl.trim())?.path ?? '';

  // DNS
  final addresses = <InternetAddress>[];
  DiagStep dns;
  final literal = InternetAddress.tryParse(host);
  if (literal != null) {
    addresses.add(literal);
    dns = const DiagStep('lookup', DiagOutcome.skipped,
        detail: 'the server is given as an IP address', passed: true);
  } else {
    final watch = Stopwatch()..start();
    try {
      addresses.addAll(
          await resolve(host).timeout(const Duration(seconds: 10)));
      dns = DiagStep('lookup', DiagOutcome.ok,
          ms: watch.elapsedMilliseconds,
          detail: '${addresses.length} address(es)',
          passed: true);
    } catch (e) {
      final c = classifyError(e);
      dns = DiagStep('lookup', c.outcome == DiagOutcome.other
              ? DiagOutcome.dns
              : c.outcome,
          ms: watch.elapsedMilliseconds, detail: c.detail);
    }
  }

  // TCP, to every address at once
  final tcp = await Future.wait([
    for (final a in addresses.take(6))
      () async {
        final watch = Stopwatch()..start();
        final label = '${a.type == InternetAddressType.IPv6 ? 'IPv6' : 'IPv4'} '
            '${maskAddress(a)}';
        try {
          await connect(a, port, const Duration(seconds: 8));
          return DiagStep(label, DiagOutcome.ok,
              ms: watch.elapsedMilliseconds, passed: true);
        } catch (e) {
          final c = classifyError(e);
          return DiagStep(label, c.outcome,
              ms: watch.elapsedMilliseconds, detail: c.detail);
        }
      }(),
  ]);

  // The requests, in the order sign-in sends them
  authDio.options.connectTimeout = const Duration(seconds: 8);
  authDio.options.receiveTimeout = const Duration(seconds: 12);
  publicDio.options.connectTimeout = const Duration(seconds: 8);
  publicDio.options.receiveTimeout = const Duration(seconds: 12);

  final probes = scopeProbes(callsign);
  final plan = <_Planned>[
    _Planned('GET /status (no token)', publicDio,
        () => publicDio.get<dynamic>(ApiEndpoints.version)),
    _Planned('GET /token', authDio,
        () => authDio.get<dynamic>(ApiEndpoints.token)),
    for (final p in probes)
      _Planned(p.label, authDio, () => _send(authDio, p),
          okStatuses: p.okStatuses),
    _Planned('GET /station (again, after ${probes.length + 2} requests)',
        authDio, () => authDio.get<dynamic>(ApiEndpoints.station)),
  ];

  final requests = <DiagStep>[];
  var timeouts = 0;
  for (final item in plan) {
    if (timeouts >= _maxConsecutiveTimeouts) {
      requests.add(DiagStep(item.label, DiagOutcome.skipped,
          detail: 'skipped after $_maxConsecutiveTimeouts timeouts in a row'));
      continue;
    }
    final step = await _timed(item);
    requests.add(step);
    timeouts = step.outcome == DiagOutcome.timeout ? timeouts + 1 : 0;
  }

  return DiagReport(
    scheme: base.scheme,
    host: host,
    port: port,
    typedWithIndexPhp: RegExp(r'/index\.php', caseSensitive: false)
        .hasMatch(typedPath),
    subfolder: base.path.isNotEmpty && base.path != '/',
    sslCheckBypassed: sslCheckBypassed,
    dns: dns,
    tcp: tcp,
    requests: requests,
  );
}

class _Planned {
  final String label;
  final Dio dio;
  final Future<Response<dynamic>> Function() send;
  final Set<int> okStatuses;
  _Planned(this.label, this.dio, this.send, {this.okStatuses = const {}});
}

Future<DiagStep> _timed(_Planned p) async {
  final watch = Stopwatch()..start();
  try {
    final response = await p.send();
    return DiagStep(p.label, DiagOutcome.ok,
        status: response.statusCode,
        ms: watch.elapsedMilliseconds,
        passed: true);
  } catch (e) {
    final c = classifyError(e);
    return DiagStep(p.label, c.outcome,
        status: c.status,
        ms: watch.elapsedMilliseconds,
        detail: c.detail,
        passed: c.outcome == DiagOutcome.http &&
            c.status != null &&
            p.okStatuses.contains(c.status));
  }
}

/// What an error from a connection or a request means, in the terms of the
/// report. The details leave out addresses and anything the server sent.
({DiagOutcome outcome, int? status, String? detail}) classifyError(Object e) {
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.badResponse:
        return (
          outcome: DiagOutcome.http,
          status: e.response?.statusCode,
          detail: _apiErrorCode(e.response?.data),
        );
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return (outcome: DiagOutcome.timeout, status: null, detail: e.type.name);
      case DioExceptionType.badCertificate:
        return (
          outcome: DiagOutcome.tls,
          status: null,
          detail: 'certificate could not be verified',
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
      case DioExceptionType.cancel:
        return classifyError(e.error ?? e.message ?? 'unknown');
    }
  }
  if (e is LocalNetworkPermissionDeniedError) {
    return (
      outcome: DiagOutcome.localNetworkDenied,
      status: null,
      detail: 'Android local network permission denied',
    );
  }
  if (e is TlsException) {
    return (outcome: DiagOutcome.tls, status: null, detail: e.message);
  }
  if (e is TimeoutException) {
    return (outcome: DiagOutcome.timeout, status: null, detail: 'timed out');
  }
  if (e is SocketException) {
    final code = e.osError?.errorCode;
    final text = '${e.message} ${e.osError?.message ?? ''}'.toLowerCase();
    DiagOutcome outcome = DiagOutcome.other;
    if (code == 111 || code == 61 || code == 10061 ||
        text.contains('connection refused')) {
      outcome = DiagOutcome.refused;
    } else if (text.contains('failed host lookup') ||
        text.contains('no address associated') ||
        text.contains('nodename nor servname')) {
      outcome = DiagOutcome.dns;
    } else if (code == 101 || code == 113 || code == 10051 || code == 10065 ||
        text.contains('network is unreachable') ||
        text.contains('no route to host')) {
      outcome = DiagOutcome.unreachable;
    } else if (code == 104 || code == 10054 ||
        text.contains('connection reset')) {
      outcome = DiagOutcome.reset;
    } else if (code == 110 || code == 10060 || text.contains('timed out')) {
      outcome = DiagOutcome.timeout;
    }
    // A known outcome names itself; only the OS error number adds to it.
    final detail = outcome != DiagOutcome.other
        ? (code != null ? 'errno $code' : null)
        : (e.osError == null ? e.message : '${e.message} (errno $code)');
    return (outcome: outcome, status: null, detail: detail);
  }
  return (outcome: DiagOutcome.other, status: null, detail: '${e.runtimeType}');
}

/// The short code of a v2 API error body ({"error": {"code": "..."}}).
String? _apiErrorCode(Object? body) {
  if (body is! Map) return null;
  final error = body['error'];
  final code = error is Map ? error['code'] : null;
  return code is String && code.length <= 40 ? code : null;
}

// ── The report ───────────────────────────────────────────────────────────────

/// "203.0.113.x" or "2001:db8:x": enough to tell public from private and
/// IPv4 from IPv6, not enough to find the server.
String maskAddress(InternetAddress a) {
  if (a.type == InternetAddressType.IPv4) {
    final parts = a.address.split('.');
    return '${parts.take(3).join('.')}.x';
  }
  final parts = a.address.split(':').where((p) => p.isNotEmpty).toList();
  return '${parts.take(2).join(':')}:x';
}

/// "w***.org" for wavelog.example.org.
String maskHost(String host) {
  final ip = InternetAddress.tryParse(host);
  if (ip != null) return maskAddress(ip);
  final parts = host.split('.');
  if (host.isEmpty) return host;
  if (parts.length < 2) return '${host[0]}***';
  return '${parts.first[0]}***.${parts.last}';
}

String _redact(String s, {required String token, required String host}) {
  var out = s;
  if (token.length >= 6) out = out.replaceAll(token, '[token]');
  if (host.isNotEmpty) {
    out = out.replaceAll(RegExp(RegExp.escape(host), caseSensitive: false),
        maskHost(host));
  }
  return out.replaceAllMapped(
      RegExp(r'\b(\d{1,3}\.\d{1,3}\.\d{1,3})\.\d{1,3}\b'),
      (m) => '${m[1]}.x');
}

String _outcomeText(DiagStep s) {
  switch (s.outcome) {
    case DiagOutcome.ok:
      return s.status != null ? '${s.status}' : 'ok';
    case DiagOutcome.http:
      return 'HTTP ${s.status ?? '?'}${s.passed ? ' (expected)' : ''}';
    case DiagOutcome.refused:
      return 'connection refused';
    case DiagOutcome.reset:
      return 'connection reset';
    case DiagOutcome.timeout:
      return 'timeout';
    case DiagOutcome.dns:
      return 'host name not found';
    case DiagOutcome.tls:
      return 'TLS / certificate error';
    case DiagOutcome.unreachable:
      return 'network unreachable';
    case DiagOutcome.localNetworkDenied:
      return 'local network permission denied';
    case DiagOutcome.other:
      return 'error';
    case DiagOutcome.skipped:
      return 'skipped';
  }
}

String _line(DiagStep s, {String indent = '  '}) {
  final time = s.outcome == DiagOutcome.skipped ? '' : ' (${s.ms} ms)';
  final detail = s.detail != null && s.detail!.isNotEmpty ? ' [${s.detail}]' : '';
  return '$indent${s.label}: ${_outcomeText(s)}$time$detail';
}

/// What the results point to, in a few lines for whoever reads the report.
List<String> diagnosticHints(DiagReport r) {
  final hints = <String>[];
  final tcpFailed = r.tcp.where((s) => !s.passed).toList();
  final tcpOk = r.tcp.where((s) => s.passed).toList();
  final failed = r.requests.where((s) => !s.passed && s.outcome != DiagOutcome.skipped).toList();
  final firstFail = failed.isEmpty ? null : failed.first;

  if (!r.dns.passed) {
    hints.add('The server name could not be resolved: check the address, or '
        'the DNS of this network.');
  }
  if (tcpFailed.isNotEmpty && tcpOk.isNotEmpty) {
    hints.add('Only some of the server addresses accept connections '
        '(${tcpOk.length} of ${r.tcp.length}). A broken IPv6 (AAAA) record or '
        'a firewall rule for one address family can cause this.');
  }
  if (tcpFailed.isNotEmpty && tcpOk.isEmpty && r.tcp.isNotEmpty) {
    hints.add('No server address accepts a connection on port ${r.port}: the '
        'port is closed, or a firewall blocks this network.');
  }
  if (firstFail != null) {
    final index = r.requests.indexOf(firstFail);
    final answeredBefore = r.requests.take(index).where((s) => s.passed).length;
    final connectionLevel = const {
      DiagOutcome.refused,
      DiagOutcome.reset,
      DiagOutcome.timeout,
    }.contains(firstFail.outcome);
    if (connectionLevel && answeredBefore > 0) {
      hints.add('The server answered $answeredBefore request(s), then stopped '
          'answering (request ${index + 1}). A rate limit or an automatic IP '
          'ban (fail2ban, CrowdSec, a firewall) in front of Wavelog can do '
          'this.');
    } else if (connectionLevel && answeredBefore == 0 && tcpOk.isNotEmpty) {
      hints.add('The connection to the server opens, but no request got an '
          'answer: the server or its firewall may block this phone or '
          'network.');
    }
    if (firstFail.outcome == DiagOutcome.http &&
        (firstFail.status == 401 || firstFail.status == 403)) {
      hints.add('The server rejected the token (HTTP ${firstFail.status}): '
          'check the token and its scopes.');
    }
    if (firstFail.outcome == DiagOutcome.tls) {
      hints.add('The TLS certificate could not be verified.');
    }
    if (firstFail.outcome == DiagOutcome.localNetworkDenied) {
      hints.add('Android blocked the local network. Allow it for this app in '
          'the Android settings.');
    }
  }
  if (hints.isEmpty && failed.isEmpty && tcpFailed.isEmpty && r.dns.passed) {
    hints.add('Everything answered. If sign-in still fails, the cause is not '
        'the connection.');
  }
  return hints;
}

/// The report as text to paste into a bug report. It has no token, and the
/// server name and addresses are partly hidden. [environment] lists what
/// the app knows about the device.
String formatDiagnosticReport(
  DiagReport r, {
  required String token,
  required Map<String, String> environment,
  DateTime? now,
}) {
  String red(String s) => _redact(s, token: token, host: r.host);
  final out = StringBuffer()
    ..writeln('Wavelog Mobile connection report')
    ..writeln('Time (UTC): '
        '${(now ?? DateTime.now()).toUtc().toIso8601String().split('.').first}Z');
  for (final e in environment.entries) {
    out.writeln('${e.key}: ${red(e.value)}');
  }
  out
    ..writeln('Server: ${r.scheme}://${maskHost(r.host)}:${r.port}')
    ..writeln('Typed with /index.php: ${r.typedWithIndexPhp ? 'yes' : 'no'}'
        ' | Subfolder install: ${r.subfolder ? 'yes' : 'no'}'
        ' | SSL check: ${r.sslCheckBypassed ? 'off' : 'on'}')
    ..writeln()
    ..writeln('DNS')
    ..writeln(red(_line(r.dns)))
    ..writeln('TCP connect to port ${r.port}');
  if (r.tcp.isEmpty) out.writeln('  (no address to connect to)');
  for (final s in r.tcp) {
    out.writeln(red(_line(s)));
  }
  out.writeln('Requests, in the order sign-in sends them');
  for (var i = 0; i < r.requests.length; i++) {
    final n = '${i + 1}.'.padLeft(3);
    out.writeln(red(_line(r.requests[i], indent: '$n ')));
  }
  out
    ..writeln()
    ..writeln('What this points to');
  for (final h in diagnosticHints(r)) {
    out.writeln('- $h');
  }
  return out.toString();
}
