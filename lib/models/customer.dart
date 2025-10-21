// UTF-8, 한국어 주석
// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:label_printer/database/db_client.dart';
import 'package:label_printer/database/db_result_utils.dart';
import 'dao.dart';

class Customer {
  static Customer? instance;

  final int customerId;
  final String cooperatorId;
	final String customerName;

  const Customer({
    required this.customerId,
    required this.cooperatorId,
    required this.customerName,
  });

  static void setInstance(Customer? customer) {
    instance = customer;
  }

  factory Customer.fromPipe(String line) {
    final parts = line.split(DAO.SPLITTER);

    if (parts.length < 2) {
      throw FormatException('${DAO.incorrect_format}: $line');
    }

    final customerId = int.tryParse(parts[0].trim()) ?? 0;
    final cooperatorId = parts[1].trim();
    final customerName = parts[2].trim();

    return Customer(
      customerId: customerId,
      cooperatorId: cooperatorId,
      customerName: customerName,
    );
  }

  @override
  String toString() =>
    'CustomerId: $customerId, CoopId: $cooperatorId, CustomerName: $customerName';
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

  // WHERE 절: Customer ID로 조회 (Integer)
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
			  debugPrint('$cn.$fn: ${DAO.query_no_data}');
        return null;
      }
  
      return Customer.fromPipe(decodeUtf16LeFromBase64String(base64Str));
    }
    catch (e) {
      throw Exception('[$cn.$fn] $e');
    }
  }
}
