import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/data/models/dx_spot_model.dart';
import 'package:wavelog_mobile/data/models/pota_spot_model.dart';
import 'package:wavelog_mobile/providers/dx_spot_provider.dart';
import 'package:wavelog_mobile/providers/pota_spot_provider.dart';

DxSpotModel dx(String call, String mode) => DxSpotModel(
      dxCall: call,
      spotter: 'SP4BL',
      frequency: '14200',
      band: '20m',
      mode: mode,
      info: '',
      time: DateTime.utc(2026, 11, 3),
    );

PotaSpotModel pota(String call, int minute) => PotaSpotModel(
      spotId: minute,
      spotTime: DateTime.utc(2026, 11, 3, 0, minute),
      activator: call,
      frequency: '14250',
      mode: 'SSB',
      reference: 'US-0001',
      spotter: 'SP4BL',
      source: 'Web',
      comments: '',
      parkName: '',
      locationDesc: '',
    );

void main() {
  test('the SSB mode filter finds USB and LSB spots', () async {
    final c = ProviderContainer(overrides: [
      dxSpotsProvider.overrideWith((_) async =>
          [dx('A1', 'USB'), dx('B2', 'LSB'), dx('C3', 'CW'), dx('D4', 'SSB')]),
    ]);
    addTearDown(c.dispose);
    await c.read(dxSpotsProvider.future);

    c.read(dxSpotFilterProvider.notifier).state =
        const DxSpotFilter(mode: 'SSB');
    expect(c.read(filteredDxSpotsProvider).value!.map((s) => s.dxCall),
        ['A1', 'B2', 'D4']);
  });

  test('POTA spots are sorted by time, whatever order the API gives',
      () async {
    final c = ProviderContainer(overrides: [
      potaSpotsProvider.overrideWith(
          (_) async => [pota('B2', 20), pota('A1', 10), pota('C3', 30)]),
    ]);
    addTearDown(c.dispose);
    await c.read(potaSpotsProvider.future);

    List<String> calls() =>
        c.read(filteredPotaSpotsProvider).value!.map((s) => s.activator).toList();
    expect(calls(), ['C3', 'B2', 'A1']);

    c.read(potaSpotFilterProvider.notifier).state =
        const PotaSpotFilter(newestFirst: false);
    expect(calls(), ['A1', 'B2', 'C3']);
  });
}
