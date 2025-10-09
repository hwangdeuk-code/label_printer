
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:label_printer/core/app.dart';
import '../ui_desktop/screens/home_desktop.dart' as desktop;
import '../ui_tablet/screens/home_tablet.dart' as tablet;

// 공통 시작 페이지: 비어있는 홈페이지 + 시작 다이얼로그(로그인/공지/광고)
class StartupHomePage extends StatefulWidget {
  const StartupHomePage({super.key});
  
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

  void _goNext() {
    final next = isDesktop ? const desktop.HomeDesktop() : const tablet.HomeTablet();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => next),
      (route) => false,
    );
  }

  void _showStartupDialog() {
    bool noticeClosed = false;
    bool dontShowUntilNextUpdate = false;

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
              onToggleDontShow: (v) => setState(() => dontShowUntilNextUpdate = v),
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
                child: Padding(padding: const EdgeInsets.all(12), child: dialogBody),
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
        _showStartupDialog();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$appTitle v$appVersion'), centerTitle: false),
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
      id: id, company: company, branch: branch, user: user, password: password,
      dontShow: dontShow, onToggleDontShow: onToggleDontShow, onLogin: onLogin,
    );
    if (noticeClosed) {
      return loginPanel;
    }
    return IntrinsicHeight(
      child: Row(
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
                    child: _LabeledField(label: '업데이트 버전', child: Text('2.7.5.3')),
                  ),
                  const Expanded(flex: 2, child: SizedBox.shrink()),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 공지 영역
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
                            Text('1. 공용라벨관리 - 첨자 기능 추가'),
                            Text('2. tab 메뉴 이동 단축키 추가'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 광고 영역
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'assets/images/ad_banner.png',
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            color: const Color(0xFFEFEFEF),
                            alignment: Alignment.center,
                            child: const Text('광고 이미지(assets/images/ad_banner.png)'),
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
                  Checkbox(value: dontShow, onChanged: (v) => onToggleDontShow(v ?? false)),
                  const Text('다음 업데이트까지 이창 열지 않음'),
                  const Spacer(),
                  // 확인 버튼
                  ElevatedButton(onPressed: onCloseNotice, child: const Text('확인')),
                ],
              )
            ],
          ),
          ),
        ],
      ),
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

    Widget _kLabel(String t) => SizedBox(width: 88, child: Text(t, textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFF333333))));

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x11000000)),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('사용자 인증', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _LabeledField(label: '접속 서버', child: Text('라벨매니저 서버(실서버) - 일반거래처')),
          const SizedBox(height: 6),
          _LabeledField(label: '접속 상태', child: Text('서버 연결 성공')),
          const SizedBox(height: 12),
          Row(children: [ _kLabel('아이디'), const SizedBox(width: 8), Expanded(child: TextField(controller: id, decoration: _dec('아이디')))]),
          const SizedBox(height: 8),
          Row(children: [ _kLabel('업체명'), const SizedBox(width: 8), Expanded(child: TextField(controller: company, decoration: _dec('업체명')))]),
          const SizedBox(height: 8),
          Row(children: [ _kLabel('지점명'), const SizedBox(width: 8), Expanded(child: TextField(controller: branch, decoration: _dec('지점명')))]),
          const SizedBox(height: 8),
          Row(children: [ _kLabel('사용자 이름'), const SizedBox(width: 8), Expanded(child: TextField(controller: user, decoration: _dec('사용자 이름')))]),
          const SizedBox(height: 8),
          Row(children: [ _kLabel('비밀번호'), const SizedBox(width: 8), Expanded(child: TextField(controller: password, obscureText: true, decoration: _dec('비밀번호')))]),
          const SizedBox(height: 12),
          _LabeledField(height: 200, child: Text('※ 테스트용 로그인입니다. 아이디: 8134, 비밀번호: 12345678')),
          const SizedBox(height: 12),
          Row(
            children: [
              const Spacer(),
              ElevatedButton(onPressed: onLogin, child: const Text('로그인')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () => SystemNavigator.pop(), child: const Text('취소')),
            ],
          ),
        ],
      ),
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
          SizedBox(width: 88, child: Text(label!, textAlign: TextAlign.right)),
          const SizedBox(width: 8),
        ],
        Expanded(child: Container(
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
        )),
      ],
    );
  }
}
