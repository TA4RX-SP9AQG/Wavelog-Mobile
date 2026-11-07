import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/remote/park_boundary_datasource.dart';
import '../data/datasources/remote/pota_parks_datasource.dart';
import '../data/models/park_boundary_model.dart';
import '../data/models/pota_park_model.dart';

final potaParksDatasourceProvider =
    Provider<PotaParksDatasource>((_) => PotaParksDatasource());

/// The time, as a provider so tests can move it.
final potaParksClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// How long the parks of a square are taken as current. pota.app serves them
/// with `max-age=3600`.
const kParkSquareFreshness = Duration(hours: 1);

/// After a failed load a square is left alone this long, unless the user asks
/// again, so that a bad connection is not hammered by every map move.
const kParkSquareCooldown = Duration(seconds: 30);

/// Squares loaded at the same time.
const kParkLoadsAtOnce = 3;

/// Squares kept in memory; the least recently wanted go first.
const kParkSquaresKept = 300;

/// One square of parks. [fetchedAt] is null when it was never loaded, and an
/// entry that failed after loading keeps its older [parks].
@immutable
class SquareEntry {
  final List<PotaParkPoint> parks;
  final DateTime? fetchedAt;
  final DateTime? failedAt;
  const SquareEntry({this.parks = const [], this.fetchedAt, this.failedAt});

  bool get loaded => fetchedAt != null;

  SquareEntry loadedAt(DateTime at, List<PotaParkPoint> parks) =>
      SquareEntry(parks: parks, fetchedAt: at);

  SquareEntry failed(DateTime at) =>
      SquareEntry(parks: parks, fetchedAt: fetchedAt, failedAt: at);
}

/// The parks loaded so far. Replaced, never changed, on every update.
@immutable
class PotaParksState {
  final Map<String, SquareEntry> squares;

  /// Squares being loaded now.
  final Set<String> loading;
  const PotaParksState(
      {this.squares = const {}, this.loading = const <String>{}});

  /// The parks of [wanted] squares, each park once (a park on a border can
  /// be in two squares' replies).
  List<PotaParkPoint> parksIn(Iterable<String> wanted) {
    final seen = <String>{};
    return [
      for (final s in wanted)
        for (final p in squares[s]?.parks ?? const <PotaParkPoint>[])
          if (seen.add(p.reference)) p,
    ];
  }

  /// Squares of [wanted] whose last load failed.
  List<String> failedIn(Iterable<String> wanted) =>
      [for (final s in wanted) if (squares[s]?.failedAt != null) s];

  /// Whether any of [wanted] has nothing to show yet.
  bool isLoadingAny(Iterable<String> wanted) =>
      wanted.any((s) => loading.contains(s) && !(squares[s]?.loaded ?? false));

  /// A loaded park by reference, for a search that needs no network.
  PotaParkPoint? find(String reference) {
    final r = reference.trim().toUpperCase();
    for (final e in squares.values) {
      for (final p in e.parks) {
        if (p.reference == r) return p;
      }
    }
    return null;
  }
}

final potaParksProvider =
    NotifierProvider<PotaParksNotifier, PotaParksState>(PotaParksNotifier.new);

/// Loads the parks of the squares a map shows. One request per square, never
/// two for the same square at once, at most [kParkLoadsAtOnce] at a time, and
/// the squares the map no longer shows are dropped from the queue.
class PotaParksNotifier extends Notifier<PotaParksState> {
  var _disposed = false;
  var _wanted = const <String>{};
  final _queue = Queue<String>();
  final _inFlight = <String>{};

  /// Square -> last wanted, oldest first, to drop the least recent.
  final _recent = <String>{};

  @override
  PotaParksState build() {
    ref.onDispose(() => _disposed = true);
    return const PotaParksState();
  }

  DateTime get _now => ref.read(potaParksClockProvider)();

  /// Declares which squares the map shows now, nearest to its centre first.
  /// Whatever is missing, out of date, or failed long enough ago is queued.
  void ensureSquares(List<String> squares) {
    _wanted = squares.toSet();
    for (final s in squares.reversed) {
      _recent
        ..remove(s)
        ..add(s);
    }
    _queue.removeWhere((s) => !_wanted.contains(s));
    final now = _now;
    for (final s in squares) {
      if (_inFlight.contains(s) || _queue.contains(s)) continue;
      if (_needsLoad(state.squares[s], now)) _queue.add(s);
    }
    _pump();
  }

  bool _needsLoad(SquareEntry? e, DateTime now) {
    if (e == null) return true;
    final failedAt = e.failedAt;
    if (failedAt != null && now.difference(failedAt) < kParkSquareCooldown) {
      return false;
    }
    final fetchedAt = e.fetchedAt;
    return fetchedAt == null ||
        now.difference(fetchedAt) >= kParkSquareFreshness;
  }

  /// The user asked again: the wanted squares that failed are loaded now,
  /// cooldown or not.
  void retryFailed() {
    for (final s in _wanted) {
      final e = state.squares[s];
      if (e?.failedAt == null || _inFlight.contains(s) || _queue.contains(s)) {
        continue;
      }
      _queue.add(s);
    }
    _pump();
  }

  void _pump() {
    while (_inFlight.length < kParkLoadsAtOnce && _queue.isNotEmpty) {
      final s = _queue.removeFirst();
      if (!_wanted.contains(s) || _inFlight.contains(s)) continue;
      _inFlight.add(s);
      _publish();
      unawaited(_load(s));
    }
  }

  Future<void> _load(String square) async {
    final before = state.squares[square] ?? const SquareEntry();
    List<PotaParkPoint>? parks;
    Object? error;
    try {
      parks = await ref.read(potaParksDatasourceProvider).parksInSquare(square);
    } catch (e) {
      error = e;
    }
    // The answer may come after the screen is gone: the ref is dead then
    if (_disposed) return;
    final SquareEntry after;
    if (parks != null) {
      after = before.loadedAt(_now, List.unmodifiable(parks));
    } else {
      debugPrint('POTA parks: square $square failed: $error');
      after = before.failed(_now);
    }
    _inFlight.remove(square);
    _publish(replace: {square: after});
    _pump();
  }

  void _publish({Map<String, SquareEntry> replace = const {}}) {
    if (_disposed) return;
    final squares = {...state.squares, ...replace};
    // Drop the least recently wanted squares beyond the limit, keeping
    // whatever is shown or loading.
    if (squares.length > kParkSquaresKept) {
      for (final s in _recent.toList()) {
        if (squares.length <= kParkSquaresKept) break;
        if (_wanted.contains(s) || _inFlight.contains(s)) continue;
        if (squares.remove(s) != null) _recent.remove(s);
      }
    }
    state = PotaParksState(
      squares: Map.unmodifiable(squares),
      loading: Set.unmodifiable(_inFlight),
    );
  }
}

// ── One park's card ───────────────────────────────────────────────────────────

/// Each part of a park's card is its own provider, so that a slow or failed
/// part does not hold back the others. The park's name and place come from
/// the map data and show at once.
final potaParkDetailProvider =
    FutureProvider.autoDispose.family<PotaParkDetail?, String>(
        (ref, reference) =>
            ref.read(potaParksDatasourceProvider).getDetail(reference));

final potaParkStatsProvider =
    FutureProvider.autoDispose.family<PotaParkStats?, String>(
        (ref, reference) =>
            ref.read(potaParksDatasourceProvider).getStats(reference));

final potaParkActivationsProvider =
    FutureProvider.autoDispose.family<List<PotaActivation>, String>(
        (ref, reference) =>
            ref.read(potaParksDatasourceProvider).getRecentActivations(reference));

// ── The park's outline ────────────────────────────────────────────────────────

final parkBoundaryDatasourceProvider =
    Provider<ParkBoundaryDatasource>((_) => ParkBoundaryDatasource());

/// How long a park stays selected before its outline is asked for, so that
/// tapping through several parks does not ask for each.
const kParkBoundaryDwell = Duration(milliseconds: 700);

/// What is needed to look an outline up. A record, so equal parks are the
/// same key.
typedef ParkBoundaryKey = ({String reference, String name, double lat, double lon});

ParkBoundaryKey parkBoundaryKey(PotaParkPoint p) =>
    (reference: p.reference, name: p.name, lat: p.lat, lon: p.lon);

/// The outline of a park, or null when OpenStreetMap has none that fits.
/// Nothing is asked until the park has stayed selected for a moment, and
/// nothing at all when it is deselected in that moment.
final potaParkBoundaryProvider =
    FutureProvider.autoDispose.family<ParkBoundary?, ParkBoundaryKey>(
        (ref, key) async {
  // The wait ends early, and its timer is cancelled, when the park is let go
  var gone = false;
  final waited = Completer<void>();
  final timer = Timer(kParkBoundaryDwell, waited.complete);
  ref.onDispose(() {
    gone = true;
    timer.cancel();
    if (!waited.isCompleted) waited.complete();
  });
  await waited.future;
  if (gone) return null;
  return ref.read(parkBoundaryDatasourceProvider).find(
        reference: key.reference,
        name: key.name,
        lat: key.lat,
        lon: key.lon,
      );
});
