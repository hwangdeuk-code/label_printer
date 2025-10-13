// UTF-8 인코딩
// 기능: 연결, 조회, 업데이트

// ignore_for_file: constant_identifier_names

import 'package:flutter/foundation.dart';
import 'package:label_printer/data/db_server_connect_info.dart';
import 'package:mssql_connection/mssql_connection.dart';

const String cName = 'MainDatabaseHelper';

class MainDatabaseHelper {
  static const table = 'BM_DB_SERVER_CONNECT_INFO';

  static MssqlConnection? _connection;

  static bool get isConnected => _connection != null && _connection!.isConnected;

  static void connect(ServerConnectInfo serverConnectInfo) async {
    if (_connection != null && _connection!.isConnected) {
      debugPrint('$cName.connect() | already connected.');
      return;
    }

    final connection = MssqlConnection.getInstance();
    final success = await connection.connect(
      ip: serverConnectInfo.serverIp,
      port: serverConnectInfo.serverPort.toString(),
      databaseName: serverConnectInfo.databaseName,
      username: serverConnectInfo.userId,
      password: serverConnectInfo.password,
      timeoutInSeconds: 15,
    );

    if (success) {
      debugPrint('$cName.connect() | connected to ${serverConnectInfo.serverIp}:${serverConnectInfo.serverPort}/${serverConnectInfo.databaseName} as ${serverConnectInfo.userId}');
      _connection = connection;
    } else {
      final error = 'failed to connect to ${serverConnectInfo.serverIp}:${serverConnectInfo.serverPort}/${serverConnectInfo.databaseName} as ${serverConnectInfo.userId}';
      debugPrint('$cName.connect() | $error');
      throw Exception(error);
    }
  }

  static void disconnect() async {
    if (_connection != null && _connection!.isConnected) {
      await _connection!.disconnect();
      debugPrint('$cName.disconnect() | disconnected.');
      _connection = null;
    } else {
      debugPrint('$cName.disconnect() | not connected.');
    } 
  }
}
