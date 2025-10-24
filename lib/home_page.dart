// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/lifecycle.dart';

import 'package:label_printer/core/app.dart';
import 'package:label_printer/database/db_client.dart';
import 'package:label_printer/models/user.dart';
import 'package:label_printer/models/market.dart';
import 'package:label_printer/models/customer.dart';
import 'package:label_printer/models/cooperator.dart';
import 'database/db_connection_status_icon.dart';
import 'home_page_manager.dart';
import 'page_login/startup_dialog.dart';
import 'page_login/startup_db_helper.dart';

// 사용자 로그인 및 앱 시작: 기본 프린터 설정 + 사용자 정보 입력
class HomePage extends StatefulWidget {
  final bool fromLogout; // 사용자 로그아웃으로 진입했는지 여부
  const HomePage({super.key, this.fromLogout = false});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String cn = '_HomePageState';
  final StartupDbHelper _db = StartupDbHelper();
  bool _loggedIn = false;
  // 컨트롤 영역 상태(샘플 값): 실제 데이터 연동 전까지 플레이스홀더로 사용
  String _selectedBrand = 'Test';
  String _selectedLabelSize = '바코드 test2';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

		LifecycleManager.instance.addObserver(LifecycleCallbacks(
			onResumed: () {
				const String fn = 'onResumed';
				debugPrint('$cn.$fn: $START');

				if (!DbClient.instance.isConnected) {
					_loginToServerDB();
				}

				debugPrint('$cn.$fn: $END');
			},
			onDetached: () { _onLogout(true); },
			onExitRequested: () { _onLogout(true); },
		));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await _loginToServerDB();
    });
  }

  // 로그아웃 유입이면 자동 표시하지 않음, 사용자 요청 시(앱바 로그인 아이콘) 열도록 함
  Future<void> _loginToServerDB() async {
    const String fn = '_loginToServerDB';
    debugPrint('$cn.$fn: $START');

    if (!(await _db.connectToServerDB(context))) {
      debugPrint('$cn.$fn: Failed to connect to server DB');
      return;
    }

    if (!widget.fromLogout) {
      _showStartupDialog();
    }
    
    debugPrint('$cn.$fn: $END');
  }

  // 재연결 모달은 전역 오버레이(GlobalReconnectOverlay)가 담당하므로 여기서는 처리하지 않음
  void _showStartupDialog({bool forceNoticeClosed = false}) async {
    await StartupDialog.show(
      context, onLogin: _onLogin,
      serverName: _db.lastConnectInfo?.serverName,
      forceNoticeClosed: forceNoticeClosed,
    );
  }

  void _onLogin() {
    if (!mounted) return;
    setState(() { _loggedIn = true; });
  }

  Future<void> _onLogout(bool isDisconnect) async {
		const String fn = '_onLogout';
    debugPrint('$cn.$fn: $START');

    User.instance = null;
    Market.instance = null;
    Customer.instance = null;
    Cooperator.instance = null;

		if (isDisconnect == true) {
			_db.dispose();
    	DbClient.instance.disconnect('$cn.$fn');
		}

    if (mounted) {
    	setState(() { _loggedIn = false; });
		}

		debugPrint('$cn.$fn: $END');
  }

  @override
  void dispose() {
		const String fn = 'dispose';
		debugPrint('$cn.$fn: $START');
    _searchCtrl.dispose();
    super.dispose();
		debugPrint('$cn.$fn: $END');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        // 데스크톱의 창 닫기와 동일한 로직으로 종료 처리
        LifecycleManager.instance.notifyExitRequested();
        // 짧은 딜레이로 정리(예: DB연결 해제) 누락 완화
        await Future.delayed(const Duration(milliseconds: 120));
        await SystemNavigator.pop(); // 앱 완전 종료
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('$APP_TITLE v$appVersion'),
          centerTitle: false,
          actions: [
            const DbConnectionStatusIcon(),
            if (_loggedIn)
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: '로그아웃',
                onPressed: () => _onLogout(false),
              )
            else
              IconButton(
                icon: const Icon(Icons.login),
                tooltip: '로그인',
                onPressed: () => DbClient.instance.isConnected
                    ? _showStartupDialog()
                    : _loginToServerDB(),
              ),
            // IconButton(
            //   icon: const Icon(Icons.exit_to_app),
            //   tooltip: '종료',
            //   onPressed: _exitApp,
            // ),
            const SizedBox(width: 10),
          ],
        ),
        body: _loggedIn
            ? HomePageManager(
                selectedBrand: _selectedBrand,
                onBrandChanged: (v) => setState(() => _selectedBrand = v ?? _selectedBrand),
                selectedLabelSize: _selectedLabelSize,
                onLabelSizeChanged: (v) => setState(() => _selectedLabelSize = v ?? _selectedLabelSize),
            )
            : _buildLoggedOutBackground(),
      ),
    );
  }

  Widget _buildLoggedOutBackground() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        image: isShowLogo ? const DecorationImage(
          image: AssetImage('assets/images/MainLogo.webp'),
          fit: BoxFit.none,
          colorFilter: ColorFilter.mode(Color(0xFFF4F4F4), BlendMode.multiply),
        ) : null,
      ),
    );
  }
}