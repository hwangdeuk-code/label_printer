// UTF-8
import 'package:flutter/material.dart';

/// 스낵바에 표시할 메시지 유형
enum SnackBarType {
  /// 정보 (기본값)
  info,
  /// 경고
  warning,
  /// 오류
  error,
  /// 진행 중
  inProgress,
}

/// 앱 전역에서 재사용 가능한 스낵바 표시 유틸 함수
void showSnackBar(
  BuildContext context,
  String message, {
  SnackBarType type = SnackBarType.info,
  VoidCallback? onVisible,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  // 유형별 아이콘 및 색상 결정
  Widget icon;
  Color? backgroundColor;
  Color? foregroundColor = Colors.white;

  switch (type) {
    case SnackBarType.info:
      icon = Icon(Icons.info_outline, color: foregroundColor);
      backgroundColor = const Color(0xFF424242); // 기본 스낵바 색상과 유사하게
      break;
    case SnackBarType.warning:
      icon = const Icon(Icons.warning_amber_rounded, color: Colors.black87);
      backgroundColor = const Color(0xFFFFC107); // Amber
      foregroundColor = Colors.black87;
      break;
    case SnackBarType.error:
      icon = Icon(Icons.error_outline, color: colorScheme.onError);
      backgroundColor = colorScheme.error;
      foregroundColor = colorScheme.onError;
      break;
    case SnackBarType.inProgress:
      icon = SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
      backgroundColor = const Color(0xFF424242);
      break;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: foregroundColor),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      onVisible: onVisible,
    ),
  );
}
