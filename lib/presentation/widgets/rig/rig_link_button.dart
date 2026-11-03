import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/l10n_extension.dart';
import '../../../providers/rig_provider.dart';
import '../../screens/rig/rig_screen.dart';

/// Frequency-field suffix: lit while the radio's CAT link is up, opens the
/// radio connection screen on tap.
class RigLinkButton extends ConsumerWidget {
  const RigLinkButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(
        rigProvider.select((s) => s.status == RigStatus.connected));
    return IconButton(
      tooltip: context.l10n.rigScreenTitle,
      icon: Icon(
        connected ? Icons.settings_input_antenna : Icons.usb_off,
        color: connected ? Theme.of(context).colorScheme.primary : null,
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const RigScreen()),
      ),
    );
  }
}
