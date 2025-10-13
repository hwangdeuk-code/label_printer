import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/app.dart';
import 'core/lifecycle.dart';
import 'ui_shared/startup_home.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  LifecycleManager.instance.ensureInitialized();

  // 앱 버전 정보 가져오기
  final info = await PackageInfo.fromPlatform();
  appVersion = info.version;

  // StartupHomePage 실행
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StartupHomePage(),
    ),
  );
}
