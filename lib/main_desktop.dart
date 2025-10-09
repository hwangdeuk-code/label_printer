import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/app.dart';
import 'core/bootstrap.dart';
import 'ui_shared/startup_home.dart';

Future<void> main(List<String> args) async {
  // Widgets 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 데스크톱 창 초기화
  await initDesktopWindow();
  isDesktop = true;

  // 앱 버전 정보 가져오기
  final info = await PackageInfo.fromPlatform();
  appVersion = info.version;

  // StartupHomePage 실행
  runApp(const MaterialApp(
    debugShowCheckedModeBanner:false,
    home: StartupHomePage()
  ));
}
