import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/datasources/remote/dx_cluster_datasource.dart';
import '../data/models/dx_spot_model.dart';

final dxDatasourceProvider =
    Provider<DxClusterDatasource>((_) => DxClusterDatasource());

/// The spots of the latest successful fetch. When a refresh fails (e.g. no
/// connection) it keeps showing them, minus the ones that aged out, and
/// [dxOfflineSinceProvider] says since when; with nothing to show yet the
/// error goes through.
final dxSpotsProvider = FutureProvider<List<DxSpotModel>>((ref) async {
  final history = ref.read(_dxHistoryProvider);
  try {
    final spots = await ref.read(dxDatasourceProvider).getSpots();
    history.update(spots);
    return spots;
  } catch (_) {
    final last = history.failed();
    if (last == null) rethrow;
    return last;
  }
});

String dxSpotKey(DxSpotModel s) =>
    '${s.dxCall}|${s.frequency}|${s.spotter}|${s.time.toIso8601String()}';

/// The previous fetch: its spot keys tell which spots are new, and its time
/// how old the list is when the next refresh fails.
class _DxHistory {
  List<DxSpotModel>? _spots;
  Set<String> _keys = const {};
  DateTime? _updatedAt;
  Set<String> newKeys = const {};
  DateTime? offlineSince;

  void update(List<DxSpotModel> spots) {
    final keys = spots.map(dxSpotKey).toSet();
    // The first fetch has nothing to compare with; an unchanged list (e.g.
    // a cached answer) keeps the current highlights.
    if (_spots != null && !_keys.containsAll(keys)) {
      newKeys = keys.difference(_keys);
    }
    _spots = spots;
    _keys = keys;
    _updatedAt = DateTime.now();
    offlineSince = null;
  }

  /// The last spots still within [DxClusterDatasource.maxAge], or null if
  /// there are none to fall back on.
  List<DxSpotModel>? failed() {
    final spots = _spots;
    if (spots == null) return null;
    offlineSince = _updatedAt;
    final cutoff =
        DateTime.now().toUtc().subtract(DxClusterDatasource.maxAge);
    return spots.where((s) => s.time.isAfter(cutoff)).toList();
  }
}

final _dxHistoryProvider = Provider<_DxHistory>((_) => _DxHistory());

/// Keys ([dxSpotKey]) of the spots that appeared in the latest update.
final dxNewSpotKeysProvider = Provider<Set<String>>((ref) {
  ref.watch(dxSpotsProvider);
  return ref.read(_dxHistoryProvider).newKeys;
});

/// When the shown spots were fetched, if the latest refresh failed; null
/// while the list is current.
final dxOfflineSinceProvider = Provider<DateTime?>((ref) {
  ref.watch(dxSpotsProvider);
  return ref.read(_dxHistoryProvider).offlineSince;
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
