import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:wavelog_mobile/core/utils/map_geo.dart';

/// Whether [p] is inside [polygon] (ray casting, flat lat/lon).
bool inside(List<LatLng> polygon, LatLng p) {
  var c = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i], b = polygon[j];
    if ((a.latitude > p.latitude) != (b.latitude > p.latitude) &&
        p.longitude <
            (b.longitude - a.longitude) *
                    (p.latitude - a.latitude) /
                    (b.latitude - a.latitude) +
                a.longitude) {
      c = !c;
    }
  }
  return c;
}

void main() {
  group('greatCircle', () {
    test('starts and ends at the two stations', () {
      const lomza = LatLng(53.19, 22.04), crete = LatLng(35.4, 25.2);
      final runs = greatCircle(lomza, crete);
      expect(runs, hasLength(1));
      expect(runs.first.first.latitude, closeTo(53.19, 1e-6));
      expect(runs.first.last.longitude, closeTo(25.2, 1e-6));
    });

    test('Europe to Japan bends north, as a great circle does', () {
      final run = greatCircle(const LatLng(52, 21), const LatLng(35.7, 139.7)).first;
      final top = run.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
      expect(top, greaterThan(60));
    });

    test('a path over the antimeridian is split, not drawn across the map', () {
      final runs = greatCircle(const LatLng(35.7, 139.7), const LatLng(37.8, -122.4));
      expect(runs.length, 2);
      for (final run in runs) {
        for (var i = 1; i < run.length; i++) {
          expect((run[i].longitude - run[i - 1].longitude).abs(), lessThan(180));
        }
      }
    });
  });

  group('nightPolygon', () {
    test('June solstice, 12 UTC: day over Europe and Africa, night over the Pacific',
        () {
      final night = nightPolygon(DateTime.utc(2026, 6, 21, 12));
      expect(inside(night, const LatLng(0, 0)), isFalse);
      expect(inside(night, const LatLng(52, 21)), isFalse);
      expect(inside(night, const LatLng(0, 179)), isTrue);
      // Midnight sun in the Arctic, polar night in the Antarctic.
      expect(inside(night, const LatLng(80, 179)), isFalse);
      expect(inside(night, const LatLng(-80, 0)), isTrue);
    });

    test('December solstice, 0 UTC: night over Europe', () {
      final night = nightPolygon(DateTime.utc(2026, 12, 21, 0));
      expect(inside(night, const LatLng(52, 21)), isTrue);
      expect(inside(night, const LatLng(-80, 0)), isFalse);
    });
  });
}
