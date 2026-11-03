import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavelog_mobile/data/datasources/remote/wavelog_remote_datasource.dart';
import 'package:wavelog_mobile/data/models/callsign_lookup_model.dart';
import 'package:wavelog_mobile/l10n/app_localizations.dart';
import 'package:wavelog_mobile/presentation/screens/qso/add_qso_screen.dart';
import 'package:wavelog_mobile/providers/remote_datasource_provider.dart';

class _FakeRemote extends WavelogRemoteDatasource {
  final lookups = <String>[];
  _FakeRemote() : super(dio: Dio());

  @override
  Future<CallsignLookupModel> lookupCallsign(
      {required String callsign, String? band, String? mode}) async {
    lookups.add(callsign);
    throw Exception('offline');
  }
}

void main() {
  testWidgets('first callsign typed on a fresh form is looked up',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Tall phone-sized surface, so the whole form lays out.
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final remote = _FakeRemote();
    await tester.pumpWidget(ProviderScope(
      overrides: [wavelogRemoteDatasourceProvider.overrideWithValue(remote)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AddQsoScreen(),
      ),
    ));
    await tester.pump();

    final field = find.byType(TextFormField).first;
    for (final text in ['S', 'SP', 'SP9', 'SP9A', 'SP9AQ', 'SP9AQG']) {
      await tester.enterText(field, text);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 700));
    // Only the complete callsign is looked up, never the partial ones typed
    // before it. (The inline previous-QSOs panel also looks it up on its
    // own, so the count alone doesn't prove the form did.)
    expect(remote.lookups, everyElement('SP9AQG'));
    // The form's own lookup ran and finished (failed, offline): the search
    // button gave way to the "not found" mark without being tapped.
    expect(find.descendant(of: field, matching: find.byIcon(Icons.search)),
        findsNothing);
    expect(
        find.descendant(of: field, matching: find.byIcon(Icons.help_outline)),
        findsOneWidget);
  });
}
