import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/l10n_extension.dart';

/// Editable "paper QSL" status block for the QSO edit form. Controlled
/// component: seeds itself once from [initial] (raw-ADIF QSL_* keys) and
/// reports the full replacement state for [keys] via [onChanged] on every
/// change — the caller is responsible for merging (see [keys]).
class PaperQslEditFields extends StatefulWidget {
  /// The raw-ADIF keys this widget owns. Callers use this to clear stale
  /// values from a base map before merging in the emitted patch, since an
  /// unset switch simply omits its keys rather than emitting an explicit
  /// deletion marker.
  static const keys = {
    'QSL_SENT',
    'QSL_RCVD',
    'QSL_SENT_VIA',
    'QSL_RCVD_VIA',
    'QSLSDATE',
    'QSLRDATE',
  };

  final Map<String, String> initial;
  final ValueChanged<Map<String, String>> onChanged;

  const PaperQslEditFields({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<PaperQslEditFields> createState() => _PaperQslEditFieldsState();
}

class _PaperQslEditFieldsState extends State<PaperQslEditFields> {
  late bool _sent;
  late bool _rcvd;
  late String _sentVia;
  late String _rcvdVia;
  DateTime? _sentDate;
  DateTime? _rcvdDate;

  static final _df = DateFormat('dd.MM.yyyy');

  @override
  void initState() {
    super.initState();
    _sent = widget.initial['QSL_SENT']?.toUpperCase() == 'Y';
    _rcvd = widget.initial['QSL_RCVD']?.toUpperCase() == 'Y';
    _sentVia = widget.initial['QSL_SENT_VIA'] ?? 'D';
    _rcvdVia = widget.initial['QSL_RCVD_VIA'] ?? 'D';
    _sentDate = _parseAdifDate(widget.initial['QSLSDATE']);
    _rcvdDate = _parseAdifDate(widget.initial['QSLRDATE']);
  }

  static DateTime? _parseAdifDate(String? raw) {
    if (raw == null || raw.length < 8) return null;
    final y = int.tryParse(raw.substring(0, 4));
    final m = int.tryParse(raw.substring(4, 6));
    final d = int.tryParse(raw.substring(6, 8));
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  static String _formatAdifDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';

  void _emit() {
    final map = <String, String>{};
    if (_sent) {
      map['QSL_SENT'] = 'Y';
      map['QSL_SENT_VIA'] = _sentVia;
      if (_sentDate != null) map['QSLSDATE'] = _formatAdifDate(_sentDate!);
    }
    if (_rcvd) {
      map['QSL_RCVD'] = 'Y';
      map['QSL_RCVD_VIA'] = _rcvdVia;
      if (_rcvdDate != null) map['QSLRDATE'] = _formatAdifDate(_rcvdDate!);
    }
    widget.onChanged(map);
  }

  Future<void> _pickDate(bool isSent) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isSent ? _sentDate : _rcvdDate) ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      if (isSent) {
        _sentDate = picked;
      } else {
        _rcvdDate = picked;
      }
    });
    _emit();
  }

  Widget _row({
    required String switchLabel,
    required bool value,
    required String via,
    required DateTime? date,
    required ValueChanged<bool> onValueChanged,
    required ValueChanged<String?> onViaChanged,
    required VoidCallback onPickDate,
  }) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(switchLabel),
          value: value,
          onChanged: (v) {
            setState(() => onValueChanged(v));
            _emit();
          },
        ),
        if (value)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: via,
                    decoration: InputDecoration(labelText: l10n.qslMethod),
                    items: [
                      DropdownMenuItem(value: 'D', child: Text(l10n.viaDirect)),
                      DropdownMenuItem(value: 'B', child: Text(l10n.bureau)),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => onViaChanged(v));
                      _emit();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    onPressed: onPickDate,
                    label: Text(
                      date != null ? _df.format(date) : l10n.qslPickDate,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.paperQslFull,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        _row(
          switchLabel: l10n.qslMarkSent,
          value: _sent,
          via: _sentVia,
          date: _sentDate,
          onValueChanged: (v) => _sent = v,
          onViaChanged: (v) => _sentVia = v!,
          onPickDate: () => _pickDate(true),
        ),
        _row(
          switchLabel: l10n.qslMarkReceived,
          value: _rcvd,
          via: _rcvdVia,
          date: _rcvdDate,
          onValueChanged: (v) => _rcvd = v,
          onViaChanged: (v) => _rcvdVia = v!,
          onPickDate: () => _pickDate(false),
        ),
      ],
    );
  }
}
