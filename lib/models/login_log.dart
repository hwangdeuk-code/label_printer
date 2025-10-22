// UTF-8, 한국어 주석
// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:label_printer/core/app.dart';
import 'package:label_printer/database/db_client.dart';
import 'package:label_printer/database/db_result_utils.dart';
import 'package:r_get_ip/r_get_ip.dart';
import 'dao.dart';
import 'user.dart';

enum LoginCondition {
	LOGIN(0),
	LOGOUT(1);

  final int code;
  const LoginCondition(this.code);
  static LoginCondition fromCode(int code) => LoginCondition.values.firstWhere((e) => e.code == code);
}

class LoginLog {
 	final int logId;
	final String userId;
	final UserGrade userGrade;
	final String programVersion;
	final int customerId;
	final String customerName;
	final String loginDate;
	final String loginDateYYYYMMDD;
	final String lLoginIP;
	final LoginCondition loginCondition;

  const LoginLog({
    required this.logId,
    required this.userId,
    required this.userGrade,
    required this.programVersion,
    required this.customerId,
    required this.customerName,
    required this.loginDate,
    required this.loginDateYYYYMMDD,
    required this.lLoginIP,
    required this.loginCondition,
  });

  factory LoginLog.fromPipe(String line) {
    final parts = line.split(DAO.SPLITTER);

    if (parts.length < 2) {
      throw FormatException('${DAO.incorrect_format}: $line');
    }

    final logId = int.tryParse(parts[0].trim()) ?? 0;
    final userId = parts[1].trim();
    final userGrade = UserGrade.fromCode(int.tryParse(parts[2].trim()) ?? 0);
    final programVersion = parts[3].trim();
    final customerId = int.tryParse(parts[4].trim()) ?? 0;
    final customerName = parts[5].trim();
    final loginDate = parts[6].trim();
    final loginDateYYYYMMDD = parts[7].trim();
    final lLoginIP = parts[8].trim();
    final loginCondition = LoginCondition.fromCode(int.tryParse(parts[9].trim()) ?? 0);

    return LoginLog(
      logId: logId,
      userId: userId,
      userGrade: userGrade,
      programVersion: programVersion,
      customerId: customerId,
      customerName: customerName,
      loginDate: loginDate,
      loginDateYYYYMMDD: loginDateYYYYMMDD,
      lLoginIP: lLoginIP,
      loginCondition: loginCondition,
    );
  }
}

class LoginLogDAO extends DAO {
  static const String cn = 'LoginLogDAO';

  static const String SelectSql = '''
  ''';

  static const String WhereSqlLogId = '''
  ''';

  static const String InsertSql = '''
    INSERT INTO BM_LOGIN_LOG
      (USER_ID,USER_GRADE,PROGRAM_VERSION,CUST_ID,CUST_NAME,
       LOGIN_DATE,LOGIN_DATE_YYYYMMDD,LOGIN_IP,LOGIN_CONDITION,LOGIN_OUTER_IP)
		VALUES
		  (CONVERT(NVARCHAR(30), CONVERT(VARCHAR(30), CONVERT(VARBINARY(100), @userId, 1)) COLLATE ${DAO.CP949}),
       CONVERT(NVARCHAR(20), CONVERT(VARCHAR(20), CONVERT(VARBINARY(100), @userGrade, 1)) COLLATE ${DAO.CP949}),
       CONVERT(NVARCHAR(50), CONVERT(VARCHAR(50), CONVERT(VARBINARY(150), @programVersion, 1)) COLLATE ${DAO.CP949}),
       @customerId,
       CONVERT(NVARCHAR(50), CONVERT(VARCHAR(50), CONVERT(VARBINARY(150), @customerName, 1)) COLLATE ${DAO.CP949}),
       @loginDate,
       CONVERT(NVARCHAR(8), CONVERT(VARCHAR(8), CONVERT(VARBINARY(30), @loginDateYYYYMMDD, 1)) COLLATE ${DAO.CP949}),
       CONVERT(NVARCHAR(32), CONVERT(VARCHAR(32), CONVERT(VARBINARY(100), @loginIP, 1)) COLLATE ${DAO.CP949}),
       @loginCondition,
       CONVERT(VARCHAR(15), CONNECTIONPROPERTY('client_net_address')))
  ''';

  static Future<LoginLog?> getByLogId(int logId) async {
    const String fn = 'getByLogId';

    try {
			final res = await DbClient.instance.getDataWithParams(
				'$SelectSql $WhereSqlLogId', { 'logId': logId },
				timeout: const Duration(seconds: DAO.query_timeouts)
			);

      final base64Str = extractJsonDBResult(DAO.LINE_U16LE, res);

      if (base64Str.isEmpty) {
			  debugPrint('$cn.$fn: ${DAO.query_no_data}');
        return null;
      }

      return LoginLog.fromPipe(decodeUtf16LeFromBase64String(base64Str));
    }
    catch (e) {
      throw Exception('[$cn.$fn] $e');
    }
  }

  static Future<void> insertLoginLog({
    required String userId,
    required UserGrade userGrade,
    required int customerId,
    required String customerName,
    required LoginCondition loginCondition,
  }) async {
    const String fn = 'InsertLoginLog';
    debugPrint('$cn.$fn: $START');

    try {
      final now = DateTime.now();
      final localIp = await RGetIp.internalIP;
      final hexUserId = await stringToHexCp949(userId);
      final hexUserGrade = await stringToHexCp949(userGrade.label);
      final hexProgramVersion = await stringToHexCp949(appVersion);
      final hexCustomerName = await stringToHexCp949(customerName); 
      final loginDate = DateFormat('yyyy-MM-dd HH:mm:ss', appLocale).format(now);
      final hexLoginDateYYYYMMDD = await stringToHexCp949(DateFormat('yyyyMMdd', appLocale).format(now));
      final hexLoginIP = await stringToHexCp949(localIp!);

      await DbClient.instance.writeDataWithParams(
        InsertSql,
        {
          'userId': hexUserId,
          'userGrade': hexUserGrade,
          'programVersion': hexProgramVersion,
          'customerId': customerId,
          'customerName': hexCustomerName,
          'loginDate': loginDate,
          'loginDateYYYYMMDD': hexLoginDateYYYYMMDD,
          'loginIP': hexLoginIP,
          'loginCondition': loginCondition.code,
        },
        timeout: const Duration(seconds: DAO.query_timeouts)
      );

      debugPrint('$cn.$fn: $END');
    }
    catch (e) {
      debugPrint('$cn.$fn: $e');
      throw Exception('[$cn.$fn] $e');
    }
  }
}
