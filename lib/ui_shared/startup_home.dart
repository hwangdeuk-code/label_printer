// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:label_printer/core/app.dart';
import 'package:label_printer/database/db_client.dart';
import 'package:label_printer/ui_shared/components/connection_status_icon.dart';
import '../ui_desktop/screens/home_desktop.dart' as desktop;
import '../ui_tablet/screens/home_tablet.dart' as tablet;
import 'startup_dialog.dart';
import 'startup_db_helper.dart';

// 사용자 로그인 및 앱 시작: 기본 프린터 설정 + 사용자 정보 입력
class StartupHomePage extends StatefulWidget {
  final bool fromLogout; // 사용자 로그아웃으로 진입했는지 여부
  const StartupHomePage({super.key, this.fromLogout = false});

  @override
  State<StartupHomePage> createState() => _StartupHomePageState();
}

class _StartupHomePageState extends State<StartupHomePage> {
  final StartupDbHelper _db = StartupDbHelper();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await _loginToServerDB();
    });
  }

  void _goNext() {
    final next = isDesktop ? const desktop.HomeDesktop() : const tablet.HomeTablet();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => next), (route) => false,
    );
  }

  // 로그아웃 유입이면 자동 표시하지 않음, 사용자 요청 시(앱바 로그인 아이콘) 열도록 함
  Future<void> _loginToServerDB() async {
    if (!(await _db.connectToServerDB(context))) return;
    if (!widget.fromLogout) _showStartupDialog();
  }

  // 재연결 모달은 전역 오버레이(GlobalReconnectOverlay)가 담당하므로 여기서는 처리하지 않음
  void _showStartupDialog({bool forceNoticeClosed = false}) async {
    await StartupDialog.show(
      context, onLogin: _goNext,
      serverName: _db.lastConnectInfo?.serverName,
      forceNoticeClosed: forceNoticeClosed,
    );
  }

  @override
  void dispose() {
    _db.dispose();
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
            onPressed: () => DbClient.instance.isConnected ? _showStartupDialog() : _loginToServerDB()
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

