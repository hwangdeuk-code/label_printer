import 'dart:io';

import 'package:label_printer/database/db_connection_service.dart';
import 'package:mssql_connection/mssql_connection.dart' as mssql;
import 'package:sql_connection/sql_connection.dart' as sqlconn;

/// 앱 전역에서 DB 액세스를 단일 경로로 제공하는 클라이언트.
/// - 폴링 일시중지/재개를 내부에서 처리하여 세션 충돌을 방지한다.
/// - 쿼리 앞에 SET NOCOUNT ON; 을 자동 주입한다.
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
  }) => _db.connect(
        ip: ip,
        port: port,
        databaseName: databaseName,
        username: username,
        password: password,
        timeoutInSeconds: timeoutInSeconds,
      );
  @override
  Future<String> getData(String sql) {
    // mssql_connection 사용 시에는 NOCOUNT를 주입해 불필요한 rowcount 결과셋을 제거한다.
    final wrapped = _withNoCount(sql);
    return _db.getData(wrapped);
  }
  @override
  Future<String> getDataWithParams(String sql, Map<String, dynamic> params) {
    final wrapped = _withNoCount(sql);
    return _db.getDataWithParams(wrapped, params);
  }
  @override
  Future<String> writeData(String sql) {
    final wrapped = _withNoCount(sql);
    return _db.writeData(wrapped);
  }
  @override
  Future<bool> disconnect() => _db.disconnect();
}

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
  }) => _db.connect(
        ip: ip,
        port: port,
        databaseName: databaseName,
        username: username,
        password: password,
        timeoutInSeconds: timeoutInSeconds,
      );
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
  Future<bool> disconnect() => _db.disconnect();

  static String _escapeValue(Object? v) {
    if (v == null) return 'NULL';
    if (v is num) return v.toString();
    if (v is bool) return v ? '1' : '0';
    final s = v.toString().replaceAll("'", "''");
    return "N'$s'";
  }
}

class DbClient {
  DbClient._();
  static final DbClient instance = DbClient._();
  final _DbBackend _backend = (Platform.isAndroid) ? _SqlConnBackend() : _MssqlBackend();

  bool get isConnected => _backend.isConnected;

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

  Future<String> getData(String sql, {Duration? timeout, String Function()? onTimeout}) async {
    return DbConnectionService.instance.runUserDbAction<String>((db) async {
      return await _backend.getData(sql);
    }, timeout: timeout, onTimeout: onTimeout);
  }

  Future<String> getDataWithParams(String sql, Map<String, dynamic> params, {Duration? timeout, String Function()? onTimeout}) async {
    return DbConnectionService.instance.runUserDbAction<String>((db) async {
      return await _backend.getDataWithParams(sql, params);
    }, timeout: timeout, onTimeout: onTimeout);
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
  void disconnect() {
    _backend.disconnect();
  }
}

// Backend 공통 사용 유틸: mssql 백엔드에서만 사용되는 NOCOUNT 주입기
String _withNoCount(String sql) {
  final s = sql.trimLeft();
  final lower = s.toLowerCase();
  if (lower.startsWith('set nocount on;') || lower.startsWith('set nocount on')) {
    return sql;
  }
  return 'SET NOCOUNT ON; $sql';
}
