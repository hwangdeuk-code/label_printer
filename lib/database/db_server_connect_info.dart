// UTF-8 인코딩
// 로컬 DB: dmServerConnectInfo.db (테이블: DB_SERVER_CONNECT_INFO)
// 기능: 생성, 오픈, 조회, 업데이트

// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:label_printer/core/app.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const _dbName = 'labelmanager_server_connect_info.db';
  static const _table = 'BM_DB_SERVER_CONNECT_INFO';
  static const _lastTable = 'BM_LAST_CONNECT_DB_SERVER';
  static const _dbVersion = 2;

  static Database? _db;
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static Completer<void>? _androidPermissionLock;
  static int? _cachedAndroidSdkInt;
  static String? _cachedAndroidDocumentsDir;
  static const String _prefsAndroidDocumentsDirKey = 'db_server_connect_info_android_documents_dir';

  /// 데스크톱(Windows/macOS/Linux)에서 sqflite_ffi 초기화
  static void _ensureDesktopInit() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      // 데스크톱 환경에서 sqflite_common_ffi를 초기화한다.
      // 이 초기화는 데이터베이스 작업을 가능하게 한다.
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfi;
    }
  }

  /// 앱의 쓰기 가능한 디렉터리 하위에 assets/data 경로 보장
  static Future<String> _dbPath() async {
    // 앱의 쓰기 가능한 디렉터리 하위에 assets/data 경로를 생성하고,
    // 해당 경로에 DB 파일을 복사한다.
    Directory baseDir;
    if (kIsWeb) {
      // Web은 sqflite 미지원. 여기선 예외를 던집니다.
      throw UnsupportedError('sqflite is not supported on Web');
    }
    else if (Platform.isAndroid) {
      // Android: SAF/Legacy 권한을 처리한 뒤 선택된 Documents 하위 경로를 사용한다.
      final docs = await _ensureAndroidDocumentsDirectory();
      baseDir = Directory(p.join(docs, appPackageName));
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

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    if (Platform.isAndroid) {
      // Android에서는 공개 문서 디렉터리에 생성된 폴더가 미디어 스캔에서 누락될 수 있으므로,
      // .nomedia 파일을 생성해 다른 미디어 스캔이 이 폴더를 스캔하지 않도록 합니다.
      final noMediaFile = File(p.join(dir.path, '.nomedia'));
      if (!await noMediaFile.exists()) { await noMediaFile.create(); }

      // labelmanager_server_connect_info.db 파일을 assets/data 경로에 복사합니다.
      final dbFile = File(p.join(dir.path, _dbName));
      if (!await dbFile.exists()) {
        final dbAssetPath = p.join('assets', 'data', _dbName);
        final byteData = await rootBundle.load(dbAssetPath);
        final bytes = byteData.buffer.asUint8List();
        await dbFile.writeAsBytes(bytes, flush: true);
      }
    }

    return p.join(dir.path, _dbName);
  }

  static const MethodChannel _filesChannel = MethodChannel('com.itsng.label_printer/files');

  static Future<String> _ensureAndroidDocumentsDirectory() async {
    final sdkInt = await _getAndroidSdkInt();
    if (sdkInt >= 33) {
      await _ensureAndroidSafDirectory();
      final path = _cachedAndroidDocumentsDir;
      if (path == null || path.isEmpty) {
        throw StateError('SAF Documents 경로 확보에 실패했습니다.');
      }
      if (!path.startsWith('content://')) {
        await _ensureDirectoryExists(path);
      } else {
        debugPrint('$cn._ensureAndroidDocumentsDirectory, content uri result: $path');
      }
      return path;
    }

    await _ensureAndroidLegacyPermission();
    final docs = await _getAndroidPublicDocumentsDir();
    await _ensureDirectoryExists(docs);
    return docs;
  }

  static Future<void> _ensureAndroidLegacyPermission() async {
    await _runAndroidPermissionLock(() async {
      final status = await ph.Permission.storage.status;
      if (status.isGranted || status.isLimited) {
        return;
      }

      final result = await ph.Permission.storage.request();
      if (result.isGranted || result.isLimited) {
        return;
      }

      throw Exception('공용 Documents 폴더 접근을 위한 저장소 권한이 거부되었습니다.');
    });
  }

  static Future<void> _ensureAndroidSafDirectory() async {
    if (_cachedAndroidDocumentsDir != null && _cachedAndroidDocumentsDir!.isNotEmpty) {
      return;
    }

    await _runAndroidPermissionLock(() async {
      if (_cachedAndroidDocumentsDir != null && _cachedAndroidDocumentsDir!.isNotEmpty) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsAndroidDocumentsDirKey);
      if (saved != null && saved.isNotEmpty) {
        _cachedAndroidDocumentsDir = saved;
        return;
      }

      final initialDir = await _getAndroidPublicDocumentsDir();
      final selected = await getDirectoryPath(
        initialDirectory: initialDir.isEmpty ? null : initialDir,
        confirmButtonText: '선택',
      );

      if (selected == null || selected.isEmpty) {
        throw Exception('공용 Documents 폴더의 하위 경로를 선택해야 합니다.');
      }

      if (!selected.startsWith('content://')) {
        await _ensureDirectoryExists(selected);
      } else {
        debugPrint('$cn._ensureAndroidSafDirectory, content uri selected: $selected');
      }

      _cachedAndroidDocumentsDir = selected;
      await prefs.setString(_prefsAndroidDocumentsDirKey, selected);
    });
  }

  static Future<void> _ensureDirectoryExists(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  static Future<void> _runAndroidPermissionLock(Future<void> Function() action) {
    final existing = _androidPermissionLock;
    if (existing != null) {
      return existing.future;
    }

    final completer = Completer<void>();
    _androidPermissionLock = completer;

    () async {
      try {
        await action();
        if (!completer.isCompleted) {
          completer.complete();
        }
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      } finally {
        if (identical(_androidPermissionLock, completer)) {
          _androidPermissionLock = null;
        }
      }
    }();

    return completer.future;
  }

  static Future<int> _getAndroidSdkInt() async {
    if (_cachedAndroidSdkInt != null) {
      return _cachedAndroidSdkInt!;
    }
    final info = await _deviceInfo.androidInfo;
    _cachedAndroidSdkInt = info.version.sdkInt;
    return _cachedAndroidSdkInt!;
  }

  static Future<String> _getAndroidPublicDocumentsDir() async {
    try {
      final String? path = await _filesChannel.invokeMethod<String>('getPublicDocumentsDir');
      if (path != null && path.isNotEmpty) return path;
    } catch (_) {}
    // 폴백: 앱 전용 문서 디렉토리
    final d = await getApplicationDocumentsDirectory();
    return d.path;
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
