import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../data/models/pota_spot_model.dart';

class PotaDatasource {
  static const _baseUrl = 'https://api.pota.app';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 12),
    headers: {'User-Agent': 'WavelogMobile/1.0'},
  ));

  /// Park bilgisi döner. `null` = park bulunamadı (404).
  /// Ağ/sunucu hatalarında fırlatır — çağıran "bulunamadı" ile karıştırmasın.
  Future<({String name, String locationDesc})?> getPark(
      String reference) async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/park/$reference');
      final data = response.data;
      if (data == null) return null;
      return (
        name: data['name']?.toString() ?? reference,
        locationDesc: data['locationDesc']?.toString() ?? '',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      debugPrint('POTA park lookup failed for $reference: $e');
      rethrow;
    }
  }

  /// Parks whose reference or name matches [query] (pota.app's search, the
  /// one its website uses), best match first. Other hits, such as
  /// activators' callsigns, are left out.
  Future<List<({String reference, String name})>> searchParks(String query,
      {int size = 8}) async {
    final response = await _dio.get<List<dynamic>>('/lookup',
        queryParameters: {'search': query, 'size': size});
    return [
      for (final r in response.data ?? const [])
        if (r is Map && r['type'] == 'park' && r['value'] != null)
          (
            reference: r['value'].toString(),
            // "PL-0341  Dębowe Góry Nature Reserve" -> the name part.
            name: (r['display']?.toString() ?? '')
                .replaceFirst(r['value'].toString(), '')
                .trim(),
          ),
    ];
  }

  Future<List<PotaSpotModel>> getSpots() async {
    final response = await _dio.get<List<dynamic>>('/spot');
    final list = response.data ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(PotaSpotModel.fromJson)
        .toList();
  }

  Future<void> addSpot({
    required String activator,
    required String spotter,
    required String frequency,
    required String mode,
    required String reference,
    String comments = '',
  }) async {
    await _dio.post<dynamic>(
      '/spot',
      data: {
        'activator': activator.toUpperCase().trim(),
        'spotter': spotter.toUpperCase().trim(),
        'frequency': frequency.trim(),
        'mode': mode.trim(),
        'reference': reference.toUpperCase().trim(),
        'source': 'Web',
        'comments': comments.trim(),
      },
    );
  }
}
