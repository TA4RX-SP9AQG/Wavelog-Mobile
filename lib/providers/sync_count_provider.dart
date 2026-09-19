import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/qso_model.dart';
import 'remote_datasource_provider.dart';

/// Number of QSOs waiting to sync to the server.
///
/// Invalidated by [QsoNotifier] after every mutation and by the sync
/// controller after every batch, so the drawer badge and the sync page never
/// show a stale backlog.
final pendingSyncCountProvider = Provider<int>((ref) {
  final cache = ref.watch(qsoCacheDatasourceProvider);
  return cache.getUnsyncedCount();
});

/// The queued QSOs themselves, newest first. Re-evaluated whenever the count
/// provider is invalidated.
final pendingQsosProvider = FutureProvider<List<QsoModel>>((ref) async {
  ref.watch(pendingSyncCountProvider);
  final list =
      await ref.watch(qsoCacheDatasourceProvider).getUnsyncedQsos();
  list.sort((a, b) => b.dateTimeOn.compareTo(a.dateTimeOn));
  return list;
});

/// Deletions made offline that still have to reach the server.
final pendingDeleteCountProvider = FutureProvider<int>((ref) async {
  ref.watch(pendingSyncCountProvider);
  final deletes =
      await ref.watch(qsoCacheDatasourceProvider).getPendingDeletes();
  return deletes.length;
});
