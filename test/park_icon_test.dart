import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/core/utils/pota_parks.dart';
import 'package:wavelog_mobile/presentation/widgets/pota/park_icon.dart';
import 'package:wavelog_mobile/presentation/widgets/pota/pota_park_style.dart';

const _ratio = 2.0;

/// A pixel of [image] as an ARGB colour.
Future<Color> pixel(ui.Image image, int x, int y) async {
  final bytes = (await image.toByteData())!.buffer.asUint8List();
  final i = (y * image.width + x) * 4;
  return Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
}

bool near(Color a, Color b, {int tolerance = 6}) =>
    (a.r * 255 - b.r * 255).abs() <= tolerance &&
    (a.g * 255 - b.g * 255).abs() <= tolerance &&
    (a.b * 255 - b.b * 255).abs() <= tolerance;

void main() {
  testWidgets('every status has an icon of its own size', (tester) async {
    final icons = ParkIcons.create(pixelRatio: _ratio);
    addTearDown(icons.dispose);
    for (final s in PotaParkStatus.values) {
      final side = (parkIconSize(s) * _ratio).ceil();
      expect(icons.of(s).width, side, reason: '$s');
      expect(icons.of(s).height, side, reason: '$s');
    }
    // The ones that matter are larger
    expect(parkIconSize(PotaParkStatus.activated),
        greaterThan(parkIconSize(PotaParkStatus.other)));
  });

  testWidgets('a filled icon: the status colour with a white glyph, a white '
      'rim, and nothing outside the disk', (tester) async {
    await tester.runAsync(() async {
      final icons = ParkIcons.create(pixelRatio: _ratio);
      for (final s in [
        PotaParkStatus.activated,
        PotaParkStatus.hunted,
        PotaParkStatus.other,
      ]) {
        final image = icons.of(s);
        final c = image.width ~/ 2;
        final r = parkIconSize(s) / 2 * _ratio;
        // On the coloured disk, between the glyph and the rim
        final onDisk = await pixel(image, c, (c + r - 5 * _ratio).round());
        expect(near(onDisk, potaStatusColor(s)), isTrue,
            reason: '$s was $onDisk');
        // The white rim
        final rim = await pixel(image, c, (c + r - 1.6 * _ratio).round());
        expect(near(rim, Colors.white, tolerance: 16), isTrue,
            reason: '$s rim was $rim');
        // The corner is outside the disk: see-through
        expect((await pixel(image, 0, 0)).a, 0, reason: '$s');
        // The glyph is white somewhere in the middle
        var white = 0;
        for (var y = c - 8; y < c + 8; y++) {
          for (var x = c - 8; x < c + 8; x++) {
            if (near(await pixel(image, x, y), Colors.white)) white++;
          }
        }
        expect(white, greaterThan(20), reason: '$s has no glyph');
      }
      icons.dispose();
    });
  });

  testWidgets('a never-activated icon is a ring with an empty middle and a '
      'glyph in the status colour', (tester) async {
    await tester.runAsync(() async {
      final icons = ParkIcons.create(pixelRatio: _ratio);
      const s = PotaParkStatus.neverActivated;
      final image = icons.of(s);
      final c = image.width ~/ 2;
      final r = parkIconSize(s) / 2 * _ratio;
      final color = potaStatusColor(s);
      // The ring
      final ring = await pixel(image, c, (c + r - 3.4 * _ratio).round());
      expect(near(ring, color), isTrue, reason: 'ring was $ring');
      // The middle is white, not filled: sample beside the glyph
      final side = await pixel(image, c - (r - 6 * _ratio).round(), c);
      expect(near(side, Colors.white), isTrue, reason: 'middle was $side');
      // The glyph is in the status colour
      var coloured = 0;
      for (var y = c - 8; y < c + 8; y++) {
        for (var x = c - 8; x < c + 8; x++) {
          if (near(await pixel(image, x, y), color)) coloured++;
        }
      }
      expect(coloured, greaterThan(20));
      icons.dispose();
    });
  });

  testWidgets('the glyph is a tree and a bench: ink on the left half for the '
      'tree, and a row of ink on the right for the bench', (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      paintParkGlyph(canvas, const Rect.fromLTWH(0, 0, 48, 48), Colors.black);
      final image = await recorder.endRecording().toImage(48, 48);
      final bytes = (await image.toByteData())!.buffer.asUint8List();
      bool ink(int x, int y) => bytes[(y * 48 + x) * 4 + 3] > 128;
      // The tree: the trunk, and the point of its crown
      expect(ink(16, 34), isTrue, reason: 'trunk');
      expect(ink(16, 6), isTrue, reason: 'top of the tree');
      // The bench: its seat and its back span the same width, with a gap
      // between them, and its legs reach below the seat
      expect(ink(36, 30), isTrue, reason: 'seat');
      expect(ink(36, 23), isTrue, reason: 'back');
      expect(ink(36, 27), isFalse, reason: 'gap between back and seat');
      expect(ink(30, 38), isTrue, reason: 'leg');
      // And the corner is empty
      expect(ink(0, 0), isFalse);
      expect(ink(47, 0), isFalse);
      image.dispose();
    });
  });
}
