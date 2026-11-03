import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/core/rig/cat_protocol.dart';

List<int?> freqs(List<CatUpdate> u) =>
    [for (final x in u) if (x.frequencyHz != null) x.frequencyHz];
List<RigMode?> modes(List<CatUpdate> u) =>
    [for (final x in u) if (x.mode != null) x.mode];

void main() {
  group('IcomCivCodec', () {
    // 14.074.000 Hz → BCD little-endian 00 40 07 14 00
    const freq = [0x00, 0x40, 0x07, 0x14, 0x00];

    test('polls alternate between frequency and mode', () {
      final codec = IcomCivCodec(0x94);
      expect(codec.nextPoll(), [0xFE, 0xFE, 0x94, 0xE0, 0x03, 0xFD]);
      expect(codec.nextPoll(), [0xFE, 0xFE, 0x94, 0xE0, 0x04, 0xFD]);
      expect(codec.nextPoll(), [0xFE, 0xFE, 0x94, 0xE0, 0x03, 0xFD]);
    });

    test('decodes a read-frequency reply', () {
      final codec = IcomCivCodec(0x94);
      expect(freqs(codec.feed([0xFE, 0xFE, 0xE0, 0x94, 0x03, ...freq, 0xFD])),
          [14074000]);
    });

    test('decodes a transceive frequency broadcast', () {
      final codec = IcomCivCodec(0xA4);
      // 7.155.120 Hz
      expect(
          freqs(codec.feed(
              [0xFE, 0xFE, 0x00, 0xA4, 0x00, 0x20, 0x51, 0x15, 0x07, 0x00, 0xFD])),
          [7155120]);
    });

    test('decodes mode replies and broadcasts', () {
      final codec = IcomCivCodec(0x94);
      expect(modes(codec.feed([0xFE, 0xFE, 0xE0, 0x94, 0x04, 0x01, 0x01, 0xFD])),
          [RigMode.usb]);
      expect(modes(codec.feed([0xFE, 0xFE, 0x00, 0x94, 0x01, 0x03, 0x02, 0xFD])),
          [RigMode.cw]);
      // DV and other unmapped modes are ignored
      expect(codec.feed([0xFE, 0xFE, 0xE0, 0x94, 0x04, 0x17, 0x01, 0xFD]),
          isEmpty);
    });

    test('ignores the echo of our own poll and other radios', () {
      final codec = IcomCivCodec(0x94);
      expect(codec.feed([0xFE, 0xFE, 0x94, 0xE0, 0x03, 0xFD]), isEmpty);
      expect(codec.feed([0xFE, 0xFE, 0x94, 0xE0, 0x04, 0xFD]), isEmpty);
      expect(codec.feed([0xFE, 0xFE, 0xE0, 0x98, 0x03, ...freq, 0xFD]), isEmpty);
    });

    test('Xiegu G90: one-wire CI-V echo, then the replies from 0x88', () {
      expect(CatProtocol.xieguCiv.defaultCivAddress, 0x88);
      final codec = CatCodec(CatProtocol.xieguCiv,
          civAddress: CatProtocol.xieguCiv.defaultCivAddress);
      expect(codec.nextPoll(), [0xFE, 0xFE, 0x88, 0xE0, 0x03, 0xFD]);
      final updates = codec.feed([
        0xFE, 0xFE, 0x88, 0xE0, 0x03, 0xFD, // our poll echoed back
        0xFE, 0xFE, 0xE0, 0x88, 0x03, ...freq, 0xFD,
        0xFE, 0xFE, 0x88, 0xE0, 0x04, 0xFD, // echo
        0xFE, 0xFE, 0xE0, 0x88, 0x04, 0x00, 0x01, 0xFD,
      ]);
      expect(freqs(updates), [14074000]);
      expect(modes(updates), [RigMode.lsb]);
    });

    test('reassembles a frame split across reads, with leading noise', () {
      final codec = IcomCivCodec(0x94);
      expect(codec.feed([0x12, 0xFE]), isEmpty);
      expect(codec.feed([0xFE, 0xFE, 0xE0, 0x94, 0x03, 0x00, 0x40]), isEmpty);
      expect(freqs(codec.feed([0x07, 0x14, 0x00, 0xFD])), [14074000]);
    });
  });

  group('KenwoodCodec', () {
    test('asks for the mode only once the dialect is known', () {
      final kenwood = KenwoodCodec();
      expect(kenwood.nextPoll(), ascii.encode('FA;'));
      kenwood.feed(ascii.encode('FA00014074000;'));
      expect(kenwood.nextPoll(), ascii.encode('FA;MD;'));

      final yaesu = KenwoodCodec();
      yaesu.feed(ascii.encode('FA014074000;'));
      expect(yaesu.nextPoll(), ascii.encode('FA;MD0;'));
    });

    test('decodes Kenwood 11-digit and Yaesu 9-digit replies', () {
      expect(freqs(KenwoodCodec().feed(ascii.encode('FA00014074000;'))),
          [14074000]);
      expect(freqs(KenwoodCodec().feed(ascii.encode('FA007074000;'))),
          [7074000]);
    });

    test('decodes the mode with the right table per dialect', () {
      final kenwood = KenwoodCodec();
      expect(modes(kenwood.feed(ascii.encode('FA00007030000;MD3;'))),
          [RigMode.cw]);
      final yaesu = KenwoodCodec();
      expect(modes(yaesu.feed(ascii.encode('FA007030000;MD03;'))),
          [RigMode.cw]);
      // Yaesu DATA-U (C) says nothing about FT8 vs PSK: ignored
      expect(yaesu.feed(ascii.encode('MD0C;')), isEmpty);
    });

    test('ignores a mode reply before the dialect is known', () {
      expect(KenwoodCodec().feed(ascii.encode('MD2;')), isEmpty);
    });

    test('reassembles split replies and skips unrelated ones', () {
      final codec = KenwoodCodec();
      expect(codec.feed(ascii.encode('?;PS1;FA0002')), isEmpty);
      expect(freqs(codec.feed(ascii.encode('8074000;FA00028075000;'))),
          [28074000, 28075000]);
    });
  });

  group('YaesuLegacyCodec', () {
    test('decodes the 5-byte reply: 10 Hz steps plus mode', () {
      final codec = YaesuLegacyCodec();
      expect(codec.nextPoll(), [0, 0, 0, 0, 0x03]);
      expect(codec.feed([0x01, 0x40]), isEmpty);
      final updates = codec.feed([0x74, 0x50, 0x01]);
      expect(freqs(updates), [14074500]);
      expect(modes(updates), [RigMode.usb]);
    });

    test('a new poll drops a partial reply', () {
      final codec = YaesuLegacyCodec();
      codec.feed([0x99]);
      codec.nextPoll();
      final updates = codec.feed([0x00, 0x70, 0x74, 0x00, 0x00]);
      expect(freqs(updates), [7074000]);
      expect(modes(updates), [RigMode.lsb]);
    });
  });

  group('tune', () {
    test('CI-V: set frequency, then mode + filter, then polling resumes', () {
      final codec = IcomCivCodec(0x88);
      codec.tune(14074000, RigMode.usb);
      expect(codec.nextPoll(),
          [0xFE, 0xFE, 0x88, 0xE0, 0x05, 0x00, 0x40, 0x07, 0x14, 0x00, 0xFD]);
      expect(codec.nextPoll(), [0xFE, 0xFE, 0x88, 0xE0, 0x06, 0x01, 0x01, 0xFD]);
      expect(codec.nextPoll(), [0xFE, 0xFE, 0x88, 0xE0, 0x03, 0xFD]);
    });

    test('CI-V: no mode leaves the radio mode alone', () {
      final codec = IcomCivCodec(0x94);
      codec.tune(7155120, null);
      expect(codec.nextPoll(),
          [0xFE, 0xFE, 0x94, 0xE0, 0x05, 0x20, 0x51, 0x15, 0x07, 0x00, 0xFD]);
      expect(codec.nextPoll(), [0xFE, 0xFE, 0x94, 0xE0, 0x03, 0xFD]);
    });

    test('Kenwood/Yaesu: waits for the dialect, then sets in its format', () {
      final kenwood = KenwoodCodec()..tune(7030000, RigMode.cw);
      expect(kenwood.nextPoll(), ascii.encode('FA;'));
      kenwood.feed(ascii.encode('FA00014074000;'));
      expect(kenwood.nextPoll(), ascii.encode('FA00007030000;MD3;FA;MD;'));
      expect(kenwood.nextPoll(), ascii.encode('FA;MD;'));

      final yaesu = KenwoodCodec();
      yaesu.feed(ascii.encode('FA014074000;'));
      yaesu.tune(3700000, RigMode.lsb);
      expect(yaesu.nextPoll(), ascii.encode('FA003700000;MD01;FA;MD0;'));
    });

    test('FT-817: set frequency and mode, one per tick', () {
      final codec = YaesuLegacyCodec()..tune(14074500, RigMode.usb);
      expect(codec.nextPoll(), [0x01, 0x40, 0x74, 0x50, 0x01]);
      expect(codec.nextPoll(), [0x01, 0, 0, 0, 0x07]);
      expect(codec.nextPoll(), [0, 0, 0, 0, 0x03]);
    });

    test('spot modes map to radio modes; digital ones leave it alone', () {
      expect(RigMode.forLogMode('SSB', 7100000), RigMode.lsb);
      expect(RigMode.forLogMode('SSB', 14200000), RigMode.usb);
      expect(RigMode.forLogMode('CW', 14020000), RigMode.cw);
      expect(RigMode.forLogMode('FT8', 14074000), isNull);
      expect(RigMode.forLogMode('', 14074000), isNull);
    });
  });

  group('RigMode', () {
    test('maps to the log modes', () {
      expect(RigMode.lsb.appMode, 'SSB');
      expect(RigMode.lsb.appSubmode, 'LSB');
      expect(RigMode.cw.appMode, 'CW');
      expect(RigMode.cw.appSubmode, isNull);
    });

    test('a sideband never overrides a digital mode', () {
      expect(RigMode.usb.appliesTo('FT8'), isFalse);
      expect(RigMode.usb.appliesTo('PSK31'), isFalse);
      expect(RigMode.usb.appliesTo('CW'), isTrue);
      expect(RigMode.cw.appliesTo('FT8'), isTrue);
    });
  });

  test('formatRigFreqMhz keeps Hz precision, at least kHz', () {
    expect(formatRigFreqMhz(14074000), '14.074');
    expect(formatRigFreqMhz(14285500), '14.2855');
    expect(formatRigFreqMhz(7155123), '7.155123');
  });
}
