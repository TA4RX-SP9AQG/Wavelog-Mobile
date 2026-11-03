import 'dart:async';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dxcc/dxcc_prefix_matcher.dart';
import '../core/utils/worked_before.dart';
import 'qso_provider.dart';
import 'remote_datasource_provider.dart';

/// Callsign -> DXCC entity, from the server's DXCC catalog joined with the
/// bundled cty.dat prefixes. Null while the catalog can't be fetched
/// (offline, or a Wavelog without the catalog endpoint); retried a minute
/// later in that case.
final dxccMatcherProvider = FutureProvider<DxccPrefixMatcher?>((ref) async {
  try {
    final entities =
        (await ref.watch(wavelogRemoteDatasourceProvider).getDxccList())
            .where((e) => !e.deleted)
            .toList();
    if (entities.isNotEmpty) return await DxccPrefixMatcher.build(entities);
  } catch (_) {}
  final retry = Timer(const Duration(minutes: 1), ref.invalidateSelf);
  ref.onDispose(retry.cancel);
  return null;
});

/// Bands and modes worked per DXCC entity across the QSOs in scope. Null
/// until both the log and the matcher are there: without the matcher most
/// QSOs have no entity, and everything would look like a new country.
final workedIndexProvider = FutureProvider<WorkedIndex?>((ref) async {
  final log = ref.watch(scopedQsoProvider).valueOrNull;
  final matcher = await ref.watch(dxccMatcherProvider.future);
  if (log == null || matcher == null) return null;
  final rows = [
    for (final q in log)
      (call: q.callsign, dxcc: q.dxcc, band: q.band, mode: q.mode, submode: q.submode),
  ];
  return Isolate.run(() => WorkedIndex.build(rows, matcher));
});
