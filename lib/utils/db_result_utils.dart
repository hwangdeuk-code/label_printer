// UTF-8 인코딩
// SQL 결과(JSON 문자열)에서 특정 컬럼의 값을 행 단위로 모아 하나의 문자열로 합치는 유틸리티

import 'dart:convert';
import 'dart:typed_data';

// 탭을 공백으로 확장하는 유틸 (고정 탭폭: 4)
String expandTabs(String s, {int tabSize = 4}) {
  final sb = StringBuffer();
  int col = 0;

  for (int i = 0; i < s.length; i++) {
    final ch = s[i];

    if (ch == '\n') {
      sb.write('\n');
      col = 0;
    }
    else if (ch == '\r') {
      // 무시하거나 그대로 출력
    }
    else if (ch == '\t') {
      final spaces = tabSize - (col % tabSize);
      sb.write(' ' * spaces);
      col += spaces;
    }
    else {
      sb.write(ch);
      col += 1;
    }
  }

  return sb.toString();
}

String extractJsonDBResult(String columnName, String jsonStr) {
  final map = jsonDecode(jsonStr) as Map<String, dynamic>;
  final rows = (map['rows'] as List);
  if (rows.isEmpty) return '';
  final firstRow = rows.first as Map<String, dynamic>;
  return firstRow[columnName] as String; // ← Base64 문자열
}

// Base64 문자열을 UTF-16LE로 디코드 (드라이버가 VARBINARY를 Base64로 직렬화한 경우 대비)
String decodeUtf16LeFromBase64String(String b64) {
  try {
    final bytes = base64.decode(b64);
    return decodeUtf16Le(Uint8List.fromList(bytes));
  }
  catch (_) {
    return '';
  }
}

// UTF-16LE 바이트 -> String (BOM 처리)
String decodeUtf16Le(Uint8List bytes) {
  if (bytes.isEmpty) return '';
  int offset = 0;

  if (bytes.length >= 2) {
    // BOM: FF FE (LE)
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      offset = 2;
    }
  }

  final bd = ByteData.sublistView(bytes, offset);
  final codeUnits = List<int>.generate(bd.lengthInBytes ~/ 2, (i) => bd.getUint16(i * 2, Endian.little));
  return String.fromCharCodes(codeUnits);
}
