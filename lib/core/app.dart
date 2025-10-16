// 한글 주석: 전역 정의 파일
// 앱 전역에서 참조되는 상수 및 변수들을 모아둡니다.

import '../models/user.dart';

const String appTitle = 'ITS&G Label Printer';

// StartupHomePage.initState()에서 설정됨.
String appPackageName = '';
String appVersion = '';
bool isDesktop = false;

// 전역 사용자 세션 정보.
User? gUserInfo;
