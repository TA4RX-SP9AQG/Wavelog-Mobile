import '../../core/utils/pota_activity.dart';

/// One park as pota.app lists it for a map square: enough to draw it and to
/// open its card. Built only from a well-formed feature, see [tryParse].
class PotaParkPoint {
  final String reference;
  final String name;
  final double lat;
  final double lon;

  /// Nobody has activated it yet.
  final bool neverActivated;

  const PotaParkPoint({
    required this.reference,
    required this.name,
    required this.lat,
    required this.lon,
    this.neverActivated = false,
  });

  /// A GeoJSON feature of `/park/grids`, or null when it cannot be used: no
  /// valid reference, no position, or a position of 0,0 (parks without
  /// coordinates are stored there).
  static PotaParkPoint? tryParse(Object? feature) {
    if (feature is! Map) return null;
    final props = feature['properties'];
    final geometry = feature['geometry'];
    if (props is! Map || geometry is! Map) return null;

    final ref = props['reference']?.toString().trim().toUpperCase() ?? '';
    if (!potaRefPattern.hasMatch(ref)) return null;

    final coords = geometry['coordinates'];
    if (coords is! List || coords.length < 2) return null;
    final lon = coords[0];
    final lat = coords[1];
    if (lon is! num || lat is! num) return null;
    if (!_validPosition(lat.toDouble(), lon.toDouble())) return null;

    final name = props['name']?.toString().trim() ?? '';
    final atno = props['atno'];
    return PotaParkPoint(
      reference: ref,
      name: name.isEmpty ? ref : name,
      lat: lat.toDouble(),
      lon: lon.toDouble(),
      neverActivated: atno == true || atno == 1,
    );
  }
}

bool _validPosition(double lat, double lon) =>
    lat >= -90 &&
    lat <= 90 &&
    lon >= -180 &&
    lon <= 180 &&
    !(lat == 0 && lon == 0);

/// What `/park/{reference}` tells about a park.
class PotaParkDetail {
  final String reference;
  final String name;
  final double? lat;
  final double? lon;
  final String grid6;

  /// "National Park", "Nature Reserve"...
  final String type;

  /// "PL-MZ" and "Mazowieckie".
  final String locationDesc;
  final String locationName;
  final String country;
  final String firstActivator;
  final DateTime? firstActivationDate;
  final String website;

  const PotaParkDetail({
    required this.reference,
    required this.name,
    this.lat,
    this.lon,
    this.grid6 = '',
    this.type = '',
    this.locationDesc = '',
    this.locationName = '',
    this.country = '',
    this.firstActivator = '',
    this.firstActivationDate,
    this.website = '',
  });

  /// Null when the body is not a park.
  static PotaParkDetail? tryParse(Object? json) {
    if (json is! Map) return null;
    final ref = _text(json['reference']).toUpperCase();
    if (ref.isEmpty) return null;
    final rawLat = json['latitude'];
    final rawLon = json['longitude'];
    final lat = rawLat is num ? rawLat.toDouble() : null;
    final lon = rawLon is num ? rawLon.toDouble() : null;
    final hasPosition = lat != null && lon != null && _validPosition(lat, lon);
    final name = _text(json['name']);
    return PotaParkDetail(
      reference: ref,
      name: name.isEmpty ? ref : name,
      lat: hasPosition ? lat : null,
      lon: hasPosition ? lon : null,
      grid6: _text(json['grid6']),
      type: _text(json['parktypeDesc']),
      locationDesc: _text(json['locationDesc']),
      locationName: _text(json['locationName']),
      country: _text(json['entityName']),
      firstActivator: _text(json['firstActivator']),
      firstActivationDate: _date(json['firstActivationDate']),
      website: _text(json['website']),
    );
  }
}

/// What `/park/stats/{reference}` counts.
class PotaParkStats {
  final int attempts;
  final int activations;
  final int contacts;
  const PotaParkStats(
      {required this.attempts,
      required this.activations,
      required this.contacts});

  static PotaParkStats? tryParse(Object? json) {
    if (json is! Map) return null;
    final contacts = _count(json['contacts']);
    final activations = _count(json['activations']);
    if (contacts == null && activations == null) return null;
    return PotaParkStats(
      attempts: _count(json['attempts']) ?? 0,
      activations: activations ?? 0,
      contacts: contacts ?? 0,
    );
  }
}

/// One past activation of a park, from `/park/activations/{reference}`.
class PotaActivation {
  final String callsign;

  /// The UTC day.
  final DateTime? date;
  final int qsos;
  const PotaActivation(
      {required this.callsign, required this.date, required this.qsos});

  static PotaActivation? tryParse(Object? json) {
    if (json is! Map) return null;
    final call = _text(json['activeCallsign']).toUpperCase();
    if (call.isEmpty) return null;
    return PotaActivation(
      callsign: call,
      date: _date(json['qso_date']),
      qsos: _count(json['totalQSOs']) ?? 0,
    );
  }
}

String _text(Object? v) => v == null ? '' : v.toString().trim();

int? _count(Object? v) => v is num ? v.toInt() : int.tryParse(_text(v));

/// "20250629" or "2013-09-15" as a UTC date.
DateTime? _date(Object? v) {
  final s = _text(v).replaceAll('-', '');
  if (!RegExp(r'^\d{8}$').hasMatch(s)) return null;
  final y = int.parse(s.substring(0, 4));
  final m = int.parse(s.substring(4, 6));
  final d = int.parse(s.substring(6, 8));
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  return DateTime.utc(y, m, d);
}
