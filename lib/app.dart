/// 한글 주석: 최상위 앱 위젯
/// MaterialApp, 테마, 홈 라우트를 정의합니다.
import 'package:flutter/material.dart';
import 'core/constants.dart';
import 'pages/painter_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PainterPage(),
    );
  }
}
