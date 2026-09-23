import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../../data/models/dxcc_entity_model.dart';

/// Loads and applies country-files.com's cty.dat-derived prefix table to
/// expand each Wavelog DXCC catalog entity's single "primary" prefix into
/// the full set of known prefix variants for that entity, then produces a
/// longest-prefix-match lookup list.
///
/// This compensates for gaps in Wavelog's own catalog data:
/// - `/api/v2/catalog?topic=dxcc` returns exactly one representative prefix
///   per entity, not every alias a callsign might use (e.g. only "K", not
///   "K"/"AA".."AL"/"N"/"W").
/// - Wavelog's chosen "primary" prefix doesn't always match cty.dat's own
///   primary (e.g. Serbia: Wavelog uses "YT" as primary, while cty.dat uses
///   "YU" as primary with "YT" listed only as a secondary variant) — so a
///   naive primary-to-primary join would miss entities like this entirely.
/// - Wavelog's "representative prefix" is sometimes more specific than
///   cty.dat's own prefix for the same entity (e.g. Andorra: Wavelog uses
///   "C31" — a real callsign-shaped example — while cty.dat's only prefix
///   for Andorra is the bare "C3"), so an *exact* reverse-index lookup on
///   Wavelog's prefix also misses entities like this.
///
/// The join instead looks up each Wavelog entity's prefix against a reverse
/// index built from *every* variant in cty.dat using longest-prefix match
/// (not an exact match — see the Andorra case above), regardless of which
/// variant cty.dat calls "primary". `adif`/`name`/`continent` always come
/// from the live Wavelog catalog entity, never from cty.dat — the bundled
/// table is used purely to expand the set of prefixes that resolve to that
/// entity. Entities with no match in cty.dat fall back to their own single
/// prefix unchanged, so behavior never regresses below the previous
/// single-prefix matching.
///
/// Data source: cty.dat, maintained by Jim Reisert, AD1C
/// (https://www.country-files.com), MIT License — see
/// `assets/dxcc/NOTICE.md`.
class DxccPrefixMatcher {
  DxccPrefixMatcher._(this._expanded);

  /// (prefix variant, owning entity), sorted by prefix length descending
  /// for longest-prefix-match.
  final List<(String, DxccEntity)> _expanded;

  static const _assetPath = 'assets/dxcc/dxcc_prefix_table.json';

  static Future<DxccPrefixMatcher> build(List<DxccEntity> entities) async {
    Map<String, List<String>> table = {};
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      table = decoded.map((k, v) => MapEntry(k, (v as List).cast<String>()));
    } catch (_) {
      // Asset missing/corrupt: fall back to catalog-only prefixes below.
    }

    final variantToPrimary = <String, String>{};
    for (final entry in table.entries) {
      for (final variant in entry.value) {
        variantToPrimary.putIfAbsent(variant, () => entry.key);
      }
    }
    // Sorted longest-first so the catalog-prefix lookup below finds the most
    // specific cty.dat variant that is a prefix of the catalog's own prefix
    // (e.g. cty.dat's "C3" for a catalog prefix of "C31").
    final variantEntries = variantToPrimary.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    String? findPrimary(String catalogPrefix) {
      for (final entry in variantEntries) {
        if (catalogPrefix.startsWith(entry.key)) return entry.value;
      }
      return null;
    }

    final expanded = <(String, DxccEntity)>[];
    for (final entity in entities) {
      if (entity.prefix.isEmpty || entity.adif <= 0) continue;
      final key = entity.prefix.toUpperCase();
      final primary = findPrimary(key);
      final variants = primary != null ? table[primary] : null;
      if (variants != null && variants.isNotEmpty) {
        for (final v in variants) {
          expanded.add((v, entity));
        }
      } else {
        expanded.add((key, entity));
      }
    }

    expanded.sort((a, b) => b.$1.length.compareTo(a.$1.length));
    return DxccPrefixMatcher._(expanded);
  }

  /// Finds the DXCC entity whose prefix variant is the longest match for
  /// [call]. [call] must already be uppercased/normalized (see
  /// `_normalizeQsoCall` in statistics_screen.dart).
  DxccEntity? match(String call) {
    for (final (prefix, entity) in _expanded) {
      if (call.startsWith(prefix)) return entity;
    }
    return null;
  }
}
