import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/data/datasources/remote/pota_datasource.dart';
import 'package:wavelog_mobile/data/datasources/remote/pota_parks_datasource.dart';

String fixture(String name) =>
    File('test/fixtures/$name').readAsStringSync();

/// Answers by [reply]: a status and a body, or a thrown error. Keeps the
/// requests.
class _Adapter implements HttpClientAdapter {
  final FutureOr<(int, String)> Function(RequestOptions o) reply;
  final requests = <RequestOptions>[];
  _Adapter(this.reply);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final (status, body) = await reply(options);
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    });
  }

  @override
  void close({bool force = false}) {}
}

(PotaParksDatasource, _Adapter) make(
    FutureOr<(int, String)> Function(RequestOptions o) reply) {
  final adapter = _Adapter(reply);
  final dio = Dio(BaseOptions(baseUrl: 'https://api.pota.app'))
    ..httpClientAdapter = adapter;
  return (PotaParksDatasource(dio: dio), adapter);
}

String features(List<String> items) =>
    '{"type":"FeatureCollection","features":[${items.join(',')}]}';

String feature(String ref, {String coords = '[21.0,52.5]', String? name}) =>
    '{"type":"Feature","properties":{"reference":"$ref",'
    '"name":${name == null ? 'null' : '"$name"'},"atno":false},'
    '"geometry":{"type":"Point","coordinates":$coords}}';

void main() {
  group('parks of a square', () {
    test('asks for a speck at the square centre, latitude first', () async {
      final (ds, adapter) = make((_) => (200, fixture('pota_grid_square.json')));
      await ds.parksInSquare('KO02');
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.path,
          '/park/grids/52.499/20.999/52.501/21.001/0');
    });

    test('reads the parks of a real reply', () async {
      // None of the real parks is new; the last one is made so here.
      final data = jsonDecode(fixture('pota_grid_square.json'))
          as Map<String, dynamic>;
      ((data['features'] as List).last['properties'] as Map)['atno'] = true;
      final json = jsonEncode(data);
      final (ds, _) = make((_) => (200, json));
      final parks = await ds.parksInSquare('KO02');
      expect(parks.map((p) => p.reference), ['PL-0363', 'PL-0365', 'PL-0373']);
      final first = parks.first;
      expect(first.name, 'Dąbrowy Seroczyńskie Nature Reserve');
      // GeoJSON is longitude first; the park stores latitude first
      expect(first.lat, closeTo(52.0088, 1e-9));
      expect(first.lon, closeTo(21.9843, 1e-9));
      expect(parks.map((p) => p.neverActivated), [false, false, true]);
    });

    test('leaves out what cannot be drawn and keeps the rest', () async {
      final (ds, _) = make((_) => (
            200,
            features([
              feature('PL-0001'),
              feature('pl-0002', coords: '[21.1,52.6]', name: 'Lower case'),
              feature('PL-0001', coords: '[21.2,52.7]'), // the same park again
              feature('NOT A REF'),
              feature('PL-0003', coords: '[0,0]'), // stored without position
              feature('PL-0004', coords: '[21.0,95.0]'),
              feature('PL-0005', coords: '["x","y"]'),
              feature('PL-0006', coords: '[21.0]'),
              '{"type":"Feature","properties":{"reference":"PL-0007"}}',
              '"garbage"',
              'null',
              feature('PL-0008', name: '   '),
            ])
          ));
      final parks = await ds.parksInSquare('KO02');
      expect(parks.map((p) => p.reference), ['PL-0001', 'PL-0002', 'PL-0008']);
      expect(parks[0].lat, 52.5); // the first of the repeated park
      expect(parks[1].name, 'Lower case');
      expect(parks[2].name, 'PL-0008'); // no name: the reference
    });

    test('an empty square is a valid answer', () async {
      final (ds, _) = make((_) => (200, features([])));
      expect(await ds.parksInSquare('KO02'), isEmpty);
    });

    test('a page or an empty body with status 200 is an error', () async {
      for (final body in ['<html><body>Maintenance</body></html>', '', '  ']) {
        final (ds, _) = make((_) => (200, body));
        await expectLater(
            ds.parksInSquare('KO02'), throwsA(isA<PotaApiException>()),
            reason: body);
      }
    });

    test('JSON that is not a feature collection is an error', () async {
      for (final body in ['[]', '{}', '{"features":"no"}', '"x"', 'null']) {
        final (ds, _) = make((_) => (200, body));
        await expectLater(
            ds.parksInSquare('KO02'), throwsA(isA<PotaApiException>()),
            reason: body);
      }
    });

    test('server errors and a timeout reach the caller', () async {
      for (final status in [404, 429, 500, 503]) {
        final (ds, _) = make((_) => (status, '{}'));
        await expectLater(
          ds.parksInSquare('KO02'),
          throwsA(isA<DioException>()
              .having((e) => e.response?.statusCode, 'status', status)),
        );
      }
      final (ds, _) = make((o) => throw DioException(
          requestOptions: o, type: DioExceptionType.connectionTimeout));
      await expectLater(ds.parksInSquare('KO02'), throwsA(isA<DioException>()));
    });

    test('a bad square name never leaves the app', () async {
      final (ds, adapter) = make((_) => (200, features([])));
      await expectLater(ds.parksInSquare('nope'), throwsArgumentError);
      expect(adapter.requests, isEmpty);
    });
  });

  group('one park', () {
    test('detail', () async {
      final (ds, adapter) =
          make((_) => (200, fixture('pota_park_detail.json')));
      final park = (await ds.getDetail('pl-0363'))!;
      expect(adapter.requests.single.path, '/park/PL-0363');
      expect(park.reference, 'PL-0363');
      expect(park.name, 'Dąbrowy Seroczyńskie');
      expect(park.type, 'Nature Reserve');
      expect(park.locationName, 'Mazowieckie');
      expect(park.country, 'Poland');
      expect(park.grid6, 'KO02xa');
      expect(park.lat, closeTo(52.0088, 1e-9));
      expect(park.lon, closeTo(21.9843, 1e-9));
      expect(park.firstActivator, 'SQ8JCB');
      expect(park.firstActivationDate, DateTime.utc(2013, 9, 15));
    });

    test('an unknown park is null, not an error', () async {
      final (ds, _) = make((_) => (404, '{"message":"not found"}'));
      expect(await ds.getDetail('PL-9999'), isNull);
      expect(await ds.getStats('PL-9999'), isNull);
      expect(await ds.getRecentActivations('PL-9999'), isEmpty);
    });

    test('other failures are not "not found"', () async {
      final (ds, _) = make((_) => (500, '{}'));
      await expectLater(ds.getDetail('PL-0363'), throwsA(isA<DioException>()));
      await expectLater(ds.getStats('PL-0363'), throwsA(isA<DioException>()));
    });

    test('a body that is not a park is an error', () async {
      final (ds, _) = make((_) => (200, '{"hello":"world"}'));
      await expectLater(
          ds.getDetail('PL-0363'), throwsA(isA<PotaApiException>()));
      await expectLater(
          ds.getStats('PL-0363'), throwsA(isA<PotaApiException>()));
    });

    test('a reference that is not one is refused before any request', () async {
      final (ds, adapter) = make((_) => (200, '{}'));
      for (final bad in ['', 'PL-', '../etc', 'PL-0363/../x', 'PL-0363?x=1']) {
        await expectLater(ds.getDetail(bad), throwsArgumentError, reason: bad);
        await expectLater(ds.getStats(bad), throwsArgumentError, reason: bad);
        await expectLater(ds.getRecentActivations(bad), throwsArgumentError,
            reason: bad);
      }
      expect(adapter.requests, isEmpty);
    });

    test('statistics', () async {
      final (ds, adapter) =
          make((_) => (200, fixture('pota_park_stats.json')));
      final stats = (await ds.getStats('PL-0363'))!;
      expect(adapter.requests.single.path, '/park/stats/PL-0363');
      expect((stats.attempts, stats.activations, stats.contacts), (4, 4, 390));
    });

    test('recent activations: dates as UTC days, the count in the query',
        () async {
      final (ds, adapter) =
          make((_) => (200, fixture('pota_park_activations.json')));
      final list = await ds.getRecentActivations('PL-0363', count: 3);
      expect(adapter.requests.single.uri.toString(),
          'https://api.pota.app/park/activations/PL-0363?count=3');
      expect(list.map((a) => a.callsign), ['SP5TEN', 'SQ8JCB', 'SQ8JCB']);
      expect(list.first.date, DateTime.utc(2025, 6, 29));
      expect(list.first.qsos, 11);
    });

    test('an activation that is not usable is dropped, a bad date is null',
        () async {
      final (ds, _) = make((_) => (
            200,
            '[{"activeCallsign":"sp5ten","qso_date":"20250230x","totalQSOs":"7"},'
                '{"qso_date":"20250101"},"junk",null]'
          ));
      final list = await ds.getRecentActivations('PL-0363');
      expect(list, hasLength(1));
      expect(list.single.callsign, 'SP5TEN');
      expect(list.single.date, isNull);
      expect(list.single.qsos, 7);
    });
  });

  test('every call goes out with the app\'s user agent', () {
    final dio = createPotaDio();
    expect(dio.options.baseUrl, 'https://api.pota.app');
    expect(dio.options.headers['User-Agent'], 'WavelogMobile/1.0');
  });
}
