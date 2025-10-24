// UTF-8, 한국어 주석
// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:label_printer/core/app.dart';
import 'package:label_printer/database/db_client.dart';
import 'package:label_printer/database/db_result_utils.dart';
import 'dao.dart';

class Brand {
  static List<Brand>? datas;

  final int brandId;
  final int customerId;
  final String brandName;

  const Brand({
    required this.brandId,
    required this.customerId,
    required this.brandName,
  });

  static void setBrands(List<Brand>? values) {
    datas = values;
  }

  factory Brand.fromPipe(String line) {
    final parts = line.split(DAO.SPLITTER);

    if (parts.length < 3) {
      throw FormatException('${DAO.incorrect_format}: $line');
    }

    final brandId = int.tryParse(parts[0].trim()) ?? 0;
    final customerId = int.tryParse(parts[1].trim()) ?? 0;
    final brandName = parts[2].trim();

    return Brand(
      brandId: brandId,
      customerId: customerId,
      brandName: brandName,
    );
  }

  static List<Brand> fromPipeLines(List<String> lines) =>
      lines.map(Brand.fromPipe).toList();

  @override
  String toString() =>
      'BrandId: $brandId, CustomerId: $customerId, BrandName: $brandName';
}

class BrandDAO extends DAO {
  static const String cn = 'BrandDAO';

  static const String SelectSql =
      '''
    SELECT
			CONVERT(VARBINARY(300),
        CONCAT_WS(N'${DAO.SPLITTER}',
          COALESCE(CONVERT(NVARCHAR(20), RICH_BRAND_ID), N''),
          COALESCE(CONVERT(NVARCHAR(20), RICH_CUSTOMER_ID), N''),
          COALESCE(CONVERT(NVARCHAR(50), RICH_BRAND_NAME COLLATE ${DAO.CP949}), N'')
			)) AS ${DAO.LINE_U16LE}
    FROM BM_RICH_BRAND
  ''';

  // WHERE 절: Customer ID로 조회 (Integer)
  static const String WhereSqlCustomerId = '''
	  WHERE RICH_CUSTOMER_ID=@customerId
  ''';

  static const String OrderSqlByBrandrder = '''
	  ORDER BY RICH_BRAND_ORDER ASC
  ''';

  static Future<List<Brand>?> getByCustomerIdByBrandOrder(
    int customerId,
  ) async {
    const String fn = 'getByCustomerIdByBrandOrder';
    debugPrint('$cn.$fn: $START, customerId:$customerId');

    try {
      final res = await DbClient.instance.getDataWithParams(
        '$SelectSql $WhereSqlCustomerId $OrderSqlByBrandrder',
        {'customerId': customerId},
        timeout: const Duration(seconds: DAO.query_timeouts),
      );

      final base64Rows = extractJsonDBResults(DAO.LINE_U16LE, res);

      if (base64Rows.isEmpty) {
        debugPrint('$cn.$fn: ${DAO.query_no_data}');
        return null;
      }

      final lines = base64Rows
          .map(decodeUtf16LeFromBase64String)
          .where((line) => line.isNotEmpty)
          .toList();

      if (lines.isEmpty) {
        debugPrint('$cn.$fn: $END, decoded lines empty');
        return null;
      }

      debugPrint('$cn.$fn: $END');
      return Brand.fromPipeLines(lines);
    }
    catch (e) {
      debugPrint('$cn.$fn: $END, $e');
      throw Exception('[$cn.$fn] $e');
    }
  }
}
