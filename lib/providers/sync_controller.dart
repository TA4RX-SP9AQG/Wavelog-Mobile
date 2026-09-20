import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/qso_repository.dart';
import 'remote_datasource_provider.dart';
import 'sync_count_provider.dart';

/// Live state of the offline-QSO synchronisation, shown on the sync page.
class SyncState {
  final bool running;

  /// Progress of the current (or last) run.
  final int total;
  final int done;
  final int failed;

  final DateTime? lastRunAt;
  final DateTime? lastSuccessAt;
  final int lastSynced;
  final int lastFailed;
  final int lastDeletes;
  final String? lastError;
  final bool lastOffline;

  const SyncState({
    this.running = false,
    this.total = 0,
    this.done = 0,
    this.failed = 0,
    this.lastRunAt,
    this.lastSuccessAt,
    this.lastSynced = 0,
    this.lastFailed = 0,
    this.lastDeletes = 0,
    this.lastError,
    this.lastOffline = false,
  });

  /// 0.0 – 1.0 over the QSOs that were queued when the run started.
  double get progress => total == 0 ? 0 : ((done + failed) / total).clamp(0, 1);

  SyncState copyWith({
    bool? running,
    int? total,
    int? done,
    int? failed,
    DateTime? lastRunAt,
    DateTime? lastSuccessAt,
    int? lastSynced,
    int? lastFailed,
    int? lastDeletes,
    String? lastError,
    bool clearError = false,
    bool? lastOffline,
  }) {
    return SyncState(
      running: running ?? this.running,
      total: total ?? this.total,
      done: done ?? this.done,
      failed: failed ?? this.failed,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastSynced: lastSynced ?? this.lastSynced,
      lastFailed: lastFailed ?? this.lastFailed,
      lastDeletes: lastDeletes ?? this.lastDeletes,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastOffline: lastOffline ?? this.lastOffline,
    );
  }
}

final syncControllerProvider =
    StateNotifierProvider<SyncController, SyncState>(SyncController.new);

class SyncController extends StateNotifier<SyncState> {
  final Ref _ref;
  Future<SyncReport?>? _current;

  SyncController(this._ref) : super(const SyncState());

  /// Runs one sync. Concurrent callers share the run that is already going,
  /// so the auto-sync timer, a manual tap and a list refresh never overlap.
  /// Returns null when there was nothing to send.
  Future<SyncReport?> sync() {
    return _current ??= _run().whenComplete(() => _current = null);
  }

  Future<SyncReport?> _run() async {
    final cache = _ref.read(qsoCacheDatasourceProvider);
    final queued = cache.getUnsyncedCount();
    final deletes = (await cache.getPendingDeletes()).length;
    if (queued == 0 && deletes == 0) return null;

    state = state.copyWith(
      running: true,
      total: queued,
      done: 0,
      failed: 0,
      clearError: true,
    );

    SyncReport report;
    try {
      report = await _ref.read(qsoRepositoryProvider).syncPending(
        onProgress: (done, failed, total) {
          if (!mounted) return;
          state = state.copyWith(done: done, failed: failed, total: total);
          // Let the badge count down while the run is in progress.
          _ref.invalidate(pendingSyncCountProvider);
        },
      );
    } catch (e) {
      report = SyncReport(
        total: queued,
        synced: 0,
        failed: queued,
        deletesDone: 0,
        deletesLeft: deletes,
        offline: false,
        error: e.toString(),
      );
    }

    if (mounted) {
      final now = DateTime.now();
      final ok = report.failed == 0 && report.deletesLeft == 0;
      state = state.copyWith(
        running: false,
        done: report.synced,
        failed: report.failed,
        lastRunAt: now,
        lastSuccessAt: ok ? now : state.lastSuccessAt,
        lastSynced: report.synced,
        lastFailed: report.failed,
        lastDeletes: report.deletesDone,
        lastError: report.error,
        clearError: report.error == null,
        lastOffline: report.offline,
      );
    }
    _ref.invalidate(pendingSyncCountProvider);
    return report;
  }
}
