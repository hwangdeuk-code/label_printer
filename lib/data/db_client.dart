import 'package:label_printer/data/db_connection_service.dart';
import 'package:mssql_connection/mssql_connection.dart';

/// 앱 전역에서 DB 액세스를 단일 경로로 제공하는 클라이언트.
/// - 폴링 일시중지/재개를 내부에서 처리하여 세션 충돌을 방지한다.
/// - 쿼리 앞에 SET NOCOUNT ON; 을 자동 주입한다.
/// - 선택적 타임아웃 처리를 지원한다.
class DbClient {
  DbClient._();
  static final DbClient instance = DbClient._();

  bool get isConnected => MssqlConnection.getInstance().isConnected;

  String _withNoCount(String sql) {
    final s = sql.trimLeft();
    final lower = s.toLowerCase();
    if (lower.startsWith('set nocount on;') || lower.startsWith('set nocount on')) {
      return sql;
    }
    return 'SET NOCOUNT ON; $sql';
  }

  Future<String> getData(String sql, {Duration? timeout, String Function()? onTimeout}) async {
    final wrapped = _withNoCount(sql);
    return DbConnectionService.instance.runUserDbAction<String>((db) async {
      return await db.getData(wrapped);
    }, timeout: timeout, onTimeout: onTimeout);
  }

  Future<String> getDataWithParams(String sql, Map<String, dynamic> params, {Duration? timeout, String Function()? onTimeout}) async {
    final wrapped = _withNoCount(sql);
    return DbConnectionService.instance.runUserDbAction<String>((db) async {
      return await db.getDataWithParams(wrapped, params);
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
    MssqlConnection.getInstance().disconnect();
  }
}
