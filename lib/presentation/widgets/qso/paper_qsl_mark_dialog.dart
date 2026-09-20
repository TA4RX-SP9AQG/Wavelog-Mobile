import 'package:flutter/material.dart';

import '../../../core/utils/l10n_extension.dart';

/// Result of [showPaperQslMarkDialog]. `cleared == true` means the user
/// removed the existing mark; otherwise [via] ('D'/'B') and [date] hold the
/// new state.
class PaperQslMarkResult {
  final String? via;
  final DateTime? date;
  final bool cleared;

  const PaperQslMarkResult({this.via, this.date, this.cleared = false});
}

/// Quick one-tap dialog for marking a paper QSL card as sent/received (or
/// clearing an existing mark), from the QSO detail screen.
Future<PaperQslMarkResult?> showPaperQslMarkDialog(
  BuildContext context, {
  required bool isSent,
  String? initialVia,
  String? initialAdifDate,
  bool alreadyMarked = false,
}) {
  return showDialog<PaperQslMarkResult>(
    context: context,
    builder: (_) => _PaperQslMarkDialog(
      isSent: isSent,
      initialVia: initialVia,
      initialAdifDate: initialAdifDate,
      alreadyMarked: alreadyMarked,
    ),
  );
}

DateTime? _parseAdifDate(String? raw) {
  if (raw == null || raw.length < 8) return null;
  final y = int.tryParse(raw.substring(0, 4));
  final m = int.tryParse(raw.substring(4, 6));
  final d = int.tryParse(raw.substring(6, 8));
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

class _PaperQslMarkDialog extends StatefulWidget {
  final bool isSent;
  final String? initialVia;
  final String? initialAdifDate;
  final bool alreadyMarked;

  const _PaperQslMarkDialog({
    required this.isSent,
    this.initialVia,
    this.initialAdifDate,
    required this.alreadyMarked,
  });

  @override
  State<_PaperQslMarkDialog> createState() => _PaperQslMarkDialogState();
}

class _PaperQslMarkDialogState extends State<_PaperQslMarkDialog> {
  late String _via;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _via = widget.initialVia ?? 'D';
    _date = _parseAdifDate(widget.initialAdifDate) ?? DateTime.now();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = widget.isSent ? l10n.qslMarkSent : l10n.qslMarkReceived;

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'D', label: Text(l10n.viaDirect)),
              ButtonSegment(value: 'B', label: Text(l10n.bureau)),
            ],
            selected: {_via},
            onSelectionChanged: (s) => setState(() => _via = s.first),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            onPressed: _pickDate,
            label: Text(
              '${_date.year.toString().padLeft(4, '0')}-'
              '${_date.month.toString().padLeft(2, '0')}-'
              '${_date.day.toString().padLeft(2, '0')}',
            ),
          ),
        ],
      ),
      actions: [
        if (widget.alreadyMarked)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              const PaperQslMarkResult(cleared: true),
            ),
            child: Text(
              l10n.clear,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            PaperQslMarkResult(via: _via, date: _date),
          ),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
