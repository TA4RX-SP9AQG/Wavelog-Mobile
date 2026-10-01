import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Progress of a station's multi-page QSO fetch currently in flight (either
/// the first, never-synced-before sync, or a background deletion
/// reconciliation, see QsoRepository). Null means no multi-page fetch is
/// running right now, a station with only one page of QSOs never produces
/// this at all, since there's nothing worth showing progress for.
class QsoSyncProgress {
  final int pagesDone;
  final int totalPages;

  const QsoSyncProgress({required this.pagesDone, required this.totalPages});

  double get fraction =>
      totalPages > 0 ? (pagesDone / totalPages).clamp(0, 1) : 0;
}

final qsoSyncProgressProvider = StateProvider<QsoSyncProgress?>((ref) => null);
