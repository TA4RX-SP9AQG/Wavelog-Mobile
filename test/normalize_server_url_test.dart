import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/providers/dio_provider.dart';

void main() {
  group('normalizeServerUrl', () {
    test('leaves a bare domain unchanged', () {
      expect(normalizeServerUrl('https://wavelog.example.com'),
          'https://wavelog.example.com');
    });

    test('strips a trailing slash', () {
      expect(normalizeServerUrl('https://wavelog.example.com/'),
          'https://wavelog.example.com');
    });

    test('strips a bare /index.php suffix', () {
      expect(normalizeServerUrl('https://wavelog.example.com/index.php'),
          'https://wavelog.example.com');
    });

    test('strips /index.php/api/vN', () {
      expect(
          normalizeServerUrl('https://wavelog.example.com/index.php/api/v2'),
          'https://wavelog.example.com');
    });

    test('strips /index.php/api/vN/<endpoint> and a query string', () {
      expect(
          normalizeServerUrl(
              'https://wavelog.example.com/index.php/api/v2/qso?station_id=1'),
          'https://wavelog.example.com');
    });

    test('strips a bare /api/vN suffix (index.php hidden by rewrite rules)',
        () {
      expect(normalizeServerUrl('https://wavelog.example.com/api/v2'),
          'https://wavelog.example.com');
    });

    test(
        'strips /index.php followed by a NON-api route — the bug a user hit '
        'by pasting a browser URL from some other Wavelog page (e.g. the '
        'dashboard), which previously fell through both cleanup rules '
        'unchanged and produced a doubled, broken path once ApiEndpoints '
        'appended its own "/index.php/api/v2/..." on top of it', () {
      expect(
          normalizeServerUrl('https://wavelog.example.com/index.php/dashboard'),
          'https://wavelog.example.com');
      expect(
          normalizeServerUrl(
              'https://wavelog.example.com/index.php/station/edit/5'),
          'https://wavelog.example.com');
    });

    test('preserves a subdirectory install root', () {
      expect(normalizeServerUrl('https://example.com/wavelog'),
          'https://example.com/wavelog');
    });

    test('preserves a subdirectory install root while stripping its own '
        '/index.php/api/vN suffix', () {
      expect(
          normalizeServerUrl(
              'https://example.com/wavelog/index.php/api/v2/qso'),
          'https://example.com/wavelog');
    });

    test('trims surrounding whitespace', () {
      expect(normalizeServerUrl('  https://wavelog.example.com  '),
          'https://wavelog.example.com');
    });
  });
}
