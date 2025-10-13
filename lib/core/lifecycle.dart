import 'package:flutter/widgets.dart';

/// 콜백 모음: 필요한 이벤트만 선택적으로 전달하면 됩니다.
class LifecycleCallbacks {
  final VoidCallback? onResumed;
  final VoidCallback? onInactive;
  final VoidCallback? onPaused;
  final VoidCallback? onDetached;       // 엔진 분리 (종료 직전)
  final VoidCallback? onExitRequested;  // 데스크톱 창 닫기 등 명시적 종료 요청 시 수동 통지용

  const LifecycleCallbacks({
    this.onResumed,
    this.onInactive,
    this.onPaused,
    this.onDetached,
    this.onExitRequested,
  });
}

/// 앱 전역 라이프사이클을 관찰/브로드캐스트하는 싱글톤 매니저.
class LifecycleManager with WidgetsBindingObserver {
  LifecycleManager._internal();
  static final LifecycleManager instance = LifecycleManager._internal();

  bool _initialized = false;
  final Set<LifecycleCallbacks> _observers = <LifecycleCallbacks>{};

  /// WidgetsBinding에 옵저버를 1회만 등록합니다.
  void ensureInitialized() {
    if (_initialized) return;
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    _initialized = true;
  }

  /// 옵저버(콜백 묶음)를 등록합니다.
  void addObserver(LifecycleCallbacks callbacks) {
    _observers.add(callbacks);
  }

  /// 등록된 옵저버를 제거합니다.
  void removeObserver(LifecycleCallbacks callbacks) {
    _observers.remove(callbacks);
  }

  /// 수명 종료 시 매니저를 해제합니다.
  void dispose() {
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(this);
      _initialized = false;
    }
    _observers.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    for (final cb in List<LifecycleCallbacks>.from(_observers)) {
      try {
        switch (state) {
          case AppLifecycleState.resumed:
            cb.onResumed?.call();
            break;
          case AppLifecycleState.inactive:
            cb.onInactive?.call();
            break;
          case AppLifecycleState.paused:
            cb.onPaused?.call();
            break;
          case AppLifecycleState.detached:
            cb.onDetached?.call();
            break;
          case AppLifecycleState.hidden:
            // Android/desktop에서 화면이 완전히 숨겨졌을 때. 특별 처리 필요시 콜백을 추가하세요.
            break;
        }
      } catch (_) {
        // 개별 콜백 오류는 전파하지 않음
      }
    }
  }

  /// 창 닫기 등 명시적 종료 요청 시 수동으로 호출해 콜백을 알립니다.
  void notifyExitRequested() {
    for (final cb in List<LifecycleCallbacks>.from(_observers)) {
      try {
        cb.onExitRequested?.call();
      } catch (_) {}
    }
  }
}
