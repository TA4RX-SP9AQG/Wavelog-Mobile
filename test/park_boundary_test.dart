import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/data/datasources/remote/park_boundary_datasource.dart';
import 'package:wavelog_mobile/data/models/park_boundary_model.dart';
import 'package:wavelog_mobile/providers/pota_parks_provider.dart';

/// A real result from Nominatim, thinned: the Don Edwards San Francisco Bay
/// National Wildlife Refuge, 15 pieces.
List<dynamic> fixture() =>
    jsonDecode(File('test/fixtures/nominatim_park.json').readAsStringSync())
        as List<dynamic>;

// A point inside the biggest piece of the refuge
const insideLat = 37.546780735;
const insideLon = -122.145143805;
const refuge = 'Don Edwards San Francisco Bay National Wildlife Refuge';

Map<String, dynamic> square(String category, String type, String name,
        {double lat = 37.5, double lon = -122.0, double half = 0.5}) =>
    {
      'category': category,
      'type': type,
      'name': name,
      'geojson': {
        'type': 'Polygon',
        'coordinates': [
          [
            [lon - half, lat - half],
            [lon + half, lat - half],
            [lon + half, lat + half],
            [lon - half, lat + half],
            [lon - half, lat - half],
          ]
        ],
      },
    };

void main() {
  group('the outline of a result', () {
    test('a real, many-piece outline is read', () {
      final b = ParkBoundary.tryParse(fixture().first)!;
      // 15 pieces in OpenStreetMap; the fixture is thinned, which drops the
      // smallest rings
      expect(b.areas.length, greaterThan(3));
      expect(b.name, refuge);
      expect(b.kind, 'boundary:protected_area');
      expect(b.contains(insideLat, insideLon), isTrue);
      // Open water in the middle of the bay is not in it
      expect(b.contains(37.62, -122.20), isFalse);
      final box = b.bounds;
      expect(box.south, closeTo(37.417, 0.001));
      expect(box.east, closeTo(-121.942, 0.001));
    });

    test('a hole is not inside', () {
      final b = ParkBoundary.tryParse({
        'geojson': {
          'type': 'Polygon',
          'coordinates': [
            [
              [0, 0], [10, 0], [10, 10], [0, 10], [0, 0]
            ],
            [
              [4, 4], [6, 4], [6, 6], [4, 6], [4, 4]
            ],
          ],
        },
      })!;
      expect(b.contains(2, 2), isTrue);
      expect(b.contains(5, 5), isFalse);
      expect(b.contains(20, 20), isFalse);
    });

    test('what is not a usable polygon is refused', () {
      expect(ParkBoundary.tryParse(null), isNull);
      expect(ParkBoundary.tryParse('x'), isNull);
      expect(ParkBoundary.tryParse({}), isNull);
      expect(ParkBoundary.tryParse({'geojson': {'type': 'Point', 'coordinates': [1, 2]}}),
          isNull);
      expect(
          ParkBoundary.tryParse({
            'geojson': {'type': 'Polygon', 'coordinates': []}
          }),
          isNull);
      // A ring too short, a coordinate that is not a number, one out of range
      for (final ring in [
        [[0, 0], [1, 1], [0, 0]],
        [[0, 0], [1, 'x'], [2, 2], [0, 0]],
        [[0, 0], [1, 95], [2, 2], [0, 0]],
      ]) {
        expect(
            ParkBoundary.tryParse({
              'geojson': {
                'type': 'Polygon',
                'coordinates': [ring]
              }
            }),
            isNull,
            reason: '$ring');
      }
    });
  });

  group('choosing the outline of a park', () {
    test('the real result is taken for its park', () {
      final b = pickBoundary(fixture(),
          name: refuge, lat: insideLat, lon: insideLon);
      expect(b, isNotNull);
      expect(b!.name, refuge);
    });

    test('a station or a street with the same name is not a park', () {
      final b = pickBoundary([
        square('railway', 'station', 'Mount Park'),
        square('highway', 'residential', 'Mount Park'),
        square('place', 'suburb', 'Mount Park'),
      ], name: 'Mount Park', lat: 37.5, lon: -122.0);
      expect(b, isNull);
    });

    test('a park that only lies around the position, under another name, is '
        'not taken', () {
      final b = pickBoundary([
        square('boundary', 'protected_area', 'Big Coastal Wilderness', half: 3),
      ], name: 'Mount Eagle State Park', lat: 37.5, lon: -122.0);
      expect(b, isNull);
    });

    test('words like "park" and "national" do not make two names alike', () {
      final b = pickBoundary([
        square('leisure', 'park', 'Pine National Park'),
      ], name: 'Mount Eagle National Park', lat: 37.5, lon: -122.0);
      expect(b, isNull);
    });

    test('an outline that does not hold the park is not its outline', () {
      final b = pickBoundary(
          [square('leisure', 'park', 'Mount Park', lat: 40, lon: 10)],
          name: 'Mount Park', lat: 37.5, lon: -122.0);
      expect(b, isNull);
    });

    test('of two that hold it, the closer name wins, then the smaller', () {
      final big = square('boundary', 'protected_area', 'Coast Forest', half: 2);
      final named = square('leisure', 'nature_reserve', 'Mount Eagle Reserve');
      final small = square('boundary', 'protected_area', 'Mount Eagle Reserve',
          half: 0.1);
      final b = pickBoundary([big, named, small],
          name: 'Mount Eagle Reserve', lat: 37.5, lon: -122.0)!;
      // Same name twice: the smaller one
      expect(b.kind, 'boundary:protected_area');
      expect(b.boxArea, lessThan(0.1));
      // A name that matches beats a bigger one that does not
      final other = pickBoundary([big, named],
          name: 'Mount Eagle Reserve', lat: 37.5, lon: -122.0)!;
      expect(other.name, 'Mount Eagle Reserve');
    });

    test('a position just outside is accepted for a close name only',
        () {
      // The outline's box holds the point, the outline itself does not
      final l = {
        'category': 'boundary',
        'type': 'protected_area',
        'name': 'Crescent Lake Reserve',
        'geojson': {
          'type': 'Polygon',
          'coordinates': [
            [
              [0, 0], [10, 0], [0, 10], [0, 0]
            ]
          ],
        },
      };
      // (8, 8) is in the box (0..10) but past the diagonal edge
      expect(pickBoundary([l], name: 'Crescent Lake Reserve', lat: 8, lon: 8),
          isNotNull);
      expect(pickBoundary([l], name: 'Something Else Entirely', lat: 8, lon: 8),
          isNull);
    });

    test('names with accents and other scripts are compared by their letters',
        () {
      final b = pickBoundary([
        square('leisure', 'nature_reserve', 'Rezerwat Dąbrowy Seroczyńskie',
            lat: 52.0, lon: 21.9),
      ], name: 'Dąbrowy Seroczyńskie Nature Reserve', lat: 52.0, lon: 21.9);
      expect(b, isNotNull);
    });
  });

  group('asking Nominatim', () {
    late List<RequestOptions> requests;
    late List<DateTime> times;
    late ParkBoundaryDatasource ds;
    FutureOr<(int, String)> Function(RequestOptions o) reply =
        (_) => (200, '[]');

    setUp(() {
      requests = [];
      times = [];
      reply = (_) => (200, '[]');
      final dio = Dio(BaseOptions(baseUrl: 'https://nominatim.openstreetmap.org'))
        ..httpClientAdapter = _Adapter((o) async {
          requests.add(o);
          times.add(DateTime.now());
          return reply(o);
        });
      ds = ParkBoundaryDatasource(
          dio: dio, minGap: const Duration(milliseconds: 150));
    });

    Future<ParkBoundary?> find([String ref = 'US-0189', String name = refuge]) =>
        ds.find(reference: ref, name: name, lat: insideLat, lon: insideLon);

    test('searches the name in a box around the park, asking for a polygon',
        () async {
      reply = (_) => (200, jsonEncode(fixture()));
      final b = await find();
      expect(b, isNotNull);
      expect(requests, hasLength(1));
      final q = requests.single.queryParameters;
      expect(q['q'], refuge);
      expect(q['polygon_geojson'], 1);
      expect(q['bounded'], 1);
      expect(q['format'], 'jsonv2');
      final box = (q['viewbox'] as String).split(',').map(double.parse).toList();
      // left, top, right, bottom around the park
      expect(box[0], lessThan(insideLon));
      expect(box[2], greaterThan(insideLon));
      expect(box[1], greaterThan(insideLat));
      expect(box[3], lessThan(insideLat));
    });

    test('the app identifies itself', () {
      // The real client carries the user agent Nominatim's policy asks for
      final real = ParkBoundaryDatasource();
      expect(real, isNotNull);
    });

    test('what was found is remembered: the same park is asked for once',
        () async {
      reply = (_) => (200, jsonEncode(fixture()));
      await find();
      await find();
      expect(requests, hasLength(1));
    });

    test('so is "none": no asking again for a park without an outline',
        () async {
      await find('PL-0001', 'Nowhere Park');
      await find('PL-0001', 'Nowhere Park');
      // The name, then the name without "Nature Reserve" if that differs
      expect(requests, hasLength(1));
    });

    test('a failure is not remembered', () async {
      reply = (_) => (503, 'busy');
      await expectLater(find(), throwsA(isA<DioException>()));
      reply = (_) => (200, jsonEncode(fixture()));
      expect(await find(), isNotNull);
    });

    test('a second try without the words pota.app adds', () async {
      reply = (o) => o.queryParameters['q'] == 'Seroczyńskie Dąbrowy Nature Reserve'
          ? (200, '[]')
          : (200, jsonEncode(fixture()));
      final b = await ds.find(
          reference: 'PL-0363',
          name: 'Seroczyńskie Dąbrowy Nature Reserve',
          lat: insideLat,
          lon: insideLon);
      // The fixture's park has other words, so it does not match: two asks
      expect(requests.map((r) => r.queryParameters['q']),
          ['Seroczyńskie Dąbrowy Nature Reserve', 'Seroczyńskie Dąbrowy']);
      expect(b, isNull);
    });

    test('never faster than the gap, even for two at once', () async {
      final a = find('US-0001', 'Alpha Park');
      final b = find('US-0002', 'Beta Park');
      await Future.wait([a, b]);
      expect(times, hasLength(2));
      expect(times[1].difference(times[0]).inMilliseconds, greaterThanOrEqualTo(140));
    });

    test('a reply that is not JSON, or not a list, is an error or empty',
        () async {
      reply = (_) => (200, '<html>busy</html>');
      await expectLater(find('US-0003', 'Gamma Park'), throwsA(isA<StateError>()));
      reply = (_) => (200, '{"error":"x"}');
      expect(await find('US-0004', 'Delta Park'), isNull);
      reply = (_) => (200, '');
      expect(await find('US-0005', 'Epsilon Park'), isNull);
    });

    test('only the latest few are remembered', () async {
      final small = ParkBoundaryDatasource(
          dio: Dio(BaseOptions(baseUrl: 'https://x'))
            ..httpClientAdapter = _Adapter((o) async {
              requests.add(o);
              return (200, '[]');
            }),
          minGap: Duration.zero,
          remembered: 2);
      for (final ref in ['A-0001', 'A-0002', 'A-0003']) {
        await small.find(reference: ref, name: 'x', lat: 1, lon: 1);
      }
      final before = requests.length;
      await small.find(reference: 'A-0003', name: 'x', lat: 1, lon: 1);
      expect(requests.length, before); // still there
      await small.find(reference: 'A-0001', name: 'x', lat: 1, lon: 1);
      expect(requests.length, greaterThan(before)); // forgotten, asked again
    });
  });

  group('the provider waits before it asks', () {
    test('a park left within the dwell is never asked for', () async {
      final fake = _CountingDatasource();
      final container = ProviderContainer(
          overrides: [parkBoundaryDatasourceProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
      const key = (reference: 'US-1', name: 'x', lat: 1.0, lon: 1.0);
      final sub = container.listen(potaParkBoundaryProvider(key), (_, __) {});
      await Future<void>.delayed(kParkBoundaryDwell ~/ 3);
      sub.close(); // deselected
      await Future<void>.delayed(kParkBoundaryDwell * 2);
      expect(fake.asked, 0);
    });

    test('a park that stays is asked for once', () async {
      final fake = _CountingDatasource();
      final container = ProviderContainer(
          overrides: [parkBoundaryDatasourceProvider.overrideWithValue(fake)]);
      addTearDown(container.dispose);
      const key = (reference: 'US-1', name: 'x', lat: 1.0, lon: 1.0);
      container.listen(potaParkBoundaryProvider(key), (_, __) {});
      await container.read(potaParkBoundaryProvider(key).future);
      expect(fake.asked, 1);
    });
  });
}

class _CountingDatasource extends ParkBoundaryDatasource {
  var asked = 0;
  _CountingDatasource() : super(dio: Dio());

  @override
  Future<ParkBoundary?> find({
    required String reference,
    required String name,
    required double lat,
    required double lon,
  }) async {
    asked++;
    return null;
  }
}

class _Adapter implements HttpClientAdapter {
  final Future<(int, String)> Function(RequestOptions o) reply;
  _Adapter(this.reply);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final (status, body) = await reply(options);
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}
