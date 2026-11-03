import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/pota_activity.dart';
import '../data/datasources/remote/pota_datasource.dart';
import '../data/models/pota_stats_model.dart';
import 'qso_provider.dart';
import 'remote_datasource_provider.dart';
import 'station_provider.dart';

/// Parks hunted so far (POTA_REF across the whole log). Null until the log
/// has loaded, so that no park looks new before it is known.
final huntedParksProvider = Provider<Set<String>?>((ref) {
  final log = ref.watch(qsoProvider).valueOrNull;
  return log == null ? null : huntedParks(log);
});

final _potaDatasourceProvider = Provider<PotaDatasource>((_) => PotaDatasource());

final potaStatsProvider = FutureProvider<PotaStats?>((ref) async {
  final stations = await ref.watch(stationProvider.future);
  final potaStations =
      stations.where((s) => s.pota != null && s.pota!.isNotEmpty).toList();

  // No station has a POTA profile configured
  if (potaStations.isEmpty) return null;

  final potaStationIds = potaStations.map((s) => s.id).toSet();
  final stationPotaRefs = {for (final s in potaStations) s.id: s.pota!};

  final cache = ref.read(qsoCacheDatasourceProvider);
  final byPark = cache.computePotaQsosByPark(potaStationIds, stationPotaRefs);

  if (byPark.isEmpty) {
    return const PotaStats(totalQsos: 0, parks: [], activatedCount: 0);
  }

  final pota = ref.read(_potaDatasourceProvider);

  // Fetch park names in parallel
  final parks = await Future.wait(
    byPark.entries.map((entry) async {
      ({String name, String locationDesc})? info;
      try {
        info = await pota.getPark(entry.key);
      } catch (_) {
        info = null; // ağ hatası — referansı ad olarak göster
      }
      return PotaParkInfo(
        reference: entry.key,
        name: info?.name ?? entry.key,
        locationDesc: info?.locationDesc ?? '',
        qsoCount: entry.value,
      );
    }),
  );

  parks.sort((a, b) => b.qsoCount.compareTo(a.qsoCount));

  return PotaStats(
    totalQsos: byPark.values.fold(0, (s, v) => s + v),
    parks: parks,
    activatedCount: parks.where((p) => p.isActivated).length,
  );
});
