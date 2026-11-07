import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/geo_utils.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/pota_parks.dart';
import '../../../data/models/park_boundary_model.dart';
import '../../../data/models/pota_park_model.dart';
import '../../../providers/pota_parks_provider.dart';
import '../../../providers/pota_stats_provider.dart';
import 'pota_park_style.dart';

typedef LaunchUri = Future<bool> Function(Uri uri);
typedef ShareText = Future<void> Function(String text);

Future<bool> _launchExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

Future<void> _shareText(String text) => Share.share(text);

/// The card of one park, from the map's own data at once and, as they
/// arrive, the park's details, counts and latest activations. Works with no
/// network: the name, place and actions need none.
class PotaParkSheet extends ConsumerWidget {
  final PotaParkPoint park;

  /// Where the operator is, or null: no distance is shown then.
  final ({double lat, double lon})? me;

  /// Scrolls the card with its draggable sheet.
  final ScrollController? controller;
  final VoidCallback onClose;

  /// Starts a QSO form for this park.
  final ValueChanged<String> onLog;

  /// For tests; the defaults open a maps app and the share sheet.
  final LaunchUri launch;
  final ShareText share;

  const PotaParkSheet({
    super.key,
    required this.park,
    required this.onClose,
    required this.onLog,
    this.me,
    this.controller,
    this.launch = _launchExternal,
    this.share = _shareText,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final statuses = parkStatuses(
      ref: park.reference,
      neverActivated: park.neverActivated,
      activated: ref.watch(activatedParksProvider),
      hunted: ref.watch(huntedParksProvider),
    );
    final me = this.me;
    final from = me == null
        ? null
        : l10n.potaParkFromYou(
            formatDistance(
                calculateDistance(me.lat, me.lon, park.lat, park.lon)),
            compassLabel(
                l10n,
                compassPoint(
                    calculateAzimuth(me.lat, me.lon, park.lat, park.lon))),
          );

    return Material(
      color: cs.surface,
      elevation: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 16 + MediaQuery.paddingOf(context).bottom),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(park.reference,
                        style: theme.textTheme.labelLarge?.copyWith(
                            fontFamily: 'JetBrains Mono',
                            color: cs.primary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(park.name, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                tooltip: l10n.potaParkCopyRef,
                onPressed: () => _copy(context, park.reference),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.close,
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final s in statuses) _StatusChip(status: s),
            ],
          ),
          if (from != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.near_me_outlined, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(from, style: theme.textTheme.bodyMedium),
            ]),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => onLog(park.reference),
                icon: const Icon(Icons.edit_note),
                label: Text(l10n.potaParkLog),
              ),
              OutlinedButton.icon(
                onPressed: () => _directions(context),
                icon: const Icon(Icons.directions_outlined),
                label: Text(l10n.potaParkDirections),
              ),
              IconButton.outlined(
                icon: const Icon(Icons.open_in_new),
                tooltip: l10n.potaParkOpenWeb,
                onPressed: () => launch(parkWebUri(park.reference)),
              ),
              IconButton.outlined(
                icon: const Icon(Icons.share_outlined),
                tooltip: l10n.potaParkShare,
                onPressed: () => share(_shareMessage()),
              ),
            ],
          ),
          const Divider(height: 24),
          _Details(reference: park.reference),
          const SizedBox(height: 8),
          _BoundaryNote(park: park),
          const SizedBox(height: 12),
          _Activity(reference: park.reference),
        ],
      ),
    );
  }

  String _shareMessage() => '${park.reference} ${park.name}\n'
      '${parkWebUri(park.reference)}';

  Future<void> _copy(BuildContext context, String text) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final copied = context.l10n.potaParkCopied;
    await Clipboard.setData(ClipboardData(text: text));
    messenger?.showSnackBar(SnackBar(content: Text(copied)));
  }

  /// A maps app, else openstreetmap.org, else the coordinates to copy.
  Future<void> _directions(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final noApp = context.l10n.potaParkNoMapApp;
    for (final uri in [
      parkGeoUri(park.lat, park.lon, park.name),
      parkOsmUri(park.lat, park.lon),
    ]) {
      try {
        if (await launch(uri)) return;
      } catch (_) {
        // try the next way
      }
    }
    await Clipboard.setData(
        ClipboardData(text: parkCoordinates(park.lat, park.lon)));
    messenger?.showSnackBar(SnackBar(content: Text(noApp)));
  }
}

class _StatusChip extends StatelessWidget {
  final PotaParkStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = potaStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(potaStatusLabel(context.l10n, status),
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: cs.onSurface)),
      ]),
    );
  }
}

/// A part of the card that loads on its own: a thin bar while waiting, a
/// short note with a retry when it failed.
class _Part<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final String failedText;
  final Widget Function(T data) builder;
  const _Part({
    required this.value,
    required this.onRetry,
    required this.failedText,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) => value.when(
        data: builder,
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: LinearProgressIndicator(minHeight: 2),
        ),
        error: (e, _) => Row(children: [
          Icon(Icons.cloud_off_outlined,
              size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(child: Text(failedText)),
          TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
        ]),
      );
}

class _Details extends ConsumerWidget {
  final String reference;
  const _Details({required this.reference});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    return _Part<PotaParkDetail?>(
      value: ref.watch(potaParkDetailProvider(reference)),
      onRetry: () => ref.invalidate(potaParkDetailProvider(reference)),
      failedText: l10n.potaParkDetailFailed,
      builder: (d) {
        if (d == null) return Text(l10n.potaParkUnknown);
        final place = [d.locationName, d.country]
            .where((s) => s.isNotEmpty)
            .join(', ');
        final first = d.firstActivationDate;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (d.type.isNotEmpty || place.isNotEmpty)
              Text([d.type, place].where((s) => s.isNotEmpty).join(' · '),
                  style: theme.textTheme.bodyMedium),
            if (d.grid6.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(d.grid6,
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'JetBrains Mono',
                        color: theme.colorScheme.onSurfaceVariant)),
              ),
            if (d.firstActivator.isNotEmpty && first != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  l10n.potaParkFirstActivation(
                      d.firstActivator, DateFormat.yMMMd(locale).format(first)),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Activity extends ConsumerWidget {
  final String reference;
  const _Activity({required this.reference});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final stats = ref.watch(potaParkStatsProvider(reference));
    final recent = ref.watch(potaParkActivationsProvider(reference));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Part<PotaParkStats?>(
          value: stats,
          onRetry: () => ref.invalidate(potaParkStatsProvider(reference)),
          failedText: l10n.potaParkDetailFailed,
          builder: (s) => s == null
              ? const SizedBox()
              : Row(children: [
                  _Figure(value: s.activations, label: l10n.potaParkActivations),
                  const SizedBox(width: 24),
                  _Figure(value: s.contacts, label: l10n.potaParkQsosLabel),
                ]),
        ),
        const SizedBox(height: 12),
        Text(l10n.potaParkRecent, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        _Part<List<PotaActivation>>(
          value: recent,
          onRetry: () => ref.invalidate(potaParkActivationsProvider(reference)),
          failedText: l10n.potaParkDetailFailed,
          builder: (list) => list.isEmpty
              ? Text(l10n.potaParkNoActivations,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant))
              : Column(children: [
                  for (final a in list)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        SizedBox(
                          width: 96,
                          child: Text(a.callsign,
                              style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: Text(
                            a.date == null
                                ? ''
                                : DateFormat.yMMMd(locale).format(a.date!),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Text(l10n.qsoCount(a.qsos),
                            style: theme.textTheme.bodySmall),
                      ]),
                    ),
                ]),
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  final int value;
  final String label;
  const _Figure({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(NumberFormat.decimalPattern(
                Localizations.localeOf(context).toString())
            .format(value),
            style: theme.textTheme.titleLarge),
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

/// Says whether the park's outline is on the map: being looked for, found
/// (with the reminder that it is only approximate) or not found.
class _BoundaryNote extends ConsumerWidget {
  final PotaParkPoint park;
  const _BoundaryNote({required this.park});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final outline = ref.watch(potaParkBoundaryProvider(parkBoundaryKey(park)));
    return outline.when(
      loading: () => Row(children: [
        const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 8),
        Expanded(child: Text(l10n.potaParkBoundaryLooking, style: muted)),
      ]),
      error: (_, __) => Text(l10n.potaParkBoundaryMissing, style: muted),
      data: (ParkBoundary? b) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
              b == null ? Icons.layers_clear_outlined : Icons.info_outline,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
                switch (b?.source) {
                  null => l10n.potaParkBoundaryMissing,
                  BoundarySource.padus => l10n.potaParkBoundaryNotePadus,
                  BoundarySource.osm => l10n.potaParkBoundaryNote,
                },
                style: muted),
          ),
        ],
      ),
    );
  }
}
