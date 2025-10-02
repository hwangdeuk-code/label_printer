/// 한글 주석: 데스크톱(Windows/macOS) 창 초기화 유틸리티
/// 멀티 모니터 환경에서 초기 위치/크기를 설정합니다.
import 'dart:io' show Platform;
import 'dart:ui' show Offset, Size;
import 'package:flutter/material.dart'; // Colors 사용
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';
import '../core/constants.dart';

Future<void> initDesktopWindow({int targetIndex = 0}) async {
  await windowManager.ensureInitialized();

  if (!(Platform.isWindows || Platform.isMacOS)) {
    return;
  }

  // 모니터 목록 조회
  final displays = await screenRetriever.getAllDisplays();
  if (displays.isEmpty) {
    return;
  }

  final safeIndex = targetIndex.clamp(0, displays.length - 1);
  final display = displays[safeIndex];

  // 작업표시줄 제외한 표시 영역(논리 픽셀) 얻기
  final pos = display.visiblePosition ?? const Offset(0, 0);
  final size = display.visibleSize ?? display.size;

  // 기본 창 크기
  const double winW = 1200.0;
  const double winH = 800.0;

  // 가운데 정렬
  final left = pos.dx + (size.width - winW) / 2;
  final top  = pos.dy + (size.height - winH) / 2;

  // 창 옵션 및 표시
  const windowOptions = WindowOptions(
    title: appTitle,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // 먼저 크기 → 그다음 위치 → show 순으로 처리
    await windowManager.setSize(const Size(winW, winH));
    await windowManager.setPosition(Offset(left, top));
    await windowManager.show();
    await windowManager.focus();
  });
}
