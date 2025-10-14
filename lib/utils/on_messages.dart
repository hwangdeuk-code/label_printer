// UTF-8
import 'package:flutter/material.dart';

/// 앱 전역에서 재사용 가능한 스낵바 표시 유틸 함수
void showSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
    ),
  );
}

// 확인/취소 없이 프로그램에서 보여주고/숨기는 완전 모달

/// BlockingOverlay에 표시할 액션 버튼 한 쌍(라벨 + 콜백)
class BlockingOverlayAction {
  final String label;
  final VoidCallback? onPressed; // 생략 가능
  const BlockingOverlayAction({required this.label, this.onPressed});
}

class BlockingOverlay {
  static OverlayEntry? _entry;

  /// 모달을 표시합니다.
  /// - message: 스피너 옆에 표시할 텍스트
  /// - actions: 표시할 버튼 목록(라벨+콜백). 클릭 시 모달을 먼저 닫고 콜백을 호출합니다.
  static void show(
    BuildContext context, {
    String message = '처리 중...',
    List<BlockingOverlayAction> actions = const [],
  }) {
    if (_entry != null) {
      _entry?.remove();
    }

    _entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // 터치 차단 + 반투명 배경
          const ModalBarrier(dismissible: false, color: Colors.black54),
          // 내용
          Center(
            child: Material(
              type: MaterialType.card,
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          actions.isEmpty
                              ? const CircularProgressIndicator()
                              : Icon(Icons.info_outline,
                                  color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 16),
                          Flexible(child: Text(message)),
                        ],
                      ),
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Spacer(),
                            Wrap(
                              spacing: 8,
                              children: actions
                                  .map(
                                    (a) => TextButton(
                                      onPressed: () {
                                        final cb = a.onPressed;
                                        BlockingOverlay.hide();
                                        // 모달을 먼저 닫고, 콜백이 있으면 실행
                                        if (cb != null) Future.microtask(cb);
                                      },
                                      child: Text(a.label),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final overlay = Overlay.of(context, rootOverlay: true);
    overlay.insert(_entry!);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }
}
