import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connectivity_provider.dart';
import 'qso_provider.dart';
import 'settings_provider.dart';
import 'sync_controller.dart';

/// Keeps the offline queue draining without the user doing anything:
///  * the moment the device comes back online,
///  * when the app returns to the foreground,
///  * and every [_retryInterval] while something is still queued (covers a
///    server that was unreachable, or a connection that dropped mid-sync).
///
/// The manual "Offline mode" switch is respected: while it is on, nothing is
/// sent automatically. The sync page's button still works in that mode.
final autoSyncProvider = Provider<void>((ref) {
  final auto = _AutoSync(ref)..start();
  ref.onDispose(auto.dispose);
});

class _AutoSync with WidgetsBindingObserver {
  static const _retryInterval = Duration(seconds: 30);

  final Ref _ref;
  Timer? _timer;

  _AutoSync(this._ref);

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _ref.listen<bool>(isOnlineProvider, (prev, next) {
      if (next && prev == false) _trySync();
    });
    _timer = Timer.periodic(_retryInterval, (_) => _trySync());
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _trySync();
  }

  Future<void> _trySync() async {
    if (!_ref.read(isOnlineProvider)) return;
    final settings = _ref.read(settingsProvider);
    if (settings.offlineModeEnabled || !settings.isLoggedIn) return;

    final report = await _ref.read(syncControllerProvider.notifier).sync();
    // Pull the fresh list so synced QSOs pick up their server IDs.
    if (report != null && (report.synced > 0 || report.deletesDone > 0)) {
      _ref.invalidate(qsoProvider);
    }
  }
}
