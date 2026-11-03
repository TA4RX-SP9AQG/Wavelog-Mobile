class DxccEntity {
  final int adif;
  final String name;
  final String prefix;
  final String continent;
  final int cqZone;
  final int ituZone;
  final bool deleted;
  /// The entity's centre, from the catalog; null when the server has none.
  final double? lat;
  final double? lon;

  const DxccEntity({
    required this.adif,
    required this.name,
    required this.prefix,
    this.continent = '',
    required this.cqZone,
    required this.ituZone,
    this.deleted = false,
    this.lat,
    this.lon,
  });

  factory DxccEntity.fromJson(Map<String, dynamic> j) => DxccEntity(
        adif:      _i(j['adif']),
        name:      j['name']?.toString() ?? '',
        prefix:    j['prefix']?.toString() ?? '',
        continent: j['continent']?.toString() ?? j['cont']?.toString() ?? '',
        cqZone:    _i(j['cqz']),
        ituZone:   _i(j['ituz']),
        deleted:   j['deleted'] == true,
        lat:       _d(j['lat']),
        lon:       _d(j['long']),
      );

  static double? _d(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

  static int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  String get displayName => '$name ($prefix)';
}
