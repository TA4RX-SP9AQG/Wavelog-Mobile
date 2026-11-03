import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/rig/cat_protocol.dart';
import '../core/services/rig_serial_service.dart';
import '../data/datasources/local/settings_local_datasource.dart';
import '../data/models/rig_config_model.dart';
import 'settings_provider.dart';

enum RigStatus { disconnected, connecting, connected }

class RigState {
  final RigConfig config;
  final RigStatus status;
  final RigUsbDevice? device;

  /// Last frequency the radio reported, in Hz. Null until the first reply.
  final int? frequencyHz;

  /// Last mode the radio reported. Null until the first reply, and for
  /// data modes, which say nothing about FT8 vs PSK (see [RigMode]).
  final RigMode? mode;

  /// Platform error code of the last failed connection or lost link
  /// (`PERMISSION_DENIED`, `DETACHED`, …), cleared on the next connect.
  final String? errorCode;

  const RigState({
    this.config = const RigConfig(),
    this.status = RigStatus.disconnected,
    this.device,
    this.frequencyHz,
    this.mode,
    this.errorCode,
  });
}

/// App-wide radio link: stays connected while the user moves between
/// screens, so every QSO form can follow the radio's dial. Kept alive from
/// app start (app.dart) so it can connect as soon as the radio is plugged in.
final rigProvider = StateNotifierProvider<RigNotifier, RigState>((ref) {
  return RigNotifier(RigSerialService(), ref.watch(settingsLocalDatasourceProvider));
});

class RigNotifier extends StateNotifier<RigState> {
  // Icom CI-V asks for frequency and mode on alternate polls.
  static const _pollInterval = Duration(milliseconds: 300);

  final RigSerialService _serial;
  final SettingsLocalDatasource _settings;

  StreamSubscription<Uint8List>? _dataSub;
  Timer? _pollTimer;
  CatCodec? _codec;

  RigNotifier(this._serial, this._settings) : super(const RigState()) {
    _serial.setOnDeviceAttached(_autoConnect);
    _settings.getRigConfig().then((config) {
      if (!mounted) return;
      state = RigState(config: config);
      _autoConnect();
    });
  }

  /// Changing protocol or baud rate drops the link; reconnect to apply.
  Future<void> setConfig(RigConfig config) async {
    if (state.status != RigStatus.disconnected) await disconnect();
    state = RigState(config: config);
    await _settings.saveRigConfig(config);
  }

  /// Changes only whether to connect automatically; keeps the link up.
  Future<void> setAutoConnect(bool on) async {
    final config = state.config.copyWith(autoConnect: on);
    state = _copy(config: config);
    await _settings.saveRigConfig(config);
  }

  Future<List<RigUsbDevice>> listDevices() => _serial.listDevices();

  Future<void> connect(RigUsbDevice device) async {
    await disconnect();
    final config = state.config.copyWith(
        lastVendorId: device.vendorId, lastProductId: device.productId);
    state = RigState(config: config, status: RigStatus.connecting, device: device);
    try {
      await _serial.open(device, baudRate: config.baudRate);
    } on PlatformException catch (e) {
      if (mounted) state = RigState(config: config, errorCode: e.code);
      return;
    }
    await _settings.saveRigConfig(config);
    final codec = CatCodec(config.protocol, civAddress: config.civAddress);
    _codec = codec;
    _dataSub = _serial.data.listen(
      (bytes) {
        var hz = state.frequencyHz;
        var mode = state.mode;
        for (final u in codec.feed(bytes)) {
          hz = u.frequencyHz ?? hz;
          mode = u.mode ?? mode;
        }
        if (hz != state.frequencyHz || mode != state.mode) {
          state = _copy(frequencyHz: hz, mode: mode);
        }
      },
      onError: (Object e) => _lost(e is PlatformException ? e.code : 'IO_ERROR'),
    );
    state = RigState(config: config, status: RigStatus.connected, device: device);
    _poll();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  /// Tunes the radio to [hz] and, when given, [mode] — no-op while not
  /// connected. Goes out on the next poll tick, ahead of the next query.
  void tune(int hz, {RigMode? mode}) => _codec?.tune(hz, mode);

  Future<void> disconnect() async {
    _stop();
    state = RigState(config: state.config);
    await _serial.close();
  }

  /// Connects to the radio used last time (or the only serial device, if
  /// none is remembered yet) when Android already allows opening it: at app
  /// start, and when the cable is plugged in.
  Future<void> _autoConnect() async {
    if (!state.config.autoConnect || state.status != RigStatus.disconnected) {
      return;
    }
    final List<RigUsbDevice> devices;
    try {
      devices = (await _serial.listDevices())
          .where((d) => d.hasPermission)
          .toList();
    } on PlatformException {
      return;
    }
    final config = state.config;
    final device = devices.firstWhereOrNull((d) =>
            d.vendorId == config.lastVendorId &&
            d.productId == config.lastProductId) ??
        (devices.length == 1 ? devices.single : null);
    if (device != null && mounted && state.status == RigStatus.disconnected) {
      await connect(device);
    }
  }

  void _poll() {
    final codec = _codec;
    if (codec == null) return;
    _serial.write(codec.nextPoll()).catchError((Object e) {
      _lost(e is PlatformException ? e.code : 'IO_ERROR');
    });
  }

  void _lost(String code) {
    _stop();
    if (mounted) state = RigState(config: state.config, errorCode: code);
  }

  void _stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _dataSub?.cancel();
    _dataSub = null;
    _codec = null;
  }

  RigState _copy({RigConfig? config, int? frequencyHz, RigMode? mode}) =>
      RigState(
        config: config ?? state.config,
        status: state.status,
        device: state.device,
        frequencyHz: frequencyHz ?? state.frequencyHz,
        mode: mode ?? state.mode,
        errorCode: state.errorCode,
      );

  @override
  void dispose() {
    _stop();
    _serial.close();
    super.dispose();
  }
}
