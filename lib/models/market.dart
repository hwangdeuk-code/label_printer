// UTF-8, 한국어 주석
// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:label_printer/core/app.dart';
import 'package:label_printer/database/db_client.dart';
import 'package:label_printer/database/db_result_utils.dart';
import 'dao.dart';

class Market {
  static Market? instance;

 	final int marketId;
  final int customerId;
	final String name;

  const Market({
    required this.marketId,
    required this.customerId,
    required this.name,
  });

  static void setInstance(Market? market) {
    instance = market;
  }

  factory Market.fromPipe(String line) {
    final parts = line.split(DAO.SPLITTER);

    if (parts.length < 2) {
      throw FormatException('${DAO.incorrect_format}: $line');
    }

    final marketId = int.tryParse(parts[0].trim()) ?? 0;
    final customerId = int.tryParse(parts[1].trim()) ?? 0;
    final name = parts[2].trim();

    return Market(
      marketId: marketId,
      customerId: customerId,
      name: name,
    );
  }

  @override
  String toString() =>
    'MarketId: $marketId, CustomerId: $customerId, Name: $name';
}

class MarketDAO extends DAO {
  static const String cn = 'MarketDAO';

  static const String SelectSql = '''
    SELECT
			CONVERT(VARBINARY(300),
			CONCAT_WS(N'${DAO.SPLITTER}',
        RICH_MARKET_ID,
        RICH_CUSTOMER_ID,
        CONVERT(NVARCHAR(50),RICH_NAME COLLATE ${DAO.CP949}),
        CONVERT(NVARCHAR(20),RICH_ETC COLLATE ${DAO.CP949})
			)) AS ${DAO.LINE_U16LE}
    FROM BM_MARKET
  ''';

  // WHERE 절: Market ID로 조회 (Integer)
  static const String WhereSqlMarketId = '''
	  WHERE RICH_MARKET_ID=@marketId
  ''';

  static Future<Market?> getByMarketId(int marketId) async {
    const String fn = 'getByMarketId';
    debugPrint('$cn.$fn: $START, marketId:$marketId');

    try {
			final res = await DbClient.instance.getDataWithParams(
				'$SelectSql $WhereSqlMarketId', { 'marketId': marketId },
				timeout: const Duration(seconds: DAO.query_timeouts)
			);

      final base64Str = extractJsonDBResult(DAO.LINE_U16LE, res);

      if (base64Str.isEmpty) {
			  debugPrint('$cn.$fn: $END, ${DAO.query_no_data}');
        return null;
      }

      debugPrint('$cn.$fn: $END');
      return Market.fromPipe(decodeUtf16LeFromBase64String(base64Str));
    }
    catch (e) {
      debugPrint('$cn.$fn: $e');
      throw Exception('[$cn.$fn] $e');
    }
  }
}
