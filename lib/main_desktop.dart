import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/app.dart';
import 'core/bootstrap.dart';
import 'ui_shared/startup_home.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final requestedDisplay = resolveDisplayIndex(args);
  await initDesktopWindow(targetIndex: requestedDisplay ?? 0);
  isDesktop = true;

  final info = await PackageInfo.fromPlatform();
  appVersion = info.version;

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StartupHomePage(),
    ),
  );
}
