import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/data/datasources/remote/pota_datasource.dart';
import 'package:wavelog_mobile/presentation/widgets/pota/pota_park_autocomplete.dart';

/// pota.app search without the network; [offline] makes it fail.
class _FakePota extends PotaDatasource {
  final bool offline;
  final queries = <String>[];
  _FakePota({this.offline = false});

  @override
  Future<List<({String reference, String name})>> searchParks(String query,
      {int size = 8}) async {
    queries.add(query);
    if (offline) throw Exception('offline');
    return [
      (reference: 'PL-0194', name: 'Biebrzański National Park'),
      (reference: 'PL-2213', name: 'Dolina Biebrzy Protected Landscape Area'),
    ];
  }
}

void main() {
  Future<List<PotaPark>> pump(WidgetTester tester, _FakePota pota) async {
    final picked = <PotaPark>[];
    final ctrl = TextEditingController();
    final focus = FocusNode();
    addTearDown(ctrl.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PotaParkAutocomplete(
          controller: ctrl,
          focusNode: focus,
          datasource: pota,
          onSelected: picked.add,
          fieldBuilder: (context, _) =>
              TextField(controller: ctrl, focusNode: focus),
        ),
      ),
    ));
    return picked;
  }

  testWidgets('typing a name suggests parks, a tap picks one', (tester) async {
    final pota = _FakePota();
    final picked = await pump(tester, pota);

    await tester.enterText(find.byType(TextField), 'bie');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'biebrz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    // Only the text after the pause in typing was searched.
    expect(pota.queries, ['biebrz']);
    expect(find.text('Biebrzański National Park'), findsOneWidget);

    await tester.tap(find.text('PL-0194'));
    await tester.pump();
    expect(picked.single.reference, 'PL-0194');
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('offline, the field just takes typing', (tester) async {
    final picked = await pump(tester, _FakePota(offline: true));
    await tester.enterText(find.byType(TextField), 'PL-0341');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byType(ListTile), findsNothing);
    expect(picked, isEmpty);
  });

  test('a POTA reference is told from a name being searched', () {
    expect(potaRefPattern.hasMatch('PL-0341'), isTrue);
    expect(potaRefPattern.hasMatch('US-12345'), isTrue);
    expect(potaRefPattern.hasMatch('BIEBRZ'), isFalse);
    expect(potaRefPattern.hasMatch('PL-03'), isFalse);
  });
}
