import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/l10n_extension.dart';
import '../../../providers/qso_sync_progress_provider.dart';

/// A slim banner with a progress bar, shown only while a station's fetch is
/// spread across more than one page, a large station's first sync, or a
/// background deletion reconciliation catching up on one. Absent for the
/// common case (small stations, incremental refreshes), so it never
/// interrupts routine use of the app.
class QsoSyncProgressBanner extends ConsumerWidget {
  const QsoSyncProgressBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(qsoSyncProgressProvider);
    if (progress == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.primaryContainer,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.qsoSyncBigTitle,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.qsoSyncBigBody,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 4,
              backgroundColor:
                  theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}
