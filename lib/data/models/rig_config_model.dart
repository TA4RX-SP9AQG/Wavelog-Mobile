import '../../core/rig/cat_protocol.dart';

/// How to talk to the radio's CAT port; persisted by SettingsLocalDatasource.
class RigConfig {
  final CatProtocol protocol;
  final int baudRate;

  /// Icom CI-V address of the radio (0x94 = IC-7300 default).
  final int civAddress;

  /// Connect on its own when the radio's USB cable is plugged in, or when
  /// the app starts with it already plugged in.
  final bool autoConnect;

  /// USB vendor/product ID of the last device connected to, so automatic
  /// connection picks the radio and not some other serial adapter.
  final int? lastVendorId;
  final int? lastProductId;

  const RigConfig({
    this.protocol = CatProtocol.icomCiv,
    this.baudRate = 19200,
    this.civAddress = 0x94,
    this.autoConnect = true,
    this.lastVendorId,
    this.lastProductId,
  });

  RigConfig copyWith({
    CatProtocol? protocol,
    int? baudRate,
    int? civAddress,
    bool? autoConnect,
    int? lastVendorId,
    int? lastProductId,
  }) =>
      RigConfig(
        protocol: protocol ?? this.protocol,
        baudRate: baudRate ?? this.baudRate,
        civAddress: civAddress ?? this.civAddress,
        autoConnect: autoConnect ?? this.autoConnect,
        lastVendorId: lastVendorId ?? this.lastVendorId,
        lastProductId: lastProductId ?? this.lastProductId,
      );
}
