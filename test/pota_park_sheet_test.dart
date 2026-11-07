import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/core/utils/pota_parks.dart';
import 'package:wavelog_mobile/data/datasources/remote/pota_parks_datasource.dart';
import 'package:wavelog_mobile/data/models/pota_park_model.dart';
import 'helpers/fake_boundaries.dart';
import 'package:wavelog_mobile/l10n/app_localizations.dart';
import 'package:wavelog_mobile/presentation/widgets/pota/pota_park_sheet.dart';
import 'package:wavelog_mobile/providers/pota_parks_provider.dart';
import 'package:wavelog_mobile/providers/pota_stats_provider.dart';


const park = PotaParkPoint(
    reference: 'PL-0363', name: 'Dąbrowy Seroczyńskie', lat: 52.0088, lon: 21.9843);

class FakeCard implements PotaParksDatasource {
  Future<PotaParkDetail?> Function() detail = () async => PotaParkDetail(
        reference: 'PL-0363',
        name: 'Dąbrowy Seroczyńskie',
        type: 'Nature Reserve',
        locationName: 'Mazowieckie',
        country: 'Poland',
        grid6: 'KO02xa',
        firstActivator: 'SQ8JCB',
        firstActivationDate: DateTime.utc(2013, 9, 15),
      );
  Future<PotaParkStats?> Function() stats =
      () async => const PotaParkStats(attempts: 4, activations: 4, contacts: 1390);
  Future<List<PotaActivation>> Function() recent = () async => [
        PotaActivation(
            callsign: 'SP5TEN', date: DateTime.utc(2025, 6, 29), qsos: 11),
        PotaActivation(
            callsign: 'SQ8JCB', date: DateTime.utc(2023, 5, 3), qsos: 152),
      ];
  var detailCalls = 0;

  @override
  Future<PotaParkDetail?> getDetail(String reference) {
    detailCalls++;
    return detail();
  }

  @override
  Future<PotaParkStats?> getStats(String reference) => stats();

  @override
  Future<List<PotaActivation>> getRecentActivations(String reference,
          {int count = 5}) =>
      recent();

  @override
  Future<List<PotaParkPoint>> parksInSquare(String grid4) =>
      throw UnimplementedError();
}

Future<void> show(
  WidgetTester tester,
  FakeCard fake, {
  ({double lat, double lon})? me,
  Set<String>? activated = const {},
  Set<String>? hunted = const {},
  PotaParkPoint point = park,
  ValueChanged<String>? onLog,
  LaunchUri? launch,
  ShareText? share,
  Locale locale = const Locale('en'),
  double width = 400,
  FakeBoundaries? boundaries,
}) async {
  tester.view.physicalSize = Size(width * 3, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      potaParksDatasourceProvider.overrideWithValue(fake),
      parkBoundaryDatasourceProvider
          .overrideWithValue(boundaries ?? FakeBoundaries()),
      activatedParksProvider.overrideWithValue(activated),
      huntedParksProvider.overrideWithValue(hunted),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PotaParkSheet(
          park: point,
          me: me,
          onClose: () {},
          onLog: onLog ?? (_) {},
          launch: launch ?? (_) async => true,
          share: share ?? (_) async {},
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('opens at once with what the map knows, before any details',
      (tester) async {
    final fake = FakeCard()
      ..detail = (() => Completer<PotaParkDetail?>().future)
      ..stats = (() => Completer<PotaParkStats?>().future)
      ..recent = (() => Completer<List<PotaActivation>>().future);
    await show(tester, fake);
    expect(find.text('PL-0363'), findsOneWidget);
    expect(find.text('Dąbrowy Seroczyńskie'), findsOneWidget);
    expect(find.text('Log QSO'), findsOneWidget);
    expect(find.text('Directions'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsWidgets);
  });

  testWidgets('shows the details, counts and latest activations as they come',
      (tester) async {
    await show(tester, FakeCard());
    await tester.pumpAndSettle();
    expect(find.text('Nature Reserve · Mazowieckie, Poland'), findsOneWidget);
    expect(find.text('KO02xa'), findsOneWidget);
    expect(find.textContaining('First activated by SQ8JCB'), findsOneWidget);
    expect(find.text('1,390'), findsOneWidget);
    expect(find.text('SP5TEN'), findsOneWidget);
    expect(find.text('152 QSOs'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('a part that fails does not hold back the others',
      (tester) async {
    final fake = FakeCard()..detail = (() => Future.error(Exception('offline')));
    await show(tester, fake);
    await tester.pumpAndSettle();
    expect(find.text('Could not load park details'), findsOneWidget);
    expect(find.text('1,390'), findsOneWidget);
    expect(find.text('SP5TEN'), findsOneWidget);

    // Retry asks again
    fake.detail = () async => const PotaParkDetail(
        reference: 'PL-0363', name: 'x', type: 'National Park');
    final before = fake.detailCalls;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(fake.detailCalls, before + 1);
    expect(find.text('National Park'), findsOneWidget);
  });

  testWidgets('a park pota.app does not know says so', (tester) async {
    final fake = FakeCard()
      ..detail = (() async => null)
      ..stats = (() async => null)
      ..recent = (() async => <PotaActivation>[]);
    await show(tester, fake);
    await tester.pumpAndSettle();
    expect(find.text('pota.app has no details for this park'), findsOneWidget);
    expect(find.text('No activations yet'), findsOneWidget);
  });

  group('status', () {
    testWidgets('every status that applies, most important first',
        (tester) async {
      await show(tester, FakeCard(),
          point: const PotaParkPoint(
              reference: 'PL-0363',
              name: 'x',
              lat: 52,
              lon: 21,
              neverActivated: true),
          activated: {'PL-0363'},
          hunted: {'PL-0363'});
      expect(find.text('Activated by me'), findsOneWidget);
      expect(find.text('Hunted'), findsOneWidget);
      expect(find.text('Never activated'), findsOneWidget);
      expect(find.text('Other parks'), findsNothing);
    });

    testWidgets('a park with no history is "other"', (tester) async {
      await show(tester, FakeCard());
      expect(find.text('Other parks'), findsOneWidget);
    });

    testWidgets('while the log loads nobody is called activated or hunted',
        (tester) async {
      await show(tester, FakeCard(), activated: null, hunted: null);
      expect(find.text('Other parks'), findsOneWidget);
      expect(find.text('Hunted'), findsNothing);
    });
  });

  testWidgets('distance and direction only with a position', (tester) async {
    await show(tester, FakeCard());
    expect(find.textContaining('from you'), findsNothing);

    // ~52 km south-west of the park
    await show(tester, FakeCard(), me: (lat: 51.6, lon: 21.4));
    expect(find.textContaining('from you'), findsOneWidget);
    expect(find.textContaining('km'), findsOneWidget);
    expect(find.textContaining(' NE from you'), findsOneWidget);
  });

  testWidgets('the direction is in the app language', (tester) async {
    await show(tester, FakeCard(),
        me: (lat: 51.6, lon: 21.4), locale: const Locale('tr'));
    // North-east is "KD" in Turkish
    expect(find.textContaining(' KD'), findsOneWidget);
    expect(find.textContaining(' NE'), findsNothing);
  });

  testWidgets('Log starts a QSO for this park', (tester) async {
    String? logged;
    await show(tester, FakeCard(), onLog: (r) => logged = r);
    await tester.tap(find.text('Log QSO'));
    expect(logged, 'PL-0363');
  });

  group('actions', () {
    testWidgets('Directions opens a maps app on the park', (tester) async {
      final opened = <Uri>[];
      await show(tester, FakeCard(), launch: (u) async {
        opened.add(u);
        return true;
      });
      await tester.tap(find.text('Directions'));
      await tester.pump();
      expect(opened, hasLength(1));
      expect(opened.single.scheme, 'geo');
      expect(opened.single.toString(), startsWith('geo:52.00880,21.98430?q='));
    });

    testWidgets('without a maps app it falls back to openstreetmap.org',
        (tester) async {
      final tried = <Uri>[];
      await show(tester, FakeCard(), launch: (u) async {
        tried.add(u);
        return u.scheme != 'geo';
      });
      await tester.tap(find.text('Directions'));
      await tester.pump();
      expect(tried.map((u) => u.scheme), ['geo', 'https']);
      expect(tried.last.host, 'www.openstreetmap.org');
    });

    testWidgets('and then to the coordinates on the clipboard',
        (tester) async {
      String? clip;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clip = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await show(tester, FakeCard(), launch: (u) async => throw Exception('x'));
      await tester.tap(find.text('Directions'));
      await tester.pump();
      expect(clip, '52.00880, 21.98430');
      expect(find.text('No maps app found. Coordinates copied.'),
          findsOneWidget);
    });

    testWidgets('open on pota.app, share and copy the reference',
        (tester) async {
      final opened = <Uri>[];
      String? shared;
      String? clip;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clip = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await show(tester, FakeCard(), launch: (u) async {
        opened.add(u);
        return true;
      }, share: (t) async => shared = t);

      await tester.tap(find.byTooltip('Open on pota.app'));
      expect(opened.single.toString(), 'https://pota.app/#/park/PL-0363');

      await tester.tap(find.byTooltip('Share'));
      expect(shared, contains('PL-0363'));
      expect(shared, contains('https://pota.app/#/park/PL-0363'));

      await tester.tap(find.byTooltip('Copy reference'));
      await tester.pump();
      expect(clip, 'PL-0363');
      expect(find.text('Copied'), findsOneWidget);
    });
  });

  testWidgets('fits a narrow screen in every language', (tester) async {
    for (final locale in AppLocalizations.supportedLocales) {
      await show(tester, FakeCard(),
          width: 320,
          me: (lat: 51.6, lon: 21.4),
          point: const PotaParkPoint(
              reference: 'PL-0363',
              name: 'A park with a very long name that has to wrap somewhere',
              lat: 52,
              lon: 21,
              neverActivated: true),
          activated: {'PL-0363'},
          hunted: {'PL-0363'},
          locale: locale);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$locale');
    }
  });

  group('the outline note', () {
    testWidgets('says it is looking, then that the outline is approximate',
        (tester) async {
      final b = FakeBoundaries(result: squareOutline(52.0088, 21.9843))
        ..gate = Completer<void>();
      await show(tester, FakeCard(), boundaries: b);
      await tester.pump(kParkBoundaryDwell + const Duration(milliseconds: 50));
      expect(find.text('Looking for the park outline'), findsOneWidget);

      b.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Looking for the park outline'), findsNothing);
      expect(find.textContaining('Approximate outline from OpenStreetMap'),
          findsOneWidget);
      expect(b.asked, ['PL-0363']);
    });

    testWidgets('says so when there is none', (tester) async {
      await show(tester, FakeCard(), boundaries: FakeBoundaries());
      await tester.pumpAndSettle();
      expect(find.text('No outline found for this park'), findsOneWidget);
      expect(find.textContaining('Approximate outline'), findsNothing);
    });

    testWidgets('and when Nominatim could not be reached', (tester) async {
      final b = FakeBoundaries()..error = Exception('offline');
      await show(tester, FakeCard(), boundaries: b);
      await tester.pumpAndSettle();
      expect(find.text('No outline found for this park'), findsOneWidget);
    });

    testWidgets('in the app language', (tester) async {
      await show(tester, FakeCard(),
          boundaries: FakeBoundaries(result: squareOutline(52.0088, 21.9843)),
          locale: const Locale('tr'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Yaklaşık sınır'), findsOneWidget);
    });
  });

  group('links', () {
    test('the geo link carries the name, without brackets', () {
      final u = parkGeoUri(52.0088, 21.9843, 'Park (north) ąę');
      expect(u.scheme, 'geo');
      final s = u.toString();
      expect(s, startsWith('geo:52.00880,21.98430?q=52.00880,21.98430('));
      expect(s, endsWith(')'));
      expect(s.substring(s.indexOf('(') + 1, s.length - 1), isNot(contains('(')));
      expect(s, isNot(contains(' ')));
    });

    test('a park with no name still has a pin', () {
      expect(parkGeoUri(1, 2, '  ').toString(), 'geo:1.00000,2.00000?q=1.00000,2.00000');
    });

    test('the web links', () {
      expect(parkWebUri('pl-0363').toString(), 'https://pota.app/#/park/PL-0363');
      expect(parkOsmUri(52.0088, 21.9843).toString(),
          'https://www.openstreetmap.org/?mlat=52.00880&mlon=21.98430#map=15/52.00880/21.98430');
      expect(parkCoordinates(52.0088, 21.9843), '52.00880, 21.98430');
    });
  });
}
