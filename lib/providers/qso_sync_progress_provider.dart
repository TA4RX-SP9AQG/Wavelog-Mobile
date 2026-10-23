import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Progress of a station's first, never-synced-before multi-page QSO fetch
/// currently in flight. Background reconciliation (QsoRepository) runs its
/// own multi-page fetches too but deliberately doesn't report here, so a
/// routine periodic recheck never re-shows the "first sync" banner. Null
/// means no first-sync fetch is running right now, a station with only one
/// page of QSOs never produces this at all, since there's nothing worth
/// showing progress for.
class QsoSyncProgress {
  final int pagesDone;
  final int totalPages;

  const QsoSyncProgress({required this.pagesDone, required this.totalPages});

  double get fraction =>
      totalPages > 0 ? (pagesDone / totalPages).clamp(0, 1) : 0;
}

final qsoSyncProgressProvider = StateProvider<QsoSyncProgress?>((ref) => null);
