import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/rig/cat_protocol.dart';
import '../../../core/services/rig_serial_service.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../providers/rig_provider.dart';

/// Radio CAT setup: protocol, baud rate, USB device, and the live frequency.
class RigScreen extends ConsumerStatefulWidget {
  const RigScreen({super.key});

  @override
  ConsumerState<RigScreen> createState() => _RigScreenState();
}

class _RigScreenState extends ConsumerState<RigScreen> {
  static const _baudRates = [4800, 9600, 19200, 38400, 57600, 115200];

  List<RigUsbDevice>? _devices;
  late final TextEditingController _civCtrl;

  @override
  void initState() {
    super.initState();
    _civCtrl = TextEditingController(
        text: _hex(ref.read(rigProvider).config.civAddress));
    // The saved config loads asynchronously the first time the provider is
    // read, which may be this screen.
    ref.listenManual<int>(rigProvider.select((s) => s.config.civAddress),
        (_, addr) {
      if (_civCtrl.text.toUpperCase() != _hex(addr)) _civCtrl.text = _hex(addr);
    });
    _refreshDevices();
  }

  @override
  void dispose() {
    _civCtrl.dispose();
    super.dispose();
  }

  static String _hex(int v) => v.toRadixString(16).toUpperCase().padLeft(2, '0');

  Future<void> _refreshDevices() async {
    final devices = await ref.read(rigProvider.notifier).listDevices();
    if (mounted) setState(() => _devices = devices);
  }

  String _protocolLabel(CatProtocol p) => switch (p) {
        CatProtocol.icomCiv => context.l10n.rigProtocolIcom,
        CatProtocol.xieguCiv => context.l10n.rigProtocolXiegu,
        CatProtocol.kenwood => context.l10n.rigProtocolKenwood,
        CatProtocol.yaesuLegacy => context.l10n.rigProtocolYaesuLegacy,
      };

  String _errorText(String code) => switch (code) {
        'PERMISSION_DENIED' => context.l10n.rigErrorPermission,
        'DETACHED' => context.l10n.rigErrorDetached,
        _ => context.l10n.rigErrorConnection(code),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rig = ref.watch(rigProvider);
    final notifier = ref.read(rigProvider.notifier);
    final config = rig.config;
    final scheme = Theme.of(context).colorScheme;

    final hz = rig.frequencyHz;
    final statusText = switch (rig.status) {
      RigStatus.connected => l10n.rigStatusConnected(rig.device?.name ?? ''),
      RigStatus.connecting => l10n.rigStatusConnecting,
      RigStatus.disconnected => l10n.rigStatusDisconnected,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.rigScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Live status ─────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(statusText, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    hz != null ? '${formatRigFreqMhz(hz)} MHz' : '—',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontFamily: 'JetBrains Mono',
                          color: rig.status == RigStatus.connected
                              ? scheme.primary
                              : null,
                        ),
                  ),
                  if (rig.mode != null)
                    Text(
                      '${rig.mode!.appMode} ${rig.mode!.appSubmode ?? ''}'.trim(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  if (rig.status == RigStatus.connected && hz == null) ...[
                    const SizedBox(height: 8),
                    Text(l10n.rigWaitingForData),
                  ],
                  if (rig.errorCode != null) ...[
                    const SizedBox(height: 8),
                    Text(_errorText(rig.errorCode!),
                        style: TextStyle(color: scheme.error)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Protocol settings ───────────────────────────────────────
          DropdownButtonFormField<CatProtocol>(
            key: ValueKey(config.protocol),
            initialValue: config.protocol,
            decoration: InputDecoration(labelText: l10n.rigProtocolLabel),
            items: [
              for (final p in CatProtocol.values)
                DropdownMenuItem(value: p, child: Text(_protocolLabel(p))),
            ],
            onChanged: (p) {
              if (p == null) return;
              notifier.setConfig(config.copyWith(
                protocol: p,
                baudRate: p.defaultBaudRate,
                civAddress: p.defaultCivAddress,
              ));
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            // Rebuilt when the protocol change resets it to the default.
            key: ValueKey('${config.protocol.name}-${config.baudRate}'),
            initialValue: config.baudRate,
            decoration: InputDecoration(labelText: l10n.rigBaudLabel),
            items: [
              for (final b in _baudRates)
                DropdownMenuItem(value: b, child: Text('$b')),
            ],
            onChanged: (b) {
              if (b != null) notifier.setConfig(config.copyWith(baudRate: b));
            },
          ),
          if (config.protocol.usesCiv) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _civCtrl,
              decoration: InputDecoration(
                labelText: l10n.rigCivAddressLabel,
                helperText: l10n.rigCivAddressHint,
                prefixText: '0x',
              ),
              maxLength: 2,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
              ],
              onChanged: (v) {
                final addr = int.tryParse(v, radix: 16);
                if (v.length == 2 && addr != null) {
                  notifier.setConfig(config.copyWith(civAddress: addr));
                }
              },
            ),
          ],
          const SizedBox(height: 16),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.rigAutoConnect),
            subtitle: Text(l10n.rigAutoConnectHint),
            value: config.autoConnect,
            onChanged: notifier.setAutoConnect,
          ),
          const SizedBox(height: 8),

          // ── USB devices ─────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(l10n.rigDevicesLabel,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              IconButton(
                tooltip: l10n.rigRefresh,
                icon: const Icon(Icons.refresh),
                onPressed: _refreshDevices,
              ),
            ],
          ),
          if (_devices == null)
            const Center(child: CircularProgressIndicator())
          else if (_devices!.isEmpty)
            Text(l10n.rigNoDevices)
          else
            for (final d in _devices!) _deviceTile(d, rig, notifier),
        ],
      ),
    );
  }

  Widget _deviceTile(RigUsbDevice d, RigState rig, RigNotifier notifier) {
    final l10n = context.l10n;
    final isThis = rig.device?.deviceId == d.deviceId &&
        rig.status != RigStatus.disconnected;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.usb),
      title: Text(d.name),
      subtitle: Text(d.driver),
      trailing: isThis
          ? OutlinedButton(
              onPressed: notifier.disconnect,
              child: Text(l10n.rigDisconnect),
            )
          : FilledButton(
              onPressed: rig.status == RigStatus.connecting
                  ? null
                  : () => notifier.connect(d),
              child: Text(l10n.rigConnect),
            ),
    );
  }
}
