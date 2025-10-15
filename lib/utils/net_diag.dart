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
}
