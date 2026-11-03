import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavelog_mobile/presentation/widgets/keep_screen_on.dart';
import 'package:wavelog_mobile/providers/settings_provider.dart';

class _Screen extends ConsumerStatefulWidget {
  final Widget? child;
  const _Screen({this.child});

  @override
  ConsumerState<_Screen> createState() => _ScreenState();
}

class _ScreenState extends ConsumerState<_Screen> {
  final _screenOn = KeepScreenOn();

  @override
  void initState() {
    super.initState();
    _screenOn.start(ref);
  }

  @override
  void dispose() {
    _screenOn.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox();
}

void main() {
  late List<bool> calls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.wavelog_mobile/screen'),
            (call) async {
      calls.add(call.arguments as bool);
      return null;
    });
    // Saving the settings also writes the API key to secure storage.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => null);
  });

  Future<ProviderContainer> pump(WidgetTester tester, Widget child) async {
    final container = ProviderContainer();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: Directionality(textDirection: TextDirection.ltr, child: child)));
    return container;
  }

  testWidgets('keeps the screen on while shown and lets go when left',
      (tester) async {
    final c = await pump(tester, const _Screen());
    expect(calls, [true]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c, child: const SizedBox()));
    expect(calls, [true, false]);
  });

  testWidgets('a screen opened on top keeps it on until the last one closes',
      (tester) async {
    final c = await pump(
        tester,
        const _Screen(child: Column(children: [_Screen()])));
    expect(calls, [true]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const Directionality(
            textDirection: TextDirection.ltr,
            child: _Screen(child: Column(children: [SizedBox()])))));
    expect(calls, [true]); // the outer screen still holds it
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c, child: const SizedBox()));
    expect(calls, [true, false]);
  });

  testWidgets('follows the setting', (tester) async {
    final c = await pump(tester, const _Screen());
    // Saving goes through SharedPreferences: real async, not fake time.
    await tester.runAsync(() =>
        c.read(settingsProvider.notifier).setKeepScreenOnWhileLogging(false));
    await tester.pump();
    expect(calls, [true, false]);
    await tester.runAsync(() =>
        c.read(settingsProvider.notifier).setKeepScreenOnWhileLogging(true));
    await tester.pump();
    expect(calls, [true, false, true]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c, child: const SizedBox()));
  });
}
