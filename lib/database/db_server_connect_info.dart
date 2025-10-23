// UTF-8 인코딩
// 로컬 DB: dmServerConnectInfo.db (테이블: DB_SERVER_CONNECT_INFO)
// 기능: 생성, 오픈, 조회, 업데이트

// ignore_for_file: constant_identifier_names, body_might_complete_normally_catch_error

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:synchronized/synchronized.dart';

import 'package:label_printer/core/app.dart';

enum CustomerType {
	CUST_TYPE_NORMAL(0),
	CUST_SHINSEGAE(1),
	CUST_GS_RETAIL(2);

  final int code;
  const CustomerType(this.code);
  static CustomerType fromCode(int code) => CustomerType.values.firstWhere((e) => e.code == code);
}

/// 서버 연결 정보 모델
class ServerConnectInfo {
  final String serverIp;
  final String databaseName;
  final int serverPort;
  final String userId;
  final String password;
  final String serverName;
	final CustomerType customerType;

  const ServerConnectInfo({
    required this.serverIp,
    required this.databaseName,
		required this.serverPort,
    required this.userId,
    required this.password,
		required this.serverName,
		required this.customerType,
  });

  Map<String, Object?> toMap() => {
    'RICH_SERVER_IP': serverIp,
    'RICH_DATABASE_NAME': databaseName,
    'RICH_SERVER_PORT': serverPort,
    'RICH_USER_ID': userId,
    'RICH_PWD': password,
    'RICH_SERVER_NAME': serverName,
		'RICH_CUSTOMER_TYPE': customerType.code,
  };

  static ServerConnectInfo fromMap(Map<String, Object?> m) => ServerConnectInfo(
    serverIp: (m['RICH_SERVER_IP'] ?? '') as String,
    databaseName: (m['RICH_DATABASE_NAME'] ?? '') as String,
    serverPort: (m['RICH_SERVER_PORT'] ?? 0) as int,
    userId: (m['RICH_USER_ID'] ?? '') as String,
 		password: (m['RICH_PWD'] ?? '') as String,
    serverName: (m['RICH_SERVER_NAME'] ?? '') as String,
		customerType: CustomerType.fromCode((m['RICH_CUSTOMER_TYPE'] ?? 0) as int),
 );
}

/// DB 헬퍼: 생성/오픈/조회/업데이트
class DbServerConnectInfoHelper {
  static const cn = 'DbServerConnectInfoHelper';
  static const _data = 'data';
  static const _dbName = 'labelmanager_server_connect_info.db';
  static const _table = 'BM_DB_SERVER_CONNECT_INFO';
  static const _lastTable = 'BM_LAST_CONNECT_DB_SERVER';
  static const _dbVersion = 2;

  static Database? _db;
  static MethodChannel? _channel;
  static final _dbInitLock = Lock(); // 동시성 방지

  /// 데스크톱(Windows/macOS/Linux)에서 sqflite_ffi 초기화
  static void _ensureDesktopInit() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfi;
    }
  }

  /// DB 파일의 최종 경로를 결정
  static Future<String> _dbFullPath(String? internalDbPath) async {
    const fn = '_dbFullPath';
    debugPrint('$cn.$fn: $START');

    // Android: SAF/Legacy 권한을 처리한 뒤 선택된 Documents 하위 경로를 사용한다.
    // 앱의 쓰기 가능한 디렉터리 하위에 assets/data 경로를 생성하고, 해당 경로에 DB 파일을 복사한다.
    if (Platform.isAndroid) {
      _channel ??= MethodChannel('$appPackageName/storage');

      String? dbPath = await _channel!.invokeMethod<String>(
        'prepareDocumentsAndGetPath', {'isInternalDbExists': internalDbPath!=null});

      if (dbPath != null && dbPath.isNotEmpty) {
        debugPrint('$cn.$fn: Android SAF/Legacy Path = $dbPath');

        // SAF URI인 경우, 내용을 로컬 파일로 복사
        if (dbPath.startsWith('content://')) {
          try {
            _channel ??= MethodChannel('$appPackageName/storage');
            final Uint8List? data = await _channel!.invokeMethod('readContentUri', {'uri': dbPath});

            if (data != null) {
              final docDir = await getApplicationDocumentsDirectory();
              final localPath = p.join(docDir.path, _data, _dbName);
              await File(localPath).writeAsBytes(data, flush: true);
              debugPrint('$cn.$fn: Copied SAF content URI to local file: $localPath');
              dbPath = localPath; // DB 열기 경로를 로컬 경로로 변경
            } else {
              debugPrint('$cn.$fn: Internal db file: $internalDbPath');
              dbPath = internalDbPath;
            }
          }
          catch (e) {
            debugPrint('$cn.$fn: Failed to read/copy content URI: $e');
            // 에러 발생 시 기존 경로(content://)로 시도하도록 둠 (실패하겠지만)
          }
        }

        return dbPath!; // content://... 또는 실제 파일 경로
      }

      throw UnsupportedError('ERROR!!');
    }

    Directory baseDir;

    if (kIsWeb) {
      // Web은 sqflite 미지원. 여기선 예외를 던집니다.
      throw UnsupportedError('sqflite is not supported on Web');
    }
    else if (Platform.isIOS) {
      // iOS는 앱의 Documents 디렉터리를 사용합니다.
      baseDir = await getApplicationDocumentsDirectory();
      debugPrint('DB baseDir (iOS): ${baseDir.path}');
    }
    else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      if (kDebugMode) {
        baseDir = Directory.current;
      } else {
        baseDir = await getApplicationSupportDirectory();
      }
    }
    else {
      baseDir = await getTemporaryDirectory();
    }

    final dir = Directory(p.join(baseDir.path, 'assets', 'data'));

    debugPrint('$cn.$fn: $END, path=${dir.path}');
    return p.join(dir.path, _dbName);
  }

  //////////////////////////////////////////////////////////////////////////////
  /// DB 오픈 (필요 시 생성 및 마이그레이션)

  static Future<Database> open() => _dbInitLock.synchronized(() async {
    const fn = 'open';
    debugPrint('$cn.$fn: $START');

    if (_db != null && _db!.isOpen) return _db!;

    _ensureDesktopInit();

    // 내부에 labelmanager_server_connect_info.db가 있는 지 판단 (안드로이드만)
    String? internalDbPath;
    if (Platform.isAndroid) {
      final docDir = await getApplicationDocumentsDirectory();
      final localPath = p.join(docDir.path, _data, _dbName);
      if (await File(localPath).exists()) { internalDbPath = localPath; }
    }

    String dbPath = await _dbFullPath(internalDbPath);
    debugPrint('$cn.$fn: Initial DB path = $dbPath');

    try {
      _db = await openDatabase(
        dbPath,
        version: _dbVersion,
        onCreate: (db, version) async {
          debugPrint('$cn.$fn: Creating database version $version');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $_table (
              RICH_SERVER_IP     TEXT (0, 64),
              RICH_DATABASE_NAME TEXT (0, 256),
              RICH_SERVER_PORT   INTEGER (0, 5),
              RICH_USER_ID       TEXT (0, 64),
              RICH_PWD           TEXT (0, 64),
              RICH_SERVER_NAME   TEXT (0, 512),
              RICH_CUSTOMER_TYPE INTEGER (0, 5) DEFAULT (0),
              RICH_ETC           TEXT (0, 64),
              PRIMARY KEY (
                  RICH_SERVER_IP COLLATE RTRIM ASC,
                  RICH_DATABASE_NAME COLLATE RTRIM ASC
              )
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $_lastTable (
              RICH_SERVER_IP     TEXT (64),
              RICH_DATABASE_NAME TEXT (0, 256),
              PRIMARY KEY (
                RICH_SERVER_IP COLLATE RTRIM ASC,
                RICH_DATABASE_NAME COLLATE RTRIM ASC
              )
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          debugPrint('$cn.$fn: Upgrading database from $oldVersion to $newVersion');
        },
      );
    }
    catch (e) {
      debugPrint('$cn.$fn: Failed to open database at $dbPath, error=$e');
      rethrow;
    }

    debugPrint('$cn.$fn: $END, isOpen=${_db!.isOpen}');
    return _db!;
  });

  /// 마지막 접속 정보 조회
  static Future<ServerConnectInfo?> getLastConnectDBInfo() async {
  	const sql = '''
			SELECT
				P2.RICH_SERVER_IP,
				P2.RICH_DATABASE_NAME,
				P2.RICH_SERVER_PORT,
				P2.RICH_USER_ID,
				P2.RICH_PWD,
				P2.RICH_SERVER_NAME,
				P2.RICH_CUSTOMER_TYPE
			FROM BM_LAST_CONNECT_DB_SERVER AS P1
			INNER JOIN BM_DB_SERVER_CONNECT_INFO AS P2
				ON P1.RICH_SERVER_IP = P2.RICH_SERVER_IP
			AND P1.RICH_DATABASE_NAME = P2.RICH_DATABASE_NAME
		''';

		final db = await open();
    final rows = await db.rawQuery(sql);
    if (rows.isEmpty) return null;
    return ServerConnectInfo.fromMap(rows.first);
  }

  /// upsert: 존재하면 업데이트, 없으면 삽입
  static Future<void> upsert(ServerConnectInfo info) async {
    final db = await open();
    await db.insert(
      _table,
      info.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // 마지막 접속 테이블 갱신 (업데이트 타임스탬프)
    await db.insert(
      _lastTable,
      {
        'RICH_SERVER_IP': info.serverIp,
        'RICH_DATABASE_NAME': info.databaseName,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 마지막 접속 정보 수동 갱신 (필요 시 호출)
  static Future<void> setLastConnected(String serverIp, String databaseName) async {
    final db = await open();
    await db.insert(
      _lastTable,
      {
        'RICH_SERVER_IP': serverIp,
        'RICH_DATABASE_NAME': databaseName,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// DB 닫기
  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
