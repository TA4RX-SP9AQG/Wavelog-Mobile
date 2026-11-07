import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/presentation/widgets/map/base_map.dart';

void main() {
  group('tilesFor', () {
    test('auto follows the theme', () {
      expect(tilesFor(BaseMap.auto, false).darkened, isFalse);
      expect(tilesFor(BaseMap.auto, true).darkened, isTrue);
      expect(tilesFor(BaseMap.auto, true).url, tilesFor(BaseMap.light, true).url);
    });

    test('dark is the light tiles seen through the filter', () {
      final dark = tilesFor(BaseMap.dark, false);
      expect(dark.darkened, isTrue);
      expect(dark.url, tilesFor(BaseMap.light, false).url);
    });

    test('topo has subdomains, a lower native zoom and its own credit', () {
      final topo = tilesFor(BaseMap.topo, false);
      expect(topo.subdomains, ['a', 'b', 'c']);
      expect(topo.maxZoom, 17);
      expect(topo.attribution, contains('OpenTopoMap'));
      expect(topo.attribution, contains('OpenStreetMap'));
    });

    test('every background names OpenStreetMap', () {
      for (final b in BaseMap.values) {
        expect(tilesFor(b, false).attribution, contains('OpenStreetMap'),
            reason: '$b');
      }
    });
  });

  test('a saved name that is gone falls back to auto', () {
    expect(BaseMap.fromName('topo'), BaseMap.topo);
    expect(BaseMap.fromName('esri'), BaseMap.auto);
    expect(BaseMap.fromName(null), BaseMap.auto);
  });
}
