import 'dart:math';

import 'package:latlong2/latlong.dart';

const _rad = pi / 180;

/// The latitude where a Web Mercator map ends.
const kWebMercatorMaxLat = 85.05112878;
const _deg = 180 / pi;

/// The great-circle path from [a] to [b] as [segments] + 1 points, split
/// into separate runs where it crosses the antimeridian, so a flat map draws
/// it without a line across the whole world.
List<List<LatLng>> greatCircle(LatLng a, LatLng b, {int segments = 48}) {
  final lat1 = a.latitude * _rad, lon1 = a.longitude * _rad;
  final lat2 = b.latitude * _rad, lon2 = b.longitude * _rad;
  final d = 2 *
      asin(sqrt(pow(sin((lat2 - lat1) / 2), 2) +
          cos(lat1) * cos(lat2) * pow(sin((lon2 - lon1) / 2), 2)));
  if (d < 1e-9) return [[a, b]];

  final runs = <List<LatLng>>[[]];
  double? prevLon;
  for (var i = 0; i <= segments; i++) {
    final f = i / segments;
    final p = sin((1 - f) * d) / sin(d);
    final q = sin(f * d) / sin(d);
    final x = p * cos(lat1) * cos(lon1) + q * cos(lat2) * cos(lon2);
    final y = p * cos(lat1) * sin(lon1) + q * cos(lat2) * sin(lon2);
    final z = p * sin(lat1) + q * sin(lat2);
    final lat = atan2(z, sqrt(x * x + y * y)) * _deg;
    final lon = atan2(y, x) * _deg;
    if (prevLon != null && (lon - prevLon).abs() > 180) runs.add([]);
    runs.last.add(LatLng(lat, lon));
    prevLon = lon;
  }
  return runs.where((r) => r.length > 1).toList();
}

/// The night side of the Earth at [utc], as a polygon for a flat map: the
/// day/night terminator from 180° W to 180° E, closed over the pole that is
/// in darkness. The band along its edge is the greyline.
List<LatLng> nightPolygon(DateTime utc, {double step = 2}) {
  final t = utc.toUtc();
  // Days since J2000.0, enough for a terminator drawn on a world map.
  final n = t.difference(DateTime.utc(2000, 1, 1, 12)).inSeconds / 86400.0;
  final meanLon = (280.460 + 0.9856474 * n) % 360;
  final g = ((357.528 + 0.9856003 * n) % 360) * _rad;
  final eclLon = (meanLon + 1.915 * sin(g) + 0.020 * sin(2 * g)) * _rad;
  final obliquity = (23.439 - 0.0000004 * n) * _rad;
  final decl = asin(sin(obliquity) * sin(eclLon));
  final ra = atan2(cos(obliquity) * sin(eclLon), cos(eclLon));
  // Greenwich hour angle of the sun.
  final gmst = (280.46061837 + 360.98564736629 * n) % 360;
  final gha = gmst - ra * _deg;

  // At the equinoxes the terminator runs through the poles; nudge the
  // declination so the formula below stays finite.
  final dec = decl.abs() < 1e-6 ? 1e-6 : decl;
  final points = <LatLng>[];
  for (var lon = -180.0; lon <= 180.0; lon += step) {
    final ha = (gha + lon) * _rad;
    final lat = atan(-cos(ha) / tan(dec)) * _deg;
    points.add(LatLng(lat, lon));
  }
  // The pole away from the sun is the dark one. Closed at the web map's
  // edge (85.05°), not at 90°: Web Mercator puts the pole at infinity.
  final darkPole = dec > 0 ? -kWebMercatorMaxLat : kWebMercatorMaxLat;
  return [
    ...points,
    LatLng(darkPole, 180),
    LatLng(darkPole, -180),
  ];
}
