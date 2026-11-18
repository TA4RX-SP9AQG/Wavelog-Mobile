import 'dart:math';

/// The park map asks pota.app for whole 4-character Maidenhead squares
/// (2 degrees of longitude by 1 of latitude), so the squares a map view
/// touches are what is loaded, cached and retried.

final _squarePattern = RegExp(r'^[A-R]{2}[0-9]{2}$');

/// Most squares one view may touch before the map asks to zoom in. A phone
/// screen at zoom 6 and up stays well below it.
const kMaxParkSquares = 16;

// Just inside the poles and the date line, which belong to no square.
const _maxLat = 90 - 1e-9;
const _maxLon = 180 - 1e-9;

/// The 4-character square ("KO02") that holds the point. Points on the poles
/// and the date line are taken into the last square.
String gridSquare4(double lat, double lon) =>
    _squareId(_lonIndex(lon), _latIndex(lat));

int _lonIndex(double lon) =>
    ((lon.clamp(-180.0, _maxLon) + 180) / 2).floor();

int _latIndex(double lat) => (lat.clamp(-90.0, _maxLat) + 90).floor();

String _squareId(int lonIndex, int latIndex) =>
    '${String.fromCharCode(65 + lonIndex ~/ 10)}'
    '${String.fromCharCode(65 + latIndex ~/ 10)}'
    '${lonIndex % 10}${latIndex % 10}';

({int lon, int lat}) _indexes(String grid4) {
  final g = grid4.toUpperCase();
  if (!_squarePattern.hasMatch(g)) {
    throw ArgumentError.value(grid4, 'grid4', 'not a 4-character square');
  }
  return (
    lon: (g.codeUnitAt(0) - 65) * 10 + (g.codeUnitAt(2) - 48),
    lat: (g.codeUnitAt(1) - 65) * 10 + (g.codeUnitAt(3) - 48),
  );
}

/// The edges of a square, in degrees.
typedef GeoBox = ({double south, double west, double north, double east});

GeoBox squareBounds(String grid4) {
  final i = _indexes(grid4);
  final west = i.lon * 2.0 - 180;
  final south = i.lat * 1.0 - 90;
  return (south: south, west: west, north: south + 1, east: west + 2);
}

({double lat, double lon}) squareCentre(String grid4) {
  final b = squareBounds(grid4);
  return (lat: (b.south + b.north) / 2, lon: (b.west + b.east) / 2);
}

/// The squares a view touches, nearest to [near] first (else to the view's
/// own centre). A view that crosses the date line has [west] > [east]. A view
/// of more than [maxSquares] squares is `tooMany` and lists none: the map
/// does not draw parks then.
({List<String> squares, bool tooMany}) squaresCovering({
  required double south,
  required double west,
  required double north,
  required double east,
  ({double lat, double lon})? near,
  int maxSquares = kMaxParkSquares,
}) {
  // An edge on a square's border does not reach into the next square.
  int last(double edge, int first, double origin, double size, int max) =>
      (((edge - origin) / size).ceil() - 1).clamp(first, max);

  final latFirst = _latIndex(south);
  final latLast = last(north.clamp(-90.0, _maxLat), latFirst, -90, 1, 179);

  // One or two longitude runs, as (first index, last index).
  List<(int, int)> runs() {
    int lonLast(double e, int first) =>
        last(e.clamp(-180.0, _maxLon), first, -180, 2, 179);
    if (west <= east) {
      final first = _lonIndex(west);
      return [(first, lonLast(east, first))];
    }
    final first = _lonIndex(west);
    return [(first, 179), (0, lonLast(east, 0))];
  }

  final lonRuns = runs();
  final lonCount = lonRuns.fold<int>(0, (n, r) => n + r.$2 - r.$1 + 1);
  final count = lonCount * (latLast - latFirst + 1);
  if (count > maxSquares) return (squares: const <String>[], tooMany: true);

  final from = near ??
      (
        lat: (south + north) / 2,
        lon: west <= east ? (west + east) / 2 : (west + east + 360) / 2 - 360,
      );
  final cosLat = cos(from.lat * pi / 180);
  double distance(String s) {
    final c = squareCentre(s);
    var dLon = (c.lon - from.lon).abs();
    if (dLon > 180) dLon = 360 - dLon;
    final dx = dLon * cosLat;
    final dy = c.lat - from.lat;
    return dx * dx + dy * dy;
  }

  final squares = <String>{
    for (final (first, lastLon) in lonRuns)
      for (var lat = latFirst; lat <= latLast; lat++)
        for (var lon = first; lon <= lastLon; lon++) _squareId(lon, lat),
  }.toList()
    ..sort((a, b) => distance(a).compareTo(distance(b)));
  return (squares: squares, tooMany: false);
}

/// What the logbook says about a park, from the most to the least
/// interesting to the operator.
enum PotaParkStatus {
  /// A QSO was logged from this park by me.
  activated,

  /// I worked this park from elsewhere.
  hunted,

  /// Nobody has activated it yet, per pota.app.
  neverActivated,

  /// None of the above.
  other,
}

/// Every status that applies to [ref], most important first. [activated] and
/// [hunted] are null while the log is loading: the park is then judged by
/// pota.app's own flag alone, never as activated or hunted.
List<PotaParkStatus> parkStatuses({
  required String ref,
  required bool neverActivated,
  required Set<String>? activated,
  required Set<String>? hunted,
}) {
  final r = ref.toUpperCase();
  final all = [
    if (activated?.contains(r) ?? false) PotaParkStatus.activated,
    if (hunted?.contains(r) ?? false) PotaParkStatus.hunted,
    if (neverActivated) PotaParkStatus.neverActivated,
  ];
  return all.isEmpty ? const [PotaParkStatus.other] : all;
}

/// The one status a park is drawn with: the first of [parkStatuses].
PotaParkStatus parkStatus({
  required String ref,
  required bool neverActivated,
  required Set<String>? activated,
  required Set<String>? hunted,
}) =>
    parkStatuses(
      ref: ref,
      neverActivated: neverActivated,
      activated: activated,
      hunted: hunted,
    ).first;

/// The eight compass points, as a bearing falls among them.
enum CompassPoint { n, ne, e, se, s, sw, w, nw }

/// The compass point of a bearing in degrees (0 = north).
CompassPoint compassPoint(double azimuth) {
  final a = ((azimuth % 360) + 360) % 360;
  return CompassPoint.values[((a + 22.5) ~/ 45) % 8];
}

// ── Links ─────────────────────────────────────────────────────────────────────

String _coord(double v) => v.toStringAsFixed(5);

/// A `geo:` link that opens a maps app on the park, with its name as the pin
/// label.
Uri parkGeoUri(double lat, double lon, String name) {
  // Brackets would end the pin label early.
  final label = name.replaceAll(RegExp(r'[()]'), ' ').trim();
  final at = '${_coord(lat)},${_coord(lon)}';
  return Uri.parse(
      'geo:$at?q=$at${label.isEmpty ? '' : '(${Uri.encodeComponent(label)})'}');
}

/// For a phone without a maps app: the same spot on openstreetmap.org.
Uri parkOsmUri(double lat, double lon) => Uri.parse(
    'https://www.openstreetmap.org/?mlat=${_coord(lat)}&mlon=${_coord(lon)}'
    '#map=15/${_coord(lat)}/${_coord(lon)}');

/// The park's page on pota.app.
Uri parkWebUri(String reference) => Uri.parse(
    'https://pota.app/#/park/${Uri.encodeComponent(reference.toUpperCase())}');

/// The coordinates as typed into a maps search: "52.00880, 21.98430".
String parkCoordinates(double lat, double lon) =>
    '${_coord(lat)}, ${_coord(lon)}';
