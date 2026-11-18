import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:wavelog_mobile/core/utils/tile_cache.dart';

/// A tile server that counts how often it is asked.
class FakeServer extends BaseClient {
  var asked = 0;
  var status = 200;
  Object? failWith;
  String contentType = 'image/png';
  String? cacheControl = 'public, max-age=86400';
  Uint8List body = Uint8List.fromList(List.generate(300, (i) => i % 251));

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    asked++;
    if (failWith != null) throw failWith!;
    return StreamedResponse(Stream.value(body), status,
        contentLength: body.length,
        request: request,
        headers: {
          'content-type': contentType,
          if (cacheControl != null) 'cache-control': cacheControl!,
        });
  }
}

void main() {
  late Directory dir;
  late FakeServer server;
  late DateTime clock;
  late TileCacheClient cache;
  final tile = Uri.parse('https://a.tile.opentopomap.org/11/1118/674.png');

  Future<Uint8List> get(Uri url, {TileCacheClient? via}) async =>
      (await (via ?? cache).get(url)).bodyBytes;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tiles_test');
    server = FakeServer();
    clock = DateTime.utc(2026, 11, 7, 12);
    cache = TileCacheClient(
        inner: server, directory: dir, now: () => clock);
  });

  tearDown(() async {
    // Background writes and pruning may still be finishing
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
        return;
      } on FileSystemException {
        // try again
      }
    }
  });

  /// The cache stores a tile without making the caller wait for the disk.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

  test('a tile seen before comes from the disk, not the server', () async {
    final first = await get(tile);
    await settle();
    final second = await get(tile);
    expect(second, first);
    expect(server.asked, 1);
  });

  test('it survives a restart: a new client reads the same files', () async {
    await get(tile);
    await settle();
    final again = TileCacheClient(inner: server, directory: dir, now: () => clock);
    await get(tile, via: again);
    expect(server.asked, 1);
  });

  test('each URL has its own tile', () async {
    final other = Uri.parse('https://a.tile.opentopomap.org/11/1118/675.png');
    await get(tile);
    server.body = Uint8List.fromList([9, 9, 9]);
    await settle();
    expect(await get(other), [9, 9, 9]);
    await settle();
    expect(await get(tile), isNot([9, 9, 9]));
    expect(server.asked, 2);
  });

  group('how long a tile is kept', () {
    test("as the server says, and not longer", () async {
      server.cacheControl = 'max-age=7200'; // two hours
      await get(tile);
      await settle();

      clock = clock.add(const Duration(minutes: 119));
      await get(tile);
      expect(server.asked, 1);

      clock = clock.add(const Duration(minutes: 2));
      await get(tile);
      expect(server.asked, 2);
    });

    test('a day when the server says nothing', () async {
      server.cacheControl = null;
      await get(tile);
      await settle();
      clock = clock.add(const Duration(hours: 23));
      await get(tile);
      expect(server.asked, 1);
      clock = clock.add(const Duration(hours: 2));
      await get(tile);
      expect(server.asked, 2);
    });

    test('never less than an hour nor more than a week', () async {
      server.cacheControl = 'max-age=5';
      await get(tile);
      await settle();
      clock = clock.add(const Duration(minutes: 59));
      await get(tile);
      expect(server.asked, 1);

      final other = Uri.parse('https://a.tile.opentopomap.org/11/1/1.png');
      server.cacheControl = 'max-age=99999999';
      await get(other);
      await settle();
      clock = clock.add(const Duration(days: 6, hours: 23));
      await get(other);
      expect(server.asked, 2);
      clock = clock.add(const Duration(hours: 2));
      await get(other);
      expect(server.asked, 3);
    });
  });

  group('when the network fails', () {
    test('an out-of-date tile is better than none', () async {
      await get(tile);
      await settle();
      clock = clock.add(const Duration(days: 3));
      server.failWith = const SocketException('offline');
      final old = await get(tile);
      expect(old, isNotEmpty);
    });

    test('a server error also falls back to the old tile', () async {
      await get(tile);
      await settle();
      clock = clock.add(const Duration(days: 3));
      server.status = 503;
      final response = await cache.get(tile);
      expect(response.statusCode, 200);
      expect(response.bodyBytes, isNotEmpty);
    });

    test('with nothing kept, the error reaches the caller', () async {
      server.failWith = const SocketException('offline');
      await expectLater(cache.get(tile), throwsA(isA<SocketException>()));
    });
  });

  group('what is not kept', () {
    test('an error page is passed on, not stored', () async {
      server.status = 404;
      final r = await cache.get(tile);
      expect(r.statusCode, 404);
      await settle();
      server.status = 200;
      await get(tile);
      expect(server.asked, 2);
    });

    test('something that is not an image is not stored', () async {
      server.contentType = 'text/html';
      await get(tile);
      await settle();
      await get(tile);
      expect(server.asked, 2);
    });

    test('an oversized body is passed on, not stored', () async {
      server.body = Uint8List(600 * 1024);
      final body = await get(tile);
      expect(body.length, 600 * 1024);
      await settle();
      await get(tile);
      expect(server.asked, 2);
    });

    test('only GET is cached', () async {
      await cache.post(tile);
      await cache.post(tile);
      expect(server.asked, 2);
      expect(await dir.list().toList(), isEmpty);
    });
  });

  test('a damaged file is ignored and fetched again', () async {
    await get(tile);
    await settle();
    for (final f in await dir.list().toList()) {
      await (f as File).writeAsBytes([1, 2, 3]);
    }
    await get(tile);
    expect(server.asked, 2);
  });

  group('the size limit', () {
    test('the oldest tiles go first, down to 80% of the limit', () async {
      final small = TileCacheClient(
          inner: server, directory: dir, maxBytes: 1000, now: () => clock);
      server.body = Uint8List(300);
      // Five tiles of 308 bytes: 1540, over the 1000 limit
      for (var i = 0; i < 5; i++) {
        final f = File('${dir.path}${Platform.pathSeparator}t$i.tile');
        await f.writeAsBytes(Uint8List(308));
        await f.setLastModified(DateTime.utc(2026, 1, 1 + i));
      }
      await small.prune();
      final left = [
        for (final f in await dir.list().toList()) f.uri.pathSegments.last
      ]..sort();
      // 800 bytes are allowed: the two newest fit
      expect(left, ['t3.tile', 't4.tile']);
    });

    test('an old half-written file is removed, a recent one is left',
        () async {
      final old = File('${dir.path}${Platform.pathSeparator}old.tile.part');
      final recent = File('${dir.path}${Platform.pathSeparator}new.tile.part');
      await old.writeAsBytes([1]);
      await recent.writeAsBytes([1]);
      await old.setLastModified(DateTime.now().subtract(const Duration(hours: 2)));
      final real = TileCacheClient(inner: server, directory: dir);
      await real.prune();
      expect(await old.exists(), isFalse);
      expect(await recent.exists(), isTrue);
    });

    test('under the limit, nothing is removed', () async {
      await get(tile);
      await settle();
      await cache.prune();
      expect(await dir.list().toList(), hasLength(1));
    });
  });
}
