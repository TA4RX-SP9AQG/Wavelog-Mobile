import 'package:flutter/material.dart';

import '../../../core/utils/pota_parks.dart';
import '../../../l10n/app_localizations.dart';

/// Colours of the park statuses. Chosen from the Okabe-Ito palette, which
/// stays apart for the common kinds of colour blindness; the map also varies
/// the dot size and gives never-activated parks a ring, so colour is never the
/// only sign.
Color potaStatusColor(PotaParkStatus status) => switch (status) {
      PotaParkStatus.activated => const Color(0xFF0072B2),
      PotaParkStatus.hunted => const Color(0xFF009E73),
      PotaParkStatus.neverActivated => const Color(0xFFD55E00),
      PotaParkStatus.other => const Color(0xFF8A8F98),
    };

String potaStatusLabel(AppLocalizations l10n, PotaParkStatus status) =>
    switch (status) {
      PotaParkStatus.activated => l10n.potaMapStatusActivated,
      PotaParkStatus.hunted => l10n.potaMapStatusHunted,
      PotaParkStatus.neverActivated => l10n.potaMapStatusNever,
      PotaParkStatus.other => l10n.potaMapStatusOther,
    };
