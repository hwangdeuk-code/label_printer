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
class BlockingOverlay {
  static OverlayEntry? _entry;

  static void show(BuildContext context, {String message = '처리 중...'}) {
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 16),
                    Flexible(child: Text(message)),
                  ],
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
