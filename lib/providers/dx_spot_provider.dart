import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/datasources/remote/dx_cluster_datasource.dart';
import '../data/models/dx_spot_model.dart';

final _dxDatasourceProvider =
    Provider<DxClusterDatasource>((_) => DxClusterDatasource());

final dxSpotsProvider = FutureProvider<List<DxSpotModel>>((ref) async {
  return ref.read(_dxDatasourceProvider).getSpots();
});

class DxSpotFilter {
  /// The bands shown; empty shows all.
  final Set<String> bands;
  final String? mode;
  final bool newestFirst;

  const DxSpotFilter({
    this.bands = const {},
    this.mode,
    this.newestFirst = true,
  });

  bool get hasFilters => bands.isNotEmpty || mode != null;

  DxSpotFilter copyWith({
    Set<String>? bands,
    Object? mode = _s,
    bool? newestFirst,
  }) =>
      DxSpotFilter(
        bands: bands ?? this.bands,
        mode: mode == _s ? this.mode : mode as String?,
        newestFirst: newestFirst ?? this.newestFirst,
      );

  static const _s = Object();
}

final dxSpotFilterProvider =
    StateProvider<DxSpotFilter>((_) => const DxSpotFilter());

final filteredDxSpotsProvider =
    Provider<AsyncValue<List<DxSpotModel>>>((ref) {
  final raw = ref.watch(dxSpotsProvider);
  final filter = ref.watch(dxSpotFilterProvider);

  return raw.whenData((spots) {
    var result = spots.where((s) {
      if (filter.bands.isNotEmpty && !filter.bands.contains(s.band)) {
        return false;
      }
      if (filter.mode != null && s.mode != filter.mode) return false;
      return true;
    }).toList();

    if (!filter.newestFirst) result = result.reversed.toList();
    return result;
  });
});
