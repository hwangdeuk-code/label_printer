// UTF-8, 한국어 주석
// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:label_printer/database/db_client.dart';
import 'package:label_printer/database/db_result_utils.dart';
import 'dao.dart';

enum CooperatorGrade {
	COOP_GRADE_SYS_ADMIN(0),
	COOP_GRADE_COOP_MANAGER(1);

  final int code;
  const CooperatorGrade(this.code);
  static CooperatorGrade fromCode(int code) => CooperatorGrade.values.firstWhere((e) => e.code == code);

  String get label {
    switch (this) {
      case CooperatorGrade.COOP_GRADE_SYS_ADMIN:
        return '시스템 관리자';
      case CooperatorGrade.COOP_GRADE_COOP_MANAGER:
        return '협력업체 책임자';
    }
  }
}

class Cooperator {
  static Cooperator? instance;

	final String id;
	final String name;

  const Cooperator({
    required this.id,
    required this.name,
  });

  static void setInstance(Cooperator? cooperator) {
    instance = cooperator;
  }

  factory Cooperator.fromPipe(String line) {
    final parts = line.split(DAO.SPLITTER);

    if (parts.length < 2) {
      throw FormatException('${DAO.incorrect_format}: $line');
    }

    final id = parts[0].trim();
    final name = parts[1].trim();

    return Cooperator(
      id: id,
      name: name,
    );
  }

  @override
  String toString() => 'CooperatorId: $id, Name: $name';
}

class CooperatorDAO extends DAO {
  static const String cn = 'CooperatorDAO';

  static const String SelectSql = '''
    SELECT
			CONVERT(VARBINARY(100),
			CONCAT_WS(N'${DAO.SPLITTER}',
        CONVERT(NVARCHAR(30),RICH_COOP_ID COLLATE ${DAO.CP949}),
        CONVERT(NVARCHAR(30),RICH_NAME COLLATE ${DAO.CP949})
			)) AS ${DAO.LINE_U16LE}
    FROM BM_COOPERATOR
  ''';

  static const String WhereSqlCooperatorId = '''
    WHERE LTRIM(RTRIM(CONVERT(NVARCHAR(30),RICH_COOP_ID COLLATE ${DAO.CP949}))) =
          LTRIM(RTRIM(CONVERT(NVARCHAR(30),@cooperatorId)))
  ''';

  static Future<Cooperator?> getByCooperatorId(String cooperatorId) async {
    const String fn = 'getByCooperatorId';

    try {
			final res = await DbClient.instance.getDataWithParams(
				'$SelectSql $WhereSqlCooperatorId', { 'cooperatorId': cooperatorId },
				timeout: const Duration(seconds: DAO.query_timeouts)
			);

      final base64Str = extractJsonDBResult(DAO.LINE_U16LE, res);

      if (base64Str.isEmpty) {
			  debugPrint('$cn.$fn, ${DAO.query_no_data}');
        return null;
      }

      return Cooperator.fromPipe(decodeUtf16LeFromBase64String(base64Str));
    }
    catch (e) {
      throw Exception('[$cn.$fn] $e');
    }
  }
}
