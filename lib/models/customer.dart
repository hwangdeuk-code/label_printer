// UTF-8, 한국어 주석
// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:label_printer/utils/db_result_utils.dart';
import 'package:label_printer/database/db_client.dart';
import 'dao.dart';

class Customer {
  final int customerId;
  final String coopId;
	final String name;

  const Customer({
    required this.customerId,
    required this.coopId,
    required this.name,
  });

  factory Customer.fromPipe(String line) {
    final parts = line.split(DAO.SPLITTER);

    if (parts.length < 2) {
      throw FormatException('${DAO.incorrect_format}: $line');
    }

    final customerId = int.tryParse(parts[0].trim()) ?? 0;
    final coopId = parts[1].trim();
    final name = parts[2].trim();

    return Customer(
      customerId: customerId,
      coopId: coopId,
      name: name,
    );
  }

  @override
  String toString() =>
    'CustomerId: $customerId, CoopId: $coopId, Name: $name';
}

class CustomerDAO extends DAO {
  static const String cn = 'CustomerDAO';

  static const String SelectSql = '''
		SELECT
			CONVERT(VARBINARY(300),
			CONCAT_WS(N'${DAO.SPLITTER}',
        RICH_CUSTOMER_ID,
        CONVERT(NVARCHAR(30),RICH_COOP_ID COLLATE ${DAO.CP949}),
        CONVERT(NVARCHAR(50),RICH_NAME COLLATE ${DAO.CP949})
			)) AS ${DAO.LINE_U16LE}
		FROM BM_CUSTOMER
  ''';

  static const String WhereSqlCustomerId = '''
	  WHERE RICH_CUSTOMER_ID=@customerId
  ''';

  static Future<Customer?> getByCustomerId(int customerId) async {
    const String fn = 'getByCustomerId';

    try {
			final res = await DbClient.instance.getDataWithParams(
				'$SelectSql $WhereSqlCustomerId', { 'customerId': customerId },
				timeout: const Duration(seconds: DAO.query_timeouts)
			);

      final base64Str = extractJsonDBResult(DAO.LINE_U16LE, res);

      if (base64Str.isEmpty) {
			  debugPrint('$cn.$fn, ${DAO.query_no_data}');
        return null;
      }
  
      return Customer.fromPipe(decodeUtf16LeFromBase64String(base64Str));
    }
    catch (e) {
      throw Exception('[$cn.$fn] $e');
    }
  }
}
