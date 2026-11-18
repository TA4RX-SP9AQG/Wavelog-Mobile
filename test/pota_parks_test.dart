import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/core/utils/maidenhead.dart';
import 'package:wavelog_mobile/core/utils/pota_parks.dart';

void main() {
  group('gridSquare4', () {
    test('known places', () {
      expect(gridSquare4(52.2, 21.0), 'KO02'); // Warsaw
      expect(gridSquare4(40.7, -74.0), 'FN30'); // New York
      expect(gridSquare4(-33.9, 151.2), 'QF56'); // Sydney
      expect(gridSquare4(41.0, 29.0), 'KN41'); // Istanbul
    });

    test('agrees with the 6-character locator everywhere', () {
      for (var lat = -89.5; lat < 90; lat += 7.3) {
        for (var lon = -179.5; lon < 180; lon += 11.7) {
          expect(gridSquare4(lat, lon), latLngToGrid(lat, lon)!.substring(0, 4),
              reason: '$lat,$lon');
        }
      }
    });

    test('a point exactly on a border belongs to the square above and east',
        () {
      expect(gridSquare4(52.0, 20.0), 'KO02');
      expect(gridSquare4(51.999999, 19.999999), 'JO91');
    });

    test('the poles and the date line are in the last squares', () {
      expect(gridSquare4(90, 180), 'RR99');
      expect(gridSquare4(-90, -180), 'AA00');
    });
  });

  group('square edges', () {
    test('bounds and centre', () {
      expect(squareBounds('KO02'),
          (south: 52.0, west: 20.0, north: 53.0, east: 22.0));
      expect(squareCentre('ko02'), (lat: 52.5, lon: 21.0));
    });

    test('the centre is inside its own square', () {
      for (final s in ['AA00', 'RR99', 'JJ00', 'KO02', 'FN30']) {
        final c = squareCentre(s);
        expect(gridSquare4(c.lat, c.lon), s);
      }
    });

    test('a bad name is refused', () {
      expect(() => squareBounds('KO0'), throwsArgumentError);
      expect(() => squareBounds('SO02'), throwsArgumentError);
      expect(() => squareBounds('KO0A'), throwsArgumentError);
    });
  });

  group('squaresCovering', () {
    test('a view inside one square is that square', () {
      final r = squaresCovering(south: 52.2, west: 20.2, north: 52.8, east: 21.8);
      expect(r.squares, ['KO02']);
      expect(r.tooMany, isFalse);
    });

    test('a view across a border lists both sides, nearest first', () {
      final r = squaresCovering(
        south: 52.2,
        west: 21.8,
        north: 52.8,
        east: 22.4,
        near: (lat: 52.5, lon: 22.3),
      );
      expect(r.squares, ['KO12', 'KO02']);
      final other = squaresCovering(
        south: 52.2,
        west: 21.8,
        north: 52.8,
        east: 22.4,
        near: (lat: 52.5, lon: 21.9),
      );
      expect(other.squares, ['KO02', 'KO12']);
    });

    test('an edge exactly on a border does not pull in the next square', () {
      final r = squaresCovering(south: 52.0, west: 20.0, north: 53.0, east: 22.0);
      expect(r.squares, ['KO02']);
    });

    test('four squares around a corner', () {
      final r = squaresCovering(south: 51.5, west: 19.0, north: 52.5, east: 21.0);
      expect(r.squares.toSet(), {'JO91', 'JO92', 'KO01', 'KO02'});
      expect(r.squares, hasLength(4));
    });

    test('a view across the date line is split', () {
      final r = squaresCovering(south: 10.2, west: 179.0, north: 10.8, east: -179.0);
      expect(r.squares.toSet(), {'RK90', 'AK00'});
      expect(r.tooMany, isFalse);
    });

    test('too wide a view loads nothing', () {
      final r = squaresCovering(south: 40, west: 0, north: 60, east: 40);
      expect(r.tooMany, isTrue);
      expect(r.squares, isEmpty);
      final world =
          squaresCovering(south: -90, west: -180, north: 90, east: 180);
      expect(world.tooMany, isTrue);
    });

    test('the limit is on the number of squares, not on the size', () {
      // 4 x 4 squares: allowed at the default limit, refused at 15
      const box = (south: 50.0, west: 20.0, north: 54.0, east: 28.0);
      final ok = squaresCovering(
          south: box.south, west: box.west, north: box.north, east: box.east);
      expect(ok.squares, hasLength(16));
      final no = squaresCovering(
          south: box.south,
          west: box.west,
          north: box.north,
          east: box.east,
          maxSquares: 15);
      expect(no.tooMany, isTrue);
    });

    test('a view reaching past the poles or the date line is clamped', () {
      final r = squaresCovering(south: 89.5, west: 179.5, north: 95, east: 190);
      expect(r.squares, ['RR99']);
    });
  });

  group('park status', () {
    PotaParkStatus status({
      bool atno = false,
      Set<String>? activated = const {},
      Set<String>? hunted = const {},
    }) =>
        parkStatus(
          ref: 'pl-0001',
          neverActivated: atno,
          activated: activated,
          hunted: hunted,
        );

    test('activated beats hunted beats never-activated', () {
      expect(status(activated: {'PL-0001'}, hunted: {'PL-0001'}, atno: true),
          PotaParkStatus.activated);
      expect(status(hunted: {'PL-0001'}, atno: true), PotaParkStatus.hunted);
      expect(status(atno: true), PotaParkStatus.neverActivated);
      expect(status(), PotaParkStatus.other);
    });

    test('the card lists every status that applies', () {
      expect(
        parkStatuses(
          ref: 'PL-0001',
          neverActivated: true,
          activated: const {'PL-0001'},
          hunted: const {'PL-0001'},
        ),
        [
          PotaParkStatus.activated,
          PotaParkStatus.hunted,
          PotaParkStatus.neverActivated,
        ],
      );
    });

    test('while the log loads only pota.app decides', () {
      expect(status(activated: null, hunted: null), PotaParkStatus.other);
      expect(status(activated: null, hunted: null, atno: true),
          PotaParkStatus.neverActivated);
    });
  });

  test('compass points', () {
    expect(compassPoint(0), CompassPoint.n);
    expect(compassPoint(22.4), CompassPoint.n);
    expect(compassPoint(22.5), CompassPoint.ne);
    expect(compassPoint(90), CompassPoint.e);
    expect(compassPoint(135), CompassPoint.se);
    expect(compassPoint(180), CompassPoint.s);
    expect(compassPoint(225), CompassPoint.sw);
    expect(compassPoint(270), CompassPoint.w);
    expect(compassPoint(315), CompassPoint.nw);
    expect(compassPoint(337.5), CompassPoint.n);
    expect(compassPoint(359.9), CompassPoint.n);
    expect(compassPoint(-90), CompassPoint.w);
    expect(compassPoint(720), CompassPoint.n);
  });
}
