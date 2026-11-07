import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    ]);
    container.listen(potaParksProvider, (_, __) {});
    addTearDown(container.dispose);
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

  test('at most three squares load at once; a finished one frees a place',
      () async {
    final six = ['AA00', 'AA01', 'AA02', 'AA03', 'AA04', 'AA05'];
    notifier().ensureSquares(six);
    expect(fake.asked, six.take(3));
    expect(state().loading, six.take(3).toSet());

    fake.answer('AA00', []);
    await settle();
    expect(fake.asked, six.take(4));

    for (final s in six.skip(1).take(3)) {
      fake.answer(s, []);
      await settle();
    }
    fake.answer('AA04', []);
    fake.answer('AA05', []);
    await settle();
    expect(fake.mostAtOnce, 3);
    expect(state().loading, isEmpty);
    expect(state().squares.values.every((e) => e.loaded), isTrue);
  });

  test('squares the map has moved away from are dropped from the queue',
      () async {
    notifier().ensureSquares(['AA00', 'AA01', 'AA02', 'AA03', 'AA04']);
    // The map moved: only AA01 and a new square are wanted now
    notifier().ensureSquares(['AA01', 'BB00']);
    fake.answer('AA00', []);
    fake.answer('AA01', []);
    fake.answer('AA02', []);
    await settle();
    // AA03 and AA04 were waiting and are no longer wanted; BB00 is next
    expect(fake.asked, ['AA00', 'AA01', 'AA02', 'BB00']);
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
    ]);
    other.listen(potaParksProvider, (_, __) {});
    other.read(potaParksProvider.notifier).ensureSquares(['KO02']);
    other.dispose();
    fake.answer('KO02', [park('PL-0001')]);
    await settle(); // must not throw
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
