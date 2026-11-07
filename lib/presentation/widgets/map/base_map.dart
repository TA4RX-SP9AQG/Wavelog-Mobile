import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/l10n_extension.dart';

/// The map backgrounds to choose from. [auto] is light or dark with the
/// app's theme. All may be used by an app without an API key, with the
/// attribution shown under the map.
enum BaseMap {
  auto,
  light,
  dark,
  topo;

  static BaseMap fromName(String? name) =>
      values.firstWhere((b) => b.name == name, orElse: () => auto);
}

class BaseTiles {
  final String url;
  final List<String> subdomains;
  final int maxZoom;
  final String attribution;

  /// Shown through [kDarkTiles]: OpenStreetMap has no dark style.
  final bool darkened;
  const BaseTiles(this.url, this.attribution,
      {this.subdomains = const [], this.maxZoom = 19, this.darkened = false});
}

const _osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _osmAttribution = '© OpenStreetMap contributors';

/// Inverts the tiles and turns the hues back by 180°, as CSS
/// `invert(1) hue-rotate(180deg)`: dark land and sea, with water still
/// blue and parks still green.
const kDarkTiles = ColorFilter.matrix(<double>[
  0.574, -1.430, -0.144, 0, 255, //
  -0.426, -0.430, -0.144, 0, 255, //
  -0.426, -1.430, 0.856, 0, 255, //
  0, 0, 0, 1, 0,
]);

BaseTiles tilesFor(BaseMap base, bool isDark) => switch (base) {
      BaseMap.auto => tilesFor(isDark ? BaseMap.dark : BaseMap.light, isDark),
      BaseMap.light => const BaseTiles(_osmUrl, _osmAttribution),
      BaseMap.dark => const BaseTiles(_osmUrl, _osmAttribution, darkened: true),
      // The credit OpenTopoMap asks for.
      BaseMap.topo => const BaseTiles(
          'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
          'Map data: © OpenStreetMap contributors, SRTM  '
          'Map style: © OpenTopoMap (CC-BY-SA)',
          subdomains: ['a', 'b', 'c'],
          maxZoom: 17),
    };

/// The saved background choice, shared by every map in the app.
const kBaseMapPrefKey = 'wl_map_base';

Future<BaseMap> loadBaseMap() async {
  try {
    final p = await SharedPreferences.getInstance();
    return BaseMap.fromName(p.getString(kBaseMapPrefKey));
  } catch (_) {
    return BaseMap.auto;
  }
}

Future<void> saveBaseMap(BaseMap base) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(kBaseMapPrefKey, base.name);
  } catch (_) {}
}

/// The tile layer for a background, dark-filtered when it asks for it.
/// [tileProvider] is for tests, which must not reach the network.
class BaseMapTileLayer extends StatelessWidget {
  final BaseTiles tiles;
  final TileProvider? tileProvider;
  const BaseMapTileLayer({super.key, required this.tiles, this.tileProvider});

  @override
  Widget build(BuildContext context) => ColorFiltered(
        colorFilter: tiles.darkened
            ? kDarkTiles
            : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
        child: TileLayer(
          urlTemplate: tiles.url,
          subdomains: tiles.subdomains,
          userAgentPackageName: 'com.wavelog_mobile',
          maxNativeZoom: tiles.maxZoom,
          maxZoom: 19,
          tileProvider: tileProvider,
        ),
      );
}

/// The small square buttons over a map (zoom, north up, my location).
class MapRoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  /// Turns the icon, so the compass needle points to north.
  final double iconAngle;

  /// Read out by screen readers.
  final String? tooltip;
  const MapRoundButton(
      {super.key,
      required this.icon,
      required this.onTap,
      this.iconAngle = 0,
      this.tooltip});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final button = Material(
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
            child: Icon(icon, size: 20, color: cs.onSurface),
          ),
        ),
      ),
    );
    // The tooltip is also what a screen reader reads out
    final label = tooltip;
    return label == null ? button : Tooltip(message: label, child: button);
  }
}

/// The sheet to choose the background. [onChanged] is called at once with
/// each choice, and the sheet stays open to show it.
Future<void> showBaseMapPicker(
  BuildContext context, {
  required BaseMap current,
  required ValueChanged<BaseMap> onChanged,
}) {
  final l10n = context.l10n;
  var chosen = current;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final names = {
          BaseMap.auto: l10n.mapBaseAuto,
          BaseMap.light: l10n.mapBaseLight,
          BaseMap.dark: l10n.mapBaseDark,
          BaseMap.topo: l10n.mapBaseTopo,
        };
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(l10n.mapLayers,
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
              RadioGroup<BaseMap>(
                groupValue: chosen,
                onChanged: (v) {
                  if (v == null) return;
                  setSheet(() => chosen = v);
                  onChanged(v);
                },
                child: Column(children: [
                  for (final b in BaseMap.values)
                    RadioListTile<BaseMap>(
                        dense: true, title: Text(names[b]!), value: b),
                ]),
              ),
            ],
          ),
        );
      },
    ),
  );
}
