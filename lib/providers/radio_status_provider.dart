import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'remote_datasource_provider.dart';
import 'rig_provider.dart';
import 'settings_provider.dart';

/// Reports the radio's frequency and mode to Wavelog while the CAT link is
/// up, like desktop CAT tools do: right away on every change, and every
/// [heartbeat] even when nothing changes, so Wavelog's on-air widget can
/// tell a rig sitting on one frequency from one that was unplugged.
/// Kept alive from app start (app.dart), next to rigProvider.
final radioStatusProvider = Provider<void>((ref) {
  const heartbeat = Duration(seconds: 30);
  Timer? timer;
  // One request in flight; a change arriving meanwhile is sent right after,
  // with the rig's state at that moment, so the last dial position always
  // reaches Wavelog without waiting for the heartbeat.
  var busy = false;
  var pending = false;

  Future<void> push() async {
    if (busy) {
      pending = true;
      return;
    }
    busy = true;
    try {
      do {
        pending = false;
        final rig = ref.read(rigProvider);
        final hz = rig.frequencyHz;
        if (rig.status != RigStatus.connected || hz == null) return;
        if (ref.read(settingsProvider).serverUrl.isEmpty) return;
        try {
          await ref.read(wavelogRemoteDatasourceProvider).pushRadioStatus(
                radio: rig.config.protocol.wavelogRadioName,
                frequencyHz: hz,
                mode: rig.mode?.appSubmode ?? rig.mode?.appMode,
              );
        } catch (e) {
          // Offline, or a token without radio:write: the log works without it.
          debugPrint('radio status push failed: $e');
          return;
        }
      } while (pending);
    } finally {
      busy = false;
    }
  }

  ref.listen<RigState>(rigProvider, (prev, next) {
    final live = next.status == RigStatus.connected && next.frequencyHz != null;
    if (!live) {
      timer?.cancel();
      timer = null;
      return;
    }
    timer ??= Timer.periodic(heartbeat, (_) => push());
    if (prev?.frequencyHz != next.frequencyHz || prev?.mode != next.mode) push();
  });
  ref.onDispose(() => timer?.cancel());
});
