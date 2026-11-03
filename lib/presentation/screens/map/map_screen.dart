import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/error_l10n.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../core/utils/map_geo.dart';
import '../../../core/utils/worked_before.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/qso_scope.dart';
import '../../../data/models/qso_model.dart';
import '../../../providers/qso_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/station_provider.dart';
import '../../../providers/worked_before_provider.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

class _QsoMarker {
  final String callsign;
  final LatLng point;
  final String band;
  final String mode;
  final String submode;
  final String rstSent;
  final String rstRcvd;
  final String name;
  final String qth;
  final String grid;
  final String country;
  final String freq;
  final String dateStr; // pre-formatted
  const _QsoMarker({
    required this.callsign,
    required this.point,
    required this.band,
    required this.mode,
    required this.submode,
    required this.rstSent,
    required this.rstRcvd,
    required this.name,
    required this.qth,
    required this.grid,
    required this.country,
    required this.freq,
    required this.dateStr,
  });
}

// Top-level: runs in isolate — no Flutter imports allowed here.
// One marker per callsign: at the grid of its newest QSO that has one, else
// at the centre of its DXCC entity ('la'/'lo'), as Wavelog's own map does
// for QSOs without a grid (contest QSOs often have none).
List<_QsoMarker> _processQsoData(List<Map<String, String>> raw) {
  final seen = <String>{};
  final result = <_QsoMarker>[];
  for (final byGrid in [true, false]) {
    for (final q in raw) {
      final callsign = q['c'] ?? '';
      if (callsign.isEmpty || seen.contains(callsign)) continue;
      final grid = q['g'] ?? '';
      final ll = byGrid
          ? (grid.length < 4 ? null : _gridToLatLng(grid))
          : _latLng(q['la'], q['lo']);
      if (ll == null) continue;
      seen.add(callsign);
      result.add(_marker(q, callsign, ll, byGrid ? grid : ''));
    }
  }
  return result;
}

LatLng? _latLng(String? lat, String? lon) {
  final la = double.tryParse(lat ?? '');
  final lo = double.tryParse(lon ?? '');
  if (la == null || lo == null || la.abs() > 90 || lo.abs() > 180) return null;
  return LatLng(la, lo);
}

_QsoMarker _marker(
        Map<String, String> q, String callsign, LatLng ll, String grid) =>
    _QsoMarker(
      callsign: callsign,
      point: ll,
      band: q['b'] ?? '',
      mode: q['m'] ?? '',
      submode: q['sm'] ?? '',
      rstSent: q['rs'] ?? '',
      rstRcvd: q['rr'] ?? '',
      name: q['n'] ?? '',
      qth: q['qt'] ?? '',
      grid: grid,
      country: q['co'] ?? '',
      freq: q['f'] ?? '',
      dateStr: q['d'] ?? '',
    );

LatLng? _gridToLatLng(String grid) {
  try {
    final g = grid.toUpperCase();
    final lon = (g.codeUnitAt(0) - 65) * 20.0 - 180.0 +
        (g.codeUnitAt(2) - 48) * 2.0 + 1.0;
    final lat = (g.codeUnitAt(1) - 65) * 10.0 - 90.0 +
        (g.codeUnitAt(3) - 48) * 1.0 + 0.5;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
    return LatLng(lat, lon);
  } catch (_) {
    return null;
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _mapMarkersProvider = FutureProvider<List<_QsoMarker>>((ref) async {
  // Only the QSOs of the active scope (logbook first, then station) are drawn.
  final scopeIds = ref.watch(scopeStationIdsProvider);
  final qsos = filterByStations(
      Hive.box<QsoModel>('qso_cache').values.toList(), scopeIds);
  // Not awaited: grids draw at once, DXCC fallbacks once the catalog is in.
  final matcher = ref.watch(dxccMatcherProvider).valueOrNull;
  final fmt = DateFormat('dd MMM yyyy  HH:mm');
  final raw = qsos.map((q) {
    final adif = dxccEntityOf(q.callsign, q.dxcc, matcher);
    final entity = adif == null ? null : matcher?.byAdif(adif);
    return {
      'c': q.callsign,
      'g': q.gridSquare ?? '',
      'b': q.band,
      'm': q.mode,
      'sm': q.submode ?? '',
      'rs': q.rstSent,
      'rr': q.rstRcvd,
      'n': q.name ?? '',
      'qt': q.qth ?? '',
      'co': q.country ?? entity?.name ?? '',
      'f': q.freqMhz != null ? '${q.freqMhz!.toStringAsFixed(3)} MHz' : '',
      'd': fmt.format(q.dateTimeOn.toLocal()),
      if (entity?.lat != null && entity?.lon != null) ...{
        'la': entity!.lat!.toString(),
        'lo': entity.lon!.toString(),
      },
    };
  }).toList();
  return compute(_processQsoData, raw);
});

// ── Base maps ─────────────────────────────────────────────────────────────────

/// The map backgrounds to choose from. [auto] is light or dark with the
/// app's theme. All may be used by an app without an API key, with the
/// attribution shown under the map.
enum _BaseMap {
  auto,
  light,
  dark,
  topo;

  static _BaseMap fromName(String? name) =>
      values.firstWhere((b) => b.name == name, orElse: () => auto);
}

class _Tiles {
  final String url;
  final List<String> subdomains;
  final int maxZoom;
  final String attribution;
  /// Shown through [_kDarkTiles]: OpenStreetMap has no dark style.
  final bool darkened;
  const _Tiles(this.url, this.attribution,
      {this.subdomains = const [], this.maxZoom = 19, this.darkened = false});
}

const _osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _osmAttribution = '© OpenStreetMap contributors';

/// Inverts the tiles and turns the hues back by 180°, as CSS
/// `invert(1) hue-rotate(180deg)`: dark land and sea, with water still
/// blue and parks still green.
const _kDarkTiles = ColorFilter.matrix(<double>[
  0.574, -1.430, -0.144, 0, 255, //
  -0.426, -0.430, -0.144, 0, 255, //
  -0.426, -1.430, 0.856, 0, 255, //
  0, 0, 0, 1, 0,
]);

_Tiles _tilesFor(_BaseMap base, bool isDark) => switch (base) {
      _BaseMap.auto => _tilesFor(isDark ? _BaseMap.dark : _BaseMap.light, isDark),
      _BaseMap.light => const _Tiles(_osmUrl, _osmAttribution),
      _BaseMap.dark => const _Tiles(_osmUrl, _osmAttribution, darkened: true),
      // The credit OpenTopoMap asks for.
      _BaseMap.topo => const _Tiles(
          'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
          'Map data: © OpenStreetMap contributors, SRTM  '
          'Map style: © OpenTopoMap (CC-BY-SA)',
          subdomains: ['a', 'b', 'c'],
          maxZoom: 17),
    };

/// Lines to more stations than this are left out: thousands of curves make
/// the map slow and unreadable.
const _kMaxGreatCircles = 300;

// ── Band colours ──────────────────────────────────────────────────────────────

const _kBandColors = <String, Color>{
  '160m': Color(0xFFFF5252),
  '80m': Color(0xFFFF6D00),
  '60m': Color(0xFFFFCA28),
  '40m': Color(0xFFD4E157),
  '30m': Color(0xFF66BB6A),
  '20m': Color(0xFF26C6DA),
  '17m': Color(0xFF42A5F5),
  '15m': Color(0xFF7E57C2),
  '12m': Color(0xFFEC407A),
  '10m': Color(0xFFFF7043),
  '6m': Color(0xFF26A69A),
  '2m': Color(0xFF78909C),
};
const _kDefaultBandColor = Color(0xFF90A4AE);

Color _bandColor(String band) => _kBandColors[band] ?? _kDefaultBandColor;

// ── Screen ────────────────────────────────────────────────────────────────────

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  /// Bands shown; empty shows all.
  Set<String> _shownBands = const {};
  _QsoMarker? _popup;
  Offset? _popupPos; // position within the map Stack

  static const _kBaseKey = 'wl_map_base';
  static const _kLinesKey = 'wl_map_great_circles';
  static const _kGreylineKey = 'wl_map_greyline';
  _BaseMap _base = _BaseMap.auto;
  bool _showLines = true;
  bool _showGreyline = true;
  // The greyline moves about a degree every four minutes.
  Timer? _greylineTimer;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _greylineTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _showGreyline) setState(() {});
    });
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _base = _BaseMap.fromName(p.getString(_kBaseKey));
        _showLines = p.getBool(_kLinesKey) ?? true;
        _showGreyline = p.getBool(_kGreylineKey) ?? true;
      });
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kBaseKey, _base.name);
      await p.setBool(_kLinesKey, _showLines);
      await p.setBool(_kGreylineKey, _showGreyline);
    } catch (_) {}
  }

  /// The active station location, from its grid.
  LatLng? _stationPoint() {
    final id = ref.watch(settingsProvider.select((s) => s.activeStationProfileId));
    final station = ref
        .watch(stationProvider)
        .valueOrNull
        ?.where((s) => s.id == id)
        .firstOrNull;
    final ll = maidenheadToLatLon(station?.gridSquare ?? '');
    return ll == null ? null : LatLng(ll.lat, ll.lon);
  }

  Future<void> _openLayers() async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          void update(VoidCallback change) {
            setState(change);
            setS(() {});
            _savePrefs();
          }

          final names = {
            _BaseMap.auto: l10n.mapBaseAuto,
            _BaseMap.light: l10n.mapBaseLight,
            _BaseMap.dark: l10n.mapBaseDark,
            _BaseMap.topo: l10n.mapBaseTopo,
          };
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Text(l10n.mapLayers,
                        style: Theme.of(ctx).textTheme.titleMedium),
                  ),
                  RadioGroup<_BaseMap>(
                    groupValue: _base,
                    onChanged: (v) => update(() => _base = v ?? _base),
                    child: Column(children: [
                      for (final b in _BaseMap.values)
                        RadioListTile<_BaseMap>(
                          dense: true,
                          title: Text(names[b]!),
                          value: b,
                        ),
                    ]),
                  ),
                  const Divider(),
                  SwitchListTile(
                    dense: true,
                    secondary: const Icon(Icons.timeline),
                    title: Text(l10n.mapGreatCircles),
                    value: _showLines,
                    onChanged: (v) => update(() => _showLines = v),
                  ),
                  SwitchListTile(
                    dense: true,
                    secondary: const Icon(Icons.wb_twilight),
                    title: Text(l10n.mapGreyline),
                    subtitle: Text(l10n.mapGreylineHint),
                    value: _showGreyline,
                    onChanged: (v) => update(() => _showGreyline = v),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<_QsoMarker> _filter(List<_QsoMarker> all) =>
      _shownBands.isEmpty
          ? all
          : all.where((m) => _shownBands.contains(m.band)).toList();

  List<String> _bands(List<_QsoMarker> all) {
    final bands = all.map((m) => m.band).where((b) => b.isNotEmpty).toSet().toList();
    const order = ['160m', '80m', '60m', '40m', '30m', '20m', '17m', '15m', '12m', '10m', '6m', '2m'];
    bands.sort((a, b) {
      final ia = order.indexOf(a);
      final ib = order.indexOf(b);
      if (ia == -1 && ib == -1) return a.compareTo(b);
      if (ia == -1) return 1;
      if (ib == -1) return -1;
      return ia.compareTo(ib);
    });
    return bands;
  }

  void _handleTap(TapPosition tapPos, LatLng tapLatLng, List<_QsoMarker> visible) {
    final zoom = _mapController.camera.zoom;
    // 24 logical-pixel tap tolerance converted to geographic degrees.
    // This keeps the hit area proportional to what's visible on screen
    // regardless of zoom level, instead of shrinking too fast at high zoom.
    final degPerPixel = 360.0 / (256.0 * pow(2.0, zoom));
    final radiusDeg = 24.0 * degPerPixel;
    final threshold = radiusDeg * radiusDeg;

    _QsoMarker? nearest;
    var best = threshold;
    for (final m in visible) {
      final dlat = m.point.latitude - tapLatLng.latitude;
      final dlon = (m.point.longitude - tapLatLng.longitude) *
          cos(m.point.latitude * pi / 180.0);
      final d = dlat * dlat + dlon * dlon;
      if (d < best) {
        best = d;
        nearest = m;
      }
    }
    setState(() {
      _popup = nearest;
      _popupPos = tapPos.relative;
    });
  }

  /// The map's rotation in degrees, for the north-up button.
  double _rotation = 0;

  void _onMapEvent(MapEvent event) {
    final r = event.camera.rotation;
    // Only the button's visibility depends on it: rebuild when it flips.
    if ((r.abs() > 0.5) != (_rotation.abs() > 0.5)) {
      setState(() => _rotation = r);
    } else {
      _rotation = r;
    }
  }

  void _zoom(double delta) {
    final cam = _mapController.camera;
    _mapController.move(cam.center, (cam.zoom + delta).clamp(1.0, 18.0));
  }

  @override
  void dispose() {
    _greylineTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final markersAsync = ref.watch(_mapMarkersProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tiles = _tilesFor(_base, isDark);
    final station = _stationPoint();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mapTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.layers_outlined),
            tooltip: l10n.mapLayers,
            onPressed: _openLayers,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {
                _shownBands = const {};
                _popup = null;
              });
              ref.invalidate(_mapMarkersProvider);
            },
          ),
        ],
      ),
      body: markersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(localizeError(context, e))),
        data: (allMarkers) {
          if (allMarkers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 64, color: cs.onSurface.withValues(alpha: 0.25)),
                  const SizedBox(height: 16),
                  Text(l10n.mapNoData,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5),
                          )),
                ],
              ),
            );
          }

          final bands = _bands(allMarkers);
          final visible = _filter(allMarkers);

          final circles = visible.map((m) => CircleMarker(
                point: m.point,
                radius: 5.5,
                color: _bandColor(m.band).withValues(alpha: 0.82),
                borderColor: Colors.white.withValues(alpha: 0.55),
                borderStrokeWidth: 1.2,
              )).toList();

          final lines = !_showLines || station == null
              ? const <Polyline>[]
              : [
                  for (final m in visible.take(_kMaxGreatCircles))
                    for (final run in greatCircle(station, m.point, segments: 32))
                      Polyline(
                        points: run,
                        strokeWidth: 1,
                        color: _bandColor(m.band).withValues(alpha: 0.45),
                      ),
                ];

          return Column(
            children: [
              // Band filter chips
              // Tap bands to show several at once; "All" clears the choice.
              if (bands.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Row(children: [
                    ChoiceChip(
                      label: Text(l10n.filterAll),
                      selected: _shownBands.isEmpty,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() {
                        _shownBands = const {};
                        _popup = null;
                      }),
                    ),
                    for (final b in bands) ...[
                      const SizedBox(width: 6),
                      FilterChip(
                        avatar: CircleAvatar(
                            radius: 5, backgroundColor: _bandColor(b)),
                        label: Text(b),
                        selected: _shownBands.contains(b),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        onSelected: (on) => setState(() {
                          _shownBands = on
                              ? {..._shownBands, b}
                              : ({..._shownBands}..remove(b));
                          _popup = null;
                        }),
                      ),
                    ],
                  ]),
                ),

              // Map + overlays
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: const LatLng(30, 15),
                        initialZoom: 2,
                        minZoom: 1,
                        cameraConstraint: CameraConstraint.contain(
                          bounds: LatLngBounds(
                            const LatLng(-kWebMercatorMaxLat, -180),
                            const LatLng(kWebMercatorMaxLat, 180),
                          ),
                        ),
                        maxZoom: 18,
                        onTap: (tapPos, latLng) => _handleTap(tapPos, latLng, visible),
                        onMapEvent: _onMapEvent,
                        // As in Google Maps: whichever two-finger gesture
                        // starts first wins, so a pinch zooms without also
                        // turning the map; turning it takes a clear twist.
                        interactionOptions: const InteractionOptions(
                          enableMultiFingerGestureRace: true,
                          rotationThreshold: 30,
                        ),
                      ),
                      children: [
                        ColorFiltered(
                          colorFilter: tiles.darkened
                              ? _kDarkTiles
                              : const ColorFilter.mode(
                                  Colors.transparent, BlendMode.dst),
                          child: TileLayer(
                            urlTemplate: tiles.url,
                            subdomains: tiles.subdomains,
                            userAgentPackageName: 'com.wavelog_mobile',
                            maxNativeZoom: tiles.maxZoom,
                            maxZoom: 19,
                          ),
                        ),
                        if (_showGreyline)
                          PolygonLayer(polygons: [
                            Polygon(
                              points: nightPolygon(DateTime.now().toUtc()),
                              color: Colors.black.withValues(alpha: 0.28),
                              borderColor: Colors.amber.withValues(alpha: 0.6),
                              borderStrokeWidth: 1,
                            ),
                          ]),
                        if (lines.isNotEmpty) PolylineLayer(polylines: lines),
                        CircleLayer(circles: circles),
                        if (station != null)
                          MarkerLayer(markers: [
                            Marker(
                              point: station,
                              width: 30,
                              height: 30,
                              child: Icon(Icons.cell_tower,
                                  size: 26,
                                  color: cs.primary,
                                  shadows: const [
                                    Shadow(color: Colors.black54, blurRadius: 4)
                                  ]),
                            ),
                          ]),
                      ],
                    ),

                    // QSO popup card
                    if (_popup != null && _popupPos != null)
                      _QsoPopup(
                        marker: _popup!,
                        tapPos: _popupPos!,
                        onClose: () => setState(() => _popup = null),
                      ),

                    // Zoom buttons — bottom-right
                    Positioned(
                      right: 12,
                      bottom: 16,
                      child: Column(
                        children: [
                          // Shown while the map is turned: back to north up.
                          if (_rotation.abs() > 0.5) ...[
                            _ZoomButton(
                              icon: Icons.navigation,
                              iconAngle: _rotation * pi / 180, // layers turn by +rotation
                              tooltip: l10n.mapNorthUp,
                              onTap: () => _mapController.rotate(0),
                            ),
                            const SizedBox(height: 6),
                          ],
                          _ZoomButton(
                            icon: Icons.add,
                            onTap: () => _zoom(1),
                          ),
                          const SizedBox(height: 6),
                          _ZoomButton(
                            icon: Icons.remove,
                            onTap: () => _zoom(-1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Status bar
              // Clear of the system navigation bar (edge-to-edge).
              Container(
                padding: EdgeInsets.fromLTRB(
                    16, 7, 16, 7 + MediaQuery.paddingOf(context).bottom),
                color: cs.surfaceContainerLow,
                child: Row(
                  children: [
                    Icon(Icons.radio, size: 13, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      l10n.mapStationCount(visible.length),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      tiles.attribution,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.35),
                            fontSize: 9,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── QSO Popup Card ────────────────────────────────────────────────────────────

const _kPopupWidth = 240.0;
const _kPopupMaxHeight = 260.0;
const _kArrowSize = 8.0;

class _QsoPopup extends StatelessWidget {
  final _QsoMarker marker;
  final Offset tapPos;
  final VoidCallback onClose;

  const _QsoPopup({required this.marker, required this.tapPos, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cs = Theme.of(context).colorScheme;
    final bandColor = _bandColor(marker.band);

    // Decide whether popup appears above or below the tap
    final showAbove = tapPos.dy > size.height * 0.55;
    const cardHeight = _kPopupMaxHeight;

    double left = tapPos.dx - _kPopupWidth / 2;
    left = left.clamp(8.0, size.width - _kPopupWidth - 8.0);

    final double top = showAbove
        ? tapPos.dy - cardHeight - _kArrowSize - 4
        : tapPos.dy + _kArrowSize + 4;

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!showAbove)
              _Arrow(up: true, color: cs.surfaceContainerHigh),
            Container(
              width: _kPopupWidth,
              constraints: const BoxConstraints(maxHeight: _kPopupMaxHeight),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                    decoration: BoxDecoration(
                      color: bandColor.withValues(alpha: 0.15),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(color: bandColor, shape: BoxShape.circle),
                        ),
                        Expanded(
                          child: Text(
                            marker.callsign,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                          ),
                        ),
                        InkWell(
                          onTap: onClose,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.close, size: 16, color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Band + Mode row
                          Row(children: [
                            _MiniChip(label: marker.band, color: bandColor),
                            const SizedBox(width: 6),
                            _MiniChip(
                              label: marker.submode.isNotEmpty
                                  ? '${marker.mode}/${marker.submode}'
                                  : marker.mode,
                              color: cs.secondary,
                            ),
                            if (marker.freq.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  marker.freq,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ]),
                          const SizedBox(height: 8),

                          // RST
                          _PopupRow(
                            icon: Icons.signal_cellular_alt,
                            label: 'RST',
                            value: '${marker.rstSent} / ${marker.rstRcvd}',
                          ),

                          // Grid
                          if (marker.grid.isNotEmpty)
                            _PopupRow(icon: Icons.grid_on, label: 'Grid', value: marker.grid),

                          // Name / QTH
                          if (marker.name.isNotEmpty)
                            _PopupRow(icon: Icons.person_outline, label: 'Name', value: marker.name),
                          if (marker.qth.isNotEmpty)
                            _PopupRow(icon: Icons.location_on_outlined, label: 'QTH', value: marker.qth),
                          if (marker.country.isNotEmpty)
                            _PopupRow(icon: Icons.flag_outlined, label: 'DXCC', value: marker.country),

                          // Coords
                          _PopupRow(
                            icon: Icons.my_location,
                            label: 'Coord',
                            value: '${marker.point.latitude.toStringAsFixed(2)}°  '
                                '${marker.point.longitude.toStringAsFixed(2)}°',
                          ),

                          // Date
                          if (marker.dateStr.isNotEmpty)
                            _PopupRow(
                              icon: Icons.access_time,
                              label: 'Date',
                              value: marker.dateStr,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showAbove)
              _Arrow(up: false, color: cs.surfaceContainerHigh),
          ],
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  final bool up;
  final Color color;
  const _Arrow({required this.up, required this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(_kArrowSize * 2, _kArrowSize),
        painter: _ArrowPainter(up: up, color: color),
      );
}

class _ArrowPainter extends CustomPainter {
  final bool up;
  final Color color;
  const _ArrowPainter({required this.up, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = ui.Paint()..color = color;
    final path = ui.Path();
    if (up) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.up != up || old.color != color;
}

class _PopupRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _PopupRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          SizedBox(
            width: 38,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      );
}

// ── Zoom Buttons ──────────────────────────────────────────────────────────────

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  /// Turns the icon, so the compass needle points to north.
  final double iconAngle;
  /// Read out by screen readers.
  final String? tooltip;
  const _ZoomButton(
      {required this.icon,
      required this.onTap,
      this.iconAngle = 0,
      this.tooltip});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      shadowColor: Colors.black38,
      color: cs.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Transform.rotate(
            angle: iconAngle,
            child: Icon(icon,
                size: 20, color: cs.onSurface, semanticLabel: tooltip),
          ),
        ),
      ),
    );
  }
}
