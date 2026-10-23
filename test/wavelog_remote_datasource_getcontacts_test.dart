import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/data/datasources/remote/wavelog_remote_datasource.dart';

/// A scriptable [HttpClientAdapter]: each call records the request's query
/// parameters and either throws a receive-timeout DioException (to simulate
/// a flaky page) or answers with a canned single-page JSON response. The
/// canned meta.total is configurable for getQsoCount() tests.
class _ScriptedAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> seenQueries = [];
  final int timeoutsBeforeSuccess;
  final int metaTotal;
  int calls = 0;

  _ScriptedAdapter({this.timeoutsBeforeSuccess = 0, this.metaTotal = 0});

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    seenQueries.add(Map<String, dynamic>.from(options.queryParameters));

    if (calls <= timeoutsBeforeSuccess) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }

    final body = jsonEncode({
      'data': [
        {
          'call': 'K1ABC',
          'qso_date': '2026-09-01 12:00:00',
          'band': '20m',
          'mode': 'SSB',
          'rst_sent': '59',
          'rst_rcvd': '59',
        }
      ],
      'meta': {'has_more': false, 'total': metaTotal},
    });
    return ResponseBody.fromBytes(utf8.encode(body), 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

WavelogRemoteDatasource _remoteWith(_ScriptedAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return WavelogRemoteDatasource(dio: dio);
}

void main() {
  group('WavelogRemoteDatasource.getContacts', () {
    test('fetchFromId > 0 is sent as the since_id query parameter',
        () async {
      final adapter = _ScriptedAdapter();
      final remote = _remoteWith(adapter);

      await remote.getContacts(stationId: 1, fetchFromId: 42);

      expect(adapter.seenQueries.single['since_id'], 42);
    });

    test('fetchFromId == 0 omits since_id entirely (full fetch)', () async {
      final adapter = _ScriptedAdapter();
      final remote = _remoteWith(adapter);

      await remote.getContacts(stationId: 1);

      expect(adapter.seenQueries.single.containsKey('since_id'), isFalse);
    });

    test('a single flaky page is retried in place, the fetch still '
        'succeeds without restarting from page 1', () async {
      final adapter = _ScriptedAdapter(timeoutsBeforeSuccess: 1);
      final remote = _remoteWith(adapter);

      final result = await remote.getContacts(stationId: 1);

      expect(result.length, 1);
      expect(adapter.calls, 2); // one failure + one retry, same page
    });

    test('pages beyond page 1 are fetched (fanned out) and merged, driven '
        "by each batch's own has_more rather than a page count fixed from "
        'page 1', () async {
      final adapter = _MultiPageAdapter(totalPages: 3);
      final dio = Dio()..httpClientAdapter = adapter;
      final remote = WavelogRemoteDatasource(dio: dio);
      final onPageCalls = <int>[];

      final result = await remote.getContacts(
          stationId: 1, onPage: (page) async => onPageCalls.add(page.length));

      expect(result.map((q) => q.callsign).toSet(), {'PAGE1', 'PAGE2', 'PAGE3'});
      // onPage only fires for pages that actually had data, empty
      // past-the-end pages (fetched as part of a concurrent batch, then
      // discovered to be past the end) don't count.
      expect(onPageCalls.length, 3);
      expect(adapter.requestedPages, containsAll([1, 2, 3]));
    });

    test('a QSO landing mid-fetch is not lost, even though page 1 reported '
        'a smaller total_pages than the fetch actually needs', () async {
      // Simulates a new QSO landing right after page 1 is fetched: page 1
      // itself reports a stale total_pages (3), but the true, current
      // total is 4, reflected in every page's has_more. A loop still
      // bounded by page 1's stale snapshot would stop after page 3 and
      // never see page 4 at all.
      final adapter = _DriftAdapter(staleTotalOnPage1: 3, trueTotal: 4);
      final dio = Dio()..httpClientAdapter = adapter;
      final remote = WavelogRemoteDatasource(dio: dio);

      final result = await remote.getContacts(stationId: 1);

      expect(result.map((q) => q.callsign).toSet(),
          {'PAGE1', 'PAGE2', 'PAGE3', 'PAGE4'});
    });
  });

  group('WavelogRemoteDatasource.getAdifExportRecords', () {
    test('a single flaky page is retried in place', () async {
      final adapter = _AdifAdapter(totalPages: 1, timeoutsBeforeSuccess: 1);
      final dio = Dio()..httpClientAdapter = adapter;
      final remote = WavelogRemoteDatasource(dio: dio);

      final result = await remote.getAdifExportRecords(stationId: 1);

      expect(result.single['CALL'], 'PAGE1');
      expect(adapter.calls, 2); // one failure + one retry, same page
    });

    test('pages beyond page 1 are fetched, driven by has_more', () async {
      final adapter = _AdifAdapter(totalPages: 3);
      final dio = Dio()..httpClientAdapter = adapter;
      final remote = WavelogRemoteDatasource(dio: dio);

      final result = await remote.getAdifExportRecords(stationId: 1);

      expect(result.map((r) => r['CALL']).toSet(), {'PAGE1', 'PAGE2', 'PAGE3'});
    });

    test('a record landing mid-fetch is not lost, even though page 1 '
        'reported a smaller total_pages than the fetch actually needs',
        () async {
      final adapter =
          _AdifAdapter(totalPages: 4, staleTotalOnPage1: 3);
      final dio = Dio()..httpClientAdapter = adapter;
      final remote = WavelogRemoteDatasource(dio: dio);

      final result = await remote.getAdifExportRecords(stationId: 1);

      expect(result.map((r) => r['CALL']).toSet(),
          {'PAGE1', 'PAGE2', 'PAGE3', 'PAGE4'});
    });
  });

  group('WavelogRemoteDatasource.getQsoCount', () {
    test('requests per_page=1 and returns meta.total', () async {
      final adapter = _ScriptedAdapter(metaTotal: 104983);
      final remote = _remoteWith(adapter);

      final count = await remote.getQsoCount(stationId: 1);

      expect(count, 104983);
      expect(adapter.seenQueries.single['per_page'], 1);
      expect(adapter.seenQueries.single['page'], 1);
    });

    test('returns 0 when meta.total is absent, rather than throwing',
        () async {
      final adapter = _NoMetaAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final remote = WavelogRemoteDatasource(dio: dio);

      final count = await remote.getQsoCount(stationId: 1);

      expect(count, 0);
    });
  });
}

/// Answers each page request with a distinct single-QSO body, keyed off
/// the `page` query parameter, page 1 reports [totalPages] so getContacts()
/// knows to fan the rest out.
/// Page 1 reports [staleTotalOnPage1] (a snapshot that's already out of
/// date by the time it's read), every other page reports [trueTotal] and
/// has_more computed against it, simulating a record landing right after
/// page 1 was fetched.
class _DriftAdapter implements HttpClientAdapter {
  final int staleTotalOnPage1;
  final int trueTotal;

  _DriftAdapter({required this.staleTotalOnPage1, required this.trueTotal});

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final page = options.queryParameters['page'] as int;
    final body = jsonEncode({
      'data': page <= trueTotal
          ? [
              {
                'call': 'PAGE$page',
                'qso_date': '2026-09-01 12:00:00',
                'band': '20m',
                'mode': 'SSB',
                'rst_sent': '59',
                'rst_rcvd': '59',
              }
            ]
          : [],
      'meta': {
        'has_more': page < trueTotal,
        'total_pages': page == 1 ? staleTotalOnPage1 : trueTotal,
      },
    });
    return ResponseBody.fromBytes(utf8.encode(body), 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

/// Scriptable ADIF-format adapter: each page's body carries one ADIF
/// record (`<call:N>PAGE{page}<eor>`), can fail a fixed number of times
/// before succeeding, and can report a stale total_pages on page 1 only
/// (see _DriftAdapter for the JSON equivalent and why that matters).
class _AdifAdapter implements HttpClientAdapter {
  final int totalPages;
  final int? staleTotalOnPage1;
  final int timeoutsBeforeSuccess;
  int calls = 0;

  _AdifAdapter({
    required this.totalPages,
    this.staleTotalOnPage1,
    this.timeoutsBeforeSuccess = 0,
  });

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    if (calls <= timeoutsBeforeSuccess) {
      throw DioException(
          requestOptions: options, type: DioExceptionType.receiveTimeout);
    }

    final page = options.queryParameters['page'] as int;
    final reportedTotal =
        (page == 1 && staleTotalOnPage1 != null) ? staleTotalOnPage1! : totalPages;
    final adif = page <= totalPages ? '<call:${'PAGE$page'.length}>PAGE$page<eor>' : '';

    final body = jsonEncode({
      'data': {'adif': adif, 'exported': adif.isEmpty ? 0 : 1},
      'meta': {'has_more': page < totalPages, 'total_pages': reportedTotal},
    });
    return ResponseBody.fromBytes(utf8.encode(body), 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

class _MultiPageAdapter implements HttpClientAdapter {
  final int totalPages;
  final List<int> requestedPages = [];

  _MultiPageAdapter({required this.totalPages});

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final page = options.queryParameters['page'] as int;
    requestedPages.add(page);

    // Matches a real server: a page past the end comes back empty with
    // has_more: false, not an extra record, the self-correcting fetch loop
    // relies on exactly this to know when to stop.
    final body = jsonEncode({
      'data': page <= totalPages
          ? [
              {
                'call': 'PAGE$page',
                'qso_date': '2026-09-01 12:00:00',
                'band': '20m',
                'mode': 'SSB',
                'rst_sent': '59',
                'rst_rcvd': '59',
              }
            ]
          : [],
      'meta': {'has_more': page < totalPages, 'total_pages': totalPages},
    });
    return ResponseBody.fromBytes(utf8.encode(body), 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

/// Answers with a body that has no `meta` key at all, exercising
/// getQsoCount()'s fallback when the shape isn't what's expected.
class _NoMetaAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final body = jsonEncode({'data': []});
    return ResponseBody.fromBytes(utf8.encode(body), 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}
