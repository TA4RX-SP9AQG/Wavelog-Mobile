import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/utils/connection_diagnostics.dart';
import 'dio_provider.dart';

/// What the app knows about the device, for a connection report. Each item
/// falls back to "unknown" rather than failing the report.
Future<Map<String, String>> collectDiagnosticEnvironment() async {
  final env = <String, String>{};
  try {
    final info = await PackageInfo.fromPlatform();
    env['App'] = '${info.version}+${info.buildNumber}';
  } catch (_) {
    env['App'] = 'unknown';
  }
  try {
    if (Platform.isAndroid) {
      final a = await DeviceInfoPlugin().androidInfo;
      env['Android'] = '${a.version.release} (SDK ${a.version.sdkInt}), '
          '${a.manufacturer} ${a.model}';
    } else {
      env['Platform'] = Platform.operatingSystem;
    }
  } catch (_) {
    env['Android'] = 'unknown';
  }
  try {
    final results = await Connectivity().checkConnectivity();
    env['Network'] = results.map((r) => r.name).join(', ');
  } catch (_) {
    env['Network'] = 'unknown';
  }
  return env;
}

/// Runs the connection diagnostics against [serverUrl] and returns the report
/// text. Nothing is written on the server, and the token is never part of the
/// text.
Future<String> buildConnectionReport({
  required String serverUrl,
  required String token,
  required String callsign,
  required bool allowInsecureSsl,
}) async {
  final environment = collectDiagnosticEnvironment();
  final report = await runConnectionDiagnostics(
    serverUrl: serverUrl,
    callsign: callsign,
    publicDio: buildWavelogDio(serverUrl, allowInsecureSsl: allowInsecureSsl),
    authDio: buildWavelogDio(serverUrl,
        bearerToken: token, allowInsecureSsl: allowInsecureSsl),
    sslCheckBypassed: allowInsecureSsl,
  );
  return formatDiagnosticReport(
    report,
    token: token,
    environment: await environment,
  );
}
