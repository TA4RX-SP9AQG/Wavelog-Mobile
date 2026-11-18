import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Where the device is, or why it could not be found.
@immutable
sealed class PotaLocation {
  const PotaLocation();
}

final class PotaLocationFix extends PotaLocation {
  final double lat;
  final double lon;
  const PotaLocationFix(this.lat, this.lon);
}

/// No permission. [forever]: the system will not ask again, so only the
/// app's settings page can change it.
final class PotaLocationDenied extends PotaLocation {
  final bool forever;
  const PotaLocationDenied({this.forever = false});
}

/// The device's location setting is off.
final class PotaLocationServiceOff extends PotaLocation {
  const PotaLocationServiceOff();
}

/// Permission and setting are fine, but no position came (a time-out,
/// no satellites, an error).
final class PotaLocationFailed extends PotaLocation {
  const PotaLocationFailed();
}

/// The device location for the park map, behind an interface so that tests
/// need no plugin.
abstract class PotaLocationService {
  /// The last position the system knows, with no prompt and no wait. Null when
  /// there is none or the permission has not been granted already.
  Future<PotaLocationFix?> lastKnown();

  /// A fresh position. [askPermission] false never opens the permission
  /// prompt: a permission not granted yet is just [PotaLocationDenied].
  Future<PotaLocation> locate({required bool askPermission});

  Future<void> openAppSettings();
  Future<void> openLocationSettings();
}

/// How long a fresh position may take.
const kPotaLocationTimeout = Duration(seconds: 8);

class GeolocatorPotaLocationService implements PotaLocationService {
  const GeolocatorPotaLocationService();

  Future<bool> _granted() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  @override
  Future<PotaLocationFix?> lastKnown() async {
    try {
      if (!await _granted()) return null;
      final p = await Geolocator.getLastKnownPosition();
      return p == null ? null : PotaLocationFix(p.latitude, p.longitude);
    } catch (e) {
      debugPrint('POTA map: last known position failed: $e');
      return null;
    }
  }

  @override
  Future<PotaLocation> locate({required bool askPermission}) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && askPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const PotaLocationDenied(forever: true);
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        return const PotaLocationDenied();
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const PotaLocationServiceOff();
      }
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: kPotaLocationTimeout,
      );
      return PotaLocationFix(p.latitude, p.longitude);
    } catch (e) {
      debugPrint('POTA map: position failed: $e');
      return const PotaLocationFailed();
    }
  }

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}

final potaLocationServiceProvider = Provider<PotaLocationService>(
    (_) => const GeolocatorPotaLocationService());

/// The positions to centre the map on when it opens: the last known one at
/// once, then a fresh one if it comes. Never asks for the permission; with
/// none granted the stream is empty and the map stays where it was put.
Stream<PotaLocationFix> openingPositions(PotaLocationService service) async* {
  final last = await service.lastKnown();
  if (last != null) yield last;
  final fresh = await service.locate(askPermission: false);
  if (fresh is PotaLocationFix) yield fresh;
}
