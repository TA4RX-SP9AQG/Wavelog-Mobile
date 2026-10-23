import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Connectivity as reported by the OS. The plugin's stream only emits on
/// *changes*, so the current state is read first — otherwise an app started
/// offline would look online (and a stale value could outlive reconnection).
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) async* {
  final connectivity = Connectivity();
  yield await connectivity.checkConnectivity();
  yield* connectivity.onConnectivityChanged;
});

/// True when any network interface is up. Every result except `none` counts:
/// `other` (e.g. some VPN/tethering setups) and `bluetooth` tethering carry
/// real traffic too, and treating them as offline left the banner stuck.
final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (results) => results.any((r) => r != ConnectivityResult.none),
    loading: () => true,
    error: (_, __) => true,
  );
});
