import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/app.dart';
import 'package:wavelog_mobile/l10n/app_localizations.dart';

void main() {
  test('a plain language code is that language', () {
    expect(localeFromCode('tr'), const Locale('tr'));
  });

  test('Simplified Chinese keeps its script', () {
    final locale = localeFromCode('zh_Hans');
    expect(locale.languageCode, 'zh');
    expect(locale.scriptCode, 'Hans');
  });

  test('every language the picker offers is a supported locale', () {
    for (final code in ['en', 'tr', 'de', 'pl', 'fr', 'it', 'ja', 'ko', 'ru', 'zh_Hans']) {
      final l = localeFromCode(code);
      expect(
          AppLocalizations.supportedLocales.any((s) =>
              s.languageCode == l.languageCode && s.scriptCode == l.scriptCode),
          isTrue,
          reason: code);
    }
  });

  test('Simplified Chinese resolves to the Hans translation, not the zh copy',
      () async {
    final l10n = await AppLocalizations.delegate.load(localeFromCode('zh_Hans'));
    expect(l10n.localeName, 'zh_Hans');
    expect(l10n.langChinese, '简体中文');
  });
}
