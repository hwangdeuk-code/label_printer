import 'dart:async';

import 'package:flutter/material.dart';
import 'package:label_printer/database/db_connection_service.dart';
import 'package:label_printer/models/user.dart';
import 'package:mssql_connection/mssql_connection.dart' as mssql;
//import 'package:sql_connection/sql_connection.dart' as sqlconn;

/// 앱 전역에서 DB 액세스를 단일 경로로 제공하는 클라이언트.
/// - 폴링 일시중지/재개를 내부에서 처리하여 세션 충돌을 방지한다.
/// - 연결 성공 직후 SET TEXTSIZE 2147483647;와 SET NOCOUNT ON;을 순차 실행하도록 통합한다.
/// - 선택적 타임아웃 처리를 지원한다.
abstract class _DbBackend {
  bool get isConnected;

  Future<bool> connect({
    required String ip,
    required String port,
    required String databaseName,
    required String username,
    required String password,
    int timeoutInSeconds = 15,
  });

  Future<String> getData(String sql);
  Future<String> getDataWithParams(String sql, Map<String, dynamic> params);
  Future<String> writeData(String sql);
  Future<String> writeDataWithParams(String sql, Map<String, dynamic> params);
  Future<bool> disconnect();
}

class _MssqlBackend implements _DbBackend {
  mssql.MssqlConnection get _db => mssql.MssqlConnection.getInstance();

  @override
  bool get isConnected => _db.isConnected;

  @override
  Future<bool> connect({
    required String ip,
    required String port,
    required String databaseName,
    required String username,
    required String password,
    int timeoutInSeconds = 15,
  }) async {
    final ok = await _db.connect(
      ip: ip,
      port: port,
      databaseName: databaseName,
      username: username,
      password: password,
      timeoutInSeconds: timeoutInSeconds,
    );
    if (!ok) return false;
    await _db.writeData('SET NOCOUNT ON;');
    return true;
  }

  @override
  Future<String> getData(String sql) => _db.getData(sql);

  @override
  Future<String> getDataWithParams(String sql, Map<String, dynamic> params) =>
      _db.getDataWithParams(sql, params);

  @override
  Future<String> writeData(String sql) => _db.writeData(sql);

  @override
  Future<String> writeDataWithParams(String sql, Map<String, dynamic> params) =>
      _db.writeDataWithParams(sql, params);

  @override
  Future<bool> disconnect() => _db.disconnect();
}

/*
class _SqlConnBackend implements _DbBackend {
  final sqlconn.SqlConnection _db = sqlconn.SqlConnection.getInstance();

  @override
  bool get isConnected => _db.isConnected;

  @override
  Future<bool> connect({
    required String ip,
    required String port,
    required String databaseName,
    required String username,
    required String password,
    int timeoutInSeconds = 15,
  }) async {
    final ok = await _db.connect(
      ip: ip,
      port: port,
      databaseName: databaseName,
      username: username,
      password: password,
      timeoutInSeconds: timeoutInSeconds,
    );
    if (!ok) return false;
    await _db.updateData('SET TEXTSIZE 2147483647;');
    await _db.updateData('SET NOCOUNT ON;');
    return true;
  }

  @override
  Future<String> getData(String sql) => _db.queryDatabase(sql);

  @override
  Future<String> getDataWithParams(String sql, Map<String, dynamic> params) {
    // Android(sql_connection)에서는 sp_executesql 사용 시 일부 드라이버가 프로시저 호출로 처리하며 실패할 수 있다.
    // 따라서 파라미터 토큰(@name)을 안전한 리터럴로 치환해 단일 SELECT 문으로 실행한다.
    // 주의: 쿼리 문자열 내부의 따옴표 안에서의 @토큰 치환은 지원하지 않는다(현재 쿼리 패턴에선 필요 없음).
    var inlined = sql;

    params.forEach((key, value) {
      final pattern = RegExp('@' + RegExp.escape(key) + r'\b');
      inlined = inlined.replaceAll(pattern, _escapeValue(value));
    });

    return _db.queryDatabase(inlined);
  }

  @override
  Future<String> writeData(String sql) => _db.updateData(sql);

  @override
  Future<String> writeDataWithParams(String sql, Map<String, dynamic> params) {
    var inlined = sql;

    params.forEach((key, value) {
      final pattern = RegExp('@' + RegExp.escape(key) + r'\b');
      inlined = inlined.replaceAll(pattern, _escapeValue(value));
    });

    return _db.updateData(inlined);
  }

  @override
  Future<bool> disconnect() => _db.disconnect();

  static String _escapeValue(Object? v) {
    if (v == null) return 'NULL';
    if (v is num) return v.toString();
    if (v is bool) return v ? '1' : '0';
    final s = v.toString().replaceAll("'", "''");
    return "N'$s'";
  }
}
*/

class DbClient {
  DbClient._();
  static const String cn = 'DbClient';
  static final DbClient instance = DbClient._();
//  final _DbBackend _backend = (Platform.isAndroid) ? _SqlConnBackend() : _MssqlBackend();
  final _DbBackend _backend = _MssqlBackend();
  Future<void> _operationSerial = Future<void>.value();

  bool get isConnected => _backend.isConnected;

  Future<T> _runLocked<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _operationSerial = _operationSerial.then((_) async {
      try {
        final result = await action();
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } catch (error, stack) {
        if (!completer.isCompleted) {
          completer.completeError(error, stack);
        }
        rethrow;
      }
    }).catchError((error, stack) {
      if (!completer.isCompleted) {
        completer.completeError(error, stack);
      }
      return null;
    });
    return completer.future;
  }

  Future<bool> connect({
    required String ip,
    required String port,
    required String databaseName,
    required String username,
    required String password,
    int timeoutInSeconds = 15,
  }) => _backend.connect(
        ip: ip,
        port: port,
        databaseName: databaseName,
        username: username,
        password: password,
        timeoutInSeconds: timeoutInSeconds,
      );

  Future<String> getData(String sql, {Duration? timeout, String Function()? onTimeout}) {
    return _runLocked(() {
      return DbConnectionService.instance.runUserDbAction<String>(
        (_) => _backend.getData(sql),
        timeout: timeout,
        onTimeout: onTimeout,
      );
    });
  }

  Future<String> getDataWithParams(String sql, Map<String, dynamic> params, {Duration? timeout, String Function()? onTimeout}) {
    return _runLocked(() {
      return DbConnectionService.instance.runUserDbAction<String>(
        (_) => _backend.getDataWithParams(sql, params),
        timeout: timeout,
        onTimeout: onTimeout,
      );
    });
  }

  Future<String> writeData(String sql, {Duration? timeout, String Function()? onTimeout}) {
    return _runLocked(() {
      return DbConnectionService.instance.runUserDbAction<String>(
        (_) => _backend.writeData(sql),
        timeout: timeout,
        onTimeout: onTimeout,
      );
    });
  }

  Future<String> writeDataWithParams(String sql, Map<String, dynamic> params, {Duration? timeout, String Function()? onTimeout}) {
    return _runLocked(() {
      return DbConnectionService.instance.runUserDbAction<String>(
        (_) => _backend.writeDataWithParams(sql, params),
        timeout: timeout,
        onTimeout: onTimeout,
      );
    });
  }

  /// 간단 핑. 성공 시 true. 타임아웃/예외 시 false.
  Future<bool> ping({Duration timeout = const Duration(seconds: 1)}) async {
    try {
      final s = await getData('SELECT 1 AS ok', timeout: timeout, onTimeout: () => '{"error":"timeout"}');
      return s.isNotEmpty && !s.contains('error');
    } catch (_) {
      return false;
    }
  }

  /// 비정상일 때 재연결 유도.
  void disconnect(String from) {
    const String fn = 'disconnect';
    debugPrint('$cn.$fn: from=$from');
    if (_backend.isConnected) {
      DbConnectionService.instance.detach();
      _backend.disconnect();
      debugPrint('$cn.$fn: Disconnected from database');
    }
  }
}
