// 데스크톱(Windows/macOS) 런타임 초기화를 위한 유틸리티.
// 다중 모니터 환경에서 시작 위치와 창 상태를 제어한다.
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../core/app.dart';

Future<void> initDesktopWindow({int targetIndex = 0}) async {
  await windowManager.ensureInitialized();

  final displays = await screenRetriever.getAllDisplays();
  if (displays.isEmpty) {
    return;
  }

  final safeIndex = targetIndex.clamp(0, displays.length - 1).toInt();

  const windowOptions = WindowOptions(
    title: appTitle,
    size: Size(1200, 800),
    backgroundColor: Colors.transparent,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await moveToDisplayAndMaximize(displayIndex: safeIndex, fullscreen: false);
    await windowManager.focus();
  });
}

Future<void> moveToDisplayAndMaximize({
  required int displayIndex,
  bool fullscreen = false,
}) async {
  final displays = await screenRetriever.getAllDisplays();
  if (displays.isEmpty) return;

  final safeIndex = displayIndex.clamp(0, displays.length - 1).toInt();
  final target = displays[safeIndex];

  final pos = target.visiblePosition ?? const Offset(0, 0);
  final targetSize = target.visibleSize ?? target.size;

  await windowManager.unmaximize();
  await windowManager.setFullScreen(false);
  await windowManager.setBounds(
    null,
    position: pos,
    size: Size(targetSize.width, targetSize.height),
    animate: false,
  );

  if (fullscreen) {
    await windowManager.setFullScreen(true);
  } else {
    await windowManager.maximize();
    if (!await windowManager.isMaximized()) {
      // 윈도우즈에서 첫 호출이 무시될 수 있으므로 재시도한다.
      await Future.delayed(const Duration(milliseconds: 120));
      if (!await windowManager.isMaximized()) {
        await windowManager.maximize();
      }
    }
  }
}

int? resolveDisplayIndex(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];

    if (arg.startsWith('--display=')) {
      return _parseDisplayIndexArgument(arg.substring('--display='.length));
    }

    if (arg.startsWith('--display-index=')) {
      return _parseDisplayIndexArgument(
        arg.substring('--display-index='.length),
      );
    }

    if (arg == '--display' || arg == '--display-index') {
      if (i + 1 < args.length) {
        return _parseDisplayIndexArgument(args[i + 1]);
      }
    }
  }
  return null;
}

int? _parseDisplayIndexArgument(String raw) {
  final value = int.tryParse(raw.trim());
  if (value == null || value < 0) {
    return null;
  }
  return value;
}
