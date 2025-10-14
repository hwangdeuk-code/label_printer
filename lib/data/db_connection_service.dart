import 'dart:async';

import 'package:label_printer/data/db_connection_status.dart';
import 'package:label_printer/data/db_connection_monitor.dart';
import 'package:label_printer/data/db_server_connect_info.dart';
import 'package:label_printer/data/main_database.dart';

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

  Future<void> _scheduleReconnect() async {
    if (status.reconnecting.value) return;
    status.reconnecting.value = true;
    _reconnectCancelled = false;
    while (!MainDatabaseHelper.isConnected && _lastConnectInfo != null) {
      if (_reconnectCancelled) break;
      final backoff = Duration(seconds: (5 * (1 << _retryAttempt)).clamp(5, 60));
      await Future.delayed(backoff);
      if (_reconnectCancelled) break;
      try {
        await MainDatabaseHelper.connect(_lastConnectInfo!);
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
