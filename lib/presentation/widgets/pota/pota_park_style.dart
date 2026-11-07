import 'package:flutter/material.dart';

import '../../../core/utils/pota_parks.dart';
import '../../../l10n/app_localizations.dart';

/// Colours of the park statuses: vivid, and far apart in hue so that they read
/// on a busy map. The map also varies the dot size and gives never-activated
/// parks a hollow ring, so colour is never the only sign.
Color potaStatusColor(PotaParkStatus status) => switch (status) {
      PotaParkStatus.activated => const Color(0xFF1E6BFF),
      PotaParkStatus.hunted => const Color(0xFF00C853),
      PotaParkStatus.neverActivated => const Color(0xFFFF3D00),
      PotaParkStatus.other => const Color(0xFFB620E0),
    };

String potaStatusLabel(AppLocalizations l10n, PotaParkStatus status) =>
    switch (status) {
      PotaParkStatus.activated => l10n.potaMapStatusActivated,
      PotaParkStatus.hunted => l10n.potaMapStatusHunted,
      PotaParkStatus.neverActivated => l10n.potaMapStatusNever,
      PotaParkStatus.other => l10n.potaMapStatusOther,
    };

/// The short, translated name of a compass point ("NE", "KD").
String compassLabel(AppLocalizations l10n, CompassPoint point) =>
    switch (point) {
      CompassPoint.n => l10n.compassN,
      CompassPoint.ne => l10n.compassNE,
      CompassPoint.e => l10n.compassE,
      CompassPoint.se => l10n.compassSE,
      CompassPoint.s => l10n.compassS,
      CompassPoint.sw => l10n.compassSW,
      CompassPoint.w => l10n.compassW,
      CompassPoint.nw => l10n.compassNW,
    };
