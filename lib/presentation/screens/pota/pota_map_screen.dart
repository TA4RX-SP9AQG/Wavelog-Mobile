import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/error_l10n.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/map_geo.dart';
import '../../../core/utils/pota_parks.dart';
import '../../../data/models/pota_park_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/pota_location_provider.dart';
import '../../../providers/pota_parks_provider.dart';
import '../../../providers/pota_stats_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/station_provider.dart';
import '../../widgets/map/base_map.dart';
import '../../widgets/pota/park_icon.dart';
import '../../widgets/pota/pota_park_autocomplete.dart';
import '../../widgets/pota/pota_park_sheet.dart';
import '../../widgets/pota/pota_park_style.dart';

/// Parks are drawn from this zoom; further out the map asks to zoom in.
const kMinParkZoom = 6.0;

/// How far from a dot a tap still counts as on it, in logical pixels.
const _kTapReach = 22.0;

/// Dots closer than this to the nearest one are on top of it and are offered
/// in a list instead.
const _kStackedWithin = 10.0;

const _kHiddenKey = 'wl_pota_map_hidden';

/// The park map has its own background choice, and opens on the terrain map:
/// the plain street map shows shops and airports that only get in the way.
const kPotaMapBaseKey = 'wl_pota_map_base';

/// Where the active station is, to open the map there when no position is
/// known. Null without a grid.
final potaMapHomeProvider = Provider<LatLng?>((ref) {
  final id =
      ref.watch(settingsProvider.select((s) => s.activeStationProfileId));
  final station = ref
      .watch(stationProvider)
      .valueOrNull
      ?.where((s) => s.id == id)
      .firstOrNull;
  final ll = maidenheadToLatLon(station?.gridSquare ?? '');
  return ll == null ? null : LatLng(ll.lat, ll.lon);
});

// Events that come from the person's own hands, not from the app moving the
// map: only these stop the map from jumping to a late position fix.
const _handSources = {
  MapEventSource.dragStart,
  MapEventSource.onDrag,
  MapEventSource.multiFingerGestureStart,
  MapEventSource.onMultiFinger,
  MapEventSource.doubleTap,
  MapEventSource.doubleTapHold,
  MapEventSource.scrollWheel,
  MapEventSource.flingAnimationController,
  MapEventSource.doubleTapZoomAnimationController,
};

class PotaMapScreen extends ConsumerStatefulWidget {
  /// For tests, which must not reach the tile servers.
  final TileProvider? tileProvider;
  const PotaMapScreen({super.key, this.tileProvider});

  @override
  ConsumerState<PotaMapScreen> createState() => _PotaMapScreenState();
}

class _PotaMapScreenState extends ConsumerState<PotaMapScreen> {
  final _map = MapController();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  Timer? _retryTimer;
  StreamSubscription<PotaLocationFix>? _openingSub;

  BaseMap _base = BaseMap.topo;
  Set<PotaParkStatus> _hidden = const {};

  /// The squares in view and whether too many are.
  List<String> _squares = const [];
  bool _tooMany = true;
  double _zoom = 3;
  double _rotation = 0;
  String _cameraKey = '';

  var _mapReady = false;
  var _userMoved = false;
  PotaLocationFix? _me;
  PotaLocationFix? _fixBeforeReady;
  PotaParkPoint? _selected;

  /// Null until the place for the kept tiles is known (a moment).
  TileProvider? _tiles;

  /// The park icons, drawn once for this screen's pixel density.
  ParkIcons? _icons;

  late final LatLng _startCenter;
  late final double _startZoom;

  @override
  void initState() {
    super.initState();
    final home = ref.read(potaMapHomeProvider);
    _startCenter = home ?? const LatLng(30, 15);
    _startZoom = home == null ? 3 : 9;
    _zoom = _startZoom;
    _tiles = widget.tileProvider;
    if (_tiles == null) _openTileProvider();
    _loadPrefs();
    _openingSub = openingPositions(ref.read(potaLocationServiceProvider))
        .listen(_onOpeningFix, onError: (_) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ratio = MediaQuery.devicePixelRatioOf(context);
    if (_icons?.pixelRatio == ratio) return;
    final old = _icons;
    try {
      _icons = ParkIcons.create(pixelRatio: ratio);
    } catch (e) {
      debugPrint('POTA map: could not draw the park icons: $e');
      _icons = null;
    }
    old?.dispose();
  }

  @override
  void dispose() {
    _icons?.dispose();
    _debounce?.cancel();
    _retryTimer?.cancel();
    _openingSub?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _openTileProvider() async {
    final provider = await createCachedTileProvider();
    if (!mounted) {
      provider.dispose();
      return;
    }
    setState(() => _tiles = provider);
  }

  Future<void> _loadPrefs() async {
    final base =
        await loadBaseMap(key: kPotaMapBaseKey, fallback: BaseMap.topo);
    Set<PotaParkStatus> hidden = const {};
    try {
      final p = await SharedPreferences.getInstance();
      hidden = {
        for (final n in p.getStringList(_kHiddenKey) ?? const <String>[])
          ...PotaParkStatus.values.where((s) => s.name == n),
      };
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _base = base;
      _hidden = hidden;
    });
  }

  Future<void> _saveHidden() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_kHiddenKey, [for (final s in _hidden) s.name]);
    } catch (_) {}
  }

  // ── Position ──

  void _onOpeningFix(PotaLocationFix fix) {
    if (!mounted) return;
    setState(() => _me = fix);
    if (_userMoved) return;
    if (_mapReady) {
      _map.move(LatLng(fix.lat, fix.lon), 11);
    } else {
      _fixBeforeReady = fix;
    }
  }

  Future<void> _locate() async {
    final l10n = context.l10n;
    final service = ref.read(potaLocationServiceProvider);
    final result = await service.locate(askPermission: true);
    if (!mounted) return;
    switch (result) {
      case PotaLocationFix(:final lat, :final lon):
        _userMoved = true;
        setState(() => _me = result);
        if (_mapReady) _map.move(LatLng(lat, lon), max(_map.camera.zoom, 11));
      case PotaLocationDenied(:final forever):
        _snack(
          forever ? l10n.potaMapLocationDeniedForever : l10n.potaMapLocationDenied,
          action: forever ? service.openAppSettings : null,
        );
      case PotaLocationServiceOff():
        _snack(l10n.potaMapLocationOff, action: service.openLocationSettings);
      case PotaLocationFailed():
        _snack(l10n.potaMapLocationFailed);
    }
  }

  void _snack(String text, {Future<void> Function()? action}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        action: action == null
            ? null
            : SnackBarAction(
                label: context.l10n.potaMapOpenSettings,
                onPressed: () => action(),
              ),
      ));
  }

  // ── The map in view ──

  void _onMapReady() {
    _mapReady = true;
    final fix = _fixBeforeReady;
    if (fix != null && !_userMoved) {
      _map.move(LatLng(fix.lat, fix.lon), 11);
    }
    _fixBeforeReady = null;
    _refresh();
  }

  void _onMapEvent(MapEvent event) {
    if (_handSources.contains(event.source)) _userMoved = true;
    final cam = event.camera;
    final needsRebuild = (cam.rotation.abs() > 0.5) != (_rotation.abs() > 0.5) ||
        (cam.zoom >= kMinParkZoom) != (_zoom >= kMinParkZoom);
    _rotation = cam.rotation;
    _zoom = cam.zoom;
    if (needsRebuild && mounted) setState(() {});

    final key = '${cam.center}|${cam.zoom}|${cam.rotation}|${cam.nonRotatedSize}';
    if (key == _cameraKey) return;
    _cameraKey = key;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _refresh);
  }

  /// Works out the squares in view and asks for their parks.
  void _refresh() {
    if (!mounted || !_mapReady) return;
    final cam = _map.camera;
    final b = cam.visibleBounds;
    final cover = cam.zoom < kMinParkZoom
        ? (squares: const <String>[], tooMany: true)
        : squaresCovering(
            south: b.south,
            west: b.west,
            north: b.north,
            east: b.east,
            near: (lat: cam.center.latitude, lon: cam.center.longitude),
          );
    ref.read(potaParksProvider.notifier).ensureSquares(cover.squares);
    if (!listEquals(cover.squares, _squares) || cover.tooMany != _tooMany) {
      setState(() {
        _squares = cover.squares;
        _tooMany = cover.tooMany;
      });
    }
  }

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    final cam = _map.camera;
    _map.move(cam.center, (cam.zoom + delta).clamp(2.0, 18.0));
  }

  // ── Parks ──

  /// The parks to draw: those of the squares in view, of the statuses shown.
  List<(PotaParkPoint, PotaParkStatus)> _visibleParks() {
    final parks = ref.read(potaParksProvider).parksIn(_squares);
    final activated = ref.read(activatedParksProvider);
    final hunted = ref.read(huntedParksProvider);
    return [
      for (final p in parks)
        if (!_hidden.contains(_statusOf(p, activated, hunted)))
          (p, _statusOf(p, activated, hunted)),
    ];
  }

  PotaParkStatus _statusOf(
          PotaParkPoint p, Set<String>? activated, Set<String>? hunted) =>
      parkStatus(
        ref: p.reference,
        neverActivated: p.neverActivated,
        activated: activated,
        hunted: hunted,
      );

  void _onTap(TapPosition tap, LatLng at) {
    final cam = _map.camera;
    final from = tap.relative ?? () {
      final p = cam.latLngToScreenPoint(at);
      return Offset(p.x, p.y);
    }();
    final hits = <(PotaParkPoint, double)>[];
    for (final (p, _) in _visibleParks()) {
      final s = cam.latLngToScreenPoint(LatLng(p.lat, p.lon));
      final d = (Offset(s.x, s.y) - from).distance;
      if (d <= _kTapReach) hits.add((p, d));
    }
    if (hits.isEmpty) {
      if (_selected != null) _select(null);
      return;
    }
    hits.sort((a, b) => a.$2.compareTo(b.$2));
    final stacked = [
      for (final h in hits)
        if (h.$2 - hits.first.$2 <= _kStackedWithin) h.$1,
    ];
    if (stacked.length == 1) {
      _select(stacked.first, reveal: true);
    } else {
      _chooseOne(stacked);
    }
  }

  Future<void> _chooseOne(List<PotaParkPoint> parks) async {
    final l10n = context.l10n;
    final activated = ref.read(activatedParksProvider);
    final hunted = ref.read(huntedParksProvider);
    final picked = await showModalBottomSheet<PotaParkPoint>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(l10n.potaMapSeveralParks,
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final p in parks)
              ListTile(
                dense: true,
                leading: Icon(Icons.circle,
                    size: 14,
                    color: potaStatusColor(_statusOf(p, activated, hunted))),
                title: Text(p.reference,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(p.name),
                onTap: () => Navigator.of(ctx).pop(p),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) _select(picked, reveal: true);
  }

  void _select(PotaParkPoint? park, {bool reveal = false}) {
    setState(() => _selected = park);
    if (park != null && reveal) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected(park));
    }
  }

  /// The card covers the lower part of the map: lift the camera when the park
  /// would be under it.
  void _revealSelected(PotaParkPoint park) {
    if (!mounted) return;
    final cam = _map.camera;
    if (cam.rotation.abs() > 0.5) return;
    final size = cam.nonRotatedSize;
    final at = cam.latLngToScreenPoint(LatLng(park.lat, park.lon));
    if (at.y <= size.y * 0.5) return;
    final shift = at.y - size.y * 0.28;
    _map.move(
      cam.pointToLatLng(Point(size.x / 2, size.y / 2 + shift)),
      cam.zoom,
    );
  }

  Future<void> _goToPark(String reference) async {
    final l10n = context.l10n;
    final r = reference.trim().toUpperCase();
    if (!potaRefPattern.hasMatch(r)) {
      _snack(l10n.potaMapParkNotFound);
      return;
    }
    var point = ref.read(potaParksProvider).find(r);
    if (point == null) {
      try {
        final d = await ref.read(potaParksDatasourceProvider).getDetail(r);
        if (!mounted) return;
        if (d == null || d.lat == null || d.lon == null) {
          _snack(l10n.potaMapParkNotFound);
          return;
        }
        point = PotaParkPoint(
            reference: d.reference, name: d.name, lat: d.lat!, lon: d.lon!);
      } catch (e) {
        if (!mounted) return;
        _snack(localizeError(context, e));
        return;
      }
    }
    _userMoved = true;
    _searchFocus.unfocus();
    setState(() => _selected = point);
    if (_mapReady) _map.move(LatLng(point.lat, point.lon), 12);
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tiles = tilesFor(_base, isDark);
    final parksState = ref.watch(potaParksProvider);
    ref.watch(activatedParksProvider);
    ref.watch(huntedParksProvider);

    // Back online: the squares that failed are asked again after a moment.
    ref.listen<bool>(isOnlineProvider, (wasOnline, online) {
      if (online && wasOnline == false) {
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(seconds: 2),
            () => ref.read(potaParksProvider.notifier).retryFailed());
      }
    });

    final selected = _selected == null
        ? null
        : (parksState.find(_selected!.reference) ?? _selected);
    final failed = parksState.failedIn(_squares).isNotEmpty;
    final loading = parksState.isLoadingAny(_squares);

    return PopScope(
      canPop: _selected == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(null);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.potaMapTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.layers_outlined),
              tooltip: l10n.mapLayers,
              onPressed: () => showBaseMapPicker(
                context,
                current: _base,
                onChanged: (b) {
                  setState(() => _base = b);
                  saveBaseMap(b, key: kPotaMapBaseKey);
                },
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  _buildMap(tiles, selected, cs),
                  _buildTop(l10n, failed, loading),
                  _buildButtons(l10n),
                  if (selected != null) _buildSheet(selected),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  12, 5, 12, 5 + MediaQuery.paddingOf(context).bottom),
              color: cs.surfaceContainerLow,
              child: Text(
                '${tiles.attribution}  ·  ${l10n.potaMapAttribution}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                      fontSize: 9,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(BaseTiles tiles, PotaParkPoint? selected, ColorScheme cs) {
    if (_tiles == null) return ColoredBox(color: cs.surfaceContainerLow);
    // What the map beneath looks like, whatever the app's theme
    final ring = tiles.darkened ? Colors.white : const Color(0xFF263238);
    // Least interesting first, so that the best ones are not covered
    final byStatus = {
      for (final s in PotaParkStatus.values) s: <(PotaParkPoint, PotaParkStatus)>[]
    };
    for (final item in _visibleParks()) {
      byStatus[item.$2]!.add(item);
    }
    final parks = [
      for (final s in PotaParkStatus.values.reversed) ...byStatus[s]!,
    ];

    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _startCenter,
        initialZoom: _startZoom,
        minZoom: 2,
        maxZoom: 18,
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(
            const LatLng(-kWebMercatorMaxLat, -180),
            const LatLng(kWebMercatorMaxLat, 180),
          ),
        ),
        onMapReady: _onMapReady,
        onMapEvent: _onMapEvent,
        onTap: _onTap,
        interactionOptions: const InteractionOptions(
          enableMultiFingerGestureRace: true,
          rotationThreshold: 30,
        ),
      ),
      children: [
        BaseMapTileLayer(
          tiles: tiles,
          tileProvider: _tiles,
          calm: true,
        ),
        // Dims the map's own detail so that the parks stand out
        IgnorePointer(
          child: ColoredBox(
            color: tiles.darkened
                ? Colors.black.withValues(alpha: 0.38)
                : Colors.white.withValues(alpha: 0.25),
          ),
        ),
        ParkIconLayer(parks: parks, icons: _icons),
        if (selected != null)
          CircleLayer(circles: [
            CircleMarker(
              point: LatLng(selected.lat, selected.lon),
              radius: 24,
              color: Colors.transparent,
              borderColor: ring,
              borderStrokeWidth: 3.5,
            ),
          ]),
        if (_me != null)
          MarkerLayer(markers: [
            Marker(
              point: LatLng(_me!.lat, _me!.lon),
              width: MeMarker.size,
              height: MeMarker.size,
              // Upright when the map is turned
              rotate: true,
              child: const MeMarker(key: ValueKey('me-marker')),
            ),
          ]),
      ],
    );
  }

  Widget _buildTop(AppLocalizations l10n, bool failed, bool loading) {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: _searchField(l10n, cs),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
            child: Row(children: [
              for (final s in PotaParkStatus.values) ...[
                FilterChip(
                  avatar: Icon(
                    s == PotaParkStatus.neverActivated
                        ? Icons.circle_outlined
                        : Icons.circle,
                    size: 14,
                    color: potaStatusColor(s),
                  ),
                  label: Text(potaStatusLabel(l10n, s)),
                  selected: !_hidden.contains(s),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: cs.surface,
                  onSelected: (on) {
                    setState(() => _hidden =
                        on ? ({..._hidden}..remove(s)) : {..._hidden, s});
                    _saveHidden();
                  },
                ),
                const SizedBox(width: 6),
              ],
            ]),
          ),
          if (_tooMany)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Center(
                child: Material(
                  elevation: 3,
                  color: cs.inverseSurface,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.zoom_in, size: 18, color: cs.onInverseSurface),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(l10n.potaMapZoomIn,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.onInverseSurface)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          if (failed)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Material(
                elevation: 3,
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
                  child: Row(children: [
                    Icon(Icons.cloud_off_outlined,
                        size: 18, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l10n.potaMapLoadFailed,
                          style: TextStyle(color: cs.onErrorContainer)),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(potaParksProvider.notifier).retryFailed(),
                      child: Text(l10n.retry),
                    ),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchField(AppLocalizations l10n, ColorScheme cs) => PotaParkAutocomplete(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        onSelected: (p) => _goToPark(p.reference),
        fieldBuilder: (context, selectHighlighted) => Material(
          elevation: 3,
          color: cs.surface,
          borderRadius: BorderRadius.circular(28),
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.potaMapSearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchCtrl,
                builder: (_, v, __) => v.text.isEmpty
                    ? const SizedBox()
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: l10n.close,
                        onPressed: _searchCtrl.clear,
                      ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onSubmitted: (value) {
              final r = value.trim().toUpperCase();
              if (r.isEmpty) return;
              if (potaRefPattern.hasMatch(r)) {
                _goToPark(r);
              } else {
                // A name being searched: take the top suggestion
                selectHighlighted();
              }
            },
          ),
        ),
      );

  Widget _buildButtons(AppLocalizations l10n) => Positioned(
        right: 12,
        bottom: 16,
        child: Column(
          children: [
            if (_rotation.abs() > 0.5) ...[
              MapRoundButton(
                icon: Icons.navigation,
                iconAngle: _rotation * pi / 180,
                tooltip: l10n.mapNorthUp,
                onTap: () => _map.rotate(0),
              ),
              const SizedBox(height: 6),
            ],
            MapRoundButton(
              icon: Icons.my_location,
              tooltip: l10n.potaMapMyLocation,
              onTap: _locate,
            ),
            const SizedBox(height: 6),
            MapRoundButton(icon: Icons.add, onTap: () => _zoomBy(1)),
            const SizedBox(height: 6),
            MapRoundButton(icon: Icons.remove, onTap: () => _zoomBy(-1)),
          ],
        ),
      );

  Widget _buildSheet(PotaParkPoint park) => Positioned.fill(
        child: DraggableScrollableSheet(
          key: ValueKey(park.reference),
          initialChildSize: 0.42,
          minChildSize: 0.2,
          maxChildSize: 0.92,
          snap: true,
          builder: (context, controller) => PotaParkSheet(
            park: park,
            me: _me == null ? null : (lat: _me!.lat, lon: _me!.lon),
            controller: controller,
            onClose: () => _select(null),
            onLog: (reference) => context
                .push('/add-qso?pota=${Uri.encodeQueryComponent(reference)}'),
          ),
        ),
      );
}
