import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart';

/// Map tiles kept on the device, so that a place seen before shows at once
/// and with no network, and the tile servers are asked less often.
///
/// A tile is kept for as long as its server says (`Cache-Control: max-age`),
/// within [minTtl] and [maxTtl]; with no such header, [defaultTtl]. When the
/// network fails, an out-of-date tile is still better than a blank one.
class TileCacheClient extends BaseClient {
  final BaseClient _inner;
  final Directory _dir;
  final int maxBytes;
  final Duration defaultTtl;
  final Duration minTtl;
  final Duration maxTtl;
  final DateTime Function() _now;
  var _pruned = false;

  TileCacheClient({
    required BaseClient inner,
    required Directory directory,
    this.maxBytes = 120 * 1024 * 1024,
    this.defaultTtl = const Duration(days: 1),
    this.minTtl = const Duration(hours: 1),
    this.maxTtl = const Duration(days: 7),
    DateTime Function()? now,
  })  : _inner = inner,
        _dir = directory,
        _now = now ?? DateTime.now;

  /// Tiles are small; anything bigger is not a tile.
  static const _maxTileBytes = 512 * 1024;
  static const _headerBytes = 8; // the expiry, as milliseconds since 1970

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (request.method != 'GET') return _inner.send(request);
    final file = _file(request.url);
    final cached = await _read(file);
    if (cached != null && cached.expires.isAfter(_now())) {
      return _answer(request, cached.body);
    }

    final StreamedResponse live;
    try {
      live = await _inner.send(request);
    } catch (_) {
      // No network: an old tile still beats an empty square
      if (cached != null) return _answer(request, cached.body);
      rethrow;
    }

    final isImage =
        (live.headers['content-type'] ?? '').toLowerCase().startsWith('image/');
    if (live.statusCode != 200 || !isImage) {
      if (cached != null && live.statusCode >= 500) {
        await live.stream.drain<void>();
        return _answer(request, cached.body);
      }
      return live;
    }

    final bytes = await live.stream.toBytes();
    if (bytes.isNotEmpty && bytes.length <= _maxTileBytes) {
      // Pruning waits for the write: it must not meet the file half-written
      unawaited(_write(file, bytes, _now().add(_ttl(live.headers)))
          .whenComplete(_pruneOnce));
    }
    return StreamedResponse(
      Stream.value(bytes),
      live.statusCode,
      contentLength: bytes.length,
      request: request,
      headers: live.headers,
      reasonPhrase: live.reasonPhrase,
    );
  }

  Duration _ttl(Map<String, String> headers) {
    final control = headers['cache-control'] ?? '';
    final match = RegExp(r'max-age=(\d+)').firstMatch(control);
    final ttl = match == null
        ? defaultTtl
        : Duration(seconds: int.parse(match.group(1)!));
    if (ttl < minTtl) return minTtl;
    if (ttl > maxTtl) return maxTtl;
    return ttl;
  }

  StreamedResponse _answer(BaseRequest request, Uint8List body) =>
      StreamedResponse(
        Stream.value(body),
        200,
        contentLength: body.length,
        request: request,
        headers: const {'content-type': 'image/png'},
      );

  /// The URL itself, made safe for a file name, so no two tiles share one.
  File _file(Uri url) {
    final name = base64Url.encode(utf8.encode(url.toString())).replaceAll('=', '');
    return File('${_dir.path}${Platform.pathSeparator}$name.tile');
  }

  Future<({DateTime expires, Uint8List body})?> _read(File file) async {
    try {
      final data = await file.readAsBytes();
      if (data.length <= _headerBytes) return null;
      final expiry = ByteData.sublistView(data, 0, _headerBytes).getInt64(0);
      return (
        expires: DateTime.fromMillisecondsSinceEpoch(expiry),
        body: Uint8List.sublistView(data, _headerBytes),
      );
    } catch (_) {
      return null; // not there, or not readable
    }
  }

  Future<void> _write(File file, Uint8List body, DateTime expires) async {
    try {
      await _dir.create(recursive: true);
      final data = BytesBuilder(copy: false)
        ..add((ByteData(_headerBytes)
              ..setInt64(0, expires.millisecondsSinceEpoch))
            .buffer
            .asUint8List())
        ..add(body);
      // Written aside and renamed, so a half-written tile is never read
      final temp = File('${file.path}.part');
      await temp.writeAsBytes(data.takeBytes(), flush: true);
      await temp.rename(file.path);
    } catch (e) {
      debugPrint('Tile cache: could not store a tile: $e');
    }
  }

  void _pruneOnce() {
    if (_pruned) return;
    _pruned = true;
    unawaited(prune());
  }

  /// Removes leftovers, then the oldest tiles until the cache is back under 80% of its limit.
  Future<void> prune() async {
    try {
      final files = <({File file, int size, DateTime modified})>[];
      var total = 0;
      await for (final e in _dir.list()) {
        if (e is! File) continue;
        final stat = await e.stat();
        if (e.path.endsWith('.part')) {
          // Left by a write that never finished; a recent one is still going
          if (_now().difference(stat.modified) > const Duration(minutes: 10)) {
            try {
              await e.delete();
            } catch (_) {}
          }
          continue;
        }
        files.add((file: e, size: stat.size, modified: stat.modified));
        total += stat.size;
      }
      if (total <= maxBytes) return;
      files.sort((a, b) => a.modified.compareTo(b.modified));
      for (final f in files) {
        if (total <= maxBytes * 0.8) break;
        try {
          await f.file.delete();
        } catch (_) {
          continue; // gone already, or in use: the next one
        }
        total -= f.size;
      }
    } catch (e) {
      debugPrint('Tile cache: pruning failed: $e');
    }
  }

  @override
  void close() => _inner.close();
}
