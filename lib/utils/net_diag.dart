import 'dart:io';

import 'package:flutter/foundation.dart';

class NetDiag {
  /// 지정한 호스트/포트로 TCP 접속이 가능한지 확인합니다.
  /// - timeout: 기본 3초
  /// - 반환: true면 접속 성공, false면 실패
  static Future<bool> probeTcp(String host, int port, {Duration timeout = const Duration(seconds: 3)}) async {
    try {
      final sw = Stopwatch()..start();
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      sw.stop();
      debugPrint('NetDiag: TCP $host:$port reachable in ${sw.elapsedMilliseconds}ms');
      return true;
    } on SocketException catch (e) {
      debugPrint('NetDiag: TCP $host:$port socket error: ${e.message} (${e.osError?.errorCode})');
      return false;
    } on HandshakeException catch (e) {
      // 클리어텍스트 포트에 TLS 시도 등 프로토콜 에러
      debugPrint('NetDiag: TCP $host:$port handshake error: $e');
      return false;
    } catch (e) {
      debugPrint('NetDiag: TCP $host:$port error: $e');
      return false;
    }
  }

  /// 네트워크의 기본 라우트로 선택되는 IPv4 주소를 가져옴.
  /// 실패 시 네트워크 인터페이스를 열거하여 첫 IPv4 글로벌 유니캐스트 주소를 반환.
  /// 모두 실패하면 빈 문자열("") 반환.
  static Future<String> getIp() async {
    // 1) 기본 라우트 기준 IP 추정 (외부 서버와의 연결을 통해 사용 중인 NIC 선택)
    try {
      // UDP/TCP 어떤 것이든 무관. 여기서는 TCP로 8.8.8.8:53에 짧게 연결.
      final socket = await Socket.connect('8.8.8.8', 53,
          timeout: const Duration(milliseconds: 800));
      final ip = socket.address.address; // 이 소켓에 매칭된 로컬 IP
      socket.destroy();                  // 즉시 정리
      if (_isValidIPv4(ip)) return ip;
    } catch (_) {
      // 무시하고 폴백 단계로 진행
    }

    // 2) 인터페이스를 열거하여 첫 IPv4 글로벌 유니캐스트 주소 반환
    try {
      final ifaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      for (final ni in ifaces) {
        for (final addr in ni.addresses) {
          final ip = addr.address;
          if (!addr.isLoopback && _isValidIPv4(ip)) {
            return ip;
          }
        }
      }
    } catch (_) {
      // 무시
    }

    // 3) 모두 실패 시 빈 문자열
    return "";
  }

  /// 유효한 IPv4(글로벌 유니캐스트 추정) 판별
  static bool _isValidIPv4(String ip) {
    if (ip.isEmpty || ip == '0.0.0.0') return false;
    if (ip.startsWith('127.')) return false;      // 루프백
    if (ip.startsWith('169.254.')) return false;  // 링크-로컬(APIPA)
    final first = int.tryParse(ip.split('.').first) ?? 0;
    if (first >= 224 && first <= 239) return false; // 멀티캐스트
    return true;
  }  
}
