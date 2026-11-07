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
      // Parks of the United States ask PAD-US first: here it has nothing
      ds = ParkBoundaryDatasource(
          dio: dio,
          padusDio: Dio()
            ..httpClientAdapter =
                _Adapter((_) async => (200, '{"features":[]}')),
          wdpaDio: Dio()
            ..httpClientAdapter =
                _Adapter((_) async => (200, '{"features":[]}')),
          minGap: const Duration(milliseconds: 150));
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

  group('PAD-US, for parks in the United States', () {
    late List<RequestOptions> padusAsked;
    late List<RequestOptions> osmAsked;
    late ParkBoundaryDatasource ds;
    FutureOr<(int, String)> Function(RequestOptions o) padusReply =
        (_) => (200, '{"features":[]}');
    FutureOr<(int, String)> Function(RequestOptions o) osmReply =
        (_) => (200, '[]');

    String padusFixture() => File('test/fixtures/padus_park.json').readAsStringSync();

    setUp(() {
      padusAsked = [];
      osmAsked = [];
      padusReply = (_) => (200, '{"features":[]}');
      osmReply = (_) => (200, '[]');
      ds = ParkBoundaryDatasource(
        dio: Dio(BaseOptions(baseUrl: 'https://nominatim.openstreetmap.org'))
          ..httpClientAdapter = _Adapter((o) async {
            osmAsked.add(o);
            return osmReply(o);
          }),
        padusDio: Dio(BaseOptions(baseUrl: 'https://services.arcgis.com/x'))
          ..httpClientAdapter = _Adapter((o) async {
            padusAsked.add(o);
            return padusReply(o);
          }),
        wdpaDio: Dio()
          ..httpClientAdapter =
              _Adapter((_) async => (200, '{"features":[]}')),
        minGap: Duration.zero,
      );
    });

    // The pin of US-0189 lies outside the refuge's biggest pieces
    Future<ParkBoundary?> findUs({String ref = 'US-0189', String name = refuge}) =>
        ds.find(reference: ref, name: name, lat: 37.4936, lon: -122.0567);

    test('asks for the lands within a few hundred metres of the park pin',
        () async {
      padusReply = (_) => (200, padusFixture());
      final b = await findUs();
      expect(b, isNotNull);
      expect(padusAsked, hasLength(1));
      final q = padusAsked.single.queryParameters;
      expect(q['f'], 'geojson');
      expect(q['geometryType'], 'esriGeometryEnvelope');
      final env = jsonDecode(q['geometry'] as String) as Map;
      expect(env['xmin'], lessThan(-122.0567));
      expect(env['xmax'], greaterThan(-122.0567));
      expect(env['ymin'], lessThan(37.4936));
      expect(env['ymax'], greaterThan(37.4936));
      expect((env['xmax'] as double) - (env['xmin'] as double), lessThan(0.02));
    });

    test('the unit named like the park is taken, from the official data',
        () async {
      padusReply = (_) => (200, padusFixture());
      final b = (await findUs())!;
      expect(b.source, BoundarySource.padus);
      expect(b.name, refuge);
      expect(b.areas, hasLength(4));
      // OpenStreetMap is not asked when PAD-US has the park
      expect(osmAsked, isEmpty);
    });

    test('a unit under another name is not the park: OpenStreetMap is tried',
        () async {
      padusReply = (_) => (
            200,
            jsonEncode({
              'features': [
                {
                  'properties': {'Unit_Nm': 'Some County Open Space', 'DesTp_Desc': 'Local Open Space'},
                  'geometry': jsonDecode(padusFixture())['features'][0]['geometry'],
                },
              ],
            })
          );
      osmReply = (_) => (200, jsonEncode(fixture()));
      final b = await findUs();
      expect(b!.source, BoundarySource.osm);
      expect(osmAsked, isNotEmpty);
    });

    test('the pieces of a unit that PAD-US lists in parts are put together',
        () async {
      final geometry = jsonDecode(padusFixture())['features'][0]['geometry'] as Map;
      final coords = geometry['coordinates'] as List;
      Map<String, dynamic> part(List polygons) => {
            'properties': {'Unit_Nm': refuge, 'DesTp_Desc': 'National Wildlife Refuge'},
            'geometry': {'type': 'MultiPolygon', 'coordinates': polygons},
          };
      padusReply = (_) => (
            200,
            jsonEncode({
              'features': [part(coords.take(2).toList()), part(coords.skip(2).toList())],
            })
          );
      final b = (await findUs())!;
      expect(b.areas, hasLength(4));
    });

    test('PAD-US out of reach: OpenStreetMap answers instead', () async {
      padusReply = (_) => (503, 'busy');
      osmReply = (_) => (200, jsonEncode(fixture()));
      final b = await findUs();
      expect(b, isNotNull);
      expect(b!.source, BoundarySource.osm);
    });

    test('a park outside the United States never asks PAD-US', () async {
      osmReply = (_) => (200, '[]');
      await ds.find(reference: 'PL-0363', name: 'Turzyniec Nature Reserve', lat: 52.5, lon: 21.0);
      expect(padusAsked, isEmpty);
      expect(osmAsked, isNotEmpty);
    });

    test('and the answer is remembered, from either source', () async {
      padusReply = (_) => (200, padusFixture());
      await findUs();
      await findUs();
      expect(padusAsked, hasLength(1));
    });

    test('nothing in PAD-US and nothing in OpenStreetMap: no outline',
        () async {
      expect(await findUs(), isNull);
    });
  });

  group('Protected Planet areas', () {
    Map<String, dynamic> feature(String name, String desig,
            {String status = 'Designated',
            String? nameEng,
            double lat = 52.0,
            double lon = 0.0,
            double half = 0.1}) =>
        {
          'properties': {
            'name': name,
            'name_eng': nameEng ?? name,
            'desig_eng': desig,
            'status': status,
          },
          'geometry': square('', '', '', lat: lat, lon: lon, half: half)['geojson'],
        };

    ParkBoundary? pick(List<Map<String, dynamic>> features, String name,
            {double lat = 52.0, double lon = 0.0}) =>
        pickWdpaBoundary([for (final f in features) ParkBoundary.fromWdpa(f)],
            name: name, lat: lat, lon: lon);

    test('a real reply is read: name, kind, and the pieces', () {
      final data = jsonDecode(File('test/fixtures/wdpa_park.json').readAsStringSync())
          as Map<String, dynamic>;
      final areas = [for (final f in data['features']) ParkBoundary.fromWdpa(f)];
      expect(areas, hasLength(2));
      expect(areas.first!.name, 'Barton Hills');
      expect(areas.first!.designation, 'National Nature Reserve');
      expect(areas.first!.source, BoundarySource.wdpa);
      expect(areas.first!.areas, isNotEmpty);
    });

    test('a site that is only proposed is not an area yet', () {
      expect(ParkBoundary.fromWdpa(feature('Some Hills', 'Nature Reserve', status: 'Proposed')),
          isNull);
      expect(ParkBoundary.fromWdpa(feature('Some Hills', 'Nature Reserve', status: 'Designated')),
          isNotNull);
    });

    test('the name in its own language counts too', () {
      final b = pick([
        feature('Parque Estadual Alberto Löfgren', 'Park',
            nameEng: 'Alberto Löfgren State Park')
      ], 'Alberto Löfgren State Park');
      expect(b, isNotNull);
      final local = pick([
        feature('Hoher Fläming', 'Special Protection Area', nameEng: '')
      ], 'Hoher Fläming Nature Park', lat: 60, lon: 10);
      expect(local, isNotNull); // a name that matches fully, far from the pin
    });

    test('a half-matching name that does not hold the position is refused',
        () {
      // "Chiltern Hills" against "Watlington and Pyrton Hills": only "hills"
      expect(
          pick([feature('Watlington and Pyrton Hills', 'Site of Special Scientific Interest', lat: 60)],
              'Chiltern Hills National Landscape'),
          isNull);
    });

    test('a half-matching name that holds the position is taken', () {
      final b = pick([feature('Ostoja Nadliwiecka', 'Special Areas of Conservation')],
          'Ostoja Nadliwiecka Natura 2000');
      expect(b, isNotNull);
    });

    test('a name of generic words only is too vague to match', () {
      expect(pick([feature('National Park', 'National Park')], 'National Park'),
          isNull);
    });

    test('an unrelated name is refused even where the pin is', () {
      expect(pick([feature('Streganzsee-Dahme', 'Special Areas of Conservation')],
              'Dahme-Heideseen Nature Park'),
          isNull);
    });

    test('of equal names, the one holding the position, then the smaller', () {
      final b = pick([
        feature('Barton Hills', 'Site of Special Scientific Interest', half: 0.3),
        feature('Barton Hills', 'National Nature Reserve', half: 0.1),
        feature('Barton Hills', 'Far Away Copy', lat: 60),
      ], 'Barton Hills National Nature Reserve');
      expect(b!.designation, 'National Nature Reserve');
    });

    test('distinctive words leave out the kind of place', () {
      expect(distinctiveWords('Hoher Fläming Nature Park'), ['fläming', 'hoher']);
      expect(distinctiveWords('National Park'), isEmpty);
      expect(distinctiveWords('Parque Estadual Alberto Löfgren'),
          containsAll(['alberto', 'löfgren']));
    });
  });

  group('the sources in order', () {
    late List<RequestOptions> padusAsked;
    late List<RequestOptions> wdpaAsked;
    late List<RequestOptions> osmAsked;
    late ParkBoundaryDatasource ds;
    FutureOr<(int, String)> Function(RequestOptions o) padusReply = (_) => (200, '{"features":[]}');
    FutureOr<(int, String)> Function(RequestOptions o) wdpaReply = (_) => (200, '{"features":[]}');
    FutureOr<(int, String)> Function(RequestOptions o) osmReply = (_) => (200, '[]');
    String wdpaFixture() => File('test/fixtures/wdpa_park.json').readAsStringSync();
    String padusFixture() => File('test/fixtures/padus_park.json').readAsStringSync();
    final pin = jsonDecode(File('test/fixtures/wdpa_park_pin.json').readAsStringSync()) as Map;
    final lat = (pin['lat'] as num).toDouble();
    final lon = (pin['lon'] as num).toDouble();

    Dio fake(List<RequestOptions> log, FutureOr<(int, String)> Function(RequestOptions) Function() reply) =>
        Dio(BaseOptions(baseUrl: 'https://x'))
          ..httpClientAdapter = _Adapter((o) async {
            log.add(o);
            return reply()(o);
          });

    setUp(() {
      padusAsked = [];
      wdpaAsked = [];
      osmAsked = [];
      padusReply = (_) => (200, '{"features":[]}');
      wdpaReply = (_) => (200, '{"features":[]}');
      osmReply = (_) => (200, '[]');
      ds = ParkBoundaryDatasource(
        dio: fake(osmAsked, () => osmReply),
        padusDio: fake(padusAsked, () => padusReply),
        wdpaDio: fake(wdpaAsked, () => wdpaReply),
        minGap: Duration.zero,
      );
    });

    Future<ParkBoundary?> findGb([String name = 'Barton Hills National Nature Reserve']) =>
        ds.find(reference: 'GB-0350', name: name, lat: lat, lon: lon);

    test('a park outside the United States asks Protected Planet first',
        () async {
      wdpaReply = (_) => (200, wdpaFixture());
      final b = (await findGb())!;
      expect(b.source, BoundarySource.wdpa);
      expect(b.name, 'Barton Hills');
      expect(padusAsked, isEmpty);
      expect(osmAsked, isEmpty);
    });

    test('by the distinctive words of its name, around its position',
        () async {
      wdpaReply = (_) => (200, wdpaFixture());
      await findGb();
      final q = wdpaAsked.single.queryParameters;
      final where = q['where'] as String;
      expect(where, contains("UPPER(name) LIKE '%BARTON%'"));
      expect(where, contains("UPPER(name_eng) LIKE '%HILLS%'"));
      final env = jsonDecode(q['geometry'] as String) as Map;
      expect((env['xmax'] as double) - (env['xmin'] as double), closeTo(1.6, 0.01));
      expect(env['xmin'], lessThan(lon));
      expect(env['xmax'], greaterThan(lon));
    });

    test('nothing in a name can change the query', () async {
      await ds.find(
          reference: 'GB-1',
          name: "Evil') OR 1=1 -- Hills; DROP TABLE",
          lat: lat,
          lon: lon);
      for (final r in wdpaAsked) {
        final where = r.queryParameters['where'] as String;
        // Only letters and digits sit between the quotes, and the quotes pair
        for (final m in RegExp(r"'%([^%]*)%'").allMatches(where)) {
          expect(RegExp(r'^[\p{L}\p{N}]+$', unicode: true).hasMatch(m.group(1)!), isTrue,
              reason: where);
        }
        expect("'".allMatches(where).length.isEven, isTrue, reason: where);
      }
    });

    test('a name of generic words only is not searched for', () async {
      await findGb('National Park');
      expect(wdpaAsked, isEmpty);
    });

    test('a United States park asks PAD-US before it', () async {
      padusReply = (_) => (200, padusFixture());
      final b = await ds.find(
          reference: 'US-0189', name: refuge, lat: 37.4936, lon: -122.0567);
      expect(b!.source, BoundarySource.padus);
      expect(wdpaAsked, isEmpty);
    });

    test('and Protected Planet when PAD-US has nothing under that name',
        () async {
      wdpaReply = (_) => (200, wdpaFixture());
      final b = await ds.find(
          reference: 'US-9999',
          name: 'Barton Hills National Nature Reserve',
          lat: lat,
          lon: lon);
      expect(padusAsked, hasLength(1));
      expect(b!.source, BoundarySource.wdpa);
    });

    test('OpenStreetMap is the last to be asked', () async {
      osmReply = (_) => (200, jsonEncode(fixture()));
      final b = await ds.find(
          reference: 'US-0189', name: refuge, lat: insideLat, lon: insideLon);
      expect(b!.source, BoundarySource.osm);
      expect(padusAsked, hasLength(1));
      expect(wdpaAsked, hasLength(1));
    });

    test('Protected Planet out of reach: OpenStreetMap answers instead',
        () async {
      wdpaReply = (_) => (503, 'busy');
      osmReply = (_) => (200, jsonEncode(fixture()));
      final b = await ds.find(
          reference: 'US-0189', name: refuge, lat: insideLat, lon: insideLon);
      expect(b!.source, BoundarySource.osm);
    });

    test('"none" is not remembered when a source could not be reached',
        () async {
      wdpaReply = (_) => (503, 'busy');
      expect(await findGb(), isNull);
      wdpaReply = (_) => (200, wdpaFixture());
      // The first answer was not final: asked again, and now it is found
      expect((await findGb())?.source, BoundarySource.wdpa);
    });

    test('but "none" is remembered when every source answered', () async {
      expect(await findGb(), isNull);
      final asked = wdpaAsked.length;
      expect(await findGb(), isNull);
      expect(wdpaAsked.length, asked);
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
