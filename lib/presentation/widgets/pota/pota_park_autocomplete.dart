import 'package:flutter/material.dart';

import '../../../data/datasources/remote/pota_datasource.dart';

typedef PotaPark = ({String reference, String name});

/// A POTA park reference as typed or logged, e.g. "PL-0341" or "US-12345".
final potaRefPattern = RegExp(r'^[A-Z0-9]{1,4}-\d{4,5}$');

/// Wraps a POTA reference field with pota.app park suggestions while
/// typing, by reference ("PL-034") or by name ("biebrz"). Without network
/// no suggestions show and the field works as a plain text field.
///
/// [fieldBuilder] builds the field itself on [controller] / [focusNode];
/// its `selectHighlighted` callback picks the highlighted suggestion (for
/// Enter on a typed name).
class PotaParkAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<PotaPark> onSelected;
  final Widget Function(BuildContext context, VoidCallback selectHighlighted)
      fieldBuilder;

  /// For tests; defaults to the live pota.app API.
  final PotaDatasource? datasource;

  const PotaParkAutocomplete({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSelected,
    required this.fieldBuilder,
    this.datasource,
  });

  @override
  State<PotaParkAutocomplete> createState() => _PotaParkAutocompleteState();
}

class _PotaParkAutocompleteState extends State<PotaParkAutocomplete> {
  late final PotaDatasource _pota = widget.datasource ?? PotaDatasource();
  int _querySeq = 0;

  Future<Iterable<PotaPark>> _options(TextEditingValue value) async {
    final query = value.text.trim();
    if (query.length < 3) return const [];
    // Wait for a pause in typing, then search only for the latest text.
    final seq = ++_querySeq;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (seq != _querySeq || !mounted) return const [];
    try {
      return await _pota.searchParks(query);
    } catch (_) {
      return const []; // offline or pota.app down: plain typing
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<PotaPark>(
      textEditingController: widget.controller,
      focusNode: widget.focusNode,
      displayStringForOption: (p) => p.reference,
      optionsBuilder: _options,
      onSelected: widget.onSelected,
      fieldViewBuilder: (context, _, __, onFieldSubmitted) =>
          widget.fieldBuilder(context, onFieldSubmitted),
      optionsViewBuilder: (context, onSelected, options) {
        final cs = Theme.of(context).colorScheme;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            color: cs.surfaceContainerHigh,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, maxWidth: 420),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final p in options)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.park_outlined, size: 20),
                      title: Text(p.reference,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: p.name.isEmpty ? null : Text(p.name),
                      onTap: () => onSelected(p),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
