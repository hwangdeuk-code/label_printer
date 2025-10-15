import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';

import 'core/app.dart';
import 'core/bootstrap.dart';
import 'core/lifecycle.dart';
import 'ui_shared/startup_home.dart';
import 'ui_shared/global_reconnect_overlay.dart';
export 'ui_shared/startup_home.dart';

Future<void> main(List<String> args) async {
  // Widgets 초기화는 모든 플랫폼 공통으로 필요하다.
  WidgetsFlutterBinding.ensureInitialized();

  // 앱 시작 시 라이프사이클 옵저버를 1회 등록
  LifecycleManager.instance.ensureInitialized();

  // 데스크톱 환경에서는 지정한 디스플레이로 이동 후 최대화.
  if (Platform.isWindows || Platform.isMacOS) {
    //final requestedDisplay = resolveDisplayIndex(args);
    await initDesktopWindow(targetIndex: 0); //requestedDisplay ?? 0);
    
    // 창 닫기(X) 시 우리 정리 로직을 먼저 수행할 수 있도록 보장
    await windowManager.setPreventClose(true);
    windowManager.addListener(_AppWindowListener());

    isDesktop = true;
  }

  // 앱 정보를 조회해 전역에 보관한다.
  final info = await PackageInfo.fromPlatform();
  appPackageName = info.packageName;
  appVersion = info.version;

  // 공통 StartUp 페이지를 표시한다.
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => GlobalReconnectOverlay(child: child),
      home: const StartupHomePage(),
    ),
  );
}

class _AppWindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    final isPrevent = await windowManager.isPreventClose();
    if (isPrevent) {
      // 앱 전역 종료 요청 브로드캐스트(비동기 정리 작업이 있다면 여기서 시작)
      LifecycleManager.instance.notifyExitRequested();
      // 짧은 딜레이로 즉시 종료로 인한 정리 누락을 완화(필요시 조정)
      await Future.delayed(const Duration(milliseconds: 120));
      await windowManager.destroy();
    }
  }
}
