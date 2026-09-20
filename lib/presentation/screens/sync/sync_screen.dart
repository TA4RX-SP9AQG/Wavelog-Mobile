import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/l10n_extension.dart';
import '../../../data/models/qso_model.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/qso_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/station_provider.dart';
import '../../../providers/sync_controller.dart';
import '../../../providers/sync_count_provider.dart';

/// Offline sync overview: live progress of the running sync, what is still
/// waiting, the outcome of the last run and the queued QSOs themselves.
class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (!ref.read(isOnlineProvider)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.syncNoConnection)));
      return;
    }
    final report = await ref.read(syncControllerProvider.notifier).sync();
    if (report == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.syncNothing)));
      return;
    }
    if (report.synced > 0 || report.deletesDone > 0) {
      // Reload the list so synced QSOs pick up their server IDs.
      ref.invalidate(qsoProvider);
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.syncDone(report.synced))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sync = ref.watch(syncControllerProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider);
    final deletes = ref.watch(pendingDeleteCountProvider).valueOrNull ?? 0;
    final pending = ref.watch(pendingQsosProvider).valueOrNull ?? const [];
    final isOnline = ref.watch(isOnlineProvider);
    final offlineMode =
        ref.watch(settingsProvider.select((s) => s.offlineModeEnabled));
    final stations = ref.watch(stationProvider).valueOrNull ?? const [];
    final stationNames = {
      for (final s in stations) s.id: s.callsign,
    };

    final fmt = DateFormat('dd.MM.yy HH:mm');
    String stamp(DateTime? t) => t == null ? l10n.syncNever : fmt.format(t);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncTitle)),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: [
                _StatusCard(
                  isOnline: isOnline,
                  offlineMode: offlineMode,
                ),
                const SizedBox(height: 12),
                _ProgressCard(
                  sync: sync,
                  pendingCount: pendingCount,
                  hasDeletes: deletes > 0,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        _DetailRow(l10n.syncWaiting, '$pendingCount'),
                        _DetailRow(l10n.syncWaitingDeletes, '$deletes'),
                        _DetailRow(l10n.syncLastRun, stamp(sync.lastRunAt)),
                        _DetailRow(
                            l10n.syncLastSuccess, stamp(sync.lastSuccessAt)),
                        if (sync.lastRunAt != null) ...[
                          _DetailRow(l10n.syncSyncedLast, '${sync.lastSynced}'),
                          _DetailRow(l10n.syncFailedLast, '${sync.lastFailed}'),
                        ],
                        if (sync.lastError != null)
                          _DetailRow(l10n.syncLastError, sync.lastError!,
                              isError: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed:
                      sync.running ? null : () => _syncNow(context, ref),
                  icon: sync.running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(l10n.syncNow),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.syncQueueTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                if (pending.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      l10n.syncQueueEmpty,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SliverList.builder(
            itemCount: pending.length,
            itemBuilder: (context, i) => _QueuedQsoTile(
              qso: pending[i],
              station: stationNames[pending[i].stationProfileId],
              fmt: fmt,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool isOnline;
  final bool offlineMode;
  const _StatusCard({required this.isOnline, required this.offlineMode});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final color = isOnline ? Colors.green : cs.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isOnline ? Icons.wifi : Icons.wifi_off, color: color),
                const SizedBox(width: 10),
                Text(
                  isOnline ? l10n.syncStatusOnline : l10n.syncStatusOffline,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
              ],
            ),
            if (offlineMode) ...[
              const SizedBox(height: 8),
              Text(
                l10n.syncOfflineModeNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final SyncState sync;
  final int pendingCount;
  final bool hasDeletes;

  const _ProgressCard({
    required this.sync,
    required this.pendingCount,
    required this.hasDeletes,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final allDone = !sync.running && pendingCount == 0 && !hasDeletes;

    final double value;
    final String headline;
    if (sync.running) {
      value = sync.progress;
      headline = l10n.syncRunning(sync.done + sync.failed, sync.total);
    } else if (allDone) {
      value = 1;
      headline = l10n.syncAllDone;
    } else {
      // Something is still queued (offline, failed batch, paused): show how
      // far the last run got instead of pretending nothing happened.
      value = sync.total == 0 ? 0 : sync.progress;
      headline = l10n.pendingSync(pendingCount);
    }
    final percent = (value * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  allDone
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_upload_outlined,
                  color: allDone ? Colors.green : theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    headline,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '$percent%',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: value, minHeight: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isError;
  const _DetailRow(this.label, this.value, {this.isError = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          Expanded(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isError ? cs.error : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueuedQsoTile extends StatelessWidget {
  final QsoModel qso;
  final String? station;
  final DateFormat fmt;
  const _QueuedQsoTile(
      {required this.qso, required this.station, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parts = [
      fmt.format(qso.dateTimeOn.toLocal()),
      qso.band,
      qso.mode,
      if (station != null) station!,
    ];
    return ListTile(
      dense: true,
      leading: Icon(Icons.cloud_off, size: 18, color: cs.error),
      title: Text(
        qso.callsign,
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontFamily: 'monospace'),
      ),
      subtitle: Text(parts.join(' • ')),
    );
  }
}
