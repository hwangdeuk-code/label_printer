import 'package:flutter/material.dart';
import 'package:label_printer/database/db_connection_status.dart';
import 'package:label_printer/database/db_connection_service.dart';

/// 앱 전역에 재연결 모달을 표시하는 오버레이 래퍼
/// - MaterialApp.builder에서 child를 감싸 사용
class DbReconnectOverlay extends StatefulWidget {
  final Widget? child;
  const DbReconnectOverlay({super.key, required this.child});

  @override
  State<DbReconnectOverlay> createState() => _DbReconnectOverlayState();
}

class _DbReconnectOverlayState extends State<DbReconnectOverlay> {
  final hub = DbConnectionStatus.instance;

  bool _cancelledUntilRestored = false;

  @override
  void initState() {
    super.initState();
    hub.up.addListener(_onUpChanged);
  }

  void _onUpChanged() {
    // 연결이 복구되면 취소 상태 해제
    if (hub.up.value == true && _cancelledUntilRestored) {
      setState(() => _cancelledUntilRestored = false);
    }
  }

  @override
  void dispose() {
    hub.up.removeListener(_onUpChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (widget.child != null) widget.child!,
        // 상태 변화에 따른 모달 표시
        ValueListenableBuilder<bool?>(
          valueListenable: hub.up,
          builder: (context, up, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: hub.reconnecting,
              builder: (context, reconnecting, __) {
                final shouldShow = !_cancelledUntilRestored && ((up == false) || reconnecting);
                if (!shouldShow) return const SizedBox.shrink();
                return Positioned.fill(
                  child: IgnorePointer(
                    ignoring: false,
                    child: Stack(
                      children: [
                        const ModalBarrier(dismissible: false, color: Colors.black38),
                        Center(
                          child: Material(
                            elevation: 8,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('서버 연결 재시도 중', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: const [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(child: Text('네트워크 연결 상태를 확인 중입니다...')),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () {
                                            // 재연결 취소 후 모달 숨김(복구될 때까지)
                                            DbConnectionService.instance.cancelReconnect();
                                            setState(() => _cancelledUntilRestored = true);
                                          },
                                          child: const Text('취소'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
