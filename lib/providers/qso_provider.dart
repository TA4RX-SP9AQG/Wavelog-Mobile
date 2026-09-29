import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/qso_scope.dart';
import '../data/models/qso_model.dart';
import 'remote_datasource_provider.dart';
import 'settings_provider.dart';
import 'station_logbook_provider.dart';
import 'station_provider.dart';
import 'qso_sync_progress_provider.dart';
import 'statistics_provider.dart';
import 'sync_controller.dart';
import 'sync_count_provider.dart';

class QsoFilter {
  final String? band;
  final String? mode;
  final String? callsign;

  const QsoFilter({
    this.band,
    this.mode,
    this.callsign,
  });

  bool get hasFilters =>
      (band?.isNotEmpty ?? false) ||
      (mode?.isNotEmpty ?? false) ||
      (callsign?.isNotEmpty ?? false);

  // Use a private sentinel so callers can explicitly pass null to clear a field.
  static const _keep = Object();

  QsoFilter copyWith({
    Object? band = _keep,
    Object? mode = _keep,
    Object? callsign = _keep,
  }) {
    return QsoFilter(
      band: band == _keep ? this.band : band as String?,
      mode: mode == _keep ? this.mode : mode as String?,
      callsign: callsign == _keep ? this.callsign : callsign as String?,
    );
  }

  QsoFilter cleared() => const QsoFilter();
}

final qsoFilterProvider = StateProvider<QsoFilter>((ref) => const QsoFilter());

// Aktif kapsam: logbook öncelikli, yoksa aktif istasyon, yoksa hepsi (null).
// Ana ekran, logbook listesi ve istatistikler aynı kuralı paylaşır.
final scopeStationIdsProvider = Provider<Set<int>?>((ref) {
  final scope = ref.watch(settingsProvider
      .select((s) => (s.activeLogbookId, s.activeStationProfileId)));
  final logbooks = ref.watch(stationLogbookProvider).valueOrNull;
  return activeScopeStationIds(
    logbookId: scope.$1,
    stationId: scope.$2,
    logbooks: logbooks,
  );
});

// DXCC için kapsam: aktif kapsamdaki istasyonların çağrı işaretini taşıyan
// tüm istasyonlar (ödüller çağrı işaretine aittir, logbook'a değil).
final dxccStationIdsProvider = Provider<Set<int>?>((ref) {
  final scope = ref.watch(scopeStationIdsProvider);
  final stations = ref.watch(stationProvider).valueOrNull ?? const [];
  return dxccStationIds(scope, stations);
});

final scopedQsoProvider = Provider<AsyncValue<List<QsoModel>>>((ref) {
  final raw = ref.watch(qsoProvider);
  final ids = ref.watch(scopeStationIdsProvider);
  return raw.whenData((qsos) => filterByStations(qsos, ids));
});

// Ana ekran sayaçları: API'nin istatistik ucu istasyon/logbook filtresi
// desteklemediği için kapsamdaki QSO listesinden yerelde hesaplanır.
final scopedCountsProvider = Provider<AsyncValue<QsoCounts>>((ref) {
  return ref.watch(scopedQsoProvider).whenData(countQsos);
});

final qsoProvider =
    AsyncNotifierProvider<QsoNotifier, List<QsoModel>>(QsoNotifier.new);

// Filtrelenmiş görünüm, filtre/arama değişimi ağa çıkmaz, bellekte uygulanır.
// Eskiden her arama tuş vuruşu tüm istasyonlar için sunucudan tam yeniden
// çekim + Hive yeniden yazımı tetikliyordu.
final filteredQsoProvider = Provider<AsyncValue<List<QsoModel>>>((ref) {
  final scoped = ref.watch(scopedQsoProvider);
  final filter = ref.watch(qsoFilterProvider);

  if (!filter.hasFilters) return scoped;

  return scoped.whenData((qsos) {
    final band = filter.band?.toLowerCase();
    final mode = filter.mode?.toLowerCase();
    final callsign = filter.callsign?.toUpperCase();
    return qsos.where((q) {
      if (band != null && band.isNotEmpty &&
          q.band.toLowerCase() != band) {
        return false;
      }
      if (mode != null && mode.isNotEmpty &&
          q.mode.toLowerCase() != mode) {
        return false;
      }
      if (callsign != null && callsign.isNotEmpty &&
          !q.callsign.toUpperCase().contains(callsign)) {
        return false;
      }
      return true;
    }).toList();
  });
});

class QsoNotifier extends AsyncNotifier<List<QsoModel>> {
  @override
  Future<List<QsoModel>> build() async {
    final result = await _fetch();
    // recentQsoProvider does NOT watch qsoProvider (prevents CircularDependencyError).
    // Invalidate it explicitly after every build so the home screen stays fresh.
    Future.microtask(() {
      ref.invalidate(recentQsoProvider);
      ref.invalidate(logbookSummaryProvider);
      ref.invalidate(pendingSyncCountProvider);
    });
    return result;
  }

  Future<List<QsoModel>> _fetch() async {
    final settings = ref.read(settingsProvider);
    final cache = ref.read(qsoCacheDatasourceProvider);
    final repo = ref.read(qsoRepositoryProvider);

    // Clear stale cache when the API token changes (e.g., v1 -> v2 migration).
    // Old entries parsed under the previous token format are no longer valid.
    await cache.clearIfTokenChanged(settings.apiKey);

    // Cevrimdisiyken kaydedilen/silinen QSO'lari sunucuya ilet.
    // Basarisiz olursa liste yine de yuklenmeli.
    if (!settings.offlineModeEnabled) {
      try {
        await ref.read(syncControllerProvider.notifier).sync();
      } catch (_) {}
    }

    // Get all stations and fetch QSOs for each
    final stations = await ref.read(stationProvider.future);
    if (stations.isEmpty) return [];

    void reportProgress(int pagesDone, int totalPages) {
      ref.read(qsoSyncProgressProvider.notifier).state =
          QsoSyncProgress(pagesDone: pagesDone, totalPages: totalPages);
    }

    // A station whose cache is still empty right now is about to get a
    // full fetch inside fetchQsos() below, which already reconciles
    // (prunes) as part of that fetch. Recorded up front, before any
    // fetching happens, so the background reconciliation pass further down
    // knows to skip these, running reconcileIfNeeded on one of them
    // immediately afterwards would find its own fresh data and, if the
    // station is large and still being actively logged to, a small live
    // count drift could look like a deletion and trigger a second,
    // pointless full re-fetch right after the first, this is what made the
    // progress bar visibly restart during testing against a real,
    // currently-being-logged 100k+ QSO account.
    final justGotFullFetch = {
      for (final s in stations)
        if (cache.maxServerIdForStation(s.id) == 0) s.id
    };

    // Fetch in bounded-concurrency batches rather than all stations at
    // once. A logbook with many stations (reported real case: 14 US
    // stations vs. 3 Swedish ones in the same account) means that many
    // parallel multi-page pagination loops compete for the same
    // connection pool and hit the server at the same time, making any one
    // station's request measurably more likely to time out, which then
    // falls back to that station's local cache after a couple of retries
    // (see QsoRepository.fetchQsos). A handful of stations at a time keeps
    // most of the parallelism's speed benefit while greatly reducing that
    // contention. Every station here only ever takes the fast, incremental
    // path once it has a baseline (see fetchQsos), so this loop is quick
    // even for an account with a very large station.
    const maxConcurrentStations = 4;
    final results = <List<QsoModel>>[];
    for (var i = 0; i < stations.length; i += maxConcurrentStations) {
      final batch = stations.skip(i).take(maxConcurrentStations);
      final batchResults = await Future.wait(batch.map((s) => repo
          .fetchQsos(
            stationId: s.id,
            forceLocal: settings.offlineModeEnabled,
            onProgress: reportProgress,
          )
          .catchError((_) => <QsoModel>[])));
      results.addAll(batchResults);
    }
    ref.read(qsoSyncProgressProvider.notifier).state = null;

    // Detecting a server-side deletion needs a full, multi-page fetch (see
    // QsoRepository.reconcileIfNeeded), so this runs after the above,
    // batched the same way, and deliberately not awaited by this method,
    // the UI already has fast, up-to-date data from the incremental fetch
    // above and must never wait on this. When it finds something, it
    // refreshes state itself. Stations that just had their first-ever full
    // fetch above are skipped, see justGotFullFetch.
    if (!settings.offlineModeEnabled) {
      final toReconcile =
          stations.where((s) => !justGotFullFetch.contains(s.id)).toList();
      unawaited(() async {
        for (var i = 0; i < toReconcile.length; i += maxConcurrentStations) {
          final batch = toReconcile.skip(i).take(maxConcurrentStations);
          final changed = await Future.wait(batch.map((s) => repo
              .reconcileIfNeeded(
                s.id,
                onProgress: reportProgress,
                editCheckInterval:
                    Duration(minutes: settings.qsoSyncCheckIntervalMinutes),
              )
              .catchError((_) => false)));
          ref.read(qsoSyncProgressProvider.notifier).state = null;
          if (changed.any((c) => c)) await refresh();
        }
      }());
    }

    final seen = <String>{};
    final all = results
        .expand((list) => list)
        .where((q) => q.localId == null || seen.add(q.localId!))
        .toList();

    // Sort by date descending (newest first)
    all.sort((a, b) {
      final da = a.dateTimeOn;
      final db = b.dateTimeOn;
      return db.compareTo(da);
    });

    return all;
  }

Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
    ref.invalidate(recentQsoProvider);
    ref.invalidate(logbookSummaryProvider);
    ref.invalidate(pendingSyncCountProvider);
  }

  /// Forgets every station's last periodic content check (not the cached
  /// QSOs themselves), then refreshes. The manual "Sync Reset" a user
  /// reaches for when something looks off (an edit made on the web that
  /// hasn't shown up, a stats mismatch) instead of waiting out the
  /// configured interval. Runs the same way as any other reconciliation,
  /// in the background, after the fast incremental fetch, so whatever is
  /// on screen keeps showing until the recheck actually finds something to
  /// change, nothing is cleared or hidden up front.
  Future<void> forceFullResync() async {
    await ref.read(qsoCacheDatasourceProvider).clearAllFullCheckTimestamps();
    await refresh();
  }

  // Returns true if saved to server, false if saved locally only (network failure)
  Future<bool> addQso(QsoModel qso, {bool forceLocal = false}) async {
    final repo = ref.read(qsoRepositoryProvider);
    bool savedToServer = !forceLocal;

    // UUID'yi önceden üret: cache ve state aynı key'i paylaşsın
    final localId = const Uuid().v4();
    final qsoWithId = qso.copyWith(localId: localId);

    try {
      await repo.addQso(qsoWithId, forceLocal: forceLocal);
    } on NetworkException {
      // Repository already saved locally, treat as success, not an error
      savedToServer = false;
    }

    final savedQso = qsoWithId.copyWith(synced: savedToServer);

    // Show new QSO immediately without a loading flash
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([savedQso, ...current]);

    // Invalidate home screen providers so stats/recent list update
    ref.invalidate(recentQsoProvider);
    ref.invalidate(statisticsProvider);
    ref.invalidate(logbookSummaryProvider);
    ref.invalidate(pendingSyncCountProvider);

    // Silently re-fetch in background to get server-assigned fields (incl. localId)
    if (savedToServer) {
      _fetch().then((fresh) {
        // Guard: if a concurrent deleteQso/updateQso already updated state
        // (our UUID entry is gone), don't overwrite their newer result.
        final current = state.valueOrNull;
        if (current == null || !current.any((q) => q.localId == localId)) return;

        // Remap the first server entry that matches our QSO back to the UUID
        // so any open detail screen can still find it.
        // Only remap ONE entry (remapped flag) to avoid contest duplicates
        // where two contacts share the same callsign+band+mode+second.
        final ts = savedQso.dateTimeOn.millisecondsSinceEpoch ~/ 1000;
        var remapped = false;
        final merged = fresh.map((q) {
          if (!remapped) {
            final qTs = q.dateTimeOn.millisecondsSinceEpoch ~/ 1000;
            if (q.callsign == savedQso.callsign &&
                q.band == savedQso.band &&
                q.mode == savedQso.mode &&
                qTs == ts) {
              remapped = true;
              return q.copyWith(localId: localId);
            }
          }
          return q;
        }).toList();
        state = AsyncValue.data(merged);
        ref.invalidate(recentQsoProvider);
        ref.invalidate(logbookSummaryProvider);
      }, onError: (_) {});
    }

    return savedToServer;
  }

  Future<void> deleteQso(QsoModel qso) async {
    // Optimistic removal from UI
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.where((q) => q.localId != qso.localId).toList(),
    );
    try {
      await ref.read(qsoRepositoryProvider).deleteQso(qso);
    } finally {
      // Always invalidate, even if the network call threw, the local
      // Hive delete already happened and the optimistic state is correct.
      ref.invalidate(recentQsoProvider);
      ref.invalidate(statisticsProvider);
      ref.invalidate(logbookSummaryProvider);
      ref.invalidate(pendingSyncCountProvider);
    }
  }

  Future<bool> updateQso(QsoModel original, QsoModel updated,
      {bool forceLocal = false}) async {
    final repo = ref.read(qsoRepositoryProvider);
    bool savedOnline;
    try {
      savedOnline =
          await repo.updateQso(original, updated, forceLocal: forceLocal);
    } on NetworkException {
      savedOnline = false;
    }

    final updatedQso = updated.copyWith(
      localId: original.localId,
      synced: savedOnline,
    );

    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current
          .map((q) => q.localId == original.localId ? updatedQso : q)
          .toList(),
    );

    ref.invalidate(recentQsoProvider);
    ref.invalidate(statisticsProvider);
    ref.invalidate(logbookSummaryProvider);
    ref.invalidate(pendingSyncCountProvider);

    return savedOnline;
  }

  /// Best-effort: pulls the full ADIF export for [stationId] and merges
  /// QSL/LoTW/eQSL/ClubLog/HRDLog confirmation fields into in-memory state
  /// for every cached QSO of that station. See
  /// QsoRepository.syncConfirmationFields for why ADIF export (not the list
  /// or single-QSO endpoints) is the only working source. No-op if nothing
  /// changed or the server call fails.
  Future<void> syncConfirmationFields(int stationId) async {
    try {
      final repo = ref.read(qsoRepositoryProvider);
      final updated = await repo.syncConfirmationFields(stationId);
      if (updated.isEmpty) return;

      final byId = {for (final q in updated) q.localId: q};
      final latest = state.valueOrNull;
      if (latest == null) return;
      state = AsyncValue.data([
        for (final q in latest) byId[q.localId] ?? q,
      ]);
    } catch (_) {
      // Best-effort enrichment, leave state untouched on failure.
    }
  }

  void applyFilter(QsoFilter filter) {
    ref.read(qsoFilterProvider.notifier).state = filter;
  }

  void clearFilter() {
    ref.read(qsoFilterProvider.notifier).state = const QsoFilter();
  }
}

// Fires QsoNotifier.syncConfirmationFields once per stationId per app
// session. Used by the QSO detail screen and the Statistics/DXCC screen to
// backfill QSL/LoTW/eQSL/ClubLog fields the list sync never carries, both
// screens watch the same family instance per stationId, so whichever runs
// first pays the ADIF-export cost and the other reuses its result.
// keepAlive() is required: plain autoDispose only survives while at least
// one widget is watching, so navigating from the detail screen to
// Statistics (nothing watches it in between) would otherwise refetch the
// whole log again. Station-scoped rather than per-QSO: the ADIF export
// endpoint has no per-QSO filter, so one sync covers every QSO for that
// station. The return value is unused, the notifier's own state update is
// what the UI reacts to. The refresh action on Statistics invalidates this
// family explicitly when the user wants a forced re-sync.
final confirmationSyncProvider =
    FutureProvider.autoDispose.family<void, int>((ref, stationId) {
  ref.keepAlive();
  return ref.read(qsoProvider.notifier).syncConfirmationFields(stationId);
});

// Previous QSOs with a specific callsign, used by the tablet add-QSO side panel.
final previousQsosByCallsignProvider =
    FutureProvider.family<List<QsoModel>, String>((ref, callsign) async {
  if (callsign.length < 3) return [];
  final cache = ref.read(qsoCacheDatasourceProvider);
  final all = await cache.getCachedQsos();
  final cs = callsign.toUpperCase();
  return all.where((q) => q.callsign.toUpperCase() == cs).toList();
});

// Quick list for home screen.
// Uses ref.READ (not watch) on qsoProvider to avoid the circular dependency
// that arises when addQso() changes state and immediately invalidates this
// provider in the same tick. QsoNotifier invalidates it explicitly instead.
// Reading from in-memory state (not Hive) ensures that localIds here always
// match those in qsoProvider, so QsoDetailScreen can find QSOs by id.
final recentQsoProvider = FutureProvider<List<QsoModel>>((ref) async {
  final ids = ref.watch(scopeStationIdsProvider);
  final inMemory = ref.read(qsoProvider).valueOrNull;
  if (inMemory != null && inMemory.isNotEmpty) {
    return filterByStations(inMemory, ids).take(20).toList();
  }
  // Fallback: read Hive while qsoProvider hasn't loaded yet
  final cache = ref.read(qsoCacheDatasourceProvider);
  final all = await cache.getCachedQsos();
  return filterByStations(all, ids).take(20).toList();
});

// Son 5 QSO + bugünün sayacı, add QSO ekranında kullanılır.
// qsoProvider'ı ref.watch ile değil ref.read ile kullanıyoruz: QsoNotifier
// zaten this provider'ı invalidate ediyor, dolayısıyla döngüsel bağımlılık
// oluşmaz. In-memory state her zaman optimistik add/delete'i yansıtır;
// Hive arka plan fetch'leriyle geçici kirlenebilir (race condition).
final logbookSummaryProvider =
    FutureProvider<({List<QsoModel> last5, int todayCount})>((ref) async {
  // In-memory state'i tercih et, Hive'a göre her zaman güncel ve optimistik
  // operasyonları (add/delete) hemen yansıtır.
  final ids = ref.watch(scopeStationIdsProvider);
  final inMemory = ref.read(qsoProvider).valueOrNull;
  final List<QsoModel> source;
  if (inMemory != null) {
    source = inMemory;
  } else {
    // qsoProvider henüz yüklenmediyse Hive'a düş.
    final cache = ref.read(qsoCacheDatasourceProvider);
    source = await cache.getCachedQsos();
  }
  final all = filterByStations(source, ids);
  final now = DateTime.now();
  final todayCount = all.where((q) {
    final d = q.dateTimeOn.toLocal();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }).length;
  return (last5: all.take(5).toList(), todayCount: todayCount);
});
