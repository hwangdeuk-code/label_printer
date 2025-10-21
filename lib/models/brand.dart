// UTF-8, 한국어 주석
// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:label_printer/database/db_client.dart';
import 'package:label_printer/database/db_result_utils.dart';
import 'dao.dart';

class Brand {
  static Brand? instance;

 	final int brandId;
  final int customerId;
	final String brandName;

  const Brand({
    required this.brandId,
    required this.customerId,
    required this.brandName,
  });

  static void setInstance(Brand? brand) {
    instance = brand;
  }

  factory Brand.fromPipe(String line) {
    final parts = line.split(DAO.SPLITTER);

    if (parts.length < 2) {
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

  @override
  String toString() =>
    'BrandId: $brandId, CustomerId: $customerId, BrandName: $brandName';
}

class BrandDAO extends DAO {
  static const String cn = 'BrandDAO';

  static const String SelectSql = '''
    SELECT
			CONVERT(VARBINARY(MAX),
			CONCAT_WS(N'${DAO.SPLITTER}',
        RICH_BRAND_ID,
        RICH_CUSTOMER_ID,
        CONVERT(NVARCHAR(50),RICH_BRAND_NAME COLLATE ${DAO.CP949})
			)) AS ${DAO.LINE_U16LE}
    FROM BM_RICH_BRAND
  ''';

  // WHERE 절: Customer ID로 조회 (Integer)
  static const String WhereSqlCustomerId = '''
	  WHERE RICH_CUSTOMER_ID=@customerId
  ''';

  static Future<Brand?> getByCustomerId(int customerId) async {
    const String fn = 'getByCustomerId';

    try {
			final res = await DbClient.instance.getDataWithParams(
				'$SelectSql $WhereSqlCustomerId', { 'customerId': customerId },
				timeout: const Duration(seconds: DAO.query_timeouts)
			);

      final base64Str = extractJsonDBResult(DAO.LINE_U16LE, res);

      if (base64Str.isEmpty) {
			  debugPrint('$cn.$fn: ${DAO.query_no_data}');
        return null;
      }

      return Brand.fromPipe(decodeUtf16LeFromBase64String(base64Str));
    }
    catch (e) {
      throw Exception('[$cn.$fn] $e');
    }
  }
}
