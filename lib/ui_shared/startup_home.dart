// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:label_printer/core/app.dart';
import 'package:label_printer/core/lifecycle.dart';
import 'package:label_printer/data/db_server_connect_info.dart';
import 'package:label_printer/data/main_database.dart';
import 'package:label_printer/utils/on_messages.dart';
import 'package:label_printer/utils/user_prefs.dart';
import 'package:label_printer/data/db_connection_monitor.dart';
import 'package:label_printer/data/db_connection_service.dart';
import 'package:label_printer/data/db_connection_status.dart';
import 'package:label_printer/ui_shared/components/connection_status_icon.dart';
import '../ui_desktop/screens/home_desktop.dart' as desktop;
import '../ui_tablet/screens/home_tablet.dart' as tablet;

// 사용자 로그인 및 앱 시작: 기본 프린터 설정 + 사용자 정보 입력
class StartupHomePage extends StatefulWidget {
  final bool fromLogout; // 사용자 로그아웃으로 진입했는지 여부
  const StartupHomePage({super.key, this.fromLogout = false});

  @override
  State<StartupHomePage> createState() => _StartupHomePageState();
}

class _StartupHomePageState extends State<StartupHomePage> {
  // 로그인 폼 상태 (비즈 로직 분리 안함)
  final _id = TextEditingController(text: '8134');
  final _company = TextEditingController();
  final _branch = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();
  DbConnectionMonitor? _monitor; // 제거 예정(전역 서비스로 대체)
  ServerConnectInfo? _lastConnectInfo;
  // ValueNotifier 기반 상태 감지를 위한 리스너 보관
  VoidCallback? _upListener;
  StreamSubscription<bool>? _monitorSub; // 삭제 예정

  // 공지 섹션(내용/버전)을 한 곳에서 관리하여 해시 계산과 UI가 동일한 소스를 사용하도록 함
  final String _noticeUpdateVersion = '2.7.5.3';
  final List<String> _noticeLines = const [
    '라벨매니저 2.7.4',
    '1. 공용라벨관리- 첨자 기능 추가',
    '2. tab 메뉴 자동 축소 기능 추가',
  ];

  String _currentNoticePayload() {
    final buf = StringBuffer();
    buf.writeln(_noticeUpdateVersion);
    for (final line in _noticeLines) {
      buf.writeln(line);
    }
    return buf.toString();
  }

  // 간단한 FNV-1a 64-bit 해시 구현 (의존성 없이 안정적인 텍스트 해시)
  String _fnv1a64Hex(String input) {
    const int fnv64Offset = 0xcbf29ce484222325; // 14695981039346656037
    const int fnv64Prime = 0x100000001b3;       // 1099511628211
    int hash = fnv64Offset;
    for (int i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * fnv64Prime) & 0xFFFFFFFFFFFFFFFF; // 64-bit wrap
    }
    final hex = hash.toRadixString(16).padLeft(16, '0');
    return hex;
  }

  void _goNext() {
    final next = isDesktop ? const desktop.HomeDesktop() : const tablet.HomeTablet();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => next),
      (route) => false,
    );
  }

  Future<void> _loginToServerDB() async {
    bool _errorOverlayShown = false; // 에러 오버레이가 표시되었는지 여부

    try {
      if (MainDatabaseHelper.isConnected) {
        debugPrint('Already connected to the server database.');
        return;
      }
      
      BlockingOverlay.show(context, message: '서버 데이터베이스에 접속 중 입니다...');
      final currConnectInto = await DbServerConnectInfoHelper.getLastConnectDBInfo();

      if (currConnectInto != null) {
        _lastConnectInfo = currConnectInto;
        await MainDatabaseHelper.connect(currConnectInto);

        LifecycleManager.instance.addObserver(LifecycleCallbacks(
          onDetached: () { MainDatabaseHelper.disconnect(); },
          onExitRequested: () { MainDatabaseHelper.disconnect(); }
        ));

        _startMonitor();

        // 로그아웃 유입이면 자동 표시하지 않음, 사용자 요청 시(앱바 로그인 아이콘) 열도록 함
        if (!widget.fromLogout) {
          _showStartupDialog();
        }
      }
      else {
        debugPrint('No previous server connect info found.');
      }
    }
		catch (e) {
      debugPrint('Exception: $e');

      if (mounted) {
        // 진행중 오버레이가 켜져 있을 수 있으니 먼저 닫고, 에러 오버레이를 띄운다.
        BlockingOverlay.hide();
        BlockingOverlay.show(
          context,
          message: '서버 접속에 실패하였습니다!!\n인터넷 연결상태를 먼저 확인해주시고 02)3274-1776으로 전화주세요!',
          actions: const [BlockingOverlayAction(label: '닫기')],
        );

        _errorOverlayShown = true;
      }
    }
    finally  {
      // 에러 오버레이를 띄운 경우에는 사용자가 버튼을 누를 때까지 유지
      if (!_errorOverlayShown) {
        BlockingOverlay.hide();
      }
    }
  }

  void _startMonitor() {
    // 전역 서비스로 모니터 연결 및 상태 반영
    final info = _lastConnectInfo;

    if (info != null) {
      DbConnectionService.instance.attachAndStart(info: info);

      // 상태 전환에 따라 재연결 다이얼로그 표시/닫기
      _upListener ??= () {
        // 전역 오버레이가 표시/숨김을 담당. 여기서는 추가 동작 없음
      };

      DbConnectionService.instance.status.up.addListener(_upListener!);
    }
  }

  // 재연결 모달은 전역 오버레이(GlobalReconnectOverlay)가 담당

  void _showStartupDialog({bool forceNoticeClosed = false}) async {
    // 저장된 버전과 현재 버전이 같으면 공지 섹션을 숨기고 체크박스를 기본 체크로 둔다.
    final suppressedVer = await UserPrefs.getString('suppressNoticeVersion');
    final suppressedHash = await UserPrefs.getString('suppressNoticeHash');
    final currHash = _fnv1a64Hex(_currentNoticePayload());
    final isSuppressed = (suppressedVer == appVersion) && (suppressedHash == currHash);
    bool noticeClosed = forceNoticeClosed || isSuppressed; // 로그아웃 유입시 공지 섹션 생략
    bool dontShowUntilNextUpdate = isSuppressed; // 로그아웃 유입으로 noticeClosed가 true여도 사용자 설정은 건드리지 않음

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final dialogBody = _DialogBody(
              noticeClosed: noticeClosed,
              onCloseNotice: () => setState(() => noticeClosed = true),
              onLogin: _goNext,
              id: _id,
              company: _company,
              branch: _branch,
              user: _user,
              password: _password,
              dontShow: dontShowUntilNextUpdate,
              onToggleDontShow: (v) async {
                setState(() => dontShowUntilNextUpdate = v);
                if (v) {
                  // 현재 버전에 대해 공지 숨김 유지
                  await UserPrefs.setString(
                      'suppressNoticeVersion', appVersion);
                  await UserPrefs.setString(
                      'suppressNoticeHash', currHash);
                } else {
                  // 체크 해제 시 즉시 표시되도록 제거
                  await UserPrefs.setString('suppressNoticeVersion', null);
                  await UserPrefs.setString('suppressNoticeHash', null);
                }
              },
            );

            return Dialog(
              insetPadding: const EdgeInsets.all(24),
              elevation: 8,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0x22000000)),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: noticeClosed ? 600 : MediaQuery.of(context).size.width * 0.8,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: dialogBody,
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await _loginToServerDB();
      }
    });
  }

  @override
  void dispose() {
    _monitor?.dispose();
    _monitorSub?.cancel();

    if (_upListener != null) {
      DbConnectionService.instance.status.up.removeListener(_upListener!);
      _upListener = null;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  // AppBar 아이콘으로 대체함

    return Scaffold(
      appBar: AppBar(
        title: Text('$appTitle v$appVersion'),
        centerTitle: false,
        actions: [
          const DbConnectionStatusIcon(),
          IconButton(
            icon: const Icon(Icons.login),
            tooltip: '로그인',
            onPressed: _showStartupDialog,
          ),
          // IconButton(
          //   icon: const Icon(Icons.exit_to_app),
          //   tooltip: '종료',
          //   onPressed: _exitApp,
          // ),
        ],
      ),
      body: Container(color: const Color(0xFFF4F4F4)),
    );
  }
}

class _DialogBody extends StatelessWidget {
  final bool noticeClosed;
  final VoidCallback onCloseNotice;
  final VoidCallback onLogin;
  final TextEditingController id, company, branch, user, password;
  final bool dontShow;
  final ValueChanged<bool> onToggleDontShow;

  const _DialogBody({
    required this.noticeClosed,
    required this.onCloseNotice,
    required this.onLogin,
    required this.id,
    required this.company,
    required this.branch,
    required this.user,
    required this.password,
    required this.dontShow,
    required this.onToggleDontShow,
  });

  @override
  Widget build(BuildContext context) {
    final loginPanel = _LoginPanel(
      id: id,
      company: company,
      branch: branch,
      user: user,
      password: password,
      dontShow: dontShow,
      onToggleDontShow: onToggleDontShow,
      onLogin: onLogin,
    );
    if (noticeClosed) {
      return loginPanel;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: loginPanel),
        const SizedBox(width: 12),
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: _LabeledField(
                      label: '업데이트 버전',
                      child: const Text('2.7.5.3'),
                    ),
                  ),
                  const Expanded(flex: 2, child: SizedBox.shrink()),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          border: Border.all(color: const Color(0x11000000)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('라벨매니저 2.7.4'),
                            SizedBox(height: 6),
                            Text('1. 공용라벨관리- 첨자 기능 추가'),
                            Text('2. tab 메뉴 자동 축소 기능 추가'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'assets/images/ad_banner.png',
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            color: const Color(0xFFEFEFEF),
                            alignment: Alignment.center,
                            child: const Text(
                              '광고 배너 이미지(assets/images/ad_banner.png)',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: dontShow,
                    onChanged: (v) => onToggleDontShow(v ?? false),
                  ),
                  const Text('다음 업데이트까지 이 창 보지 않음'),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: onCloseNotice,
                    child: const Text('확인'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginPanel extends StatelessWidget {
  final TextEditingController id, company, branch, user, password;
  final bool dontShow;
  final ValueChanged<bool> onToggleDontShow;
  final VoidCallback onLogin;

  const _LoginPanel({
    required this.id,
    required this.company,
    required this.branch,
    required this.user,
    required this.password,
    required this.dontShow,
    required this.onToggleDontShow,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    InputDecoration _dec(String hint) => InputDecoration(
      isDense: true,
      hintText: hint,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );

    Widget _kLabel(String t) => SizedBox(
      width: 88,
      child: Text(
        t,
        textAlign: TextAlign.right,
        style: const TextStyle(color: Color(0xFF333333)),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x11000000)),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '사용자 인증',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _LabeledField(
                    label: '접속 서버',
                    child: const Text('라벨매니저 서버(서울 - 일반거래처)'),
                  ),
                  const SizedBox(height: 6),
                  _LabeledField(
                    label: '접속 상태',
                    child: ValueListenableBuilder<bool?>(
                      valueListenable: DbConnectionStatus.instance.up,
                      builder: (context, up, _) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: DbConnectionStatus.instance.reconnecting,
                          builder: (context, reconnecting, __) {
                            final String statusText = up == null
                                ? '확인 중'
                                : (up ? '연결 양호' : (reconnecting ? '끊김 - 재연결 중' : '끊김'));
                            return Text(statusText);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _kLabel('아이디'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: id,
                          decoration: _dec('아이디'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _kLabel('업체명'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: company,
                          decoration: _dec('업체명'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _kLabel('지점명'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: branch,
                          decoration: _dec('지점명'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _kLabel('사용자 이름'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: user,
                          decoration: _dec('사용자 이름'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _kLabel('비밀번호'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: password,
                          obscureText: true,
                          decoration: _dec('비밀번호'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(
                    height: 200,
                    child: const Text('테스트용 로그인입니다. 아이디: 8134, 비밀번호: 12345678'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Spacer(),
                      ElevatedButton(
                        onPressed: onLogin,
                        child: const Text('로그인'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('취소'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String? label;
  final Widget child;
  final double? height;
  const _LabeledField({this.label, required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (label != null) ...[
          SizedBox(width: 90, child: Text(label!, textAlign: TextAlign.right)),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFDFDFD),
              border: Border.all(color: Color(0x11000000)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Color(0xFF222222)),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}
