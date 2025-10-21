// UTF-8, 한국어 주석
// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:label_printer/models/dao.dart';
import 'package:label_printer/database/db_client.dart';
import 'package:label_printer/database/db_result_utils.dart';

class NoticeDAO extends DAO {
  static const String cn = 'NoticeDAO';
  static const String Sql = '''
    SELECT
      CONVERT(VARBINARY(6000),
      CONVERT(NVARCHAR(3000),UN_MSG COLLATE ${DAO.CP949})) AS ${DAO.LINE_U16LE}
    FROM
      BM_UPDATE_NOTICE
    WHERE
      LTRIM(RTRIM(CONVERT(NVARCHAR(30),UN_USER_ID COLLATE ${DAO.CP949}))) =
      LTRIM(RTRIM(CONVERT(NVARCHAR(30),@userId)));
  ''';

  static Future<String> getByUserId(String userId) async {
    const String fn = 'getByUserId';

    try {
			final res = await DbClient.instance.getDataWithParams(
				Sql, { 'userId': userId }, timeout: const Duration(seconds: DAO.query_timeouts)
			);

      final base64Str = extractJsonDBResult(DAO.LINE_U16LE, res);

      if (base64Str.isEmpty) {
			  debugPrint('$cn.$fn: ${DAO.query_no_data}');
        return '';
      }

      return decodeUtf16LeFromBase64String(base64Str);
    }
    catch (e) {
      throw Exception('[$cn.$fn] $e');
    }
  }
}
