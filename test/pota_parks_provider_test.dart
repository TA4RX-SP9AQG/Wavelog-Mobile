import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/data/datasources/local/pota_squares_store.dart';
import 'package:wavelog_mobile/data/datasources/remote/pota_parks_datasource.dart';
import 'package:wavelog_mobile/data/models/pota_park_model.dart';
import 'package:wavelog_mobile/data/models/qso_model.dart';
import 'package:wavelog_mobile/data/models/station_model.dart';
import 'package:wavelog_mobile/providers/pota_parks_provider.dart';
import 'package:wavelog_mobile/providers/pota_stats_provider.dart';
import 'package:wavelog_mobile/providers/qso_provider.dart';
import 'package:wavelog_mobile/providers/station_provider.dart';

PotaParkPoint park(String ref) =>
    PotaParkPoint(reference: ref, name: ref, lat: 52.5, lon: 21);

/// A datasource whose answers the test hands out one by one.
class FakeParks implements PotaParksDatasource {
  final asked = <String>[];
  var active = 0;
  var mostAtOnce = 0;
  final _pending = <String, Completer<List<PotaParkPoint>>>{};

  /// Answers every request at once with these parks, or fails.
  List<PotaParkPoint>? immediate;
  Object? failWith;

  @override
  Future<List<PotaParkPoint>> parksInSquare(String grid4) {
    asked.add(grid4);
    if (failWith != null) return Future.error(failWith!);
    final now = immediate;
    if (now != null) return Future.value(now);
    active++;
    if (active > mostAtOnce) mostAtOnce = active;
    final c = Completer<List<PotaParkPoint>>();
    _pending[grid4] = c;
    return c.future.whenComplete(() => active--);
  }

  void answer(String square, List<PotaParkPoint> parks) =>
      _pending.remove(square)!.complete(parks);

  void fail(String square) =>
      _pending.remove(square)!.completeError(Exception('offline'));

  @override
  Future<PotaParkDetail?> getDetail(String reference) =>
      throw UnimplementedError();
  @override
  Future<PotaParkStats?> getStats(String reference) =>
      throw UnimplementedError();
  @override
  Future<List<PotaActivation>> getRecentActivations(String reference,
          {int count = 5}) =>
      throw UnimplementedError();
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeParks fake;
  late ProviderContainer container;
  late DateTime clock;

  PotaParksNotifier notifier() => container.read(potaParksProvider.notifier);
  PotaParksState state() => container.read(potaParksProvider);

  setUp(() {
    fake = FakeParks();
    clock = DateTime.utc(2026, 11, 7, 10);
    container = ProviderContainer(overrides: [
      potaParksDatasourceProvider.overrideWithValue(fake),
      potaParksClockProvider.overrideWithValue(() => clock),
      // These tests are about the loading, not about the disk
      potaSquaresStoreProvider.overrideWithValue(null),
    ]);
    container.listen(potaParksProvider, (_, __) {});
    addTearDown(() => container.dispose());
  });

  test('the same square is asked for once, however often it is wanted',
      () async {
    notifier().ensureSquares(['KO02']);
    notifier().ensureSquares(['KO02']);
    notifier().ensureSquares(['KO02', 'KO12']);
    fake.answer('KO02', [park('PL-0001')]);
    await settle();
    notifier().ensureSquares(['KO02', 'KO12']); // loaded now
    expect(fake.asked, ['KO02', 'KO12']);
    expect(state().squares['KO02']!.loaded, isTrue);
    expect(state().parksIn(['KO02']).single.reference, 'PL-0001');
  });

  test('a limited number of squares load at once; a finished one frees a '
      'place', () async {
    final many = [for (var i = 0; i < kParkLoadsAtOnce + 3; i++) 'AA${i.toString().padLeft(2, '0')}'];
    notifier().ensureSquares(many);
    expect(fake.asked, many.take(kParkLoadsAtOnce));
    expect(state().loading, many.take(kParkLoadsAtOnce).toSet());

    fake.answer(many.first, []);
    await settle();
    expect(fake.asked, many.take(kParkLoadsAtOnce + 1));

    for (final s in many.skip(1).take(kParkLoadsAtOnce - 1)) {
      fake.answer(s, []);
      await settle();
    }
    for (final s in many.skip(kParkLoadsAtOnce)) {
      fake.answer(s, []);
    }
    await settle();
    expect(fake.mostAtOnce, kParkLoadsAtOnce);
    expect(state().loading, isEmpty);
    expect(state().squares.values.every((e) => e.loaded), isTrue);
  });

  test('squares the map has moved away from are dropped from the queue',
      () async {
    // Two more than can load at once: those two wait in the queue
    final first = [
      for (var i = 0; i < kParkLoadsAtOnce + 2; i++) 'AA${i.toString().padLeft(2, '0')}'
    ];
    notifier().ensureSquares(first);
    final waiting = first.skip(kParkLoadsAtOnce).toList();
    expect(fake.asked, first.take(kParkLoadsAtOnce));

    // The map moved: only one of the old squares and a new one are wanted now
    notifier().ensureSquares([first.first, 'BB00']);
    for (final s in first.take(kParkLoadsAtOnce)) {
      fake.answer(s, []);
    }
    await settle();
    // Those that were waiting are no longer wanted; BB00 is next
    expect(fake.asked, [...first.take(kParkLoadsAtOnce), 'BB00']);
    expect(fake.asked, isNot(contains(waiting.first)));
  });

  test('a failed square is left alone for the cooldown, then asked again',
      () async {
    notifier().ensureSquares(['KO02']);
    fake.fail('KO02');
    await settle();
    expect(state().failedIn(['KO02']), ['KO02']);
    expect(state().squares['KO02']!.loaded, isFalse);

    clock = clock.add(const Duration(seconds: 29));
    notifier().ensureSquares(['KO02']);
    expect(fake.asked, ['KO02']);

    clock = clock.add(const Duration(seconds: 2));
    notifier().ensureSquares(['KO02']);
    expect(fake.asked, ['KO02', 'KO02']);
    fake.answer('KO02', [park('PL-0001')]);
    await settle();
    expect(state().failedIn(['KO02']), isEmpty);
    expect(state().parksIn(['KO02']), hasLength(1));
  });

  test('retry asks again at once, cooldown or not', () async {
    notifier().ensureSquares(['KO02']);
    fake.fail('KO02');
    await settle();
    notifier().retryFailed();
    expect(fake.asked, ['KO02', 'KO02']);
    fake.answer('KO02', []);
    await settle();
    expect(state().failedIn(['KO02']), isEmpty);
  });

  test('retry leaves squares that are not wanted any more', () async {
    notifier().ensureSquares(['KO02']);
    fake.fail('KO02');
    await settle();
    notifier().ensureSquares(['KO12']);
    fake.answer('KO12', []);
    await settle();
    notifier().retryFailed();
    expect(fake.asked, ['KO02', 'KO12']);
  });

  test('old parks are shown while a stale square is refreshed, and stay if '
      'the refresh fails', () async {
    notifier().ensureSquares(['KO02']);
    fake.answer('KO02', [park('PL-0001')]);
    await settle();

    clock = clock.add(const Duration(minutes: 59));
    notifier().ensureSquares(['KO02']);
    expect(fake.asked, ['KO02']); // still fresh

    clock = clock.add(const Duration(minutes: 2));
    notifier().ensureSquares(['KO02']);
    expect(fake.asked, ['KO02', 'KO02']);
    expect(state().parksIn(['KO02']).single.reference, 'PL-0001');
    // A refresh is not "loading": there is something to show
    expect(state().isLoadingAny(['KO02']), isFalse);

    fake.fail('KO02');
    await settle();
    expect(state().parksIn(['KO02']).single.reference, 'PL-0001');
    expect(state().failedIn(['KO02']), ['KO02']);

    clock = clock.add(const Duration(minutes: 5));
    notifier().ensureSquares(['KO02']);
    fake.answer('KO02', [park('PL-0002')]);
    await settle();
    expect(state().parksIn(['KO02']).single.reference, 'PL-0002');
    expect(state().failedIn(['KO02']), isEmpty);
  });

  test('a first load shows as loading until it answers', () async {
    notifier().ensureSquares(['KO02']);
    expect(state().isLoadingAny(['KO02']), isTrue);
    fake.answer('KO02', []);
    await settle();
    expect(state().isLoadingAny(['KO02']), isFalse);
    // An empty square is a result, not a gap
    expect(state().squares['KO02']!.loaded, isTrue);
  });

  test('a park on a border is listed once', () async {
    notifier().ensureSquares(['KO02', 'KO12']);
    fake.answer('KO02', [park('PL-0001'), park('PL-0002')]);
    fake.answer('KO12', [park('PL-0002'), park('PL-0003')]);
    await settle();
    expect(state().parksIn(['KO02', 'KO12']).map((p) => p.reference),
        ['PL-0001', 'PL-0002', 'PL-0003']);
  });

  test('a loaded park is found by reference without the network', () async {
    notifier().ensureSquares(['KO02']);
    fake.answer('KO02', [park('PL-0001')]);
    await settle();
    expect(state().find(' pl-0001 ')?.reference, 'PL-0001');
    expect(state().find('PL-9999'), isNull);
  });

  test('the least recently wanted squares go beyond the limit', () async {
    fake.immediate = [];
    for (var i = 0; i < kParkSquaresKept + 20; i++) {
      notifier().ensureSquares(['S$i']);
      await settle();
    }
    expect(state().squares.length, kParkSquaresKept);
    expect(state().squares.containsKey('S${kParkSquaresKept + 19}'), isTrue);
    expect(state().squares.containsKey('S0'), isFalse);
  });

  test('squares being shown are never dropped by the limit', () async {
    fake.immediate = [];
    final shown = [for (var i = 0; i < 8; i++) 'W$i'];
    notifier().ensureSquares(shown);
    await settle();
    await settle();
    for (var i = 0; i < kParkSquaresKept + 5; i++) {
      notifier().ensureSquares(['S$i', ...shown]);
      await settle();
    }
    for (final s in shown) {
      expect(state().squares.containsKey(s), isTrue, reason: s);
    }
  });

  test('an answer that arrives after the provider is gone is ignored',
      () async {
    final other = ProviderContainer(overrides: [
      potaParksDatasourceProvider.overrideWithValue(fake),
      potaSquaresStoreProvider.overrideWithValue(null),
    ]);
    other.listen(potaParksProvider, (_, __) {});
    other.read(potaParksProvider.notifier).ensureSquares(['KO02']);
    other.dispose();
    fake.answer('KO02', [park('PL-0001')]);
    await settle(); // must not throw
  });

  group('squares kept on the device', () {
    late FakeStore store;

    setUp(() {
      store = FakeStore();
      container.dispose();
      container = ProviderContainer(overrides: [
        potaParksDatasourceProvider.overrideWithValue(fake),
        potaParksClockProvider.overrideWithValue(() => clock),
        potaSquaresStoreProvider.overrideWithValue(store),
      ]);
      container.listen(potaParksProvider, (_, __) {});
    });

    test('a square seen an hour ago or less shows from the device, with no '
        'request', () async {
      store.saved['KO02'] =
          StoredSquare([park('PL-0001')], clock.subtract(const Duration(minutes: 20)));
      notifier().ensureSquares(['KO02']);
      await settle();
      expect(fake.asked, isEmpty);
      expect(state().parksIn(['KO02']).single.reference, 'PL-0001');
      expect(state().isLoadingAny(['KO02']), isFalse);
    });

    test('an older one shows at once and is fetched again', () async {
      store.saved['KO02'] =
          StoredSquare([park('PL-0001')], clock.subtract(const Duration(hours: 5)));
      notifier().ensureSquares(['KO02']);
      await settle();
      // The old parks are already on the map...
      expect(state().parksIn(['KO02']).single.reference, 'PL-0001');
      expect(state().isLoadingAny(['KO02']), isFalse);
      // ...while the new ones are on their way
      expect(fake.asked, ['KO02']);
      fake.answer('KO02', [park('PL-0002')]);
      await settle();
      expect(state().parksIn(['KO02']).single.reference, 'PL-0002');
      // and what came is kept for next time
      expect(store.saved['KO02']!.parks.single.reference, 'PL-0002');
      expect(store.saved['KO02']!.at, clock);
    });

    test('a square never seen is fetched and then kept', () async {
      notifier().ensureSquares(['KO02']);
      await settle();
      expect(fake.asked, ['KO02']);
      fake.answer('KO02', [park('PL-0001')]);
      await settle();
      expect(store.saved['KO02']!.parks.single.reference, 'PL-0001');
    });

    test('an old square whose refresh fails keeps its parks', () async {
      store.saved['KO02'] =
          StoredSquare([park('PL-0001')], clock.subtract(const Duration(hours: 5)));
      notifier().ensureSquares(['KO02']);
      await settle();
      fake.fail('KO02');
      await settle();
      expect(state().parksIn(['KO02']).single.reference, 'PL-0001');
      expect(state().failedIn(['KO02']), ['KO02']);
    });

    test('a store that fails is the same as an empty one', () async {
      store.failReads = true;
      notifier().ensureSquares(['KO02']);
      await settle();
      expect(fake.asked, ['KO02']);
      fake.answer('KO02', [park('PL-0001')]);
      await settle();
      expect(state().parksIn(['KO02']), hasLength(1));
    });

    test('many squares from the device cost no requests and are all there',
        () async {
      final squares = ['AA00', 'AA01', 'AA02', 'AA03', 'AA04', 'AA05', 'AA06', 'AA07', 'AA08', 'AA09'];
      for (final s in squares) {
        store.saved[s] = StoredSquare([park('X-$s')], clock);
      }
      notifier().ensureSquares(squares);
      await settle();
      await settle();
      expect(fake.asked, isEmpty);
      expect(state().parksIn(squares), hasLength(10));
    });
  });

  test('a view of many squares is asked for with many requests at once',
      () async {
    final squares = [for (var i = 0; i < 16; i++) 'AB${i.toString().padLeft(2, '0')}'];
    notifier().ensureSquares(squares);
    await settle();
    expect(fake.asked, hasLength(kParkLoadsAtOnce));
    expect(kParkLoadsAtOnce, greaterThanOrEqualTo(6));
  });

  group('parks the operator has been to', () {
    QsoModel qso({int station = 1, String? myPota}) => QsoModel(
          callsign: 'SP1ABC',
          dateTimeOn: DateTime.utc(2026, 11, 1),
          band: '40m',
          mode: 'SSB',
          rstSent: '59',
          rstRcvd: '59',
          stationProfileId: station,
          rawAdif: {if (myPota != null) 'MY_POTA_REF': myPota},
        );

    ProviderContainer containerWith(
        {required Future<List<QsoModel>> log,
        required Future<List<StationModel>> stations}) {
      final c = ProviderContainer(overrides: [
        qsoProvider.overrideWith(() => _Qsos(log)),
        stationProvider.overrideWith(() => _Stations(stations)),
      ]);
      addTearDown(c.dispose);
      c.listen(activatedParksProvider, (_, __) {});
      return c;
    }

    test('from the QSO itself or from its station location, with one QSO '
        'enough', () async {
      final c = containerWith(
        log: Future.value([
          qso(myPota: 'pl-0001'),
          qso(station: 2), // no MY_POTA_REF: the location's park
          qso(station: 3), // a location without a park
        ]),
        stations: Future.value(const [
          StationModel(id: 2, profileName: 'Park', callsign: 'SP1ABC', pota: 'PL-0342'),
          StationModel(id: 3, profileName: 'Home', callsign: 'SP1ABC'),
        ]),
      );
      await c.read(qsoProvider.future);
      await c.read(stationProvider.future);
      expect(c.read(activatedParksProvider), {'PL-0001', 'PL-0342'});
    });

    test('unknown, not empty, while the log is loading', () async {
      final log = Completer<List<QsoModel>>();
      final c = containerWith(log: log.future, stations: Future.value(const []));
      expect(c.read(activatedParksProvider), isNull);
      log.complete([qso(myPota: 'PL-0001')]);
      await c.read(qsoProvider.future);
      await c.read(stationProvider.future);
      expect(c.read(activatedParksProvider), {'PL-0001'});
    });

    test('a station list that failed still gives the parks of the QSOs',
        () async {
      final c = containerWith(
        log: Future.value([qso(myPota: 'PL-0001'), qso(station: 2)]),
        stations: Future.error(Exception('offline')),
      );
      await c.read(qsoProvider.future);
      await expectLater(c.read(stationProvider.future), throwsException);
      expect(c.read(activatedParksProvider), {'PL-0001'});
    });
  });
}

class _Qsos extends QsoNotifier {
  final Future<List<QsoModel>> log;
  _Qsos(this.log);
  @override
  Future<List<QsoModel>> build() => log;
}

class _Stations extends StationNotifier {
  final Future<List<StationModel>> stations;
  _Stations(this.stations);
  @override
  Future<List<StationModel>> build() => stations;
}

class FakeStore implements PotaSquaresStore {
  final saved = <String, StoredSquare>{};
  var failReads = false;

  @override
  Future<StoredSquare?> read(String square) async {
    if (failReads) throw Exception('disk');
    return saved[square];
  }

  @override
  Future<void> write(String square, List<PotaParkPoint> parks, DateTime at) async {
    saved[square] = StoredSquare(parks, at);
  }
}
