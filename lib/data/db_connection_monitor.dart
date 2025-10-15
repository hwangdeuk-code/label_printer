import 'dart:async';
import 'dart:convert';
import 'package:label_printer/data/db_client.dart';

/// MSSQL 연결 상태를 주기적으로 점검하는 간단한 모니터.
/// - 기본은 SELECT 1 핑으로 연결 끊김을 감지
/// - 실패/성공 전환 시 콜백 알림 및 스트림 이벤트 발행
class DbConnectionMonitor {
  final Duration interval;
  final Future<bool> Function()? customPing; // true면 정상, false면 실패
  final void Function()? onLost; // 정상 -> 끊김 전환 시 1회 호출
  final void Function()? onRestored; // 끊김 -> 정상 전환 시 1회 호출

  Timer? _timer;
  bool? _isUp;
  final StreamController<bool> _statusCtrl = StreamController<bool>.broadcast();

  Stream<bool> get statusStream => _statusCtrl.stream; // true: up, false: down
  bool? get lastStatus => _isUp;

  DbConnectionMonitor({
    this.interval = const Duration(seconds: 30),
    this.customPing,
    this.onLost,
    this.onRestored,
  });

  void start() {
    _timer?.cancel();
    // 즉시 1회 점검 후 주기 시작
    _check();
    _timer = Timer.periodic(interval, (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    final ok = await _pingSafe();
    if (_isUp == null) {
      _isUp = ok;
      _statusCtrl.add(ok);
      return;
    }
    if (_isUp != ok) {
      _isUp = ok;
      _statusCtrl.add(ok);
      if (ok) {
        onRestored?.call();
      } else {
        onLost?.call();
      }
    }
  }

  Future<bool> _pingSafe() async {
    try {
      if (customPing != null) {
        return await customPing!();
      }
      // 기본 핑: SELECT 1
  final s = await DbClient.instance.getData('SELECT 1');
      try {
        final j = jsonDecode(s);
        if (j is Map && j['error'] != null) return false;
        return true;
      } catch (_) {
        // 예상치 못한 응답 포맷이면 일단 성공으로 간주(네트워크·세션 오류는 예외로 떨어지는 편)
        return true;
      }
    } catch (_) {
      return false; // 예외 = 연결 실패로 판단
    }
  }

  Future<void> dispose() async {
    stop();
    await _statusCtrl.close();
  }
}
