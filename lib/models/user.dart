// UTF-8, 한국어 주석
// ignore_for_file: constant_Identifier_names, non_constant_Identifier_names

import 'package:flutter/material.dart';
import 'package:label_printer/database/db_client.dart';
import 'package:label_printer/database/db_result_utils.dart';
import 'dao.dart';

enum UserGrade {
	SYSTEM_ADMIN_USER(0),
	COOP_ADMIN_USER(1),
	MANAGER_USER(2),
	CLIENT_USER(3);

  final int code;
  const UserGrade(this.code);
  static UserGrade fromCode(int code) => UserGrade.values.firstWhere((e) => e.code == code);
}

class User {
  static const String SYSTEM = 'SYSTEM';
  
	final String userId;
	final int marketId;
	final String name;
	final String pwd;
	final UserGrade grade;
	final String marketName;
	final String customerName;

  const User({
    required this.userId,
    required this.marketId,
    required this.name,
    required this.pwd,
    required this.grade,
    required this.marketName,
    required this.customerName,
  });

  factory User.fromPipe(String line) {
    final parts = line.split(DAO.SPLITTER);

    if (parts.length < 2) {
      throw FormatException('${DAO.incorrect_format}: $line');
    }

    final userId = parts[0].trim();
    final marketId = int.tryParse(parts[1].trim()) ?? 0;
    final name = parts[2].trim();
    final pwd = parts[3].trim();
    final grade = UserGrade.fromCode(int.tryParse(parts[4].trim()) ?? 0);
    final marketName = parts[5].trim();
    final customerName = parts[6].trim();

    return User(
      userId: userId,
      marketId: marketId,
      name: name,
      pwd: pwd,
      grade: grade,
      marketName: marketName,
      customerName: customerName,
    );
  }

  @override
  String toString() =>
    '$userId ($name), MarketId: $marketId, Grade: $grade, Market: $marketName, Customer: $customerName';
}

class UserDAO extends DAO {
  static const String cn = 'UserDAO';

  static const String SelectSql = '''
    SELECT
			CONVERT(VARBINARY(1000),
			CONCAT_WS(N'${DAO.SPLITTER}',
				CONVERT(NVARCHAR(30),P1.RICH_USER_ID COLLATE ${DAO.CP949}),
				P1.RICH_MARKET_ID,
				CONVERT(NVARCHAR(50),P1.RICH_NAME COLLATE ${DAO.CP949}),
				CONVERT(NVARCHAR(20),P1.RICH_PWD COLLATE ${DAO.CP949}),
				P1.RICH_USER_GRADE,
				CONVERT(NVARCHAR(50),P2.RICH_NAME COLLATE ${DAO.CP949}),
				CONVERT(NVARCHAR(50),P3.RICH_NAME COLLATE ${DAO.CP949})
			)) AS ${DAO.LINE_U16LE}
		FROM
      BM_USER P1
      INNER JOIN BM_MARKET P2
      ON P1.RICH_MARKET_ID=P2.RICH_MARKET_ID
      INNER JOIN BM_CUSTOMER P3
      ON P2.RICH_CUSTOMER_ID=P3.RICH_CUSTOMER_ID
      INNER JOIN BM_COOPERATOR P4
      ON P3.RICH_COOP_ID=P4.RICH_COOP_ID
  ''';

  static const String WhereSqlUserId = '''
    WHERE LTRIM(RTRIM(CONVERT(NVARCHAR(30),P1.RICH_USER_ID COLLATE ${DAO.CP949}))) =
          LTRIM(RTRIM(CONVERT(NVARCHAR(30),@userId)))
  ''';

  static Future<User?> getByUserId(String userId) async {
    const String fn = 'getByUserId';

    try {
			final res = await DbClient.instance.getDataWithParams(
				'$SelectSql $WhereSqlUserId', { 'userId': userId },
				timeout: const Duration(seconds: DAO.query_timeouts)
			);

      final base64Str = extractJsonDBResult(DAO.LINE_U16LE, res);

      if (base64Str.isEmpty) {
			  debugPrint('$cn.$fn, ${DAO.query_no_data}');
        return null;
      }

      return User.fromPipe(decodeUtf16LeFromBase64String(base64Str));
    }
    catch (e) {
      throw Exception('[$cn.$fn] $e');
    }
  }
}
