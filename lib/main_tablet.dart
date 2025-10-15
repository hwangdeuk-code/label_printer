import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/app.dart';
import 'core/lifecycle.dart';
import 'ui_shared/startup_home.dart';
import 'ui_shared/global_reconnect_overlay.dart';

Future<void> main(List<String> args) async {
  // Widgets 초기화는 모든 플랫폼 공통으로 필요하다.
  WidgetsFlutterBinding.ensureInitialized();

  // 앱 시작 시 라이프사이클 옵저버를 1회 등록
  LifecycleManager.instance.ensureInitialized();

  // 앱 정보를 조회해 전역에 보관한다.
  final info = await PackageInfo.fromPlatform();
  appPackageName = info.packageName;
  appVersion = info.version;

  // StartupHomePage 실행
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => GlobalReconnectOverlay(child: child),
      home: const StartupHomePage(),
    ),
  );
}
