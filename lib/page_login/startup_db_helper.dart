import 'package:flutter/material.dart';
import 'package:label_printer/core/app.dart';

import 'package:label_printer/database/db_client.dart';
import 'package:label_printer/database/db_connection_service.dart';
import 'package:label_printer/database/db_server_connect_info.dart';
import 'package:label_printer/utils/on_messages.dart';

/// 앱 시작 시 서버 DB 연결 및 재연결 모니터링을 담당하는 헬퍼
class StartupDbHelper {
  static const String cn = 'StartupDbHelper';
  ServerConnectInfo? lastConnectInfo;
  VoidCallback? _upListener;

  /// 서버 DB에 연결 시도. 성공 시 true를 반환한다.
  /// - 진행/에러 안내는 전역 BlockingOverlay로 처리한다.
  Future<bool> connectToServerDB(BuildContext context) async {
    const String fn = 'connectToServerDB';
    debugPrint('$cn.$fn: $START');

    bool errorOverlayShown = false;

    try {
      final dbConnection = DbClient.instance;
      if (dbConnection.isConnected) {
        debugPrint('$cn.$fn: already connected');
        return true;
      }

      showSnackBar(context, '서버 데이터베이스에 접속 중 입니다...', type: SnackBarType.inProgress);
      lastConnectInfo = await DbServerConnectInfoHelper.getLastConnectDBInfo();

      if (lastConnectInfo == null) {
        debugPrint('$cn.$fn: No previous server connect info found.');
        return false;
      }

      final success = await dbConnection.connect(
        ip: lastConnectInfo!.serverIp,
        port: lastConnectInfo!.serverPort.toString(),
        databaseName: lastConnectInfo!.databaseName,
        username: lastConnectInfo!.userId,
        password: lastConnectInfo!.password,
        timeoutInSeconds: 30,
      );

      if (!success) {
        debugPrint('$cn.$fn: Failed to connect');
        throw Exception('Failed to connect');
      }

      _startDatabaseMonitor();
      debugPrint('$cn.$fn: connected successfully');
      return true;
    }
   catch (e) {
      debugPrint('$cn.$fn: Exception during DB connect: $e');

      if (context.mounted) {
        // 진행중 오버레이가 켜져 있을 수 있으니 먼저 닫고, 에러 오버레이를 띄운다.
        // 진행중 안내 스낵바 즉시 숨김
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        showSnackBar(
          context,
          '서버 접속에 실패하였습니다!!\n인터넷 연결상태를 먼저 확인해주시고 02)3274-1776으로 전화주세요!',
          type: SnackBarType.error,
        );

        errorOverlayShown = true;
      }
      
      return false;
    }
    finally {
      // 에러 오버레이를 띄운 경우에는 사용자가 버튼을 누를 때까지 유지
      if (!errorOverlayShown && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      
      debugPrint('$cn.$fn: $END');
    }
  }

  /// 재연결 모니터 시작. 필요 시 상단 상태 아이콘 등에서 표시.
  void _startDatabaseMonitor() {
    final info = lastConnectInfo;
    if (info == null) return;

    DbConnectionService.instance.attachAndStart(info: info);

    // 상태 전환에 따라 재연결 다이얼로그 표시/닫기 (글로벌 오버레이가 처리)
    _upListener ??= () {
      // no-op: 상태 변화는 전역 오버레이에서 소화
    };

    DbConnectionService.instance.status.up.addListener(_upListener!);
  }

  void dispose() {
    if (_upListener != null) {
      DbConnectionService.instance.status.up.removeListener(_upListener!);
      _upListener = null;
    }
  }
}
