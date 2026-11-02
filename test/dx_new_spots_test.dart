import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/data/datasources/remote/dx_cluster_datasource.dart';
import 'package:wavelog_mobile/data/models/dx_spot_model.dart';
import 'package:wavelog_mobile/providers/connectivity_provider.dart';
import 'package:wavelog_mobile/providers/dx_spot_provider.dart';

/// Returns the next scripted answer on each call; null stands for a failed
/// fetch (no connection).
class _ScriptedDatasource extends DxClusterDatasource {
  final List<List<DxSpotModel>?> answers;
  int _i = 0;

  _ScriptedDatasource(this.answers);

  @override
  Future<List<DxSpotModel>> getSpots({int limit = 200}) async =>
      answers[_i++] ?? (throw Exception('no connection'));
}

DxSpotModel spot(String call, {required int minutesAgo}) => DxSpotModel(
      dxCall: call,
      spotter: 'SP4BL',
      frequency: '14200',
      band: '20m',
      mode: 'SSB',
      info: '',
      time: DateTime.now().toUtc().subtract(Duration(minutes: minutesAgo)),
    );

/// What the system reports about the network in these tests.
final _online = StateProvider<bool>((_) => true);

ProviderContainer _container(List<List<DxSpotModel>?> answers) {
  final c = ProviderContainer(overrides: [
    dxDatasourceProvider.overrideWithValue(_ScriptedDatasource(answers)),
    isOnlineProvider.overrideWith((ref) => ref.watch(_online)),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<List<String>> _refresh(ProviderContainer c) async {
  c.invalidate(dxSpotsProvider);
  return (await c.read(dxSpotsProvider.future)).map((s) => s.dxCall).toList();
}

void main() {
  test('spots that arrive with an update are marked new', () async {
    final first = [spot('A1', minutesAgo: 2), spot('B2', minutesAgo: 3)];
    final second = [spot('C3', minutesAgo: 1), ...first];
    final c = _container([first, second, second]);
    Set<String> newCalls() => c
        .read(dxSpotsProvider)
        .value!
        .where((s) => c.read(dxNewSpotKeysProvider).contains(dxSpotKey(s)))
        .map((s) => s.dxCall)
        .toSet();

    await c.read(dxSpotsProvider.future);
    expect(newCalls(), isEmpty, reason: 'nothing to compare the first list with');

    await _refresh(c);
    expect(newCalls(), {'C3'});

    // An unchanged list (e.g. the datasource's cached answer) keeps them.
    await _refresh(c);
    expect(newCalls(), {'C3'});
  });

  test('a failed refresh keeps the last spots within the hour and says so',
      () async {
    final first = [spot('A1', minutesAgo: 5), spot('OLD1', minutesAgo: 61)];
    final c = _container([first, null, [spot('B2', minutesAgo: 0)]]);

    await c.read(dxSpotsProvider.future);
    expect(c.read(dxStaleSinceProvider), isNull);

    expect(await _refresh(c), ['A1']);
    expect(c.read(dxStaleSinceProvider), isNotNull);

    expect(await _refresh(c), ['B2']);
    expect(c.read(dxStaleSinceProvider), isNull);
  });

  test('the system reporting no network marks the list stale at once',
      () async {
    final c = _container([[spot('A1', minutesAgo: 5)]]);
    await c.read(dxSpotsProvider.future);
    expect(c.read(dxStaleSinceProvider), isNull);

    c.read(_online.notifier).state = false;
    expect(c.read(dxStaleSinceProvider), isNotNull);

    c.read(_online.notifier).state = true;
    expect(c.read(dxStaleSinceProvider), isNull);
  });

  test('a failure with nothing fetched yet is reported', () async {
    final c = _container([null]);
    await expectLater(c.read(dxSpotsProvider.future), throwsException);
    expect(c.read(dxStaleSinceProvider), isNull);
  });
}
