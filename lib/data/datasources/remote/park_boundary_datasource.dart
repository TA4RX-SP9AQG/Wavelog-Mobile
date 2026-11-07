import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/park_boundary_model.dart';

/// Looks a park's outline up in OpenStreetMap, through Nominatim.
///
/// pota.app has no park outlines, so the name is searched for near the park's
/// position and the best park-like result is taken (see [pickBoundary]). The
/// service is run by volunteers: this asks only for the park the person is
/// looking at, at most once a second, identifies the app, and remembers what
/// it found.
class ParkBoundaryDatasource {
  /// [dio] is for tests, which must not reach Nominatim.
  ParkBoundaryDatasource({
    Dio? dio,
    this.minGap = const Duration(seconds: 1),
    this.remembered = 40,
  }) : _dio = dio ?? _createDio();

  final Dio _dio;
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
    for (final query in _queries(name)) {
      final results = await _search(query, lat, lon);
      boundary = pickBoundary(results, name: name, lat: lat, lon: lon);
      if (boundary != null) break;
    }
    _found[reference] = boundary;
    while (_found.length > remembered) {
      _found.remove(_found.keys.first);
    }
    return boundary;
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
