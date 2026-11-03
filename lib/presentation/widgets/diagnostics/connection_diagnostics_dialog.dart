import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/l10n_extension.dart';

/// Runs a connection diagnostics and shows its report, which can be copied
/// and pasted into a bug report. [run] returns the report text.
Future<void> showConnectionDiagnostics(
  BuildContext context, {
  required Future<String> Function() run,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ConnectionDiagnosticsDialog(run: run),
  );
}

class ConnectionDiagnosticsDialog extends StatefulWidget {
  final Future<String> Function() run;
  const ConnectionDiagnosticsDialog({super.key, required this.run});

  @override
  State<ConnectionDiagnosticsDialog> createState() =>
      _ConnectionDiagnosticsDialogState();
}

class _ConnectionDiagnosticsDialogState
    extends State<ConnectionDiagnosticsDialog> {
  late final Future<String> _report = widget.run();
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.connectionDiagnosticsTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<String>(
          future: _report,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return Row(children: [
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 16),
                Expanded(child: Text(l10n.connectionDiagnosticsRunning)),
              ]);
            }
            final text = snap.data ?? '${snap.error}';
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.connectionDiagnosticsHint,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      text,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11, height: 1.35),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        FutureBuilder<String>(
          future: _report,
          builder: (context, snap) => TextButton.icon(
            onPressed: snap.hasData
                ? () async {
                    await Clipboard.setData(ClipboardData(text: snap.data!));
                    if (mounted) setState(() => _copied = true);
                  }
                : null,
            icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
            label: Text(_copied
                ? l10n.connectionDiagnosticsCopied
                : l10n.connectionDiagnosticsCopy),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
