import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/providers/pota_location_provider.dart';

class FakeLocation implements PotaLocationService {
  PotaLocationFix? last;
  PotaLocation fresh = const PotaLocationDenied();
  final asked = <bool>[];

  @override
  Future<PotaLocationFix?> lastKnown() async => last;

  @override
  Future<PotaLocation> locate({required bool askPermission}) async {
    asked.add(askPermission);
    return fresh;
  }

  @override
  Future<void> openAppSettings() async {}
  @override
  Future<void> openLocationSettings() async {}
}

void main() {
  test('the last known position comes first, then the fresh one', () async {
    final s = FakeLocation()
      ..last = const PotaLocationFix(1, 2)
      ..fresh = const PotaLocationFix(3, 4);
    final got = await openingPositions(s).toList();
    expect(got.map((f) => (f.lat, f.lon)), [(1.0, 2.0), (3.0, 4.0)]);
  });

  test('opening the map never asks for the permission', () async {
    final s = FakeLocation()..fresh = const PotaLocationDenied();
    expect(await openingPositions(s).toList(), isEmpty);
    expect(s.asked, [false]);
  });

  test('without a fresh position the last known one stands', () async {
    for (final fresh in <PotaLocation>[
      const PotaLocationFailed(),
      const PotaLocationServiceOff(),
      const PotaLocationDenied(forever: true),
    ]) {
      final s = FakeLocation()
        ..last = const PotaLocationFix(1, 2)
        ..fresh = fresh;
      final got = await openingPositions(s).toList();
      expect(got, hasLength(1), reason: '$fresh');
    }
  });

  test('a fresh position alone is enough', () async {
    final s = FakeLocation()..fresh = const PotaLocationFix(3, 4);
    expect(await openingPositions(s).toList(), hasLength(1));
  });
}
