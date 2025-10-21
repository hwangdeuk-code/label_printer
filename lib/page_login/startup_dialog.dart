// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:label_printer/core/bootstrap.dart';
import 'package:label_printer/models/login_log.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:label_printer/core/app.dart';
import 'package:label_printer/database/db_connection_status.dart';
import 'package:label_printer/database/db_result_utils.dart';
import 'package:label_printer/models/dao.dart';
import 'package:label_printer/models/notice.dart';
import 'package:label_printer/models/customer.dart';
import 'package:label_printer/models/cooperator.dart';
import 'package:label_printer/models/market.dart';
import 'package:label_printer/models/user.dart';

/// 독립적으로 호출 가능한 시작 다이얼로그
class StartupDialog extends StatefulWidget {
  final VoidCallback onLogin;
  final String? serverName;
  final bool forceNoticeClosed;

  const StartupDialog({super.key, required this.onLogin, this.serverName, this.forceNoticeClosed = false});

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onLogin,
    String? serverName,
    bool forceNoticeClosed = false,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StartupDialog(onLogin: onLogin, serverName: serverName, forceNoticeClosed: forceNoticeClosed),
    );
  }

  @override
  State<StartupDialog> createState() => _StartupDialogState();
}

class _StartupDialogState extends State<StartupDialog> {
  // 공지 해시 계산을 위한 페이로드 생성(버전+내용)
  String _currentNoticePayload({String? content, String? version}) {
    final v = version ?? '';
    final c = content ?? '';
    return '$v\n$c';
  }

  // 간단한 FNV-1a 64-bit 해시 구현
  String _fnv1a64Hex(String input) {
    const int fnv64Offset = 0xcbf29ce484222325; // 14695981039346656037
    const int fnv64Prime = 0x100000001b3; // 1099511628211
    int hash = fnv64Offset;

    for (int i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * fnv64Prime) & 0xFFFFFFFFFFFFFFFF; // 64-bit wrap
    }

    final hex = hash.toRadixString(16).padLeft(16, '0');
    return hex;
  }

  String _effectiveVersion = appVersion;
  String _effectiveContent = expandTabs('');
  bool _noticeClosed = false;
  bool _dontShowUntilNextUpdate = false;

  @override
  void initState() {
    super.initState();
    _initNoticeState();
  }

  Future<void> _initNoticeState() async {
    // 초기 notice 표시 여부 계산 (저장된 해시/버전과 비교)
    try {
      final prefs = await SharedPreferences.getInstance();
      final suppressedVer = prefs.getString('suppressNoticeVersion');
      final suppressedHash = prefs.getString('suppressNoticeHash');
      final initialHash = _fnv1a64Hex(_currentNoticePayload(content: _effectiveContent, version: _effectiveVersion));
      final isSuppressed = (suppressedVer == appVersion) && (suppressedHash == initialHash);
      if (!mounted) return;
      setState(() {
        _noticeClosed = widget.forceNoticeClosed || isSuppressed;
        _dontShowUntilNextUpdate = isSuppressed;
      });
    } catch (_) {
      // 무시
    }
  }

  @override
  Widget build(BuildContext context) {
    final fHeight = isDesktop ? 0.8 : 0.9;
    final dialogBody = _DialogBody(
      noticeClosed: _noticeClosed,
      onCloseNotice: () => setState(() => _noticeClosed = true),
      onLogin: widget.onLogin,
      dontShow: _dontShowUntilNextUpdate,
      onToggleDontShow: (v) async {
        setState(() => _dontShowUntilNextUpdate = v);
        if (v) {
          final prefs = await SharedPreferences.getInstance();
          final currHashNow = _fnv1a64Hex(_currentNoticePayload(content: _effectiveContent, version: _effectiveVersion));
          await prefs.setString('suppressNoticeVersion', appVersion);
          await prefs.setString('suppressNoticeHash', currHashNow);
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('suppressNoticeVersion');
          await prefs.remove('suppressNoticeHash');
        }
      },
      noticeVersion: _effectiveVersion,
      noticeContent: _effectiveContent,
      onNoticeUpdate: (newContent) {
        if (!mounted) return;
        setState(() {
          _effectiveContent = expandTabs(newContent);
        });
      },
      serverName: widget.serverName,
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
        width: _noticeClosed ? 600 : MediaQuery.of(context).size.width * 0.8,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * fHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: dialogBody,
        ),
      ),
    );
  }
}

class _DialogBody extends StatefulWidget {
  final bool noticeClosed;
  final VoidCallback onCloseNotice;
  final VoidCallback onLogin;
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
    required this.dontShow,
    required this.onToggleDontShow,
    required this.noticeVersion,
    required this.noticeContent,
    required this.onNoticeUpdate,
    this.serverName,
  });

  @override
  State<_DialogBody> createState() => _DialogBodyState();
}

class _DialogBodyState extends State<_DialogBody> {
  late final TextEditingController userId;
  late final TextEditingController customerName;
  late final TextEditingController marketName;
  late final TextEditingController userName;
  late final TextEditingController password;

  @override
  void initState() {
    super.initState();
    userId = TextEditingController(text: 'tester01');
    customerName = TextEditingController();
    marketName = TextEditingController();
    userName = TextEditingController();
    password = TextEditingController();
  }

  @override
  void dispose() {
    userId.dispose();
    customerName.dispose();
    marketName.dispose();
    userName.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loginPanel = _LoginPanel(
      userId: userId,
      customerName: customerName,
      marketName: marketName,
      userName: userName,
      password: password,
      dontShow: widget.dontShow,
      onToggleDontShow: widget.onToggleDontShow,
      onLogin: widget.onLogin,
      onUserIdCommit: widget.onNoticeUpdate,
      serverName: widget.serverName,
    );

    if (widget.noticeClosed) {
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
                            child: Text(widget.noticeVersion),
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
                                        child: Text(widget.noticeContent),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(child: _AdBanner()),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Checkbox(
                              value: widget.dontShow,
                              onChanged: (v) => widget.onToggleDontShow(v ?? false),
                            ),
                            const Text('다음 업데이트까지 이 창 보지 않음'),
                            const Spacer(),
                            ElevatedButton(onPressed: widget.onCloseNotice, child: const Text('확인')),
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
  bool _saveId = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    final saveId = prefs.getBool('save_id') ?? false;

    if (mounted) {
      setState(() {
        widget.userId.text = userId;
        _saveId = saveId;
      });
      // 저장된 ID가 있으면 바로 공지사항을 가져옵니다.
      if (userId.isNotEmpty) _onUserIdFieldCommit(userId);
    }
  }

  Future<void> _onUserIdFieldCommit(String userIdText) async {
    const String fn = '_onUserIdFieldCommit';

    if (_LoginPanel._noticeFetchInFlight) return;
    _LoginPanel._noticeFetchInFlight = true;

    try {
      final inputId = userIdText.trim();

      if (inputId.isEmpty) {
        if (mounted) FocusScope.of(context).requestFocus(_userIdFocus);
        return;
      }

      final noticeMsg = await NoticeDAO.getByUserId(inputId);
      if (noticeMsg.isNotEmpty) {
        widget.onUserIdCommit?.call(noticeMsg);
      }

      User.setInstance(await UserDAO.getByUserId(inputId));

      if (!mounted) return;

      if (User.instance != null) {
        widget.customerName.text = User.instance!.customerName;
        widget.marketName.text = User.instance!.marketName;
        widget.userName.text = User.instance!.name;

        if (mounted) {
          setState(() => _infoText = '');
          FocusScope.of(context).requestFocus(_passwordFocus);
        }
      } else {
        widget.customerName.text = '';
        widget.marketName.text = '';
        widget.userName.text = '';

        if (mounted) {
          setState(() => _infoText = '아이디가 존재하지 않습니다!');
          FocusScope.of(context).requestFocus(_userIdFocus);
        }
      }
    } catch (e) {
      final errmsg = e.toString();
      _infoText = stripLeadingBracketTags(errmsg);
      debugPrint('${_LoginPanel.cn}.$fn, ${DAO.exception}: $errmsg');

      if (mounted) {
        setState(() => _infoText = stripLeadingBracketTags(errmsg));
        FocusScope.of(context).requestFocus(_userIdFocus);
      }
    } finally {
      _LoginPanel._noticeFetchInFlight = false;
    }
  }

  Future<void> _onPasswordFieldCommit(String passwordText) async {
    if (passwordText.isNotEmpty) {
      if (mounted) FocusScope.of(context).requestFocus(_loginButtonFocus);
    } else {
      if (mounted) FocusScope.of(context).requestFocus(_passwordFocus);
    }
  }

  String _getDirectPassword([DateTime? now]) {
    final t = now ?? DateTime.now();
    final int nMonth = t.month;
    final int nDay = t.day;
    final int nPwd = (nMonth * 3) + nDay;

    if (nDay <= 9) {
      final dayStr = '0$nDay';
      final pwdStr = nPwd <= 9 ? '0$nPwd' : '$nPwd';
      return '$dayStr$pwdStr';
    } else {
      return '$nDay$nPwd';
    }
  }

  String _getSystemPassword([DateTime? now]) {
    final t = now ?? DateTime.now();
    final int value = t.month * 3 + t.day;
    return value.toString().padLeft(4, '0');
  }

  Future<void> _onLoginButtonPressed(String inputPwd) async {
    const String fn = '_onLoginButtonPressed';

    try {
      if (User.instance == null) {
        if (mounted) {
          setState(() => _infoText = '아이디를 먼저 조회해주세요.');
          FocusScope.of(context).requestFocus(_userIdFocus);
        }
        return;
      }

      if (equalsIgnoreCase(User.instance!.userId, User.SYSTEM)) {
        if (inputPwd != _getDirectPassword() && inputPwd != _getSystemPassword()) {
          if (mounted) {
            setState(() => _infoText = '시스템 계정 패스워드가 올바르지 않습니다!');
            FocusScope.of(context).requestFocus(_passwordFocus);
          }
          return;
        }
      }
      else if (User.instance!.pwd != inputPwd) {
        if (mounted) {
          setState(() => _infoText = '패스워드가 올바르지 않습니다!');
          FocusScope.of(context).requestFocus(_passwordFocus);
        }
        return;
      }

      // Get Market,Customer,Cooperator info after login...
      Market.setInstance(await MarketDAO.getByMarketId(User.instance!.marketId));
      Customer.setInstance(await CustomerDAO.getByCustomerId(Market.instance!.customerId));
      Cooperator.setInstance(await CooperatorDAO.getByCooperatorId(Customer.instance!.cooperatorId));

      // 로그인 정보를 저장한다.
      //if (!CLoginUser::IsLoginMasterKey()) {
        LoginLogDAO.insertLoginLog(
          userId: User.instance!.userId, userGrade: User.instance!.grade,
          customerId: Customer.instance!.customerId, customerName: Customer.instance!.name,
          loginCondition: LoginCondition.LOGIN,
        );
      //}

      setWindowTitle('$WINDOW_TITLE_PREFIX - ${widget.serverName}');
      if (mounted) Navigator.of(context).pop(null);
      widget.onLogin();
    }
    catch (e) {
      final errmsg = e.toString();
      _infoText = stripLeadingBracketTags(errmsg);
      debugPrint('${_LoginPanel.cn}.$fn, ${DAO.exception}: $errmsg');

      if (mounted) {
        setState(() => _infoText = stripLeadingBracketTags(errmsg));
      }
    }
  }

  Future<void> _onCancelButtonPressed() async {
    widget.userId.clear();
    widget.customerName.clear();
    widget.marketName.clear();
    widget.userName.clear();
    widget.password.clear();
    _infoText = '';
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // 로그인 버튼 활성화 조건
    final bool canLogin =
        widget.userId.text.trim().isNotEmpty && User.instance != null && widget.password.text.isNotEmpty;

    InputDecoration _dec(String hint) => InputDecoration(
          isDense: true,
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        );

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
    final double _inlineLabelWidth = (90.0 - _oneChar).clamp(50.0, 90.0);
    final double _fieldLabelWidth = (90.0 - _oneChar).clamp(50.0, 90.0);

    Widget _kLabel(String text) => SizedBox(
          width: _inlineLabelWidth,
          child: Text(
            text,
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
                        ) ??
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _LabeledField(
                    label: '접속 서버',
                    labelWidth: _fieldLabelWidth,
                    child: Text(
                      (widget.serverName == null || widget.serverName!.isEmpty) ? '라벨매니저' : widget.serverName!,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
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
                            return Text(
                              statusText,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
                            );
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
                          onFocusChange: (hasFocus) {
                            if (!hasFocus) _onUserIdFieldCommit(widget.userId.text);
                          },
                          child: TextField(
                            controller: widget.userId,
                            focusNode: _userIdFocus,
                            autofocus: true,
                            decoration: _dec('아이디'),
                            textInputAction: TextInputAction.done,
                            onChanged: (value) => setState(() {}),
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
                          onChanged: (value) => setState(() => _infoText = ''),
                          onSubmitted: (value) => _onPasswordFieldCommit(value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(height: 170, child: Text(_infoText)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _saveId,
                        onChanged: (v) => setState(() => _saveId = v ?? false),
                      ),
                      const Text('아이디 저장'),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Spacer(),
                      ElevatedButton(
                        onPressed: canLogin ? () => _onLoginButtonPressed(widget.password.text) : null,
                        focusNode: _loginButtonFocus,
                        child: const Text('로그인'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: () => _onCancelButtonPressed(), child: const Text('취소')),
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
    _savePreferences();
    super.dispose();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('save_id', _saveId);
    await prefs.setString('user_id', _saveId ? widget.userId.text : '');
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
    if (isShowLogo) _loadAd();
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
    } catch (_) {
      try {
        final fb = await rootBundle.load('assets/images/LabelManager_ITSad.bmp');
        if (!mounted) return;
        setState(() => _bytes = fb.buffer.asUint8List());
      } catch (_) {
        // 폴백 자산 없음: 무시
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (_bytes != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          _bytes!,
          fit: BoxFit.fill,
          alignment: Alignment.center,
        ),
      );
    } else {
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
              // 무시
            }
          },
      borderRadius: BorderRadius.circular(6),
      child: content,
    );
  }
}

// no-op
