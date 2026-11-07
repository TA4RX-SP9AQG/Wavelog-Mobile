import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show MapCamera, MobileLayerTransformer;
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../core/utils/pota_parks.dart';
import '../../../data/models/pota_park_model.dart';
import 'pota_park_style.dart';

/// Width of a park icon on the map, in logical pixels: the ones that matter to
/// the operator are larger.
double parkIconSize(PotaParkStatus status) => switch (status) {
      PotaParkStatus.activated => 34,
      PotaParkStatus.hunted || PotaParkStatus.neverActivated => 32,
      PotaParkStatus.other => 28,
    };

/// A pine tree with a park bench beside it, drawn in a 24 x 24 box at [box]
/// in [color].
void paintParkGlyph(Canvas canvas, Rect box, Color color) {
  final s = box.width / 24;
  Offset at(double x, double y) => Offset(box.left + x * s, box.top + y * s);
  Rect rect(double x, double y, double w, double h) =>
      Rect.fromLTWH(box.left + x * s, box.top + y * s, w * s, h * s);
  final paint = Paint()
    ..color = color
    ..isAntiAlias = true;

  // The tree: two layers of needles and a trunk
  canvas.drawPath(
      Path()
        ..moveTo(at(8, 1).dx, at(8, 1).dy)
        ..lineTo(at(13.2, 9.2).dx, at(13.2, 9.2).dy)
        ..lineTo(at(2.8, 9.2).dx, at(2.8, 9.2).dy)
        ..close(),
      paint);
  canvas.drawPath(
      Path()
        ..moveTo(at(8, 5).dx, at(8, 5).dy)
        ..lineTo(at(14.5, 14.2).dx, at(14.5, 14.2).dy)
        ..lineTo(at(1.5, 14.2).dx, at(1.5, 14.2).dy)
        ..close(),
      paint);
  canvas.drawRect(rect(7, 14.2, 2, 4.6), paint);

  // The bench: a back, a seat, two legs and the posts that hold the back
  final r = Radius.circular(0.6 * s);
  canvas.drawRRect(RRect.fromRectAndRadius(rect(13.2, 11, 10, 1.7), r), paint);
  canvas.drawRRect(RRect.fromRectAndRadius(rect(13.2, 14.6, 10, 2), r), paint);
  canvas.drawRect(rect(14.2, 12.7, 1.3, 2), paint);
  canvas.drawRect(rect(21, 12.7, 1.3, 2), paint);
  canvas.drawRect(rect(14.2, 16.6, 1.5, 3.6), paint);
  canvas.drawRect(rect(20.8, 16.6, 1.5, 3.6), paint);
}

/// The four icons, made once as images so that thousands of parks cost one
/// image draw each.
class ParkIcons {
  final Map<PotaParkStatus, ui.Image> _images;
  final double pixelRatio;
  ParkIcons._(this._images, this.pixelRatio);

  /// Draws them for a screen of [pixelRatio] device pixels per logical pixel.
  factory ParkIcons.create({required double pixelRatio}) => ParkIcons._({
        for (final s in PotaParkStatus.values) s: _render(s, pixelRatio),
      }, pixelRatio);

  ui.Image of(PotaParkStatus status) => _images[status]!;

  void dispose() {
    for (final image in _images.values) {
      image.dispose();
    }
  }

  static ui.Image _render(PotaParkStatus status, double ratio) {
    final size = parkIconSize(status);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(ratio);
    final c = Offset(size / 2, size / 2);
    final color = potaStatusColor(status);

    // A white disk with a thin dark edge, so that the icon is told apart from
    // whatever map lies beneath it
    canvas.drawCircle(c, size / 2 - 0.5, Paint()..color = Colors.white);
    canvas.drawCircle(
        c,
        size / 2 - 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF263238).withValues(alpha: 0.7));

    final glyphSide = size * 0.6;
    final glyph = Rect.fromCenter(center: c, width: glyphSide, height: glyphSide);
    if (status == PotaParkStatus.neverActivated) {
      // A ring with an empty middle: not told by its colour alone
      canvas.drawCircle(
          c,
          size / 2 - 3.4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..color = color);
      paintParkGlyph(canvas, glyph, color);
    } else {
      canvas.drawCircle(c, size / 2 - 2.5, Paint()..color = color);
      paintParkGlyph(canvas, glyph, Colors.white);
    }
    return recorder
        .endRecording()
        .toImageSync((size * ratio).ceil(), (size * ratio).ceil());
  }
}

/// A map layer that draws a park icon at each park. Later parks are drawn on
/// top of earlier ones. Without [icons] (not made yet) nothing is drawn.
class ParkIconLayer extends StatelessWidget {
  final List<(PotaParkPoint, PotaParkStatus)> parks;
  final ParkIcons? icons;
  const ParkIconLayer({super.key, required this.parks, required this.icons});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final icons = this.icons;
    return MobileLayerTransformer(
      child: CustomPaint(
        painter: icons == null
            ? null
            : _ParkIconPainter(parks: parks, icons: icons, camera: camera),
        size: Size(camera.size.x, camera.size.y),
        isComplex: true,
      ),
    );
  }
}

class _ParkIconPainter extends CustomPainter {
  final List<(PotaParkPoint, PotaParkStatus)> parks;
  final ParkIcons icons;
  final MapCamera camera;
  _ParkIconPainter(
      {required this.parks, required this.icons, required this.camera});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    // Icons stay upright when the map is turned
    final turn = -camera.rotationRad;
    // Parks just off the screen are skipped; the margin is an icon's width
    final visible = (Offset.zero & size).inflate(40);
    final sources = <PotaParkStatus, Rect>{};

    for (final (park, status) in parks) {
      final p = camera.getOffsetFromOrigin(LatLng(park.lat, park.lon));
      if (!visible.contains(p)) continue;
      final image = icons.of(status);
      final src =
          sources[status] ??= Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      final side = parkIconSize(status);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      if (turn != 0) canvas.rotate(turn);
      canvas.drawImageRect(
          image, src, Rect.fromCenter(center: Offset.zero, width: side, height: side), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParkIconPainter old) =>
      !identical(old.parks, parks) ||
      old.icons != icons ||
      old.camera != camera;
}

/// Where the operator is: a person in a turquoise disk with a pale halo,
/// unlike any park icon (those are white-rimmed, in other colours, and carry
/// a tree and a bench).
class MeMarker extends StatelessWidget {
  const MeMarker({super.key});

  static const size = 48.0;
  static const color = Color(0xFF00B8D4);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: color.withValues(alpha: 0.22)),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 5)
                ],
              ),
              child: const Icon(Icons.person, size: 17, color: Colors.white),
            ),
          ],
        ),
      );
}
