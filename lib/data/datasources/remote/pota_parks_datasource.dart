import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/pota_activity.dart';
import '../../../core/utils/pota_parks.dart';
import '../../models/pota_park_model.dart';
import 'pota_datasource.dart';

/// pota.app answered, but not with what the call expects (an error page with
/// status 200, an empty body).
class PotaApiException implements Exception {
  final String message;
  const PotaApiException(this.message);

  @override
  String toString() => 'PotaApiException: $message';
}

/// The map side of pota.app: the parks of a grid square and what is known
/// about one park. The API has no published terms or documentation, so every
/// call lives here, one request per call, and a reply is read defensively.
class PotaParksDatasource {
  /// [dio] is for tests, which must not reach pota.app.
  PotaParksDatasource({Dio? dio}) : _dio = dio ?? createPotaDio();

  final Dio _dio;

  /// Half the side, in degrees, of the box asked for around a square's
  /// centre: small enough to touch that square alone.
  static const _probe = 0.001;

  /// Every park of the 4-character square [grid4]. The API answers a box
  /// with all parks of every square it touches, so the box is a speck at the
  /// square's centre. Features that cannot be used are left out.
  Future<List<PotaParkPoint>> parksInSquare(String grid4) async {
    final c = squareCentre(grid4); // throws on a bad name
    String edge(double v) => v.toStringAsFixed(3);
    // The order is latitude first, then longitude
    final path = '/park/grids/${edge(c.lat - _probe)}/${edge(c.lon - _probe)}'
        '/${edge(c.lat + _probe)}/${edge(c.lon + _probe)}/0';
    final body = _decode(await _getText(path));
    final features = body is Map ? body['features'] : null;
    if (features is! List) {
      throw const PotaApiException('no features in the parks reply');
    }

    final bounds = squareBounds(grid4);
    final seen = <String>{};
    final parks = <PotaParkPoint>[];
    for (final f in features) {
      final p = PotaParkPoint.tryParse(f);
      if (p == null || !seen.add(p.reference)) continue;
      if (p.lat < bounds.south ||
          p.lat >= bounds.north ||
          p.lon < bounds.west ||
          p.lon >= bounds.east) {
        debugPrint('POTA park ${p.reference} is outside the square $grid4');
      }
      parks.add(p);
    }
    return parks;
  }

  /// The park, or null when pota.app does not know the reference.
  Future<PotaParkDetail?> getDetail(String reference) async {
    final text = await _getTextOrNull('/park/${_ref(reference)}');
    if (text == null) return null;
    final park = PotaParkDetail.tryParse(_decode(text));
    if (park == null) throw const PotaApiException('not a park');
    return park;
  }

  /// Its counts, or null when pota.app does not know the reference.
  Future<PotaParkStats?> getStats(String reference) async {
    final text = await _getTextOrNull('/park/stats/${_ref(reference)}');
    if (text == null) return null;
    final stats = PotaParkStats.tryParse(_decode(text));
    if (stats == null) throw const PotaApiException('not park statistics');
    return stats;
  }

  /// The latest activations, newest first as pota.app lists them.
  Future<List<PotaActivation>> getRecentActivations(String reference,
      {int count = 5}) async {
    final text = await _getTextOrNull(
        '/park/activations/${_ref(reference)}?count=$count');
    if (text == null) return const [];
    final body = _decode(text);
    if (body is! List) throw const PotaApiException('not a list of activations');
    return [
      for (final a in body)
        if (PotaActivation.tryParse(a) case final activation?) activation,
    ];
  }

  /// A reference that is safe in a path; anything else never leaves the app.
  String _ref(String reference) {
    final r = reference.trim().toUpperCase();
    if (!potaRefPattern.hasMatch(r)) {
      throw ArgumentError.value(reference, 'reference', 'not a park reference');
    }
    return r;
  }

  Future<String> _getText(String path) async {
    final response = await _dio.get<String>(
      path,
      options: Options(responseType: ResponseType.plain),
    );
    final text = response.data;
    if (text == null || text.trim().isEmpty) {
      throw const PotaApiException('empty reply');
    }
    return text;
  }

  /// Like [_getText], with a 404 as null.
  Future<String?> _getTextOrNull(String path) async {
    try {
      return await _getText(path);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Object? _decode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      throw const PotaApiException('the reply is not JSON');
    }
  }
}
