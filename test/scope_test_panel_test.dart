import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/l10n/app_localizations.dart';
import 'package:wavelog_mobile/presentation/screens/login/login_screen.dart';

Future<void> pump(WidgetTester tester, List<ScopeTestResult> results,
    {Locale locale = const Locale('en'), double width = 320}) async {
  tester.view.physicalSize = Size(width * 3, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ScopeTestPanel(testing: false, results: results),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  const unverified = [
    ScopeTestResult('station:read', null),
    ScopeTestResult('qso:read', null),
    ScopeTestResult('radio:write', null),
  ];

  testWidgets('checks that got no answer are not shown as a pass',
      (tester) async {
    await pump(tester, unverified);
    expect(find.text('Some scopes could not be checked (no answer from the server)'),
        findsOneWidget);
    expect(find.text('All required scopes are present'), findsNothing);
    expect(find.byIcon(Icons.help_outline), findsNWidgets(3));
  });

  testWidgets('a long header wraps on a narrow screen instead of overflowing',
      (tester) async {
    for (final locale in AppLocalizations.supportedLocales) {
      await pump(tester, unverified, locale: locale);
      expect(tester.takeException(), isNull, reason: '$locale');
    }
  });

  testWidgets('a missing scope still says so, and all passed is green',
      (tester) async {
    await pump(tester, const [
      ScopeTestResult('station:read', true),
      ScopeTestResult('qso:read', false),
      ScopeTestResult('radio:write', null),
    ]);
    expect(find.text('Some scopes are missing'), findsOneWidget);

    await pump(tester, const [
      ScopeTestResult('station:read', true),
      ScopeTestResult('qso:read', true),
    ]);
    expect(find.text('All required scopes are present'), findsOneWidget);
  });
}
