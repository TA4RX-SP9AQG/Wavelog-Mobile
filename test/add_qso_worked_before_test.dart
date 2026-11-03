import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavelog_mobile/data/datasources/remote/wavelog_remote_datasource.dart';
import 'package:wavelog_mobile/data/models/callsign_lookup_model.dart';
import 'package:wavelog_mobile/data/models/qso_model.dart';
import 'package:wavelog_mobile/l10n/app_localizations.dart';
import 'package:wavelog_mobile/presentation/screens/qso/add_qso_screen.dart';
import 'package:wavelog_mobile/providers/qso_provider.dart';
import 'package:wavelog_mobile/providers/remote_datasource_provider.dart';
import 'package:wavelog_mobile/providers/worked_before_provider.dart';

class _OfflineRemote extends WavelogRemoteDatasource {
  _OfflineRemote() : super(dio: Dio());

  @override
  Future<CallsignLookupModel> lookupCallsign(
          {required String callsign, String? band, String? mode}) =>
      Future.error(Exception('offline'));
}

void main() {
  testWidgets('a callsign already worked today on this band/mode is a dupe',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Tall phone-sized surface, so the whole form lays out.
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final earlier = QsoModel(
      callsign: 'SP9AQG',
      dateTimeOn: DateTime.now().toUtc(),
      band: '20m', // the form's defaults
      mode: 'SSB',
      rstSent: '59',
      rstRcvd: '59',
      stationProfileId: 1,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        wavelogRemoteDatasourceProvider.overrideWithValue(_OfflineRemote()),
        scopedQsoProvider.overrideWithValue(AsyncValue.data([earlier])),
        dxccMatcherProvider.overrideWith((ref) => null),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AddQsoScreen(),
      ),
    ));
    await tester.pump();

    final field = find.byType(TextFormField).first;
    await tester.enterText(field, 'SP9AQG');
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.textContaining('Dupe'), findsOneWidget);

    await tester.enterText(field, 'SP9XYZ');
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.textContaining('Dupe'), findsNothing);
  });
}
