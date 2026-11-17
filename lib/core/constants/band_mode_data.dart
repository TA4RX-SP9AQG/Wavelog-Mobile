/// Longest wavelength first, as a band plan reads. The microwave bands
/// (23cm and up) are for ATV, EME, tropo and satellite work.
const List<String> kCommonBands = [
  '160m', '80m', '60m', '40m', '30m', '20m', '17m', '15m', '12m',
  '10m', '6m', '4m', '2m', '1.25m', '70cm', '33cm', '23cm', '13cm',
  '9cm', '6cm', '3cm', '1.25cm',
];

const Map<String, double> kBandCenterFreqMhz = {
  '160m': 1.850,
  '80m': 3.750,
  '60m': 5.357,
  '40m': 7.100,
  '30m': 10.125,
  '20m': 14.225,
  '17m': 18.130,
  '15m': 21.300,
  '12m': 24.940,
  '10m': 28.500,
  '6m': 50.150,
  '4m': 70.200,
  '2m': 144.300,
  '1.25m': 222.100,
  '70cm': 432.100,
  '33cm': 903.100,
  '23cm': 1296.200,
  '13cm': 2320.200,
  '9cm': 3400.100,
  '6cm': 5760.200,
  '3cm': 10368.200,
  '1.25cm': 24048.200,
};

const List<String> kCommonModes = [
  'SSB', 'CW', 'FT8', 'FT4', 'FM', 'AM', 'RTTY', 'PSK31', 'JS8',
  'ATV', 'SSTV', 'MSK144', 'Q65', 'JT65', 'JT9', 'WSPR',
];

const Map<String, List<String>> kSubmodes = {
  'SSB': ['USB', 'LSB'],
  'AM':  ['DSB', 'LSB', 'USB'],
  'FM':  ['NFM', 'WFM'],
};

const Map<String, String> kDefaultRst = {
  'SSB': '59',
  'AM': '59',
  'FM': '59',
  'CW': '599',
  'RTTY': '599',
  'FT8': '-10',
  'FT4': '-10',
  'JS8': '-10',
  'WSPR': '-10',
  'JT65': '-10',
  'JT9': '-10',
  'PSK31': '599',
};

/// The mode a spot is filtered by: USB and LSB count as SSB, the way they
/// are logged, so one "SSB" choice finds them all.
String spotFilterMode(String mode) {
  final m = mode.trim().toUpperCase();
  return m == 'USB' || m == 'LSB' ? 'SSB' : m;
}

String getDefaultRst(String mode) {
  return kDefaultRst[mode.toUpperCase()] ?? '59';
}

// Tek band-frekans tablosu — spot modelleri ve QSO formu bunu paylaşır.
// (Önceden 5 ayrı kopyası vardı.)
String? bandFromKhz(double khz) {
  if (khz >= 1800 && khz <= 2000) return '160m';
  if (khz >= 3500 && khz <= 4000) return '80m';
  if (khz >= 5300 && khz <= 5410) return '60m';
  if (khz >= 7000 && khz <= 7300) return '40m';
  if (khz >= 10100 && khz <= 10150) return '30m';
  if (khz >= 14000 && khz <= 14350) return '20m';
  if (khz >= 18068 && khz <= 18168) return '17m';
  if (khz >= 21000 && khz <= 21450) return '15m';
  if (khz >= 24890 && khz <= 24990) return '12m';
  if (khz >= 28000 && khz <= 29700) return '10m';
  if (khz >= 50000 && khz <= 54000) return '6m';
  if (khz >= 70000 && khz <= 71000) return '4m';
  if (khz >= 144000 && khz <= 148000) return '2m';
  if (khz >= 222000 && khz <= 225000) return '1.25m';
  if (khz >= 420000 && khz <= 450000) return '70cm';
  if (khz >= 902000 && khz <= 928000) return '33cm';
  if (khz >= 1240000 && khz <= 1300000) return '23cm';
  if (khz >= 2300000 && khz <= 2450000) return '13cm';
  if (khz >= 3300000 && khz <= 3500000) return '9cm';
  if (khz >= 5650000 && khz <= 5925000) return '6cm';
  if (khz >= 10000000 && khz <= 10500000) return '3cm';
  if (khz >= 24000000 && khz <= 24250000) return '1.25cm';
  return null;
}

String? getBandFromFreq(double freqMhz) => bandFromKhz(freqMhz * 1000);

// Amateur radio convention: SSB below 10 MHz → LSB, 10 MHz and above → USB.
// FM defaults to NFM, AM to DSB. Other modes have no submode.
String? defaultSubmodeFor(String band, String mode) {
  switch (mode.toUpperCase()) {
    case 'SSB':
      const lsbBands = {'160m', '80m', '60m', '40m', '30m'};
      return lsbBands.contains(band) ? 'LSB' : 'USB';
    case 'AM':
      return 'DSB';
    case 'FM':
      return 'NFM';
    default:
      return null;
  }
}

/// Noktasız ham frekans girdisini MHz string'e dönüştürür.
///
/// Strateji (öncelik sırasıyla):
///   1. Zaten nokta varsa → dokunma.
///   2. ÷ 1000 (kHz girişi): sonuç bilinen bir banttaysa kullan.
///      Örn: 14200 → 14.200 MHz (20m), 2352000 → 2352.000 MHz (13cm)
///   3. ÷ 10000 (10 Hz çözünürlüklü kHz): sonuç banttaysa kullan.
///      Örn: 142005 → 14.2005 MHz (20m), 142.005 değil
///   4. Girdinin kendisi bir banttaysa MHz olarak kabul et (mikrodalga).
///      Örn: 2352 → 2352.000 MHz (13cm), 1296 → 1296.000 MHz (23cm)
///   5. Yedek: ÷ 1000 (en yaygın varsayım).
String autoFormatFreqInput(String raw) {
  if (raw.contains('.')) return raw;
  final val = double.tryParse(raw);
  if (val == null || val < 1000) return raw;

  final mhz = val / 1000.0;
  if (getBandFromFreq(mhz) != null) return mhz.toStringAsFixed(3);

  final mhz2 = val / 10000.0;
  if (getBandFromFreq(mhz2) != null) return mhz2.toStringAsFixed(4);

  // Typed in MHz, as the microwave bands are
  if (getBandFromFreq(val) != null) return val.toStringAsFixed(3);

  return mhz.toStringAsFixed(3); // yedek
}
