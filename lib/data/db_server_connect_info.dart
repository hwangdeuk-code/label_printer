// UTF-8 인코딩
// 로컬 DB: dmServerConnectInfo.db (테이블: DB_SERVER_CONNECT_INFO)
// 기능: 생성, 오픈, 조회, 업데이트

// ignore_for_file: constant_identifier_names

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

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
    serverIp: ((m['RICH_SERVER_IP'] ?? '') as String) + '11',
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
  static const _dbName = 'labelmanager_server_connect_info.db';
  static const table = 'BM_DB_SERVER_CONNECT_INFO';
  static const lastTable = 'BM_LAST_CONNECT_DB_SERVER';
  static const _dbVersion = 2;

  static Database? _db;

  /// 데스크톱(Windows/macOS/Linux)에서 sqflite_ffi 초기화
  static void _ensureDesktopInit() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      // 데스크톱 환경에서는 sqflite_common_ffi를 초기화하고 팩토리를 교체합니다.
      // 여러 번 호출되어도 안전합니다.
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfi;
    }
  }

  /// 앱의 쓰기 가능한 디렉터리 하위에 assets/data 경로 보장
  static Future<String> _dbPath() async {
    // 주의: 실제 앱 번들의 assets 폴더는 read-only이므로, 쓰기 가능한 앱 데이터 폴더에
    // 동일한 하위 경로(assets/data)를 만들어 DB를 저장합니다.
    final Directory baseDir;
    if (kIsWeb) {
      // Web은 sqflite 미지원. 여기선 예외를 던집니다.
      throw UnsupportedError('sqflite is not supported on Web');
    } else if (Platform.isAndroid || Platform.isIOS) {
      baseDir = await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
			if (kDebugMode) {
				baseDir = Directory.current;
			} else {
      	baseDir = await getApplicationSupportDirectory();
			}
    } else {
      baseDir = await getTemporaryDirectory();
    }

    final dir = Directory(p.join(baseDir.path, 'assets', 'data'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return p.join(dir.path, _dbName);
  }

  /// DB 오픈 (필요 시 생성 및 마이그레이션)
  static Future<Database> open() async {
    _ensureDesktopInit();

    if (_db != null && _db!.isOpen) return _db!;

    final path = await _dbPath();
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $table (
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
					CREATE TABLE IF NOT EXISTS $lastTable (
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
				debugPrint('DB Upgrade: $oldVersion -> $newVersion');
        // if (oldVersion < 2) {
        //   await db.execute('''
        //     CREATE TABLE IF NOT EXISTS $lastTable (
        //       RICH_SERVER_IP     TEXT (0, 64) NOT NULL,
        //       RICH_DATABASE_NAME TEXT (0, 256) NOT NULL,
        //       LAST_CONNECTED_AT  INTEGER,
        //       PRIMARY KEY (RICH_SERVER_IP, RICH_DATABASE_NAME)
        //     )
        //   ''');
        // }
      },
    );

    return _db!;
  }

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
      table,
      info.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // 마지막 접속 테이블 갱신 (업데이트 타임스탬프)
    await db.insert(
      lastTable,
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
      lastTable,
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
