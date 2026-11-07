import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/data/datasources/local/pota_squares_store.dart';
import 'package:wavelog_mobile/data/models/pota_park_model.dart';

PotaParkPoint park(String ref, {bool atno = false, String? name}) =>
    PotaParkPoint(
        reference: ref,
        name: name ?? 'Park $ref',
        lat: 52.5,
        lon: 21.25,
        neverActivated: atno);

void main() {
  late Directory dir;
  late FilePotaSquaresStore store;
  final at = DateTime.fromMillisecondsSinceEpoch(1790000000000);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('squares_test');
    store = FilePotaSquaresStore(() async => dir);
  });

  tearDown(() async {
    for (var i = 0; i < 10; i++) {
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  test('what was saved is read back, whole', () async {
    await store.write('KO02', [
      park('PL-0001'),
      park('PL-0002', atno: true, name: 'Dąbrowy Seroczyńskie "Reserve", 1'),
    ], at);
    final back = (await store.read('KO02'))!;
    expect(back.at, at);
    expect(back.parks.map((p) => p.reference), ['PL-0001', 'PL-0002']);
    expect(back.parks[0].neverActivated, isFalse);
    expect(back.parks[1].neverActivated, isTrue);
    expect(back.parks[1].name, 'Dąbrowy Seroczyńskie "Reserve", 1');
    expect(back.parks[1].lat, 52.5);
    expect(back.parks[1].lon, 21.25);
  });

  test('an empty square is a result too', () async {
    await store.write('KO03', [], at);
    final back = (await store.read('KO03'))!;
    expect(back.parks, isEmpty);
    expect(back.at, at);
  });

  test('a square never saved is null, not an error', () async {
    expect(await store.read('KO99'), isNull);
  });

  test('a new save replaces the old', () async {
    await store.write('KO02', [park('PL-0001')], at);
    await store.write('KO02', [park('PL-0009')], at.add(const Duration(hours: 1)));
    final back = (await store.read('KO02'))!;
    expect(back.parks.single.reference, 'PL-0009');
    expect(back.at, at.add(const Duration(hours: 1)));
  });

  test('a damaged file is null, and a damaged park is skipped', () async {
    await File('${dir.path}${Platform.pathSeparator}KO02.json')
        .writeAsString('{not json');
    expect(await store.read('KO02'), isNull);

    await File('${dir.path}${Platform.pathSeparator}KO03.json').writeAsString(
        '{"at": 1790000000000, "parks": [["PL-0001","A",52.5,21.0,0], '
        '["PL-0002", 5, 1, 2, 0], "junk", ["PL-0003","C","x",2,0], '
        '["PL-0004","D",50.0,20.0,1]]}');
    final back = (await store.read('KO03'))!;
    expect(back.parks.map((p) => p.reference), ['PL-0001', 'PL-0004']);
    expect(back.parks.last.neverActivated, isTrue);

    await File('${dir.path}${Platform.pathSeparator}KO04.json')
        .writeAsString('{"at": "yesterday", "parks": []}');
    expect(await store.read('KO04'), isNull);
  });

  test('it never throws: a place that cannot be written is just empty',
      () async {
    final broken = FilePotaSquaresStore(() async => throw Exception('no disk'));
    await broken.write('KO02', [park('PL-0001')], at); // must not throw
    expect(await broken.read('KO02'), isNull);
  });

  test('the oldest squares go when there are more than the limit', () async {
    final small = FilePotaSquaresStore(() async => dir, maxSquares: 3);
    // The store prunes every 20th save
    for (var i = 0; i < 20; i++) {
      final name = 'S${i.toString().padLeft(2, '0')}';
      await small.write(name, [park('X-$i')], at);
      await File('${dir.path}${Platform.pathSeparator}$name.json')
          .setLastModified(DateTime.utc(2026, 1, 1 + i));
    }
    final left = [
      for (final f in await dir.list().toList()) f.uri.pathSegments.last
    ]..sort();
    expect(left, ['S17.json', 'S18.json', 'S19.json']);
  });
}
