import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavelog_mobile/core/utils/pota_parks.dart';
import 'package:wavelog_mobile/data/datasources/remote/pota_parks_datasource.dart';
import 'package:wavelog_mobile/data/models/pota_park_model.dart';
import 'package:wavelog_mobile/l10n/app_localizations.dart';
import 'package:wavelog_mobile/presentation/screens/pota/pota_map_screen.dart';
import 'package:wavelog_mobile/providers/connectivity_provider.dart';
import 'package:wavelog_mobile/providers/pota_location_provider.dart';
import 'package:wavelog_mobile/providers/pota_parks_provider.dart';
import 'package:wavelog_mobile/providers/pota_stats_provider.dart';

/// Tiles that cost nothing: one transparent pixel for every tile.
class _BlankTiles extends TileProvider {
  static final _png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_png);
}

PotaParkPoint park(String ref, double lat, double lon,
        {String? name, bool atno = false}) =>
    PotaParkPoint(
        reference: ref,
        name: name ?? 'Park $ref',
        lat: lat,
        lon: lon,
        neverActivated: atno);

class FakeApi implements PotaParksDatasource {
  /// Parks by 4-character square.
  final Map<String, List<PotaParkPoint>> squares = {};
  final asked = <String>[];
  Object? failWith;
  Map<String, PotaParkDetail?> details = {};

  @override
  Future<List<PotaParkPoint>> parksInSquare(String grid4) async {
    asked.add(grid4);
    if (failWith != null) throw failWith!;
    return squares[grid4] ?? const [];
  }

  @override
  Future<PotaParkDetail?> getDetail(String reference) async =>
      details[reference];

  @override
  Future<PotaParkStats?> getStats(String reference) async => null;

  @override
  Future<List<PotaActivation>> getRecentActivations(String reference,
          {int count = 5}) async =>
      const [];
}

class FakeLocation implements PotaLocationService {
  PotaLocationFix? last;
  PotaLocation fresh = const PotaLocationDenied();
  PotaLocation onButton = const PotaLocationDenied();

  /// Holds the fresh fix back until the test lets it through.
  Completer<void>? gate;
  var settingsOpened = 0;
  var locationSettingsOpened = 0;

  @override
  Future<PotaLocationFix?> lastKnown() async => last;

  @override
  Future<PotaLocation> locate({required bool askPermission}) async {
    if (askPermission) return onButton;
    await gate?.future;
    return fresh;
  }

  @override
  Future<void> openAppSettings() async => settingsOpened++;

  @override
  Future<void> openLocationSettings() async => locationSettingsOpened++;
}

const warsaw = LatLng(52.5, 21.0); // the middle of the square KO02

final online = StateProvider<bool>((_) => true);

Future<ProviderContainer> open(
  WidgetTester tester,
  FakeApi api, {
  FakeLocation? location,
  LatLng? home = warsaw,
  Set<String>? activated = const {},
  Set<String>? hunted = const {},
  String? goTo,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(routes: [
    GoRoute(
        path: '/',
        builder: (_, __) => PotaMapScreen(tileProvider: _BlankTiles())),
    GoRoute(
      path: '/add-qso',
      builder: (_, s) => Scaffold(
          body: Text('QSO form for ${s.uri.queryParameters['pota']}')),
    ),
  ]);
  final container = ProviderContainer(overrides: [
    potaParksDatasourceProvider.overrideWithValue(api),
    potaLocationServiceProvider.overrideWithValue(location ?? FakeLocation()),
    potaMapHomeProvider.overrideWithValue(home),
    activatedParksProvider.overrideWithValue(activated),
    huntedParksProvider.overrideWithValue(hunted),
    isOnlineProvider.overrideWith((ref) => ref.watch(online)),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await settle(tester);
  return container;
}

/// Lets the map get ready, the squares load and the debounce pass.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// The dots (the layer above the rings that set them off from the map).
List<CircleMarker> circles(WidgetTester tester) =>
    tester.widget<CircleLayer>(find.byType(CircleLayer).last).circles;

Future<void> tapMapCentre(WidgetTester tester) async {
  await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('draws the parks of the squares in view, by status',
      (tester) async {
    final api = FakeApi()
      ..squares['KO02'] = [
        park('PL-0001', 52.5, 21.0),
        park('PL-0002', 52.55, 21.05),
        park('PL-0003', 52.4, 20.9, atno: true),
        park('PL-0004', 52.6, 21.1),
      ];
    await open(tester, api,
        activated: {'PL-0001'}, hunted: {'PL-0002'});

    expect(api.asked, contains('KO02'));
    final drawn = circles(tester);
    expect(drawn, hasLength(4));
    // Four statuses, four looks
    expect(drawn.map((c) => c.radius).toSet(), {9.0, 8.0, 7.0});
    expect(drawn.where((c) => c.color == const Color(0xFF1E6BFF)), hasLength(1));
    expect(drawn.where((c) => c.color == const Color(0xFF00C853)), hasLength(1));
    // The never-activated one is a ring: colour in the border, an empty middle
    final ring = drawn.singleWhere(
        (c) => c.borderColor == const Color(0xFFFF3D00));
    expect(ring.borderStrokeWidth, greaterThan(3));
    expect(ring.color, isNot(const Color(0xFFFF3D00)));
    // Every dot has a ring of its own beneath it
    final rings =
        tester.widget<CircleLayer>(find.byType(CircleLayer).first).circles;
    expect(rings, hasLength(4));
  });

  testWidgets('a filter chip hides a status and brings it back',
      (tester) async {
    final api = FakeApi()
      ..squares['KO02'] = [
        park('PL-0001', 52.5, 21.0),
        park('PL-0002', 52.55, 21.05),
      ];
    await open(tester, api, hunted: {'PL-0002'});
    expect(circles(tester), hasLength(2));

    await tester.tap(find.text('Hunted'));
    await tester.pump();
    expect(circles(tester), hasLength(1));

    await tester.tap(find.text('Hunted'));
    await tester.pump();
    expect(circles(tester), hasLength(2));
  });

  testWidgets('the park map opens on the terrain map, with a choice of its own',
      (tester) async {
    await open(tester, FakeApi());
    final layer =
        tester.widget<TileLayer>(find.byType(TileLayer));
    expect(layer.urlTemplate, contains('opentopomap.org'));

    await tester.tap(find.byTooltip('Map layers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wl_pota_map_base'), 'light');
    // The QSO map's own choice is left alone
    expect(prefs.getString('wl_map_base'), isNull);
  });

  testWidgets('the choice of statuses is remembered', (tester) async {
    final api = FakeApi()..squares['KO02'] = [park('PL-0001', 52.5, 21.0)];
    await open(tester, api);
    await tester.ensureVisible(find.text('Other parks'));
    await tester.pump();
    await tester.tap(find.text('Other parks'));
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('wl_pota_map_hidden'), ['other']);
  });

  testWidgets('tapping a dot opens its card; closing it leaves the map',
      (tester) async {
    final api = FakeApi()
      ..squares['KO02'] = [park('PL-0001', 52.5, 21.0, name: 'Test Forest')];
    await open(tester, api);
    await tapMapCentre(tester);
    expect(find.text('Test Forest'), findsOneWidget);
    expect(find.text('Log QSO'), findsOneWidget);
    // The selected park has a ring of its own
    expect(circles(tester), hasLength(2));

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(find.text('Log QSO'), findsNothing);
    expect(circles(tester), hasLength(1));
  });

  testWidgets('tapping empty map closes the card', (tester) async {
    final api = FakeApi()..squares['KO02'] = [park('PL-0001', 52.5, 21.0)];
    await open(tester, api);
    await tapMapCentre(tester);
    expect(find.text('Log QSO'), findsOneWidget);

    final box = tester.getRect(find.byType(FlutterMap));
    await tester.tapAt(box.topLeft + const Offset(40, 230));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Log QSO'), findsNothing);
  });

  testWidgets('Back closes the card first', (tester) async {
    final api = FakeApi()..squares['KO02'] = [park('PL-0001', 52.5, 21.0)];
    await open(tester, api);
    await tapMapCentre(tester);
    expect(find.text('Log QSO'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Log QSO'), findsNothing);
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('dots on top of each other are offered in a list',
      (tester) async {
    final api = FakeApi()
      ..squares['KO02'] = [
        park('PL-0001', 52.5, 21.0, name: 'First Park'),
        park('PL-0002', 52.50001, 21.00001, name: 'Second Park'),
      ];
    await open(tester, api);
    await tapMapCentre(tester);
    expect(find.text('Several parks here'), findsOneWidget);
    expect(find.text('PL-0001'), findsOneWidget);
    expect(find.text('PL-0002'), findsOneWidget);

    await tester.tap(find.text('PL-0002'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Second Park'), findsOneWidget);
    expect(find.text('Log QSO'), findsOneWidget);
  });

  testWidgets('Log opens the QSO form with the park', (tester) async {
    final api = FakeApi()..squares['KO02'] = [park('PL-0001', 52.5, 21.0)];
    await open(tester, api);
    await tapMapCentre(tester);
    await tester.tap(find.text('Log QSO'));
    await tester.pumpAndSettle();
    expect(find.text('QSO form for PL-0001'), findsOneWidget);
  });

  group('too far out', () {
    testWidgets('asks to zoom in and loads nothing', (tester) async {
      final api = FakeApi();
      await open(tester, api, home: null);
      expect(find.text('Zoom in to see parks'), findsOneWidget);
      expect(api.asked, isEmpty);
      expect(circles(tester), isEmpty);
    });

    testWidgets('no chip when the parks are in reach', (tester) async {
      await open(tester, FakeApi());
      expect(find.text('Zoom in to see parks'), findsNothing);
    });
  });

  group('when pota.app does not answer', () {
    testWidgets('a banner offers Retry, and Retry asks again', (tester) async {
      final api = FakeApi()..failWith = Exception('offline');
      await open(tester, api);
      expect(find.text('Some parks could not be loaded'), findsOneWidget);
      final before = api.asked.length;

      api
        ..failWith = null
        ..squares['KO02'] = [park('PL-0001', 52.5, 21.0)];
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(api.asked.length, greaterThan(before));
      expect(find.text('Some parks could not be loaded'), findsNothing);
      expect(circles(tester), hasLength(1));
    });

    testWidgets('parks already shown stay when a refresh fails',
        (tester) async {
      final api = FakeApi()..squares['KO02'] = [park('PL-0001', 52.5, 21.0)];
      final c = await open(tester, api);
      expect(circles(tester), hasLength(1));
      api.failWith = Exception('offline');
      c.read(potaParksProvider.notifier).retryFailed();
      await settle(tester);
      expect(circles(tester), hasLength(1));
    });

    testWidgets('back online, the failed squares are asked again',
        (tester) async {
      final api = FakeApi()..failWith = Exception('offline');
      final c = await open(tester, api);
      api
        ..failWith = null
        ..squares['KO02'] = [park('PL-0001', 52.5, 21.0)];
      c.read(online.notifier).state = false;
      await tester.pump();
      c.read(online.notifier).state = true;
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
      expect(circles(tester), hasLength(1));
    });
  });

  group('position', () {
    testWidgets('the map opens on the last known position', (tester) async {
      final api = FakeApi();
      // Krakow, a different square than the start
      final loc = FakeLocation()..last = const PotaLocationFix(50.06, 19.94);
      await open(tester, api, location: loc);
      expect(api.asked, contains(gridSquare4(50.06, 19.94)));
    });

    testWidgets('the location button asks, and centres on the answer',
        (tester) async {
      final api = FakeApi();
      final loc = FakeLocation()
        ..onButton = const PotaLocationFix(48.2, 16.37); // Vienna
      await open(tester, api, location: loc);
      await tester.tap(find.byTooltip('My location'));
      await settle(tester);
      expect(api.asked, contains(gridSquare4(48.2, 16.37)));
    });

    testWidgets('a fix that comes late does not pull the map away',
        (tester) async {
      final api = FakeApi();
      final loc = FakeLocation()
        ..gate = Completer<void>()
        ..fresh = const PotaLocationFix(48.2, 16.37);
      await open(tester, api, location: loc);

      // The person has already taken hold of the map
      await tester.drag(find.byType(FlutterMap), const Offset(60, 0));
      await settle(tester);
      loc.gate!.complete();
      await settle(tester);
      expect(api.asked, isNot(contains(gridSquare4(48.2, 16.37))));
    });

    testWidgets('a fix that comes while the map is untouched is followed',
        (tester) async {
      final api = FakeApi();
      final loc = FakeLocation()
        ..gate = Completer<void>()
        ..fresh = const PotaLocationFix(48.2, 16.37);
      await open(tester, api, location: loc);
      loc.gate!.complete();
      await settle(tester);
      expect(api.asked, contains(gridSquare4(48.2, 16.37)));
    });

    testWidgets('permission refused for good: the way to the settings',
        (tester) async {
      final loc = FakeLocation()
        ..onButton = const PotaLocationDenied(forever: true);
      await open(tester, FakeApi(), location: loc);
      await tester.tap(find.byTooltip('My location'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Location is blocked for this app. Allow it in Settings.'),
          findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pump();
      expect(loc.settingsOpened, 1);
    });

    testWidgets('location switched off: the way to its setting',
        (tester) async {
      final loc = FakeLocation()..onButton = const PotaLocationServiceOff();
      await open(tester, FakeApi(), location: loc);
      await tester.tap(find.byTooltip('My location'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Location is turned off on this device'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pump();
      expect(loc.locationSettingsOpened, 1);
    });

    testWidgets('permission not given yet: only a note', (tester) async {
      final loc = FakeLocation()..onButton = const PotaLocationDenied();
      await open(tester, FakeApi(), location: loc);
      await tester.tap(find.byTooltip('My location'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
          find.text('Location permission is needed to find parks near you'),
          findsOneWidget);
      expect(find.text('Settings'), findsNothing);
    });
  });

  group('search', () {
    testWidgets('a reference that is not loaded is looked up and shown',
        (tester) async {
      final api = FakeApi()
        ..details['PL-0999'] = const PotaParkDetail(
            reference: 'PL-0999',
            name: 'Far Away Park',
            lat: 49.0,
            lon: 20.0);
      await open(tester, api);
      await tester.enterText(find.byType(TextField), 'pl-0999');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(find.text('Far Away Park'), findsOneWidget);
      expect(find.text('Log QSO'), findsOneWidget);
      expect(api.asked, contains(gridSquare4(49.0, 20.0)));
    });

    testWidgets('a reference of a loaded park needs no lookup', (tester) async {
      final api = FakeApi()
        ..squares['KO02'] = [park('PL-0001', 52.5, 21.0, name: 'Loaded Park')];
      await open(tester, api);
      await tester.enterText(find.byType(TextField), 'PL-0001');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(find.text('Loaded Park'), findsOneWidget);
    });

    testWidgets('an unknown park says so', (tester) async {
      await open(tester, FakeApi());
      await tester.enterText(find.byType(TextField), 'PL-0888');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(find.text('Park not found'), findsOneWidget);
      expect(find.text('Log QSO'), findsNothing);
    });
  });

  testWidgets('fits a narrow screen in every language', (tester) async {
    for (final locale in AppLocalizations.supportedLocales) {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(960, 1800);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final api = FakeApi()..failWith = Exception('x');
      final container = ProviderContainer(overrides: [
        potaParksDatasourceProvider.overrideWithValue(api),
        potaLocationServiceProvider.overrideWithValue(FakeLocation()),
        potaMapHomeProvider.overrideWithValue(null),
        activatedParksProvider.overrideWithValue(const {}),
        huntedParksProvider.overrideWithValue(const {}),
        isOnlineProvider.overrideWithValue(true),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PotaMapScreen(tileProvider: _BlankTiles()),
        ),
      ));
      await settle(tester);
      final problem = tester.takeException();
      expect(problem, isNull, reason: '$locale $problem');
    }
  });
}
