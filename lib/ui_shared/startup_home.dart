// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:label_printer/core/app.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:label_printer/models/user.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:label_printer/core/lifecycle.dart';
import 'package:label_printer/database/db_client.dart';
import 'package:label_printer/database/db_connection_service.dart';
import 'package:label_printer/database/db_connection_status.dart';
import 'package:label_printer/database/db_server_connect_info.dart';
import 'package:label_printer/models/dao.dart';
import 'package:label_printer/models/notice.dart';
import 'package:label_printer/ui_shared/components/connection_status_icon.dart';
import 'package:label_printer/utils/db_result_utils.dart';
import 'package:label_printer/utils/on_messages.dart';
import 'package:label_printer/utils/user_prefs.dart';
import 'package:label_printer/utils/net_diag.dart';
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
  final _userId = TextEditingController(text: 'tester01');
  final _customerName = TextEditingController();
  final _marketName = TextEditingController();
  final _userName = TextEditingController();
  final _password = TextEditingController();

  ServerConnectInfo? _lastConnectInfo;

  // ValueNotifier 기반 상태 감지를 위한 리스너 보관
  VoidCallback? _upListener;

  // 공지 해시 계산을 위한 페이로드 생성(버전+내용)
  String _currentNoticePayload({String? content, String? version}) {
    final v = version ?? '';
    final c = content ?? '';
    return '$v\n$c';
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
  final dbConnection = DbClient.instance;

      if (dbConnection.isConnected) {
        debugPrint('Already connected to the server database.');
        return;
      }
      
      BlockingOverlay.show(context, message: '서버 데이터베이스에 접속 중 입니다...');
      _lastConnectInfo = await DbServerConnectInfoHelper.getLastConnectDBInfo();

      if (_lastConnectInfo != null) {
        // 안드로이드에서 네트워크/포트 도달성 문제를 먼저 진단
        final host = _lastConnectInfo!.serverIp;
        final port = _lastConnectInfo!.serverPort;
        final reachable = await NetDiag.probeTcp(host, port, timeout: const Duration(seconds: 3));
        if (!reachable) {
          debugPrint('TCP not reachable to $host:$port (Android에서 방화벽/라우팅/SSL 문제 가능)');
        }
        debugPrint('Connecting to MSSQL {host:$host, port:$port, db:${_lastConnectInfo!.databaseName}, user:${_lastConnectInfo!.userId}}');
        final success = await dbConnection.connect(
          ip: _lastConnectInfo!.serverIp,
          port: _lastConnectInfo!.serverPort.toString(),
          databaseName: _lastConnectInfo!.databaseName,
          username: _lastConnectInfo!.userId,
          password: _lastConnectInfo!.password,
          timeoutInSeconds: 30,
        );

        if (!success) {
          throw Exception('failed to connect');
        }

        LifecycleManager.instance.addObserver(LifecycleCallbacks(
          onDetached: () { DbClient.instance.disconnect(); },
          onExitRequested: () { DbClient.instance.disconnect(); }
        ));

        _startDatabaseMonitor();

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

  void _startDatabaseMonitor() {
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

    final fHeight = isDesktop ? 0.8 : 0.9;
		final effectiveVersion = appVersion;
		String effectiveContent = expandTabs('');
    final initialHash = _fnv1a64Hex(_currentNoticePayload(content: effectiveContent, version: effectiveVersion));
    final isSuppressed = (suppressedVer == appVersion) && (suppressedHash == initialHash);
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
              userId: _userId,
              customerName: _customerName,
              marketName: _marketName,
              userName: _userName,
              password: _password,
              dontShow: dontShowUntilNextUpdate,
              noticeVersion: effectiveVersion,
              noticeContent: effectiveContent,
              serverName: _lastConnectInfo?.serverName,
              onNoticeUpdate: (newContent) {
                setState(() {
                  effectiveContent = expandTabs(newContent);
                });
              },
              onToggleDontShow: (v) async {
                setState(() => dontShowUntilNextUpdate = v);
                if (v) {
                  // 현재 버전에 대해 공지 숨김 유지
                  final currHashNow = _fnv1a64Hex(
                    _currentNoticePayload(content: effectiveContent, version: effectiveVersion),
                  );
                  await UserPrefs.setString('suppressNoticeVersion', appVersion);
                  await UserPrefs.setString('suppressNoticeHash', currHashNow);
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
                  maxHeight: MediaQuery.of(context).size.height * fHeight,
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
  final TextEditingController userId, customerName, marketName, userName, password;
  final bool dontShow;
  final ValueChanged<bool> onToggleDontShow;
  final String noticeVersion;
  final String noticeContent;
  final ValueChanged<String> onNoticeUpdate;
  final String? serverName;

  const _DialogBody({
    required this.noticeClosed,
    required this.onCloseNotice,
    required this.onLogin,
    required this.userId,
    required this.customerName,
    required this.marketName,
    required this.userName,
    required this.password,
    required this.dontShow,
    required this.noticeVersion,
    required this.noticeContent,
    required this.onNoticeUpdate,
    required this.onToggleDontShow,
    this.serverName,
  });

  @override
  Widget build(BuildContext context) {
    final loginPanel = _LoginPanel(
      userId: userId,
      customerName: customerName,
      marketName: marketName,
      userName: userName,
      password: password,
      dontShow: dontShow,
      onToggleDontShow: onToggleDontShow,
      onLogin: onLogin,
      onUserIdCommit: onNoticeUpdate,
      serverName: serverName,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
              return CustomScrollView(
                physics: const ClampingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: _LabeledField(
                            label: '업데이트 버전',
                            child: Text(noticeVersion),
                          ),
                        ),
                        const Expanded(flex: 2, child: SizedBox.shrink()),
                      ],
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverFillRemaining(
                    hasScrollBody: keyboardOpen,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _InlayPanel(
                                  margin: const EdgeInsets.only(top: 2),
                                  child: ScrollConfiguration(
                                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
                                    child: SingleChildScrollView(
                                      physics: const ClampingScrollPhysics(),
                                      child: DefaultTextStyle.merge(
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 13,
                                          color: Color(0xFF1F1F1F),
                                        ),
                                        child: Text(noticeContent),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: _AdBanner(),
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
            },
          ),
        ),
      ],
    );
  }
}

class _LoginPanel extends StatefulWidget {
  static const String cn = '_LoginPanel';
  final TextEditingController userId, customerName, marketName, userName, password;
  final bool dontShow;
  final ValueChanged<bool> onToggleDontShow;
  final VoidCallback onLogin;
  final ValueChanged<String>? onUserIdCommit;
  final String? serverName;

  // 중복 실행 방지 플래그
  static bool _noticeFetchInFlight = false;

  const _LoginPanel({
    required this.userId,
    required this.customerName,
    required this.marketName,
    required this.userName,
    required this.password,
    required this.dontShow,
    required this.onToggleDontShow,
    required this.onLogin,
    this.onUserIdCommit,
    this.serverName,
  });

  @override
  State<_LoginPanel> createState() => _LoginPanelState();
}

class _LoginPanelState extends State<_LoginPanel> {
  String _infoText = '';
  final FocusNode _userIdFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
	final FocusNode _loginButtonFocus = FocusNode();

  // 아이디 필드에서 포커스를 잃거나 엔터(제출) 시 호출되는 함수
  Future<void> _onUserIdFieldCommit(String userIdText) async {
    const String fn = '_onUserIdFieldCommit';

    // 중복 실행 방지
    if (_LoginPanel._noticeFetchInFlight) return;
    _LoginPanel._noticeFetchInFlight = true;

    try {
      final inputId = userIdText.trim();
      if (inputId.isEmpty) return;

      // 결과를 상위 다이얼로그로 전달하여 공지 내용을 갱신
      final noticeMsg = await NoticeDAO.getByUserId(inputId);
      if (noticeMsg.isNotEmpty) { widget.onUserIdCommit?.call(noticeMsg); }

      // 사용자 정보 조회 후 로그인 섹션 필드에 반영
      gUserInfo = await UserDAO.getByUserId(inputId);

      if (gUserInfo != null) {
        // 업체명/지점명/사용자 이름 값을 컨트롤러에 채움
        widget.customerName.text = gUserInfo!.customerName;
        widget.marketName.text = gUserInfo!.marketName;
        widget.userName.text = gUserInfo!.name;
        setState(() { _infoText = ''; });
        if (mounted) FocusScope.of(context).requestFocus(_passwordFocus);
      } else {
        // 조회 실패/없음: 값을 비워둠 + 안내 문구 변경
        widget.customerName.text = '';
        widget.marketName.text = '';
        widget.userName.text = '';
        setState(() { _infoText = '아이디가 존재하지 않습니다!'; });
        if (mounted) FocusScope.of(context).requestFocus(_userIdFocus);
      }
    }
    catch (e) {
			final errmsg = e.toString();
      debugPrint('${_LoginPanel.cn}.$fn, ${DAO.exception}: $errmsg');
      setState(() { _infoText = stripLeadingBracketTags(errmsg); });
			if (mounted) FocusScope.of(context).requestFocus(_userIdFocus);
    }
    finally {
      // 중복 실행 방지 플래그 해제
      _LoginPanel._noticeFetchInFlight = false;
    }
  }

  // 패스워드 필드에서 엔터(제출) 시 호출되는 함수
  Future<void> _onPasswordFieldCommit(String passwordText) async {
		if (passwordText.isNotEmpty) {
			if (mounted) FocusScope.of(context).requestFocus(_loginButtonFocus);
		}
	}

  @override
  Widget build(BuildContext context) {
    InputDecoration _dec(String hint) => InputDecoration(
      isDense: true,
      hintText: hint,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );

    // 한 글자 너비를 측정해서 라벨 영역을 그만큼 줄이고 값 영역을 늘립니다.
    double _measureCharWidth(TextStyle style, {String sample = '가'}) {
      final painter = TextPainter(
        text: TextSpan(text: sample, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      return painter.size.width;
    }

    final TextStyle _inlineLabelStyle = const TextStyle(color: Color(0xFF333333));
    final double _oneChar = _measureCharWidth(_inlineLabelStyle);
    final double _inlineLabelWidth = (88.0 - _oneChar).clamp(50.0, 88.0);
    final double _fieldLabelWidth = (90.0 - _oneChar).clamp(50.0, 90.0);

    Widget _kLabel(String t) => SizedBox(
      width: _inlineLabelWidth,
      child: Text(
        t,
        textAlign: TextAlign.right,
        style: _inlineLabelStyle,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return _InlayPanel(
          margin: const EdgeInsets.only(top: 2),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '사용자 인증',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF202020),
                    ) ?? const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _LabeledField(
                    label: '접속 서버',
                    labelWidth: _fieldLabelWidth,
                    child: Text(
                      widget.serverName == null || widget.serverName!.isEmpty ? '라벨매니저' : widget.serverName!,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))
                    ),
                  ),
                  const SizedBox(height: 6),
                  _LabeledField(
                    label: '접속 상태',
                    labelWidth: _fieldLabelWidth,
                    child: ValueListenableBuilder<bool?>(
                      valueListenable: DbConnectionStatus.instance.up,
                      builder: (context, up, _) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: DbConnectionStatus.instance.reconnecting,
                          builder: (context, reconnecting, __) {
                            final String statusText = up == null
                              ? '확인 중'
                              : (up ? '연결 양호' : (reconnecting ? '끊김 - 재연결 중' : '끊김'));
                            return Text(statusText, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)));
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
                        child: Focus(
                          onFocusChange: (hasFocus) { if (!hasFocus) _onUserIdFieldCommit(widget.userId.text); },
                          child: TextField(
                            controller: widget.userId,
                            focusNode: _userIdFocus,
                            autofocus: true,
                            decoration: _dec('아이디'),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (value) => _onUserIdFieldCommit(value),
                          ),
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
                        child: ExcludeFocus(
                          excluding: true,
                          child: TextField(
                            controller: widget.customerName,
                            readOnly: true,
                            decoration: _dec('업체명'),
                          ),
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
                        child: ExcludeFocus(
                          excluding: true,
                          child: TextField(
                            controller: widget.marketName,
                            readOnly: true,
                            decoration: _dec('지점명'),
                          ),
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
                        child: ExcludeFocus(
                          excluding: true,
                          child: TextField(
                            controller: widget.userName,
                            readOnly: true,
                            decoration: _dec('사용자 이름'),
                          ),
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
													controller: widget.password,
													focusNode: _passwordFocus,
													obscureText: true,
													decoration: _dec('비밀번호'),
													onSubmitted: (value) => _onPasswordFieldCommit(value),
												),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(
                    height: 170,
                    child: Text(_infoText),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Spacer(),
                      ElevatedButton(
												onPressed: widget.onLogin,
												focusNode: _loginButtonFocus,
												child: const Text('로그인')
											),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
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

  @override
  void dispose() {
    _userIdFocus.dispose();
		_passwordFocus.dispose();
		_loginButtonFocus.dispose();
    super.dispose();
  }
}

class _LabeledField extends StatelessWidget {
  final String? label;
  final Widget child;
  final double? height;
  final double? labelWidth;
  const _LabeledField({this.label, required this.child, this.height, this.labelWidth});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (label != null) ...[
          SizedBox(
            width: labelWidth ?? 90,
            child: Text(
              label!,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
								color: const Color(0xFF2A2A2A),
								fontWeight: FontWeight.w600,
							),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: () {
              final isAndroid = Theme.of(context).platform == TargetPlatform.android;
              return isAndroid
								? BoxDecoration(
										color: const Color(0xFFFDFDFD),
										border: Border.all(color: const Color(0x11000000)),
										borderRadius: BorderRadius.circular(4),
									)
								: BoxDecoration(
										color: const Color(0xFFFFFFFF),
										border: Border.all(color: const Color(0x22000000)),
										borderRadius: BorderRadius.circular(6),
										boxShadow: const [
											BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
										],
									);
            }(),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Color(0xFF1F1F1F)),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

// 살짝 들어간(UI inlay) 컨테이너: 대비/그림자/패딩 보강
class _InlayPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  const _InlayPanel({required this.child, this.margin = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final BoxDecoration deco = isAndroid
        ? BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0x11000000)),
          )
        : BoxDecoration(
            color: const Color(0xFFFAFAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x22000000)),
            boxShadow: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3)),
              BoxShadow(color: Color(0x08000000), blurRadius: 3, offset: Offset(0, 0)),
            ],
          );
    return Container(
      margin: margin,
      decoration: deco,
      padding: EdgeInsets.all(isAndroid ? 12 : 14),
      child: child,
    );
  }
}

// 서버에서 광고 이미지를 내려받아 표시하는 배너 위젯
class _AdBanner extends StatefulWidget {
  const _AdBanner();

  @override
  State<_AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<_AdBanner> {
  Uint8List? _bytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    setState(() => _loading = true);
    const url = 'https://itsng.co.kr/LabelManager/LabelManager_ITSad.bmp';

    try {
      final bust = DateTime.now().millisecondsSinceEpoch.toString();
      final uri = Uri.parse(url).replace(queryParameters: {'_ts': bust});
      final resp = await http
          .get(uri, headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'})
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        if (!mounted) return;
        setState(() => _bytes = resp.bodyBytes);
      } else {
        throw Exception('HTTP ${resp.statusCode}');
      }
    }
		catch (_) {
      // 실패 시 앱 내 기본 이미지 사용(있을 경우)
      try {
        final fb = await rootBundle.load('assets/images/LabelManager_ITSad.bmp');
        if (!mounted) return;
        setState(() => _bytes = fb.buffer.asUint8List());
      } catch (_) {
        // 폴백 자산이 없으면 빈 상태 유지
      }
    }
		finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (_bytes != null) {
      // 단일 이미지로만 표시 (중첩/이중 표시 제거)
      content = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          _bytes!,
          fit: BoxFit.fill, // 한 장의 이미지로 영역을 꽉 채움(왜곡 가능, 크롭/여백 없음)
          alignment: Alignment.center,
        ),
      );
    } else {
      // 다운로드 중 혹은 실패 시 힌트 표시
      content = Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0x11000000)),
        ),
        alignment: Alignment.center,
        child: Text(
          _loading ? '다운로드 중...' : '광고 배너 이미지',
          style: const TextStyle(color: Color(0xFF666666)),
        ),
      );
    }

    return InkWell(
      onTap: _loading
          ? null
          : () async {
              final url = Uri.parse('https://itsngshop.com/index.html');
              if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                // 무시: 브라우저 실행 실패 시 별도 처리 없음
              }
            },
      borderRadius: BorderRadius.circular(6),
      child: content,
    );
  }
}
