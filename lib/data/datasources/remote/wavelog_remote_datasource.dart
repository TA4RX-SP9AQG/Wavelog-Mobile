import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/adif_parser.dart';
import '../../models/callsign_lookup_model.dart';
import '../../models/confirmation_model.dart';
import '../../models/contest_model.dart';
import '../../models/dxcc_entity_model.dart';
import '../../models/qso_model.dart';
import '../../models/state_subdivision_model.dart';
import '../../models/station_logbook_model.dart';
import '../../models/station_model.dart';
import '../../models/statistics_model.dart';

/// Talks to the official Wavelog API v2 (Bearer token) exclusively, no
/// server-side patch/plugin required as of Wavelog v3.2.0.
class WavelogRemoteDatasource {
  final Dio _dio;

  WavelogRemoteDatasource({required Dio dio}) : _dio = dio;

  // ── QSO, v2 native ─────────────────────────────────────────────────────────

  Future<bool> importQso(String adifData, int stationProfileId) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.qso,
        data: {
          'station_profile_id': stationProfileId,
          'import_type': 'adif',
          'adif': adifData,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // The v2 API has no changes/deletions feed, webhook, or "deleted_since"
  // filter (checked against the official docs), so a deletion can only be
  // detected by comparing counts. meta.total on the list endpoint is a
  // cheap way to get the server's true current count for a station without
  // paging through it, per_page=1 keeps the response minimal since only
  // meta is read.
  Future<int> getQsoCount({required int stationId}) async {
    try {
      final response = await _dio.get(ApiEndpoints.qso, queryParameters: {
        'station_id': stationId,
        'page': 1,
        'per_page': 1,
      });
      final meta = response.data is Map ? response.data['meta'] : null;
      return meta is Map ? (meta['total'] as num?)?.toInt() ?? 0 : 0;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // Wavelog v2 uses page-based pagination (page=1,2,...) with meta.has_more.
  // fetchFromId maps to the server's ?since_id= filter (only QSOs with a
  // higher primary key), passing the highest id already cached turns a
  // full re-download of the station's history into a fetch of just what's
  // new, which matters once a station has thousands of QSOs.
  Future<List<QsoModel>> getContacts({
    required int stationId,
    int fetchFromId = 0,
    String? band,
    int? stationProfileId,
    // Invoked once per fetched page, before the next page is requested,
    // lets the caller persist each page as it arrives (see
    // QsoRepository.fetchQsos) instead of holding the whole multi-page
    // result in memory until the very end, which for a large station
    // (thousands of QSOs, dozens of pages) is both a memory spike and one
    // big blocking write with no progress in between.
    Future<void> Function(List<QsoModel> page)? onPage,
    // Invoked after each page completes with (pages done so far, total
    // pages), lets the caller drive a progress indicator for a large
    // station's fetch. Only ever fires with totalPages > 1, callers can
    // treat "never called" as "this fetch is a single page, effectively
    // instant, no progress UI needed".
    void Function(int pagesDone, int totalPages)? onProgress,
  }) async {
    final allQsos = <QsoModel>[];

    // Page 1 first, alone, both to get data flowing immediately and to
    // learn the true page count (meta.total_pages) needed to fan the rest
    // out concurrently below.
    final first = await _fetchQsoPage(
        stationId: stationId, page: 1, fetchFromId: fetchFromId, band: band);
    allQsos.addAll(first.batch);
    if (onPage != null && first.batch.isNotEmpty) await onPage(first.batch);

    if (first.hasMore) {
      onProgress?.call(1, first.totalPages);
      // Remaining pages are fanned out with bounded concurrency instead of
      // fetched one at a time. Measured against a real 104,983-QSO station
      // (~21 pages at the raised per_page below): 4-at-a-time cut the wall
      // clock time roughly in half again on top of the win from raising
      // per_page itself, going much beyond 4 showed diminishing returns
      // (the server itself becomes the bottleneck, not the network), and
      // higher concurrency here would also stack with the concurrent
      // stations QsoNotifier already fetches, risking the same contention
      // that caused stations to silently fall back to stale cached data
      // in the first place.
      //
      // The loop continues based on each batch's own has_more rather than
      // a page count fixed from page 1's snapshot. A QSO added (from
      // anywhere) while this is running shifts every older record one
      // position later, since the list is newest-first, if the batch
      // range stayed pinned to the original total_pages, the true last
      // page could end up never fetched. That's not just a completeness
      // gap: on a full fetch, any record this never sees gets treated by
      // the pruning step as deleted server-side and removed locally, so a
      // stale page count could silently delete a QSO that still exists.
      const pageConcurrency = 4;
      var nextPage = 2;
      var pagesDone = 1;
      var totalPagesHint = first.totalPages;
      var hasMore = true;
      while (hasMore) {
        final pages = [for (var i = 0; i < pageConcurrency; i++) nextPage + i];
        final results = await Future.wait(pages.map((page) => _fetchQsoPage(
            stationId: stationId,
            page: page,
            fetchFromId: fetchFromId,
            band: band)));
        for (final r in results) {
          allQsos.addAll(r.batch);
          if (onPage != null && r.batch.isNotEmpty) await onPage(r.batch);
          pagesDone++;
          if (r.totalPages > totalPagesHint) totalPagesHint = r.totalPages;
        }
        hasMore = results.any((r) => r.hasMore);
        nextPage += pageConcurrency;
        onProgress?.call(pagesDone, totalPagesHint);
      }
    }

    return allQsos;
  }

  /// Fetches and parses a single QSO list page, retrying once in place on
  /// a timeout rather than letting the caller retry the whole multi-page
  /// fetch from page 1, a station with thousands of QSOs can mean dozens
  /// of page requests, requiring every single one of them to succeed in
  /// one run made any one flaky request enough to discard all the pages
  /// already fetched and restart from scratch (confirmed against a real
  /// account: a 104,983-QSO station was effectively never completing).
  Future<({List<QsoModel> batch, bool hasMore, int totalPages})> _fetchQsoPage({
    required int stationId,
    required int page,
    required int fetchFromId,
    String? band,
  }) async {
    // The server's documented max is 5000 (default 50); a bigger page
    // means far fewer sequential round trips when the whole log is
    // refreshed, each round trip carries a fixed per-request cost
    // (auth, query parsing, connection setup) that a larger payload
    // amortizes better, measured at roughly 3x fewer requests for well
    // under 3x the per-request time.
    final params = <String, dynamic>{
      'station_id': stationId,
      'page': page,
      'per_page': 5000,
    };
    if (band != null && band.isNotEmpty) params['band'] = band;
    if (fetchFromId > 0) params['since_id'] = fetchFromId;

    Response response;
    try {
      response = await _dio.get(ApiEndpoints.qso, queryParameters: params);
    } on DioException catch (e) {
      final mapped = _mapDioException(e);
      if (mapped is! TimeoutException) throw mapped;
      try {
        response = await _dio.get(ApiEndpoints.qso, queryParameters: params);
      } on DioException catch (e2) {
        throw _mapDioException(e2);
      }
    }

    final data = response.data;

    if (data is Map && data['status'] == 'failed') {
      throw ServerException(data['reason']?.toString() ?? 'Server error');
    }

    List<QsoModel> batch = const [];
    bool hasMore = false;
    int totalPages = 1;

    if (data is Map) {
      // Paginated response with meta envelope
      final contacts = data['data'] ?? data['qsos'] ?? [];
      if (contacts is List) {
        // Parsing (date parsing, rawAdif map construction, field alias
        // lookups) is CPU-bound, up to 5000 records a page, and was blocking
        // the UI isolate long enough to be felt on a large station, exactly
        // the same class of problem already fixed for DXCC stats (see
        // statistics_screen.dart's _computeDxccEntries), so it's offloaded
        // the same way. Safe to send QsoModels back across the isolate
        // boundary here specifically because these are freshly built and
        // never attached to a Hive box yet, unlike instances read from
        // Hive.box.values (whose HiveObject box reference isn't sendable).
        batch = await compute(_parseQsoBatch,
            contacts.whereType<Map<String, dynamic>>().toList());
      }
      final meta = data['meta'];
      if (meta is Map) {
        hasMore = meta['has_more'] == true;
        totalPages = (meta['total_pages'] as num?)?.toInt() ?? 1;
      }
    } else if (data is List) {
      // Legacy flat list, no pagination info, assume single page
      batch = await compute(
          _parseQsoBatch, data.whereType<Map<String, dynamic>>().toList());
    }

    return (batch: batch, hasMore: hasMore, totalPages: totalPages);
  }

  /// The CPU-bound half of [_fetchQsoPage], run on a background isolate via
  /// [compute]. Must be a top-level function, not a closure, for the isolate
  /// machinery to re-invoke it on the other side.
  static List<QsoModel> _parseQsoBatch(List<Map<String, dynamic>> records) =>
      records.map(QsoModel.fromJson).toList();

  // ADIF export (GET /api/v2/qso?format=adif). Confirmed live against a real
  // server: neither the JSON list endpoint nor the single-QSO detail
  // endpoint (GET /api/v2/qso/{id}) ever return QSL/LoTW/eQSL/ClubLog/HRDLog
  // confirmation fields, both return the exact same limited field set, even
  // for a QSO independently confirmed via /api/v2/confirmation. ADIF export
  // is the only mode that carries them. There's no per-QSO or per-callsign
  // filter for this endpoint (a call= query param is silently ignored), so
  // this always pulls the whole station log, callers should sync once per
  // station per session, not per QSO. Same page-1-first, then-fan-out
  // pattern as getContacts (see that method's comment for why), each page
  // is parsed independently, not concatenated as raw text, since every
  // page carries its own ADIF header, which would otherwise corrupt record
  // parsing at page boundaries, that also makes concurrent page fetches
  // safe here, there's no shared parse state between them.
  Future<List<Map<String, String>>> getAdifExportRecords(
      {required int stationId}) async {
    final all = <Map<String, String>>[];

    final first = await _fetchAdifPage(stationId: stationId, page: 1);
    all.addAll(first.records);

    if (first.hasMore) {
      // Same self-correcting, has_more-driven loop as getContacts, and for
      // the same reason: a QSO added while this runs shifts every older
      // record one position later (newest-first order), a page count
      // fixed from page 1 could then stop short of the true end.
      const pageConcurrency = 4;
      var nextPage = 2;
      var hasMore = true;
      while (hasMore) {
        final pages = [for (var i = 0; i < pageConcurrency; i++) nextPage + i];
        final results = await Future.wait(
            pages.map((page) => _fetchAdifPage(stationId: stationId, page: page)));
        for (final r in results) {
          all.addAll(r.records);
        }
        hasMore = results.any((r) => r.hasMore);
        nextPage += pageConcurrency;
      }
    }

    return all;
  }

  Future<({List<Map<String, String>> records, bool hasMore, int totalPages})>
      _fetchAdifPage({required int stationId, required int page}) async {
    // Same raised per_page as getContacts, far fewer sequential round
    // trips for a large station's export (real reported case: a
    // 104,983-QSO station made this the effective bottleneck behind "DXCC
    // stats never finish loading", since the Statistics screen awaits one
    // of these per station sharing the active callsign before it can
    // render anything).
    final params = <String, dynamic>{
      'format': 'adif',
      'station_id': stationId,
      'page': page,
      'per_page': 5000,
    };

    // Same one-retry-in-place as _fetchQsoPage, and for the same reason:
    // the Statistics screen fires this concurrently for every station
    // sharing the active callsign (see _dxccStatsProvider's batching), so
    // any one page timing out under that load is expected, not
    // exceptional, and shouldn't take down the whole confirmation sync for
    // that station.
    Response response;
    try {
      response = await _dio.get(ApiEndpoints.qso, queryParameters: params);
    } on DioException catch (e) {
      final mapped = _mapDioException(e);
      if (mapped is! TimeoutException) throw mapped;
      try {
        response = await _dio.get(ApiEndpoints.qso, queryParameters: params);
      } on DioException catch (e2) {
        throw _mapDioException(e2);
      }
    }

    final data = response.data;
    if (data is! Map) return (records: <Map<String, String>>[], hasMore: false, totalPages: 1);

    final inner = data['data'];
    final adif = inner is Map ? inner['adif']?.toString() : null;
    final records = (adif != null && adif.isNotEmpty) ? AdifParser.parse(adif) : <Map<String, String>>[];

    final meta = data['meta'];
    final hasMore = meta is Map && meta['has_more'] == true;
    final totalPages = meta is Map ? (meta['total_pages'] as num?)?.toInt() ?? 1 : 1;

    return (records: records, hasMore: hasMore, totalPages: totalPages);
  }

  Future<void> deleteQso(int serverId, int stationProfileId) async {

    try {
      await _dio.delete(
        ApiEndpoints.qsoById(serverId),
        queryParameters: {'station_profile_id': stationProfileId},
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<void> updateQsoFields(
      int serverId, int stationProfileId, Map<String, dynamic> fields) async {
    try {
      await _dio.patch(
        ApiEndpoints.qsoById(serverId),
        data: {'station_profile_id': stationProfileId, ...fields},
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // ── Callsign Lookup, v2 native ──────────────────────────────────────────────

  Future<CallsignLookupModel> lookupCallsign({
    required String callsign,
    String? band,
    String? mode,
  }) async {
    try {
      // v2 lookup is GET with query params (POST returns 405).
      // detail=full triggers per-band worked/confirmed flags and callbook lookup.
      // callbook must be the string 'true' (server checks === 'true').
      final params = <String, dynamic>{
        'callsign': callsign.toUpperCase(),
        'detail': 'full',
        'callbook': 'true',
      };
      if (band != null && band.isNotEmpty) params['band'] = band;
      if (mode != null && mode.isNotEmpty) params['mode'] = mode;

      final response = await _dio.get(
        ApiEndpoints.lookup,
        queryParameters: params,
      );
      final raw = response.data;

      if (raw is Map<String, dynamic>) {
        // v2 wraps response in {"data": {...}, "meta": {...}}
        final data = raw['data'] is Map<String, dynamic>
            ? raw['data'] as Map<String, dynamic>
            : raw;
        return CallsignLookupModel.fromJson(callsign, data);
      }
      return CallsignLookupModel(callsign: callsign.toUpperCase());
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // ── Statistics, v2 native ───────────────────────────────────────────────────

  Future<StatisticsModel> getStatistics() async {
    try {
      final response = await _dio.get(ApiEndpoints.statistics);
      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        // v2 wraps payload in {"data": {...}, "meta": {...}}
        final inner = raw['data'] is Map<String, dynamic>
            ? raw['data'] as Map<String, dynamic>
            : raw;
        return StatisticsModel.fromJson(inner);
      }
      return const StatisticsModel();
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // ── Version, v2 native ──────────────────────────────────────────────────────

  Future<String?> getVersion() async {
    try {
      final response = await _dio.get(ApiEndpoints.version);
      final data = response.data;
      if (data is Map) return data['version']?.toString();
      return null;
    } on DioException catch (_) {
      return null;
    }
  }

  /// Same request as [getVersion] but rethrows a mapped [AppException] on
  /// failure instead of swallowing it, used by the server-setup connection
  /// test, which needs to tell an SSL failure apart from "no server here".
  Future<String?> checkVersion() async {
    try {
      final response = await _dio.get(ApiEndpoints.version);
      final data = response.data;
      if (data is Map) return data['version']?.toString();
      return null;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // ── Station list/create, v2 native ─────────────────────────────────────────

  Future<List<StationModel>> getStations() async {
    try {
      final response = await _dio.get(ApiEndpoints.station);
      final data = response.data;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(StationModel.fromJson)
            .toList();
      }
      if (data is Map) {
        final list = data['data'] ?? data['stations'];
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map(StationModel.fromJson)
              .toList();
        }
      }
      return [];
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<StationModel> createStation(
      StationModel station, {bool linkActiveLogbook = false}) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.station,
        data: _stationV2Body(station),
      );
      final data = response.data;
      if (response.statusCode == 201 || response.statusCode == 200) {
        final inner = data is Map ? data['data'] : null;
        final id = inner is Map ? inner['id'] : null;
        if (id != null) {
          return station.copyWith(id: _parseInt(id) ?? station.id);
        }
        return station;
      }
      throw const ServerException('Could not create station');
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // ── Station extensions, v2 ──────────────────────────────────────────────────

  Future<StationModel> getStationDetail(int stationId) async {
    try {
      final response = await _dio.get(ApiEndpoints.stationById(stationId));
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return StationModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw const ServerException('Invalid server response');
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<void> updateStation(StationModel station) async {
    try {
      await _dio.patch(
        ApiEndpoints.stationById(station.id),
        data: _stationV2Body(station),
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<void> setActiveStation(int stationId) async {
    try {
      await _dio.patch(
        ApiEndpoints.stationById(stationId),
        data: {'set_active': true},
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<void> deleteStation(int stationId) async {
    try {
      await _dio.delete(ApiEndpoints.stationById(stationId));
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<int> cloneStation(int stationId, String newName) async {
    try {
      final srcResp = await _dio.get(ApiEndpoints.stationById(stationId));
      final srcData = srcResp.data;
      if (srcData is! Map || srcData['data'] is! Map) return 0;

      final src = Map<String, dynamic>.from(srcData['data'] as Map);
      src['name'] = newName;
      // active and uuid are server-generated; exclude them
      src.remove('active');
      src.remove('uuid');
      src.remove('id');
      src.remove('country');

      final resp = await _dio.post(ApiEndpoints.station, data: src);
      final d = resp.data;
      if (d is Map && d['data'] is Map) {
        return _parseInt((d['data'] as Map)['id']) ?? 0;
      }
      return 0;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // ── Logbook, v2 ────────────────────────────────────────────────────────────

  Future<List<StationLogbookModel>> getLogbooks() async {
    try {
      final response = await _dio.get(ApiEndpoints.logbook);
      final data = response.data;
      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .map((j) => StationLogbookModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<int> createLogbook(String name) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.logbook,
        data: {'name': name},
      );
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return _parseInt((data['data'] as Map)['id']) ?? 0;
      }
      return 0;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<void> updateLogbook(int logbookId, String name) async {
    try {
      await _dio.patch(
        ApiEndpoints.logbookById(logbookId),
        data: {'name': name},
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<void> deleteLogbook(int logbookId) async {
    try {
      await _dio.delete(ApiEndpoints.logbookById(logbookId));
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<void> setActiveLogbook(int logbookId) async {
    try {
      await _dio.patch(
        ApiEndpoints.logbookById(logbookId),
        data: {'set_active': true},
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<void> linkStationToLogbook(int logbookId, int stationId) async {
    try {
      final current = await _getLogbookStationIds(logbookId);
      if (!current.contains(stationId)) {
        await _dio.patch(
          ApiEndpoints.logbookById(logbookId),
          data: {'station_ids': [...current, stationId]},
        );
      }
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<void> unlinkStationFromLogbook(int logbookId, int stationId) async {
    try {
      final current = await _getLogbookStationIds(logbookId);
      final updated = current.where((id) => id != stationId).toList();
      await _dio.patch(
        ApiEndpoints.logbookById(logbookId),
        data: {'station_ids': updated},
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<List<int>> _getLogbookStationIds(int logbookId) async {
    final resp = await _dio.get(ApiEndpoints.logbookById(logbookId));
    final d = resp.data;
    if (d is Map && d['data'] is Map) {
      final ids = (d['data'] as Map)['station_ids'];
      if (ids is List) return ids.map((e) => _parseInt(e) ?? 0).where((e) => e > 0).toList();
    }
    return [];
  }

  // ── DXCC / Catalog, v2 ─────────────────────────────────────────────────────

  Future<List<DxccEntity>> getDxccList() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.catalog,
        queryParameters: {'topic': 'dxcc'},
      );
      final data = response.data;
      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .map((j) => DxccEntity.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<List<StateSubdivision>> getStateList(int dxcc) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.catalog,
        queryParameters: {'topic': 'subdivisions', 'dxcc': dxcc},
      );
      final data = response.data;
      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .map((j) => StateSubdivision.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  // ── Contest, v2 ────────────────────────────────────────────────────────────

  Future<List<ContestTemplate>> getContestList() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.catalog,
        queryParameters: {'topic': 'contest'},
      );
      final data = response.data;
      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .map((j) => ContestTemplate.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (_) {
      return [];
    }
  }

  Future<List<ContestSession>> getContestSessions() async {
    try {
      final response = await _dio.get(ApiEndpoints.contest);
      final data = response.data;
      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .map((j) => ContestSession.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<int> createContestSession({
    required int contestAdifId,
    required DateTime timeStart,
    required DateTime timeEnd,
    required int stationId,
    String adifName = '',
    String customName = '',
    List<String> exchangeFields = const ['serial'],
    String copyExchangeTo = '',
  }) async {
    try {
      String fmt(DateTime dt) =>
          '${dt.year.toString().padLeft(4, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}:00';

      final response = await _dio.post(
        ApiEndpoints.contest,
        data: {
          'contest': adifName,
          'time_start': fmt(timeStart.toUtc()),
          'time_end': fmt(timeEnd.toUtc()),
          'station_id': stationId,
          'settings': {
            'exchangefields': exchangeFields,
            'copyexchangeto': copyExchangeTo,
          },
        },
      );
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return _parseInt((data['data'] as Map)['id']) ?? 0;
      }
      throw const ServerException('Could not create contest session');
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<void> updateContestSession({
    required int contestSessionId,
    required int contestAdifId,
    required DateTime timeStart,
    required DateTime timeEnd,
    required int stationId,
    String adifName = '',
    String customName = '',
    List<String> exchangeFields = const ['serial'],
    String copyExchangeTo = '',
  }) async {
    try {
      String fmt(DateTime dt) =>
          '${dt.year.toString().padLeft(4, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}:00';

      await _dio.patch(
        ApiEndpoints.contestById(contestSessionId),
        data: {
          'contest': adifName,
          'time_start': fmt(timeStart.toUtc()),
          'time_end': fmt(timeEnd.toUtc()),
          'station_id': stationId,
          'settings': {
            'exchangefields': exchangeFields,
            'copyexchangeto': copyExchangeTo,
          },
        },
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<void> deleteContestSession(int contestSessionId) async {
    try {
      await _dio.delete(ApiEndpoints.contestById(contestSessionId));
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<void> logContestQso({
    required int contestSessionId,
    required int stationProfileId,
    required String adifString,
  }) async {
    int? qsoId;
    try {
      final response = await _dio.post(
        ApiEndpoints.qso,
        data: {
          'station_profile_id': stationProfileId,
          'import_type': 'adif',
          'adif': adifString,
        },
      );
      final raw = response.data;
      if (raw is Map) {
        final d = raw['data'];
        qsoId = _parseInt(d is Map ? d['id'] : null);
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError) {
        await importQso(adifString, stationProfileId);
        return;
      }
      throw _mapDioException(e);
    }

    if (qsoId != null && qsoId > 0) {
      try {
        await _dio.patch(
          ApiEndpoints.contestById(contestSessionId),
          data: {'link_qso_ids': [qsoId]},
        );
      } on DioException catch (_) {
        // QSO logged but not linked to session, non-critical
      }
    }
  }

  // ── Confirmations, v2 ──────────────────────────────────────────────────────

  /// Fetches all confirmation pages and returns a map of qsoId → list of types.
  ///
  /// Reported by a user: Statistics/DXCC "worked vs confirmed" counts were
  /// undercounting, disproportionately for older QSOs. Root cause: this loop
  /// used the server's small default per_page (unlike [getContacts]/
  /// [getAdifExportRecords], which explicitly request 1000) and silently
  /// swallowed any mid-pagination DioException by breaking out of the loop ,
  /// a single transient failure on any later page (confirmation records are
  /// newest-first, like everything else in this API) truncated the whole
  /// result with no error surfaced anywhere, so callers just saw an
  /// incomplete map and never knew it was incomplete. Now requests 1000/page
  /// (far fewer round trips, so far less exposure to a mid-fetch failure)
  /// and rethrows instead of swallowing, matching [getContacts]/
  /// [getAdifExportRecords], an incomplete fetch should surface as an error
  /// callers can retry, not silently render wrong numbers.
  Future<Map<int, List<String>>> getConfirmations() async {
    final all = <ConfirmationRecord>[];
    int page = 1;
    while (true) {
      try {
        final response = await _dio.get(
          ApiEndpoints.confirmation,
          queryParameters: {'page': page, 'per_page': 1000},
        );
        final data = response.data;
        if (data is! Map) break;
        final list = data['data'];
        if (list is List) {
          all.addAll(list
              .whereType<Map<String, dynamic>>()
              .map(ConfirmationRecord.fromJson));
        }
        final meta = data['meta'];
        if (meta is! Map || meta['has_more'] != true) break;
        page++;
      } on DioException catch (e) {
        throw _mapDioException(e);
      }
    }
    final map = <int, List<String>>{};
    for (final r in all) {
      if (r.qsoId > 0) {
        map.putIfAbsent(r.qsoId, () => []);
        if (!map[r.qsoId]!.contains(r.type)) map[r.qsoId]!.add(r.type);
      }
    }
    return map;
  }

  // ── Station v2 body builder ──────────────────────────────────────────────────

  static Map<String, dynamic> _stationV2Body(StationModel s) {
    final body = <String, dynamic>{
      'name': s.profileName,
      'callsign': s.callsign,
      'gridsquare': s.gridSquare ?? '',
      'city': s.city ?? '',
    };
    if (s.dxcc != null) body['dxcc'] = s.dxcc;
    if (s.cqZone != null) body['cq'] = s.cqZone;
    if (s.ituZone != null) body['itu'] = s.ituZone;
    if (s.state != null && s.state!.isNotEmpty) body['state'] = s.state;
    if (s.county != null && s.county!.isNotEmpty) body['cnty'] = s.county;
    if (s.iota != null && s.iota!.isNotEmpty) body['iota'] = s.iota;
    if (s.sota != null && s.sota!.isNotEmpty) body['sota'] = s.sota;
    if (s.wwff != null && s.wwff!.isNotEmpty) body['wwff'] = s.wwff;
    if (s.pota != null && s.pota!.isNotEmpty) body['pota'] = s.pota;
    if (s.sig != null && s.sig!.isNotEmpty) body['sig'] = s.sig;
    if (s.sigInfo != null && s.sigInfo!.isNotEmpty) body['sig_info'] = s.sigInfo;
    if (s.power != null) body['power'] = s.power;
    return body;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  AppException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
        final inner = e.error;
        // A TLS handshake failure (self-signed / private-PKI certificate)
        // can surface here instead of under DioExceptionType.unknown or
        // .badCertificate, depending on Dio/platform version, when it
        // does, it must still be classified as SslException, or the
        // server-setup screen's SSL-bypass dialog never gets offered and
        // this falls through to a generic, misleading "server
        // unreachable" message instead.
        if (inner is HandshakeException) {
          return const SslException(
              'SSL certificate error, the server certificate chain could not be verified.');
        }
        if (inner is SocketException) {
          final msg = inner.message.toLowerCase();
          if (msg.contains('connection refused')) {
            return const NetworkException(
                'Cannot connect to server, check the URL or port');
          }
          if (msg.contains('failed host lookup') ||
              msg.contains('no address associated') ||
              msg.contains('nodename nor servname')) {
            return const NetworkException(
                'Server address not found, check the URL');
          }
        }
        return const NetworkException(
            'Connection failed, server unreachable');
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutException();
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final body = e.response?.data;
        // v2 API: {"error": {"code": "...", "message": "..."}}
        String? serverMsg;
        if (body is Map) {
          final errObj = body['error'];
          serverMsg = (errObj is Map
              ? errObj['message']?.toString()
              : body['message']?.toString());
        }
        if (statusCode == 401) return const UnauthorizedException();
        // 403 means the key itself is valid but lacks the scope this call
        // needs (e.g. a read-only token trying to PATCH set_active), a
        // different problem from an invalid key, so it needs its own
        // message. The v2 API's 403 body names the missing scope directly
        // ("Token is missing the required scope: logbook:write"); surface
        // that instead of the generic "invalid API key" text, which sends
        // users chasing the wrong fix.
        if (statusCode == 403) return ForbiddenException(serverMsg);
        final msg = serverMsg ?? 'Server error ($statusCode)';
        return ServerException(msg, statusCode: statusCode);
      case DioExceptionType.unknown:
        final inner = e.error;
        if (inner is HandshakeException) {
          return const SslException(
              'SSL certificate error, the server certificate chain could not be verified.');
        }
        return NetworkException(e.message ?? 'Unknown error');
      case DioExceptionType.badCertificate:
        return const SslException(
            'SSL certificate error, the server certificate chain could not be verified.');
      default:
        return NetworkException(e.message ?? 'Unknown error');
    }
  }
}
