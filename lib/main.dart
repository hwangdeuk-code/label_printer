/// 한글 주석: 앱 진입점(리팩터링 후)
/// 1) Widgets 초기화
/// 2) 데스크톱 창 초기화
/// 3) MyApp 실행
import 'package:flutter/material.dart';
import 'core/bootstrap.dart';
import 'app.dart';
export 'app.dart';  // 테스트에서 package:.../main.dart로 가져올 때 MyApp 노출

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDesktopWindow();
  runApp(const MyApp());
}
