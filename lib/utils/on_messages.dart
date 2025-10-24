// UTF-8
import 'package:flutter/material.dart';

/// 앱 전역에서 재사용 가능한 스낵바 표시 유틸 함수
void showSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  VoidCallback? onVisible,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      onVisible: onVisible,
    ),
  );
}
