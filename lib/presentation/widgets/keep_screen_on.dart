import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';

/// Keeps the screen on while a logging screen is open, when the "keep the
/// screen on while logging" setting is enabled. Logging a QSO takes longer
/// than a short system screen timeout (15 s is common), and the screen going
/// dark mid-contact gets in the way. Leaving the screen restores the system
/// timeout; Android only applies the flag while the app is in front anyway.
///
/// A screen calls [start] from initState and [stop] from dispose.
class KeepScreenOn {
  static const _channel = MethodChannel('com.wavelog_mobile/screen');

  /// Screens currently asking for it: the contest log can open Add QSO on
  /// top, and closing that one must not let the screen go dark under it.
  static int _holders = 0;

  bool _holding = false;
  ProviderSubscription<bool>? _setting;

  void start(WidgetRef ref) {
    _setting = ref.listenManual<bool>(
      settingsProvider.select((s) => s.keepScreenOnWhileLogging),
      (_, enabled) => _hold(enabled),
      fireImmediately: true,
    );
  }

  void stop() {
    _setting?.close();
    _setting = null;
    _hold(false);
  }

  void _hold(bool hold) {
    if (hold == _holding) return;
    _holding = hold;
    final before = _holders > 0;
    _holders += hold ? 1 : -1;
    final after = _holders > 0;
    if (before != after) {
      _channel.invokeMethod<void>('setKeepScreenOn', after).catchError((_) {});
    }
  }
}
