import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/park_boundary_model.dart';

/// Looks a park's outline up.
///
/// pota.app has no park outlines. For a park in the United States the USGS
/// PAD-US service is asked first: the protected lands as the agencies that
/// manage them report them. Then Protected Planet (the World Database on
/// Protected Areas), which covers the world. Last, where neither has the park,
/// OpenStreetMap is searched through Nominatim by name near the park's
/// position. Either way the best match is taken (see
/// [pickBoundary]) and none at all when nothing fits well. Nominatim is run by
/// volunteers: it is asked only for the park the person is looking at, at most
/// once a second, with the app identified, and what is found is remembered.
class ParkBoundaryDatasource {
  /// [dio] is for tests, which must not reach Nominatim.
  ParkBoundaryDatasource({
    Dio? dio,
    Dio? padusDio,
    Dio? wdpaDio,
    this.minGap = const Duration(seconds: 1),
    this.remembered = 40,
  })  : _dio = dio ?? _createDio(),
        _padusDio = padusDio ?? _createPadusDio(),
        _wdpaDio = wdpaDio ?? _createWdpaDio();

  final Dio _dio;
  final Dio _padusDio;
  final Dio _wdpaDio;
  final Duration minGap;
  final int remembered;

  /// Reference -> outline, or null for "looked, found none". Oldest first.
  final _found = <String, ParkBoundary?>{};
  var _nextSlot = DateTime.fromMillisecondsSinceEpoch(0);

  static Dio _createDio() => Dio(BaseOptions(
        baseUrl: 'https://nominatim.openstreetmap.org',
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'User-Agent':
              'WavelogMobile/1.0 (https://github.com/TA4RX-SP9AQG/Wavelog-Mobile)',
          'Accept-Language': 'en',
        },
      ));

  static Dio _createPadusDio() => Dio(BaseOptions(
        baseUrl:
            'https://services.arcgis.com/v01gqwM5QqNysAAi/ArcGIS/rest/services/PADUS_Public_Access/FeatureServer/0',
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 25),
        headers: {'User-Agent': 'WavelogMobile/1.0'},
      ));

  static Dio _createWdpaDio() => Dio(BaseOptions(
        baseUrl:
            'https://data-gis.unep-wcmc.org/server/rest/services/ProtectedSites/The_World_Database_of_Protected_Areas/FeatureServer/1',
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'User-Agent': 'WavelogMobile/1.0'},
      ));

  /// Half the side, in degrees, of the box around the park searched in. Large
  /// parks are mapped by a position far from their centre.
  static const _reach = 0.6;

  /// The outline of the park, or null when OpenStreetMap has none that fits.
  /// Throws when Nominatim cannot be reached: that is not "no outline".
  Future<ParkBoundary?> find({
    required String reference,
    required String name,
    required double lat,
    required double lon,
  }) async {
    if (_found.containsKey(reference)) {
      final hit = _found.remove(reference); // moved to the newest end
      _found[reference] = hit;
      return hit;
    }
    ParkBoundary? boundary;
    // A source that could not be reached: "none" is then not final
    var incomplete = false;
    if (reference.toUpperCase().startsWith('US-')) {
      try {
        boundary = await _padus(name, lat, lon);
      } catch (e) {
        incomplete = true;
        debugPrint('Park outline: PAD-US failed: $e');
      }
    }
    if (boundary == null) {
      try {
        boundary = await _wdpa(name, lat, lon);
      } catch (e) {
        incomplete = true;
        debugPrint('Park outline: Protected Planet failed: $e');
      }
    }
    for (final query in boundary != null ? const <String>[] : _queries(name)) {
      final results = await _search(query, lat, lon);
      boundary = pickBoundary(results, name: name, lat: lat, lon: lon);
      if (boundary != null) break;
    }
    if (boundary != null || !incomplete) _found[reference] = boundary;
    while (_found.length > remembered) {
      _found.remove(_found.keys.first);
    }
    return boundary;
  }

  /// The park in PAD-US: every protected unit within a few hundred metres of
  /// its position, the one named like the park, with every piece of that unit
  /// (a refuge or a park is often several parcels).
  Future<ParkBoundary?> _padus(String name, double lat, double lon) async {
    const reach = 0.004; // about 400 m
    final response = await _padusDio.get<String>(
      '/query',
      queryParameters: {
        'f': 'geojson',
        'geometry': jsonEncode({
          'xmin': lon - reach,
          'ymin': lat - reach,
          'xmax': lon + reach,
          'ymax': lat + reach,
          'spatialReference': {'wkid': 4326},
        }),
        'geometryType': 'esriGeometryEnvelope',
        'inSR': 4326,
        'spatialRel': 'esriSpatialRelIntersects',
        'outFields': 'Unit_Nm,Category,DesTp_Desc,MngNm_Desc',
        'returnGeometry': 'true',
        'outSR': 4326,
        // Fewer points: the outline only has to be seen on a phone
        'maxAllowableOffset': 0.0001,
        'geometryPrecision': 5,
        'resultRecordCount': 100,
      },
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data;
    if (body == null || body.trim().isEmpty) return null;
    final Object? data;
    try {
      data = jsonDecode(body);
    } on FormatException {
      throw StateError('PAD-US did not answer with JSON');
    }
    final features = data is Map ? data['features'] : null;
    if (features is! List) return null;

    final units = [
      for (final f in features)
        if (ParkBoundary.fromPadus(f) case final b?) b,
    ];
    // The service already searched at the park, so a name that fits is enough
    final best = pickBoundary(units,
        name: name, lat: lat, lon: lon, mustHoldPosition: false);
    if (best == null) return null;
    return ParkBoundary(
      areas: [
        for (final u in units)
          if (u.name == best.name) ...u.areas,
      ],
      name: best.name,
      kind: best.kind,
      source: BoundarySource.padus,
    );
  }

  /// The park in Protected Planet: the areas whose name has the park's
  /// distinctive words, within about 80 km (a large park's pin can be far from
  /// its edge), and the one that fits best.
  Future<ParkBoundary?> _wdpa(String name, double lat, double lon) async {
    final words = distinctiveWords(name);
    if (words.isEmpty) return null;
    const reach = 0.8;
    // The words are only letters and digits, so they are safe in the query
    final where = [
      for (final w in words.take(2))
        "UPPER(name) LIKE '%${w.toUpperCase()}%' OR UPPER(name_eng) LIKE '%${w.toUpperCase()}%'",
    ].join(' OR ');
    final response = await _wdpaDio.get<String>(
      '/query',
      queryParameters: {
        'f': 'geojson',
        'where': where,
        'geometry': jsonEncode({
          'xmin': lon - reach,
          'ymin': lat - reach,
          'xmax': lon + reach,
          'ymax': lat + reach,
          'spatialReference': {'wkid': 4326},
        }),
        'geometryType': 'esriGeometryEnvelope',
        'inSR': 4326,
        'spatialRel': 'esriSpatialRelIntersects',
        'outFields': 'name,name_eng,desig_eng,iso3,status',
        'returnGeometry': 'true',
        'outSR': 4326,
        // Fewer points: the outline only has to be seen on a phone
        'maxAllowableOffset': 0.0003,
        'geometryPrecision': 5,
        'resultRecordCount': 40,
      },
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data;
    if (body == null || body.trim().isEmpty) return null;
    final Object? data;
    try {
      data = jsonDecode(body);
    } on FormatException {
      throw StateError('Protected Planet did not answer with JSON');
    }
    final features = data is Map ? data['features'] : null;
    if (features is! List) return null;
    return pickWdpaBoundary(
      [for (final f in features) ParkBoundary.fromWdpa(f)],
      name: name,
      lat: lat,
      lon: lon,
    );
  }

  /// The name as it is, then without the words that pota.app adds ("Nature
  /// Reserve") and OpenStreetMap often does not have in that form.
  List<String> _queries(String name) {
    final trimmed = name.trim();
    final shorter = trimmed
        .replaceFirst(
            RegExp(r'\s+(Nature Reserve|Landscape Park|Natura 2000|Conservation Area)$',
                caseSensitive: false),
            '')
        .trim();
    return [trimmed, if (shorter.isNotEmpty && shorter != trimmed) shorter];
  }

  Future<List<Object?>> _search(String query, double lat, double lon) async {
    // Take the next free second before asking, so that two callers at once
    // do not ask at once
    final now = DateTime.now();
    final slot = _nextSlot.isAfter(now) ? _nextSlot : now;
    _nextSlot = slot.add(minGap);
    final wait = slot.difference(now);
    if (wait > Duration.zero) await Future<void>.delayed(wait);

    final response = await _dio.get<String>(
      '/search',
      queryParameters: {
        'q': query,
        'format': 'jsonv2',
        'polygon_geojson': 1,
        // Fewer points: the outline only has to be seen on a phone
        'polygon_threshold': 0.0003,
        'limit': 10,
        'bounded': 1,
        'viewbox': '${lon - _reach},${lat + _reach},${lon + _reach},${lat - _reach}',
      },
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data;
    if (body == null || body.trim().isEmpty) return const [];
    try {
      final data = jsonDecode(body);
      return data is List ? data : const [];
    } on FormatException {
      debugPrint('Park outline: Nominatim did not answer with JSON');
      throw StateError('not JSON');
    }
  }
}
