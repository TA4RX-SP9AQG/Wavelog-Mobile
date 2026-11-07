typedef GeoPoint = ({double lat, double lon});

/// One piece of a park's outline: an outer ring and the holes in it.
class ParkArea {
  final List<GeoPoint> outer;
  final List<List<GeoPoint>> holes;
  const ParkArea(this.outer, [this.holes = const []]);

  /// Whether the point is inside the outer ring and in none of the holes.
  bool contains(double lat, double lon) =>
      _inRing(outer, lat, lon) && !holes.any((h) => _inRing(h, lat, lon));
}

/// Where an outline comes from.
enum BoundarySource {
  /// OpenStreetMap: drawn by volunteers.
  osm,

  /// USGS PAD-US: the protected lands of the United States, as the agencies
  /// that manage them report them.
  padus,
}

/// A park's outline, from [source]. An approximation: it says where the park
/// is mapped, not where its rules apply.
class ParkBoundary {
  final List<ParkArea> areas;
  final BoundarySource source;

  /// The name and kind the outline carries in OpenStreetMap.
  final String name;
  final String kind;
  const ParkBoundary({
    required this.areas,
    this.name = '',
    this.kind = '',
    this.source = BoundarySource.osm,
  });

  bool contains(double lat, double lon) =>
      areas.any((a) => a.contains(lat, lon));

  /// The box around the whole outline.
  ({double south, double west, double north, double east}) get bounds {
    var south = 90.0, north = -90.0, west = 180.0, east = -180.0;
    for (final a in areas) {
      for (final p in a.outer) {
        if (p.lat < south) south = p.lat;
        if (p.lat > north) north = p.lat;
        if (p.lon < west) west = p.lon;
        if (p.lon > east) east = p.lon;
      }
    }
    return (south: south, west: west, north: north, east: east);
  }

  /// The area of [bounds], in square degrees: only to tell a small outline
  /// from a large one.
  double get boxArea {
    final b = bounds;
    return (b.north - b.south) * (b.east - b.west);
  }

  /// A Nominatim result with a GeoJSON polygon, or null when it has none that
  /// can be used.
  static ParkBoundary? tryParse(Object? result,
      {BoundarySource source = BoundarySource.osm}) {
    if (result is! Map) return null;
    final geo = result['geojson'];
    if (geo is! Map) return null;
    final coords = geo['coordinates'];
    if (coords is! List) return null;
    final areas = <ParkArea>[];
    switch (geo['type']) {
      case 'Polygon':
        final a = _area(coords);
        if (a != null) areas.add(a);
      case 'MultiPolygon':
        for (final polygon in coords) {
          if (polygon is! List) continue;
          final a = _area(polygon);
          if (a != null) areas.add(a);
        }
      default:
        return null;
    }
    if (areas.isEmpty) return null;
    return ParkBoundary(
      areas: areas,
      name: (result['name'] ?? result['display_name'] ?? '').toString(),
      kind: '${result['category'] ?? ''}:${result['type'] ?? ''}',
      source: source,
    );
  }

  /// A GeoJSON feature of the PAD-US service: its geometry, the unit name,
  /// and the kind of land it is (a refuge, a state park).
  static ParkBoundary? fromPadus(Object? feature) {
    if (feature is! Map) return null;
    final props = feature['properties'];
    if (props is! Map) return null;
    return tryParse({
      'geojson': feature['geometry'],
      'name': props['Unit_Nm'],
      'category': 'padus',
      'type': props['DesTp_Desc'] ?? props['Category'] ?? '',
    }, source: BoundarySource.padus);
  }

  static ParkArea? _area(List rings) {
    final parsed = [
      for (final r in rings)
        if (_ring(r) case final ring?) ring,
    ];
    if (parsed.isEmpty) return null;
    return ParkArea(parsed.first, parsed.skip(1).toList());
  }

  /// A GeoJSON ring: [lon, lat] pairs, at least three distinct points.
  static List<GeoPoint>? _ring(Object? ring) {
    if (ring is! List || ring.length < 4) return null;
    final points = <GeoPoint>[];
    for (final p in ring) {
      if (p is! List || p.length < 2) return null;
      final lon = p[0], lat = p[1];
      if (lon is! num || lat is! num) return null;
      if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
      points.add((lat: lat.toDouble(), lon: lon.toDouble()));
    }
    return points;
  }
}

/// Ray casting: a point is inside when a ray from it crosses the ring an odd
/// number of times.
bool _inRing(List<GeoPoint> ring, double lat, double lon) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i], b = ring[j];
    if ((a.lat > lat) != (b.lat > lat) &&
        lon < (b.lon - a.lon) * (lat - a.lat) / (b.lat - a.lat) + a.lon) {
      inside = !inside;
    }
  }
  return inside;
}

/// Kinds of OpenStreetMap feature that are a park or reserve; anything else
/// that shares the name (a station, a street) is not an outline we want.
const _parkKinds = {
  'boundary:protected_area',
  'boundary:national_park',
  'leisure:nature_reserve',
  'leisure:park',
  'leisure:recreation_ground',
  'landuse:forest',
  'landuse:conservation',
};

/// The outline that best fits a park among the [results] of a name search:
/// a park-like feature with a name that shares at least half the park's
/// distinctive words and that contains the park's own position (or, failing
/// that, has a box around it that does and a name that is nearly the same),
/// the closest in name, then the smallest. A park that only happens to lie
/// around the position, under another name, is not taken: a wrong outline is
/// worse than none. Null when none qualifies.
ParkBoundary? pickBoundary(
  Iterable<Object?> results, {
  required String name,
  required double lat,
  required double lon,
  bool mustHoldPosition = true,
}) {
  final wanted = _words(name);
  final scored = <(ParkBoundary, double)>[];
  for (final r in results) {
    final b = r is ParkBoundary ? r : ParkBoundary.tryParse(r);
    if (b == null) continue;
    // PAD-US lists only protected land; in OpenStreetMap the name alone does
    // not say that a feature is a park
    if (b.source == BoundarySource.osm && !_parkKinds.contains(b.kind)) continue;
    final similarity = _similarity(wanted, _words(b.name));
    if (similarity < _minSimilarity) continue;
    // The search was already for what lies at the park, so a name that fits
    // is enough; elsewhere the outline must hold the park's position
    if (!mustHoldPosition || b.contains(lat, lon)) {
      scored.add((b, similarity));
      continue;
    }
    final box = b.bounds;
    final inBox = lat >= box.south &&
        lat <= box.north &&
        lon >= box.west &&
        lon <= box.east;
    if (inBox && similarity >= _minSimilarityBoxOnly) scored.add((b, similarity));
  }
  if (scored.isEmpty) return null;
  scored.sort((a, b) {
    final bySimilarity = b.$2.compareTo(a.$2);
    return bySimilarity != 0 ? bySimilarity : a.$1.boxArea.compareTo(b.$1.boxArea);
  });
  return scored.first.$1;
}

/// Share of the park's distinctive words its outline's name must have.
const _minSimilarity = 0.5;
const _minSimilarityBoxOnly = 0.8;

/// Words that say what a place is, not which: left out of the comparison, so
/// that "Mount Eagle State Park" and "Pine State Park" do not look alike.
const _generic = {
  'nature', 'reserve', 'national', 'park', 'state', 'forest', 'wildlife',
  'refuge', 'area', 'conservation', 'landscape', 'natura', 'management',
  'recreation', 'regional', 'county', 'city', 'trail', 'preserve', 'sanctuary',
  'memorial', 'historic', 'site', 'monument', 'the', 'and',
};

Set<String> _words(String s) => {
      for (final w in s.toLowerCase().split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)))
        if (w.length >= 3) w,
    };

/// The share of the wanted words that the other name has too, not counting
/// the generic ones (unless the name has nothing else).
double _similarity(Set<String> wanted, Set<String> other) {
  final distinctive = wanted.difference(_generic);
  final words = distinctive.isEmpty ? wanted : distinctive;
  return words.isEmpty ? 0 : words.intersection(other).length / words.length;
}
