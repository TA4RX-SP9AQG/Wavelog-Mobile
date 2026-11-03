import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/data/models/dx_spot_model.dart';
import 'package:wavelog_mobile/providers/dx_spot_provider.dart';

DxSpotModel spot(String call, String band) => DxSpotModel(
      dxCall: call,
      spotter: 'SP4BL',
      frequency: '14200',
      band: band,
      mode: 'SSB',
      info: '',
      time: DateTime.utc(2026, 10, 26, 18),
    );

void main() {
  final spots = [spot('A1', '20m'), spot('B2', '40m'), spot('C3', '15m')];

  test('several bands can be shown at once', () async {
    final c = ProviderContainer(overrides: [
      dxSpotsProvider.overrideWith((_) async => spots),
    ]);
    addTearDown(c.dispose);
    await c.read(dxSpotsProvider.future);

    c.read(dxSpotFilterProvider.notifier).state =
        const DxSpotFilter(bands: {'20m', '40m'});
    expect(c.read(filteredDxSpotsProvider).value!.map((s) => s.dxCall),
        ['A1', 'B2']);

    c.read(dxSpotFilterProvider.notifier).state = const DxSpotFilter();
    expect(c.read(filteredDxSpotsProvider).value, hasLength(3));
    expect(const DxSpotFilter().hasFilters, isFalse);
    expect(const DxSpotFilter(bands: {'20m'}).hasFilters, isTrue);
  });

  test('copyWith keeps the bands unless given', () {
    const f = DxSpotFilter(bands: {'20m'});
    expect(f.copyWith(mode: 'CW').bands, {'20m'});
    expect(f.copyWith(bands: const {}).bands, isEmpty);
  });
}
