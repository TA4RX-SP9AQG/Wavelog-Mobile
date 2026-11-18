import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/l10n/app_localizations.dart';
import 'package:wavelog_mobile/presentation/widgets/diagnostics/connection_diagnostics_dialog.dart';

Widget app(Future<String> Function() run) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showConnectionDiagnostics(context, run: run),
            child: const Text('open'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('shows progress, then the report, which can be copied',
      (tester) async {
    final done = Completer<String>();
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(app(() => done.future));
    await tester.tap(find.text('open'));
    await tester.pump();

    // Running: progress shown, nothing to copy yet
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
        tester
            .widget<TextButton>(
                find.widgetWithText(TextButton, 'Copy report'))
            .onPressed,
        isNull);

    done.complete('Wavelog Mobile connection report\nServer: https://w***.org:443');
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Server: https://w***.org:443'), findsOneWidget);

    await tester.tap(find.text('Copy report'));
    await tester.pumpAndSettle();
    expect(copied,
        ['Wavelog Mobile connection report\nServer: https://w***.org:443']);
    expect(find.text('Copied'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a failed run shows the error instead of a blank dialog',
      (tester) async {
    await tester.pumpWidget(app(() async => throw StateError('boom')));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);
  });
}
