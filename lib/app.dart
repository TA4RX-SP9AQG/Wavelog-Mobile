import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'providers/radio_status_provider.dart';
import 'providers/rig_provider.dart';
import 'providers/settings_provider.dart';
import 'router.dart';

/// The Locale for a language code saved in the settings: "tr", or with a
/// script such as "zh_Hans" (Simplified Chinese). The script keeps Chinese on
/// its own translation rather than on the generic "zh" fallback file.
Locale localeFromCode(String code) {
  final parts = code.split('_');
  return parts.length > 1
      ? Locale.fromSubtags(languageCode: parts[0], scriptCode: parts[1])
      : Locale(parts[0]);
}

class WavelogMobileApp extends ConsumerWidget {
  const WavelogMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    // Start the radio link with the app, so it connects as soon as the
    // radio's USB cable is plugged in, not only once a QSO form opens.
    ref.listen(rigProvider, (_, __) {});
    // …and report it to Wavelog's CAT radios while connected.
    ref.listen(radioStatusProvider, (_, __) {});

    final locale =
        settings.locale != null ? localeFromCode(settings.locale!) : null;

    return MaterialApp.router(
      title: 'Wavelog Mobile',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: settings.darkTheme ? ThemeMode.dark : ThemeMode.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
    );
  }
}
