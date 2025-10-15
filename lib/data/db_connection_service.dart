import 'dart:async';

import 'package:label_printer/data/db_connection_status.dart';
import 'package:label_printer/data/db_connection_monitor.dart';
import 'package:label_printer/data/db_server_connect_info.dart';
import 'package:label_printer/data/db_client.dart';

/// DB 연결 상태 모니터링과 재연결을 담당하는 전역 서비스
class DbConnectionService {
  DbConnectionService._();
  static final DbConnectionService instance = DbConnectionService._();
  final status = DbConnectionStatus.instance;

  DbConnectionMonitor? _monitor;
  StreamSubscription<bool>? _sub;
  ServerConnectInfo? _lastConnectInfo;
  int _retryAttempt = 0;
  bool _reconnectCancelled = false;
  int _pollingPauseDepth = 0;

  void attachAndStart({required ServerConnectInfo info, Duration interval = const Duration(seconds: 20)}) {
    _lastConnectInfo = info;
    _monitor?.dispose();
    _monitor = DbConnectionMonitor(
      interval: interval,
      onLost: () {
        status.up.value = false;
        _scheduleReconnect();
      },
      onRestored: () {
        status.up.value = true;
        _retryAttempt = 0;
        status.reconnecting.value = false;
      },
    )..start();
    _pollingPauseDepth = 0;
    _sub?.cancel();
    _sub = _monitor!.statusStream.listen((up) {
      status.up.value = up;
    });
  }

  void detach() {
    _monitor?.dispose();
    _monitor = null;
    _sub?.cancel();
    _sub = null;
    status.reset();
  }

  // 사용자 쿼리 수행 중에는 모니터링 핑을 중지하여 세션 충돌을 피한다.
  void pausePolling() {
    if (_monitor == null) return;
    _pollingPauseDepth++;
    if (_pollingPauseDepth == 1) {
      _monitor!.stop();
    }
  }

  // 사용자 쿼리가 끝난 뒤 모니터링을 재개한다.
  void resumePolling() {
    if (_monitor == null) return;
    if (_pollingPauseDepth > 0) _pollingPauseDepth--;
    if (_pollingPauseDepth == 0) {
      _monitor!.start(immediate: false);
    }
  }

  /// 사용자 주도 DB 작업을 안전하게 실행한다.
  /// - 실행 전 모니터링 폴링을 일시 중지하고, 종료 후 재개한다(중첩 안전).
  /// - [timeout]이 지정되면 해당 시간 내 미응답 시 [onTimeout] 결과를 반환한다.
  Future<T> runUserDbAction<T>(
    Future<T> Function(DbClient db) action, {
    Duration? timeout,
    T Function()? onTimeout,
  }) async {
    final db = DbClient.instance;
    pausePolling();
    try {
      final fut = action(db);
      if (timeout != null) {
        return await fut.timeout(timeout, onTimeout: onTimeout);
      }
      return await fut;
    } finally {
      resumePolling();
    }
  }

  Future<void> _scheduleReconnect() async {
    if (status.reconnecting.value) return;
    status.reconnecting.value = true;
    _reconnectCancelled = false;
  final db = DbClient.instance;

  while (!db.isConnected && _lastConnectInfo != null) {
      if (_reconnectCancelled) break;
      final backoff = Duration(seconds: (5 * (1 << _retryAttempt)).clamp(5, 60));
      await Future.delayed(backoff);
      if (_reconnectCancelled) break;

      try {
        final ok = await db.connect(
          ip: _lastConnectInfo!.serverIp,
          port: _lastConnectInfo!.serverPort.toString(),
          databaseName: _lastConnectInfo!.databaseName,
          username: _lastConnectInfo!.userId,
          password: _lastConnectInfo!.password,
          timeoutInSeconds: 15,
        );
        if (!ok) {
          throw Exception('reconnect failed');
        }
        status.up.value = true;
        break;
      } catch (_) {}

      _retryAttempt = (_retryAttempt + 1).clamp(0, 6);
    }

    status.reconnecting.value = false;
  }

  void cancelReconnect() {
    _reconnectCancelled = true;
    status.reconnecting.value = false;
  }
}
