import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/core/dxcc/dxcc_prefix_matcher.dart';
import 'package:wavelog_mobile/data/models/dxcc_entity_model.dart';

// Real-world catalog rows (prefix as Wavelog's /api/v2/catalog?topic=dxcc
// actually returns it today) used to pin down the three documented gaps
// DxccPrefixMatcher.build() exists to close — see the class doc comment.
const _andorra = DxccEntity(
  adif: 91,
  name: 'Andorra',
  prefix: 'C31', // catalog's prefix is more specific than cty.dat's bare "C3"
  continent: 'EU',
  cqZone: 14,
  ituZone: 27,
);

const _serbia = DxccEntity(
  adif: 296,
  name: 'Serbia',
  prefix: 'YT', // catalog's primary; cty.dat's primary for the block is "YU"
  continent: 'EU',
  cqZone: 15,
  ituZone: 28,
);

const _usa = DxccEntity(
  adif: 291,
  name: 'United States of America',
  prefix: 'K',
  continent: 'NA',
  cqZone: 5,
  ituZone: 8,
);

// No cty.dat variant starts with this — exercises the "entity absent from
// cty.dat falls back to its own catalog prefix unchanged" path.
const _fictional = DxccEntity(
  adif: 9999,
  name: 'Fictionland',
  prefix: 'QQ9Z',
  continent: '?',
  cqZone: 0,
  ituZone: 0,
);

// Real catalog rows for the "commonPrefix/letter" display-shorthand gap
// (see the class doc comment + the inline comment in build()). Before the
// fix, these stole every French QSO: Crozet's "FT5/W" resolved via
// findPrimary() to the bare "F" cty.dat block, handing Crozet Island the
// *entire* France variant family (F/HW/HX/HY/TH/TM/TO/TP/TQ/TV/TX) —
// discovered by diffing a live account's app-computed DXCC worked list
// against an independent reference script (60 vs 58 entities: France
// disappeared, and Crozet/Juan de Nova/Tromelin appeared with dozens of
// ordinary French QSOs attached).
const _france = DxccEntity(
  adif: 227,
  name: 'France',
  prefix: 'F',
  continent: 'EU',
  cqZone: 14,
  ituZone: 27,
);
const _crozet = DxccEntity(
  adif: 41,
  name: 'Crozet Island',
  prefix: 'FT5/W',
  continent: 'AF',
  cqZone: 39,
  ituZone: 68,
);

void main() {
  // DxccPrefixMatcher.build() loads the bundled cty.dat-derived asset via
  // rootBundle; without an initialized test binding that load silently
  // fails (build() swallows the error and falls back to catalog-only
  // prefixes), which would make every expansion-dependent assertion below
  // fail with a misleading "no match" rather than a loading error.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DxccPrefixMatcher', () {
    test('matches a call using the catalog entity\'s own prefix directly',
        () async {
      final matcher = await DxccPrefixMatcher.build([_usa]);
      expect(matcher.match('K1ABC')?.name, 'United States of America');
    });

    test(
        'expands a more specific catalog prefix to cty.dat\'s shorter block '
        'prefix (Andorra: catalog "C31" vs cty.dat "C3")', () async {
      final matcher = await DxccPrefixMatcher.build([_andorra]);
      // A real Andorran callsign shape the catalog's own "C31" would not
      // have matched under a naive exact/startsWith(catalogPrefix) join.
      expect(matcher.match('C37JPE')?.adif, 91);
      expect(matcher.match('C31ABC')?.adif, 91);
    });

    test(
        'the reverse of the Andorra case: catalog prefix shorter than '
        'cty.dat\'s real variant (Franz Josef Land: catalog "R1F" vs '
        'cty.dat "R1FJ") resolves to the specific entity, not the nearest '
        'shorter sibling block', () async {
      const franzJosefLand = DxccEntity(
        adif: 61,
        name: 'Franz Josef Land',
        prefix: 'R1F',
        continent: 'EU',
        cqZone: 75,
        ituZone: 75,
      );
      const russia = DxccEntity(
        adif: 15,
        name: 'Asiatic Russia',
        prefix: 'R', // shares the same bare "R" cty.dat block
        continent: 'AS',
        cqZone: 17,
        ituZone: 30,
      );
      final matcher =
          await DxccPrefixMatcher.build([franzJosefLand, russia]);
      // Before the fix this matched "Asiatic Russia" via the bare "R"
      // fallback, since cty.dat's real "R1FJ" variant is one character
      // longer than Wavelog's own catalog prefix and a pure forward
      // (catalogPrefix.startsWith(variant)) search can never reach it.
      expect(matcher.match('R1FJ')?.name, 'Franz Josef Land');
      // Ordinary Russian calls must still resolve to Russia, unaffected.
      expect(matcher.match('R1AV')?.name, 'Asiatic Russia');
    });

    test(
        'matches every cty.dat variant even when the catalog\'s primary '
        'differs (Serbia: catalog "YT" vs cty.dat primary "YU")', () async {
      final matcher = await DxccPrefixMatcher.build([_serbia]);
      expect(matcher.match('YU1HW')?.name, 'Serbia');
      expect(matcher.match('YT1AA')?.name, 'Serbia');
    });

    test('expands a whole prefix family (USA: K/N/W/AA..AK)', () async {
      final matcher = await DxccPrefixMatcher.build([_usa]);
      expect(matcher.match('W1AW')?.adif, 291);
      expect(matcher.match('N0AX')?.adif, 291);
      expect(matcher.match('AA1ZZZ')?.adif, 291);
    });

    test('falls back to the catalog\'s own prefix when cty.dat has no match',
        () async {
      final matcher = await DxccPrefixMatcher.build([_fictional]);
      expect(matcher.match('QQ9ZAB')?.adif, 9999);
      expect(matcher.match('QQ8ZAB'), isNull);
    });

    test('returns null for a call matching no known entity', () async {
      final matcher = await DxccPrefixMatcher.build([_usa, _andorra]);
      expect(matcher.match('ZZ1XYZ'), isNull);
    });

    test('longest-prefix-match picks the more specific entity when two '
        'catalog entities could both match', () async {
      // Neither synthetic prefix exists in cty.dat, so both fall back to
      // their own raw catalog prefix unchanged — isolating the sort/match
      // precedence itself rather than any real-world cty.dat expansion.
      const broad = DxccEntity(
        adif: 1000,
        name: 'Broad Block',
        prefix: 'QQ9Z',
        continent: '?',
        cqZone: 0,
        ituZone: 0,
      );
      const specific = DxccEntity(
        adif: 1001,
        name: 'Specific Block',
        prefix: 'QQ9ZA',
        continent: '?',
        cqZone: 0,
        ituZone: 0,
      );
      final matcher = await DxccPrefixMatcher.build([broad, specific]);
      expect(matcher.match('QQ9ZAXYZ')?.adif, 1001); // longer match wins
      expect(matcher.match('QQ9ZBXYZ')?.adif, 1000); // only the shorter fits
    });

    test('ignores entities with an empty prefix or non-positive adif '
        '(deleted-entity filtering is the caller\'s job — see '
        'statistics_screen.dart\'s .where((e) => !e.deleted))', () async {
      const noPrefix = DxccEntity(
        adif: 12346,
        name: 'No Prefix Entity',
        prefix: '',
        continent: '?',
        cqZone: 0,
        ituZone: 0,
      );
      const zeroAdif = DxccEntity(
        adif: 0,
        name: 'Placeholder Entity',
        prefix: 'ZQ',
        continent: '?',
        cqZone: 0,
        ituZone: 0,
      );
      final matcher = await DxccPrefixMatcher.build([noPrefix, zeroAdif]);
      expect(matcher.match('ZQ1AB'), isNull);
    });

    group('"commonPrefix/letter" catalog entries (Crozet, Mount Athos, ...)', () {
      test('a real call for the rare entity still matches it', () async {
        final matcher = await DxccPrefixMatcher.build([_crozet]);
        expect(matcher.match('FT5ZM')?.adif, 41);
      });

      test('does NOT steal the parent country\'s cty.dat variant family',
          () async {
        final matcher = await DxccPrefixMatcher.build([_france, _crozet]);
        // Real France traffic: bare "F" prefix and the "TM" special-event
        // variant that only cty.dat's expansion of France's block knows
        // about. Before the fix both resolved to Crozet Island.
        expect(matcher.match('F1BAV')?.name, 'France');
        expect(matcher.match('TM4GGR')?.name, 'France');
        // The rare entity itself must still resolve correctly alongside it.
        expect(matcher.match('FT5ZM')?.name, 'Crozet Island');
      });

      test('order of construction does not matter (Crozet before France)',
          () async {
        final matcher = await DxccPrefixMatcher.build([_crozet, _france]);
        expect(matcher.match('F1BAV')?.name, 'France');
        expect(matcher.match('FT5ZM')?.name, 'Crozet Island');
      });

      test('a second slash entity under the same stem only collides with '
          'its actual sibling, never with the unrelated parent', () async {
        // Kerguelen ("FT5/X") shares Crozet's "FT5" stem — a genuine,
        // pre-existing source-data ambiguity between two French Southern
        // Territory entities — but neither may reach back into bare "F"
        // and swallow ordinary France traffic.
        const kerguelen = DxccEntity(
          adif: 131,
          name: 'Kerguelen Island',
          prefix: 'FT5/X',
          continent: 'AF',
          cqZone: 39,
          ituZone: 68,
        );
        final matcher =
            await DxccPrefixMatcher.build([_france, _crozet, kerguelen]);
        expect(matcher.match('F1BAV')?.name, 'France');
        expect(matcher.match('TM4GGR')?.name, 'France');
      });
    });
  });
}
