import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/app.dart';
import 'core/bootstrap.dart';
import 'ui_shared/startup_home.dart';

export 'ui_shared/startup_home.dart';

Future<void> main(List<String> args) async {
  // Widgets 초기화는 모든 플랫폼 공통으로 필요하다.
  WidgetsFlutterBinding.ensureInitialized();

  // 데스크톱 환경에서는 지정한 디스플레이로 이동 후 최대화.
  if (Platform.isWindows || Platform.isMacOS) {
    //final requestedDisplay = resolveDisplayIndex(args);
    await initDesktopWindow(targetIndex: 0); //requestedDisplay ?? 0);
    isDesktop = true;
  }

  // 앱 버전 정보를 조회해 전역에 보관한다.
  final info = await PackageInfo.fromPlatform();
  appVersion = info.version;

  // 공통 StartUp 페이지를 표시한다.
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StartupHomePage(),
    ),
  );
}
