import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavelog_mobile/data/datasources/remote/wavelog_remote_datasource.dart';
import 'package:wavelog_mobile/data/models/callsign_lookup_model.dart';
import 'package:wavelog_mobile/data/models/station_model.dart';
import 'package:wavelog_mobile/l10n/app_localizations.dart';
import 'package:wavelog_mobile/presentation/screens/qso/add_qso_screen.dart';
import 'package:wavelog_mobile/providers/qso_provider.dart';
import 'package:wavelog_mobile/providers/remote_datasource_provider.dart';
import 'package:wavelog_mobile/providers/settings_provider.dart';
import 'package:wavelog_mobile/providers/station_provider.dart';

class _OfflineRemote extends WavelogRemoteDatasource {
  _OfflineRemote() : super(dio: Dio());

  @override
  Future<CallsignLookupModel> lookupCallsign(
          {required String callsign, String? band, String? mode}) =>
      Future.error(Exception('offline'));
}

class _Stations extends StationNotifier {
  @override
  Future<List<StationModel>> build() async => const [
        StationModel(id: 1, profileName: 'Dom', callsign: 'SP4BL', isActive: true),
        StationModel(id: 2, profileName: 'Teren1', callsign: 'SP4BL/P'),
      ];
}

void main() {
  testWidgets('picking a station in the form leaves the active station alone',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Settings are saved to secure storage too; without it a save fails
    // before the active station would change, and the test would pass
    // whatever the form does.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => null);
    // No radio attached.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.wavelog_mobile/rig_serial'),
            (call) async => call.method == 'listDevices' ? <Object>[] : null);
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      wavelogRemoteDatasourceProvider.overrideWithValue(_OfflineRemote()),
      scopedQsoProvider.overrideWithValue(const AsyncValue.data([])),
      stationProvider.overrideWith(_Stations.new),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AddQsoScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    final before = container.read(settingsProvider).activeStationProfileId;

    final picker = find.byType(DropdownButtonFormField<StationModel>);
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('SP4BL/P — Teren1').last);
    await tester.pumpAndSettle();
    // Let a settings save, if the form started one, really finish.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();

    expect(find.text('SP4BL/P — Teren1'), findsOneWidget); // chosen here
    expect(container.read(settingsProvider).activeStationProfileId, before);
    expect(before, isNot(2));
  });
}
