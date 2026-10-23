import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/adif_generator.dart';
import '../../core/utils/adif_parser.dart';
import '../datasources/local/qso_cache_datasource.dart';
import '../datasources/remote/wavelog_remote_datasource.dart';
import '../models/qso_model.dart';

class ImportResult {
  final int total;
  final int imported;
  final int duplicates;
  final int errors;

  const ImportResult({
    required this.total,
    required this.imported,
    this.duplicates = 0,
    this.errors = 0,
  });
}

/// Outcome of one [QsoRepository.syncPending] run.
class SyncReport {
  final int total;
  final int synced;
  final int failed;
  final int deletesDone;
  final int deletesLeft;
  final bool offline;
  final String? error;

  const SyncReport({
    required this.total,
    required this.synced,
    required this.failed,
    required this.deletesDone,
    required this.deletesLeft,
    required this.offline,
    this.error,
  });
}

class QsoRepository {
  static const _syncChunkSize = 50;

  final WavelogRemoteDatasource _remote;
  final QsoCacheDatasource _local;

  QsoRepository({
    required WavelogRemoteDatasource remote,
    required QsoCacheDatasource local,
  })  : _remote = remote,
        _local = local;

  Future<List<QsoModel>> fetchQsos({
    required int stationId,
    String? band,
    String? mode,
    String? callsign,
    int fetchFromId = 0,
    bool forceLocal = false,
    // See getContacts. Only ever called for a multi-page fetch, lets a
    // caller drive a progress indicator during a large station's first
    // sync (or a background reconciliation, see reconcileIfNeeded).
    void Function(int pagesDone, int totalPages)? onProgress,
  }) async {
    if (forceLocal) {
      return _local.getCachedQsos(
          stationId: stationId, band: band, mode: mode, callsign: callsign);
    }

    // A station with no cached baseline at all has to be fetched in full,
    // there is no "since" to ask for yet. Every station that already has
    // one, from this session or any earlier one, always takes the fast
    // incremental path below instead, no matter how long ago it was last
    // fully synced, so the UI never waits on a multi-page resync more than
    // once per station, ever. Catching a server-side deletion also needs a
    // full fetch, but that happens separately, in the background, and
    // never blocks this. See reconcileIfNeeded, called from
    // QsoNotifier after this returns.
    final cachedMaxId =
        fetchFromId > 0 ? fetchFromId : _local.maxServerIdForStation(stationId);

    return _fetchAndPersist(
      stationId: stationId,
      band: band,
      mode: mode,
      callsign: callsign,
      sinceId: cachedMaxId,
      isFullFetch: cachedMaxId == 0,
      onProgress: onProgress,
    );
  }

  /// Detects and repairs a server-side deletion, or a content edit to an
  /// existing QSO, for [stationId]. Meant to be run with a fire-and-forget
  /// call from a background task, never awaited inline in a code path the
  /// UI is blocked on, since either check can mean doing a full multi-page
  /// fetch.
  ///
  /// Two independent triggers, since they need different checks:
  /// - Deletion: the v2 API has no deletions feed (checked against the
  ///   official docs), so this relies on a property that always holds
  ///   given fetchQsos() above only ever adds locally: the cached count for
  ///   a station can only exceed the server's true current count when
  ///   something was deleted server-side. A single per_page=1 request gets
  ///   that true count without paging through the whole station, so this
  ///   half is cheap enough to run after every fetch.
  /// - Edit: an in-place edit to an existing QSO (say, a corrected band or
  ///   mode) changes neither the count nor any id, so it's invisible to
  ///   every cheap check, including the one above. There is no
  ///   "updated_since" filter either (also checked against the docs), so
  ///   catching this needs an actual full fetch, which already compares
  ///   every record field-by-field while persisting it (see
  ///   upsertQsosForStation's mapEquals check). Bounded to once per
  ///   [editCheckInterval] (from SettingsModel.qsoSyncCheckIntervalMinutes,
  ///   defaultEditCheckInterval otherwise) per station so it doesn't turn
  ///   into a full resync on every single fetch.
  ///
  /// Returns true if a deletion or an edit was found (and a repair
  /// attempted).
  static const defaultEditCheckInterval = Duration(minutes: 30);

  Future<bool> reconcileIfNeeded(
    int stationId, {
    void Function(int pagesDone, int totalPages)? onProgress,
    Duration editCheckInterval = defaultEditCheckInterval,
  }) async {
    final localCount = _local.countForStation(stationId);
    if (localCount == 0) return false; // nothing cached yet to go stale

    final lastFullCheck = await _local.getLastFullCheckAt(stationId);
    final editCheckDue = lastFullCheck == null ||
        DateTime.now().difference(lastFullCheck) > editCheckInterval;

    var deletionSuspected = false;
    try {
      final serverCount = await _remote.getQsoCount(stationId: stationId);
      deletionSuspected = serverCount < localCount;
    } catch (_) {
      // Network hiccup on the cheap check. Still fine to proceed if an
      // edit check is independently due, otherwise bail, the deletion
      // check will retry on the next fetch.
      if (!editCheckDue) return false;
    }

    if (!deletionSuspected && !editCheckDue) return false;

    await _fetchAndPersist(
        stationId: stationId, sinceId: 0, isFullFetch: true, onProgress: onProgress);
    return true;
  }

  Future<List<QsoModel>> _fetchAndPersist({
    required int stationId,
    String? band,
    String? mode,
    String? callsign,
    required int sinceId,
    required bool isFullFetch,
    void Function(int pagesDone, int totalPages)? onProgress,
  }) async {
    // Multi-logbook accounts fetch every station's QSOs in parallel (see
    // QsoNotifier._fetch). A logbook with many stations (e.g. 14) means
    // many concurrent multi-page pagination loops competing for the same
    // connection pool and hitting the server at once, which makes a single
    // station's request measurably more likely to time out than it would
    // fetching alone. One retry clears most of these transient,
    // contention-driven timeouts outright, when it doesn't, the
    // stale-cache fallback below still applies as the last resort.
    //
    // Çevrimdışı silinen (henüz sunucuya iletilmemiş) QSO'lar listede
    // yeniden belirmesin. Assign a deterministic localId to every server
    // QSO so the detail screen can always find it by ID.
    final pendingDeleteIds = await _local.getPendingDeleteServerIds();
    List<QsoModel> prepare(List<QsoModel> batch) => batch
        .where((q) =>
            q.serverId == null || !pendingDeleteIds.contains(q.serverId))
        .map((q) => q.localId != null
            ? q
            : q.copyWith(localId: q.serverId?.toString() ?? _qsoId(q)))
        .toList();

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final seenKeys = <String>{};
        await _remote.getContacts(
          stationId: stationId,
          fetchFromId: sinceId,
          band: band,
          // Persist each page as it arrives instead of accumulating the
          // whole multi-page result and writing it once at the end, for
          // a big station (real reported case: 104,983 QSOs, ~21 pages at
          // the raised per_page) that was both a memory spike and one long
          // blocking write, and meant an attempt that failed partway lost
          // everything it had already fetched.
          onPage: (page) async {
            final prepared = prepare(page);
            seenKeys.addAll(prepared.map((q) => q.localId!));
            await _local.upsertQsosForStation(stationId, prepared);
          },
          onProgress: onProgress,
        );

        if (isFullFetch) {
          // Every QSO the server has for this station has now been
          // upserted page by page above, anything still cached for this
          // station that ISN'T in what we just saw was deleted
          // server-side, so prune it. Only safe to do after a complete
          // fetch (no exception escaped above), pruning against a
          // partial page set would wrongly delete QSOs simply not
          // reached yet.
          await _local.pruneStaleForStation(stationId, seenKeys);
          // A full fetch just compared every record field-by-field while
          // persisting it (upsertQsosForStation's mapEquals check), so this
          // also counts as this station's periodic edit check, see
          // reconcileIfNeeded, whatever triggered this full fetch.
          await _local.setLastFullCheckAt(stationId, DateTime.now());
        }

        // Data is already fully persisted above, read the merged result
        // back from the cache rather than tracking it separately here.
        return await _local.getCachedQsos(
            stationId: stationId, band: band, mode: mode, callsign: callsign);
      } on NetworkException {
        // No connectivity at all, retrying immediately won't help.
        return _local.getCachedQsos(
            stationId: stationId, band: band, mode: mode, callsign: callsign);
      } on TimeoutException {
        if (attempt == 0) continue; // one retry, then fall back
        return _local.getCachedQsos(
            stationId: stationId, band: band, mode: mode, callsign: callsign);
      }
    }
    // Unreachable, the loop always returns on its second iteration.
    return _local.getCachedQsos(
        stationId: stationId, band: band, mode: mode, callsign: callsign);
  }

  /// Fetches the full ADIF export for [stationId] and merges QSL/LoTW/eQSL/
  /// ClubLog/HRDLog confirmation fields into locally cached QSOs for that
  /// station, persisting each merge. Confirmed live against a real server:
  /// the JSON list endpoint used by [fetchQsos] AND the single-QSO detail
  /// endpoint both omit these fields entirely, ADIF export
  /// (GET /api/v2/qso?format=adif) is the only mode that carries them. Read
  /// only: a paper-QSL write path was tried and confirmed live against a
  /// real server that the v2 PATCH endpoint silently drops qsl_sent/
  /// qsl_rcvd/qsl_*_via/qsl*date, so no such write path exists in this app.
  /// There's no per-QSO server-side filter, so this pulls the whole log ,
  /// callers should run it once per station per session, not per QSO.
  ///
  /// ADIF carries no unique per-record ID, so records are matched to cached
  /// QSOs via the same composite key [_qsoId] uses for optimistic-add
  /// reconciliation (call + second-precision timestamp + band + mode).
  /// Returns the updated QsoModels (empty if nothing changed).
  Future<List<QsoModel>> syncConfirmationFields(int stationId) async {
    final records = await _remote.getAdifExportRecords(stationId: stationId);
    if (records.isEmpty) return const [];

    final byKey = <String, Map<String, String>>{};
    for (final fields in records) {
      final qso = AdifParser.mapToQso(fields, stationId);
      byKey[_qsoId(qso)] = fields;
    }

    final local = await _local.getCachedQsos(stationId: stationId);
    final updated = <QsoModel>[];
    for (final q in local) {
      final fields = byKey[_qsoId(q)];
      if (fields == null) continue;

      final mergedRaw = {...?q.rawAdif, ...fields};
      if (mapEquals(q.rawAdif, mergedRaw)) continue;

      final merged = q.copyWith(rawAdif: mergedRaw);
      if (q.localId != null) {
        await _local.updateQso(q.localId!, merged);
      }
      updated.add(merged);
    }
    return updated;
  }

  Future<void> addQso(QsoModel qso, {bool forceLocal = false}) async {
    if (forceLocal) {
      await _local.saveLocalQso(qso);
      return;
    }

    try {
      final adif = AdifGenerator.generateSingle(qso);
      final success = await _remote.importQso(adif, qso.stationProfileId);
      if (success) {
        await _local.saveLocalQso(qso.copyWith(synced: true));
      } else {
        throw const ServerException('QSO kaydedilemedi');
      }
    } on NetworkException {
      await _local.saveLocalQso(qso.copyWith(synced: false));
      rethrow;
    } on TimeoutException {
      // Zaman aşımı da ağ hatası gibi ele alınır, QSO kaybolmasın
      await _local.saveLocalQso(qso.copyWith(synced: false));
      rethrow;
    }
  }

  Future<ImportResult> importAdif(
      String adifContent, int stationProfileId) async {
    AdifParser.validate(adifContent);
    final records = AdifParser.parse(adifContent);
    final total = records.length;

    try {
      await _remote.importQso(adifContent, stationProfileId);
      final qsos = records
          .map((r) => AdifParser.mapToQso(r, stationProfileId)
              .copyWith(synced: true))
          .toList();
      await _local.cacheQsos(qsos);
      return ImportResult(total: total, imported: total);
    } catch (e) {
      return ImportResult(total: total, imported: 0, errors: total);
    }
  }

  // 50'lik partilerle import; her parti sonrası onProgress çağrılır
  Future<ImportResult> streamingImportAdif(
    String adifContent,
    int stationProfileId,
    void Function(int processed, int total) onProgress,
  ) async {
    AdifParser.validate(adifContent);
    final records = AdifParser.parse(adifContent);
    final total = records.length;
    const batchSize = 50;
    int imported = 0;
    int errors = 0;
    // Track which record indices succeeded so only those go into local cache.
    final successfulIndices = <int>[];

    for (var i = 0; i < total; i += batchSize) {
      final end = (i + batchSize).clamp(0, total);
      final batch = records.sublist(i, end);
      final batchAdif = AdifGenerator.fromParsedRecords(batch);
      try {
        await _remote.importQso(batchAdif, stationProfileId);
        for (var j = i; j < end; j++) {
          successfulIndices.add(j);
        }
        imported += batch.length;
      } catch (_) {
        errors += batch.length;
      }
      onProgress(imported + errors, total);
    }

    // Only cache records that the server accepted.
    if (successfulIndices.isNotEmpty) {
      final qsos = successfulIndices
          .map((i) => AdifParser.mapToQso(records[i], stationProfileId)
              .copyWith(synced: true))
          .toList();
      await _local.cacheQsos(qsos);
    }
    return ImportResult(total: total, imported: imported, errors: errors);
  }

  Future<List<QsoModel>> exportQsos({
    required int stationId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final qsos = await _remote.getContacts(stationId: stationId, fetchFromId: 0);
    return qsos.where((q) {
      final dt = q.dateTimeOn.toUtc();
      if (dateFrom != null && dt.isBefore(dateFrom.toUtc())) return false;
      if (dateTo != null) {
        final end = DateTime.utc(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59);
        if (dt.isAfter(end)) return false;
      }
      return true;
    }).toList();
  }

  Future<String> exportAdif({
    required int stationId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final qsos = await exportQsos(stationId: stationId, dateFrom: dateFrom, dateTo: dateTo);
    return AdifGenerator.generate(qsos);
  }

  Future<void> deleteQso(QsoModel qso) async {
    if (qso.localId != null) {
      await _local.deleteQso(qso.localId!);
    }
    final id = qso.serverId;
    if (id != null) {
      try {
        await _remote.deleteQso(id, qso.stationProfileId);
      } catch (_) {
        // Herhangi bir hata (ağ, zaman aşımı, sunucu hatası), kuyruğa al.
        // _processPendingDeletes, 404 gibi "zaten silindi" durumlarını
        // yakalayıp kuyruktan düşürür.
        await _local.addPendingDelete(id, qso.stationProfileId);
      }
    }
  }

  // Returns true if saved to server, false if local only
  Future<bool> updateQso(QsoModel original, QsoModel updated,
      {bool forceLocal = false}) async {
    final localId = original.localId;
    if (localId == null) throw const ServerException('QSO bulunamadı');

    if (forceLocal || !original.synced) {
      await _local.updateQso(localId, updated.copyWith(synced: false));
      return false;
    }

    final serverId = original.serverId;
    if (serverId == null) {
      await _local.updateQso(localId, updated.copyWith(synced: false));
      return false;
    }

    final fields = _buildUpdateFields(original, updated);
    if (fields.isEmpty) {
      await _local.updateQso(localId, updated.copyWith(synced: true));
      return true;
    }

    try {
      await _remote.updateQsoFields(serverId, updated.stationProfileId, fields);
      await _local.updateQso(localId, updated.copyWith(synced: true));
      return true;
    } on NetworkException {
      await _local.updateQso(localId, updated.copyWith(synced: false));
      return false;
    } on TimeoutException {
      await _local.updateQso(localId, updated.copyWith(synced: false));
      return false;
    }
  }

  // Build v2 API field map (flat JSON) with only changed values.
  // Field names match the v2 PATCH /api/v2/qso/{id} schema, not COL_* columns.
  static Map<String, dynamic> _buildUpdateFields(
      QsoModel original, QsoModel updated) {
    final f = <String, dynamic>{};

    if (original.callsign != updated.callsign) f['call'] = updated.callsign;
    if (original.band != updated.band) f['band'] = updated.band;
    if (original.freqMhz != updated.freqMhz) {
      // v2 PATCH expects Hz; send empty string to clear the field.
      f['freq'] = updated.freqMhz != null
          ? (updated.freqMhz! * 1000000).round().toString()
          : '';
    }
    // mode: v2 handles submode split internally; send submode value when present
    if (original.mode != updated.mode || original.submode != updated.submode) {
      f['mode'] = (updated.submode?.isNotEmpty == true)
          ? updated.submode!
          : updated.mode;
    }
    if (original.rstSent != updated.rstSent) f['rst_sent'] = updated.rstSent;
    if (original.rstRcvd != updated.rstRcvd) f['rst_rcvd'] = updated.rstRcvd;
    // date+time must travel together per v2 spec
    if (original.dateTimeOn != updated.dateTimeOn) {
      final dt = updated.dateTimeOn.toUtc();
      f['qso_date'] = _patchDate(dt); // YYYY-MM-DD
      f['time_on'] = _patchTime(dt);  // HHMMSS
    }
    if (original.name != updated.name) f['name'] = updated.name ?? '';
    if (original.qth != updated.qth) f['qth'] = updated.qth ?? '';
    if (original.gridSquare != updated.gridSquare) {
      f['gridsquare'] = updated.gridSquare ?? '';
    }
    if (original.comment != updated.comment) f['comment'] = updated.comment ?? '';
    if (original.notes != updated.notes) f['notes'] = updated.notes ?? '';

    // rawAdif-backed extension fields
    final oRaw = original.rawAdif ?? {};
    final uRaw = updated.rawAdif ?? {};
    const adifToV2 = {
      'TX_PWR': 'tx_pwr',
      'IOTA': 'iota',
      'SOTA_REF': 'sota_ref',
      'WWFF_REF': 'wwff_ref',
      'POTA_REF': 'pota_ref',
    };
    for (final entry in adifToV2.entries) {
      final oVal = oRaw[entry.key] ?? '';
      final uVal = uRaw[entry.key] ?? '';
      if (oVal != uVal) f[entry.value] = uVal;
    }

    return f;
  }

  // YYYY-MM-DD, v2 PATCH date format (strtotime-safe)
  static String _patchDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  // HHMMSS, v2 PATCH time format
  static String _patchTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}'
      '${dt.minute.toString().padLeft(2, '0')}'
      '${dt.second.toString().padLeft(2, '0')}';

  /// Pushes offline QSOs and queued deletions to the server.
  ///
  /// QSOs go out in [_syncChunkSize]-sized ADIF batches per station so that a
  /// single bad batch (or a dropped connection) no longer loses the whole
  /// station's backlog, [onProgress] can report a real percentage, and every
  /// accepted batch is marked synced with one Hive write.
  Future<SyncReport> syncPending({
    void Function(int done, int failed, int total)? onProgress,
  }) async {
    final deletes = await _processPendingDeletes();

    final pending = await _local.getUnsyncedQsos();
    final total = pending.length;
    var synced = 0;
    var failed = 0;
    var offline = deletes.offline;
    String? error;
    onProgress?.call(0, 0, total);

    final groups = <int, List<QsoModel>>{};
    for (final qso in pending) {
      groups.putIfAbsent(qso.stationProfileId, () => []).add(qso);
    }

    outer:
    for (final entry in groups.entries) {
      final list = entry.value;
      for (var i = 0; i < list.length; i += _syncChunkSize) {
        final chunk = list.sublist(i, min(i + _syncChunkSize, list.length));
        try {
          final ok =
              await _remote.importQso(AdifGenerator.generate(chunk), entry.key);
          if (ok) {
            await _local.markManySynced(
                chunk.map((q) => q.localId).whereType<String>());
            synced += chunk.length;
          } else {
            failed += chunk.length;
          }
        } on NetworkException catch (e) {
          // Still offline, stop, the rest stays queued for the next attempt.
          offline = true;
          error = e.message;
          break outer;
        } on TimeoutException catch (e) {
          offline = true;
          error = e.message;
          break outer;
        } catch (e) {
          debugPrint('Sync batch failed, will retry later: $e');
          failed += chunk.length;
          error = e.toString();
        }
        onProgress?.call(synced, failed, total);
      }
    }

    return SyncReport(
      total: total,
      synced: synced,
      failed: failed + (total - synced - failed),
      deletesDone: deletes.done,
      deletesLeft: deletes.left,
      offline: offline,
      error: error,
    );
  }

  // Çevrimdışıyken silinen QSO'ların sunucu silmelerini işler
  Future<({int done, int left, bool offline})> _processPendingDeletes() async {
    final deletes = await _local.getPendingDeletes();
    var done = 0;
    for (var i = 0; i < deletes.length; i++) {
      final d = deletes[i];
      try {
        await _remote.deleteQso(d.serverId, d.stationProfileId);
        await _local.removePendingDelete(d.serverId, d.stationProfileId);
        done++;
      } on NetworkException {
        // hâlâ çevrimdışı, sonraki senkronda tekrar dene
        return (done: done, left: deletes.length - done, offline: true);
      } on TimeoutException {
        return (done: done, left: deletes.length - done, offline: true);
      } catch (_) {
        // Sunucu kaydı zaten silmiş olabilir, kuyruktan düş
        await _local.removePendingDelete(d.serverId, d.stationProfileId);
        done++;
      }
    }
    return (done: done, left: 0, offline: false);
  }

  int get unsyncedCount => _local.unsyncedCount;

  static String _qsoId(QsoModel q) {
    // Saniye hassasiyeti kullan, MySQL DATETIME milisaniyeleri saklamaz.
    // Optimistik ID ile sunucudan geri çekilen ID'nin eşleşmesi için gerekli.
    final ts = q.dateTimeOn.millisecondsSinceEpoch ~/ 1000;
    final safeCall = q.callsign.replaceAll('/', '-');
    return '${safeCall}_${ts}_${q.band}_${q.mode}';
  }
}
