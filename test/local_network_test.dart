import 'package:flutter_test/flutter_test.dart';
import 'package:wavelog_mobile/core/utils/local_network.dart';

void main() {
  group('isLikelyLocalNetworkHost', () {
    test('10.0.0.0/8 is local', () {
      expect(isLikelyLocalNetworkHost('10.0.0.1'), isTrue);
      expect(isLikelyLocalNetworkHost('10.255.255.255'), isTrue);
    });

    test('172.16.0.0/12 is local, just outside the range is not', () {
      expect(isLikelyLocalNetworkHost('172.16.0.1'), isTrue);
      expect(isLikelyLocalNetworkHost('172.31.255.255'), isTrue);
      expect(isLikelyLocalNetworkHost('172.15.255.255'), isFalse);
      expect(isLikelyLocalNetworkHost('172.32.0.0'), isFalse);
    });

    test('192.168.0.0/16 is local (the reported bug case)', () {
      expect(isLikelyLocalNetworkHost('192.168.50.166'), isTrue);
      expect(isLikelyLocalNetworkHost('192.168.0.1'), isTrue);
      expect(isLikelyLocalNetworkHost('192.169.0.1'), isFalse);
    });

    test('169.254.0.0/16 link-local is local', () {
      expect(isLikelyLocalNetworkHost('169.254.1.1'), isTrue);
    });

    test('100.64.0.0/10 CGNAT is local, just outside the range is not', () {
      expect(isLikelyLocalNetworkHost('100.64.0.1'), isTrue);
      expect(isLikelyLocalNetworkHost('100.127.255.255'), isTrue);
      expect(isLikelyLocalNetworkHost('100.63.255.255'), isFalse);
      expect(isLikelyLocalNetworkHost('100.128.0.0'), isFalse);
    });

    test('loopback is deliberately NOT treated as local', () {
      expect(isLikelyLocalNetworkHost('127.0.0.1'), isFalse);
    });

    test('a public IPv4 address is not local', () {
      expect(isLikelyLocalNetworkHost('8.8.8.8'), isFalse);
      expect(isLikelyLocalNetworkHost('1.1.1.1'), isFalse);
    });

    test('.local mDNS hostnames are local', () {
      expect(isLikelyLocalNetworkHost('wavelog.local'), isTrue);
      expect(isLikelyLocalNetworkHost('MYSERVER.LOCAL'), isTrue);
    });

    test('a bare hostname with no dot is local', () {
      expect(isLikelyLocalNetworkHost('wavelog-server'), isTrue);
    });

    test('a normal public domain is not local', () {
      expect(isLikelyLocalNetworkHost('wavelog.example.com'), isFalse);
      expect(isLikelyLocalNetworkHost('wavelog.sm6srw.net'), isFalse);
    });

    test('IPv6 link-local and ULA are local (best-effort)', () {
      expect(isLikelyLocalNetworkHost('fe80::1'), isTrue);
      expect(isLikelyLocalNetworkHost('fd00::1'), isTrue);
    });

    test('a public IPv6 address is not local', () {
      expect(isLikelyLocalNetworkHost('2001:4860:4860::8888'), isFalse);
    });
  });
}
