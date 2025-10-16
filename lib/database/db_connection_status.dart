import 'package:flutter/foundation.dart';

/// 앱 전역에서 DB 연결 상태를 관찰하기 위한 경량 상태 허브
/// - up: null(알 수 없음) / true(연결) / false(끊김)
/// - reconnecting: 재연결 루프 동작 여부
class DbConnectionStatus {
  DbConnectionStatus._();
  static final DbConnectionStatus instance = DbConnectionStatus._();

  /// DB가 정상인지 여부. null은 초기/미확인 상태.
  final ValueNotifier<bool?> up = ValueNotifier<bool?>(null);

  /// 재연결 시도 중인지 여부.
  final ValueNotifier<bool> reconnecting = ValueNotifier<bool>(false);

  void reset() {
    up.value = null;
    reconnecting.value = false;
  }
}
