// UTF-8, 한국어 주석
// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:label_printer/core/app.dart';
import 'package:label_printer/database/db_client.dart';
import 'package:label_printer/database/db_result_utils.dart';
import 'dao.dart';
import 'date_manager.dart';

class LabelSizeCommon {
  final int width;
  final int height;
  final String rtf;

  const LabelSizeCommon({
    required this.width,
    required this.height,
    required this.rtf,
  });

  @override
  String toString() => 'Width: $width, Height: $height, RTF: $rtf';
}

class LabelSizeSetup {
	final bool readOnly;
	final bool useMakeDate;
	final bool useMakeTime;
	final bool useValidDate;
	final bool useValidTime;
	final PrintDateFormat makingDateFormat;
	final PrintTimeFormat makingTimeFormat;
	final PrintDateFormat validDateFormat;
	final PrintTimeFormat validTimeFormat;
	final String strMakeDate;
	final String strMakeTime;
	final String strValidDate;
	final String strValidTime;

	// 저울
	final bool useScale;

  const LabelSizeSetup({
    required this.readOnly,
    required this.useMakeDate,
    required this.useMakeTime,
    required this.useValidDate,
    required this.useValidTime,
    required this.makingDateFormat,
    required this.makingTimeFormat,
    required this.validDateFormat,
    required this.validTimeFormat,
    required this.strMakeDate,
    required this.strMakeTime,
    required this.strValidDate,
    required this.strValidTime,
    required this.useScale,
  });

  @override
  String toString() => 'ReadOnly: $readOnly, '
    'UseMakeDate: $useMakeDate, UseMakeTime: $useMakeTime, '
    'UseValidDate: $useValidDate, UseValidTime: $useValidTime, '
    'MakingDateFormat: $makingDateFormat, MakingTimeFormat: $makingTimeFormat, '
    'ValidDateFormat: $validDateFormat, ValidTimeFormat: $validTimeFormat, '
    'StrMakeDate: $strMakeDate, StrMakeTime: $strMakeTime, '
    'StrValidDate: $strValidDate, StrValidTime: $strValidTime, UseScale: $useScale';
}

class LabelSize {
  static List<LabelSize>? datas;

  final int labelSizeId;
  final int brandId;
  final String labelSizeName;
  final LabelSizeCommon? labelSizeCommon;
  final LabelSizeSetup? labelSizeSetup;

  const LabelSize({
    required this.labelSizeId,
    required this.brandId,
    required this.labelSizeName,
    this.labelSizeCommon,
    this.labelSizeSetup,
  });

  static void setLabelSizes(List<LabelSize>? values) {
    datas = values;
  }

  factory LabelSize.fromPipe(String line) {
    final parts = line.split(DAO.SPLITTER);

    if (parts.length < 3) {
      throw FormatException('${DAO.incorrect_format}: $line');
    }

    int col = 0;
    final labelSizeId = int.tryParse(parts[col++].trim()) ?? 0;
    final brandId = int.tryParse(parts[col++].trim()) ?? 0;
    final labelSizeName = parts[col++].trim();

    final labelSizeCommon = LabelSizeCommon(
      width: int.tryParse(parts[col++].trim()) ?? 0,
      height: int.tryParse(parts[col++].trim()) ?? 0,
      rtf: parts[col++].trim(),
    );  

    final labelSizeSetup = LabelSizeSetup(
      readOnly: (int.tryParse(parts[col++].trim()) ?? 0) != 0,
      useMakeDate: (int.tryParse(parts[col++].trim()) ?? 0) != 0,
      useMakeTime: (int.tryParse(parts[col++].trim()) ?? 0) != 0,
      useValidDate: (int.tryParse(parts[col++].trim()) ?? 0) != 0,
      useValidTime: (int.tryParse(parts[col++].trim()) ?? 0) != 0,
      makingDateFormat: PrintDateFormat.values[int.tryParse(parts[col++].trim()) ?? 0],
      makingTimeFormat: PrintTimeFormat.values[int.tryParse(parts[col++].trim()) ?? 0],
      validDateFormat: PrintDateFormat.values[int.tryParse(parts[col++].trim()) ?? 0],
      validTimeFormat: PrintTimeFormat.values[int.tryParse(parts[col++].trim()) ?? 0],
      strMakeDate: parts[col++].trim(),
      strMakeTime: parts[col++].trim(),
      strValidDate: parts[col++].trim(),
      strValidTime: parts[col++].trim(),
      useScale: (int.tryParse(parts[col++].trim()) ?? 0) != 0,
    );

    return LabelSize(
      labelSizeId: labelSizeId,
      brandId: brandId,
      labelSizeName: labelSizeName,
      labelSizeCommon: labelSizeCommon,
      labelSizeSetup: labelSizeSetup,
    );
  }

  static List<LabelSize> fromPipeLines(List<String> lines) =>
      lines.map(LabelSize.fromPipe).toList();

  @override
  String toString() =>
    'LabelSizeId: $labelSizeId, BrandId: $brandId, LabelSizeName: $labelSizeName';
}

class LabelSizeDAO extends DAO {
  static const String cn = 'LabelSizeDAO';

  static const String SelectSql = '''
    SELECT
      CONVERT(VARBINARY(MAX),
        CONCAT_WS(N'${DAO.SPLITTER}',
          COALESCE(CONVERT(NVARCHAR(50), RICH_LABELSIZE_ID), N''),
          COALESCE(CONVERT(NVARCHAR(50), RICH_BRAND_ID), N''),
          COALESCE(CONVERT(NVARCHAR(50), RICH_LABELSIZE_NAME COLLATE ${DAO.CP949}), N''),
          COALESCE(CONVERT(NVARCHAR(50), RICH_FORM_WIDTH), N''),
          COALESCE(CONVERT(NVARCHAR(50), RICH_FORM_HEIGHT), N''),
          COALESCE(CONVERT(NVARCHAR(MAX), RICH_FORM_DATA COLLATE ${DAO.CP949}), N''),
          COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_READONLY), N''),
          COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_USE_MAKEDATE), N''),
          COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_USE_MAKETIME), N''),
          COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_USE_VALIDDATE), N''),
          COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_USE_VALIDTIME), N''),
          COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_MAKEDATE_TYPE), N''),
          COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_MAKETIME_TYPE), N''),
          COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_VALIDDATE_TYPE), N''),
          COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_VALIDTIME_TYPE), N''),
          COALESCE(CONVERT(NVARCHAR(50), RICH_USER_MAKEDATE COLLATE ${DAO.CP949}), N''),
          COALESCE(CONVERT(NVARCHAR(50), RICH_USER_MAKETIME COLLATE ${DAO.CP949}), N''),
          COALESCE(CONVERT(NVARCHAR(50), RICH_USER_VALIDDATE COLLATE ${DAO.CP949}), N''),
          COALESCE(CONVERT(NVARCHAR(50), RICH_USER_VALIDTIME COLLATE ${DAO.CP949}), N''),
          COALESCE(CONVERT(NVARCHAR(10), RICH_SETUP_USE_SCALE), N'')
      )) AS ${DAO.LINE_U16LE}
    FROM BM_RICH_LABELSIZE_FORM
  ''';

  // WHERE 절: Brand ID로 조회 (Integer)
  static const String WhereSqlBrandId = '''
	  WHERE RICH_BRAND_ID=@brandId
  ''';

  static const String OrderSqlByLabelSize = '''
	  ORDER BY RICH_LABELSIZE_ORDER ASC
  ''';

  static Future<List<LabelSize>?> getByBrandIdByLabelSizeOrder(int brandId) async {
    const String fn = 'getByBrandIdByLabelSizeOrder';
    debugPrint('$cn.$fn: $START, brandId:$brandId');

    try {
      final res = await DbClient.instance.getDataWithParams(
        '$SelectSql $WhereSqlBrandId $OrderSqlByLabelSize',
        {'brandId': brandId},
        timeout: const Duration(seconds: DAO.query_timeouts),
      );

      final base64Rows = extractJsonDBResults(DAO.LINE_U16LE, res);

      if (base64Rows.isEmpty) {
        debugPrint('$cn.$fn: $END, ${DAO.query_no_data}');
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

      return LabelSize.fromPipeLines(lines);
    }
    catch (e) {
      debugPrint('$cn.$fn: $END, $e');
      throw Exception('[$cn.$fn] $e');
    }
  }
}
