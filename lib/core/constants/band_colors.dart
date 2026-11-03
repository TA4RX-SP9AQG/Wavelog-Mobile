import 'dart:ui' show Color;

/// One colour per band, shared by the map and the spot list.
const _kBandColors = <String, Color>{
  '160m': Color(0xFFFF5252),
  '80m': Color(0xFFFF6D00),
  '60m': Color(0xFFFFCA28),
  '40m': Color(0xFFD4E157),
  '30m': Color(0xFF66BB6A),
  '20m': Color(0xFF26C6DA),
  '17m': Color(0xFF42A5F5),
  '15m': Color(0xFF7E57C2),
  '12m': Color(0xFFEC407A),
  '10m': Color(0xFFFF7043),
  '6m': Color(0xFF26A69A),
  '2m': Color(0xFF78909C),
};
const _kDefaultBandColor = Color(0xFF90A4AE);

Color bandColor(String? band) => _kBandColors[band] ?? _kDefaultBandColor;
