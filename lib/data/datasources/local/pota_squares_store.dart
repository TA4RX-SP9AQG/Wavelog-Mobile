import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/pota_park_model.dart';

/// The parks of one grid square, as last saved.
class StoredSquare {
  final List<PotaParkPoint> parks;

  /// When the parks were fetched from pota.app.
  final DateTime at;
  const StoredSquare(this.parks, this.at);
}

/// Where the parks of the squares already seen are kept between visits, so
/// that a map seen before shows its parks at once, even with no network.
abstract class PotaSquaresStore {
  /// The square as saved, or null when it was never saved or cannot be read.
  Future<StoredSquare?> read(String square);

  Future<void> write(String square, List<PotaParkPoint> parks, DateTime at);
}

/// [PotaSquaresStore] in the app's cache folder, one small file per square.
/// Never throws: a store that cannot read or write is the same as an empty one.
class FilePotaSquaresStore implements PotaSquaresStore {
  final Future<Directory> Function() _directory;
  final int maxSquares;
  Directory? _dir;
  var _writes = 0;

  FilePotaSquaresStore(this._directory, {this.maxSquares = 250});

  /// In the app's cache folder.
  factory FilePotaSquaresStore.inCache() => FilePotaSquaresStore(() async {
        final tmp = await getTemporaryDirectory();
        return Directory('${tmp.path}${Platform.pathSeparator}pota_squares');
      });

  Future<File> _file(String square) async {
    final dir = _dir ??= await _directory();
    return File('${dir.path}${Platform.pathSeparator}$square.json');
  }

  @override
  Future<StoredSquare?> read(String square) async {
    try {
      final text = await (await _file(square)).readAsString();
      final data = jsonDecode(text);
      if (data is! Map) return null;
      final at = data['at'];
      final list = data['parks'];
      if (at is! int || list is! List) return null;
      final parks = <PotaParkPoint>[];
      for (final p in list) {
        if (p is! List || p.length < 5) continue;
        final ref = p[0], name = p[1], lat = p[2], lon = p[3];
        if (ref is! String || name is! String || lat is! num || lon is! num) {
          continue;
        }
        parks.add(PotaParkPoint(
          reference: ref,
          name: name,
          lat: lat.toDouble(),
          lon: lon.toDouble(),
          neverActivated: p[4] == 1,
        ));
      }
      return StoredSquare(parks, DateTime.fromMillisecondsSinceEpoch(at));
    } catch (_) {
      return null; // not there, or not readable
    }
  }

  @override
  Future<void> write(
      String square, List<PotaParkPoint> parks, DateTime at) async {
    try {
      final file = await _file(square);
      await file.parent.create(recursive: true);
      final json = jsonEncode({
        'at': at.millisecondsSinceEpoch,
        'parks': [
          for (final p in parks)
            [p.reference, p.name, p.lat, p.lon, p.neverActivated ? 1 : 0],
        ],
      });
      // Written aside and renamed, so a half-written file is never read
      final temp = File('${file.path}.part');
      await temp.writeAsString(json, flush: true);
      await temp.rename(file.path);
      if (++_writes % 20 == 0) await _prune(file.parent);
    } catch (e) {
      debugPrint('Park squares: could not save $square: $e');
    }
  }

  /// Keeps the [maxSquares] most recently saved squares.
  Future<void> _prune(Directory dir) async {
    try {
      final files = <({File file, DateTime modified})>[];
      await for (final e in dir.list()) {
        if (e is File && e.path.endsWith('.json')) {
          files.add((file: e, modified: (await e.stat()).modified));
        }
      }
      if (files.length <= maxSquares) return;
      files.sort((a, b) => a.modified.compareTo(b.modified));
      for (final f in files.take(files.length - maxSquares)) {
        try {
          await f.file.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }
}
