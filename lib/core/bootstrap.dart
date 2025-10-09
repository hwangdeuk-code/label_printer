/// 한글 주석: 데스크톱(Windows/macOS) 창 초기화 유틸리티
/// 멀티 모니터 환경에서 초기 위치/크기를 설정합니다.
import 'package:flutter/material.dart'; // Colors 사용
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';
import '../core/app.dart';

Future<void> initDesktopWindow({int targetIndex = 0}) async {
  await windowManager.ensureInitialized();

  // 모니터 목록 조회
  final displays = await screenRetriever.getAllDisplays();
  if (displays.isEmpty) {
    return;
  }

  final safeIndex = targetIndex.clamp(0, displays.length - 1);
  final display = displays[safeIndex];

  // 창을 전체 화면으로 만들기 전, 먼저 목표 디스플레이의 위치와 크기로 설정합니다.
  final pos = display.visiblePosition ?? Offset.zero;
  final size = display.size;

  // 창 옵션 및 표시
  const windowOptions = WindowOptions(
    title: appTitle,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // 창을 보이지 않는 상태에서 위치와 크기를 먼저 설정합니다.
    await windowManager.setPosition(pos);
    await windowManager.setSize(size);
    // 그 다음 전체 화면으로 전환합니다.
    await windowManager.setFullScreen(true);
    // 모든 시각적 설정이 완료된 후에 창을 보여주고 포커스를 맞춥니다.
    await windowManager.show();
    await windowManager.focus();
  });
}
