// UTF-8 인코딩
// SQL 결과(JSON 문자열)에서 특정 컬럼의 값을 행 단위로 모아 하나의 문자열로 합치는 유틸리티

import 'dart:convert';
import 'dart:typed_data';

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
  try {
    final trimmed = jsonStr.trim();
    if (trimmed.isEmpty) return '';
    final decoded = jsonDecode(trimmed);

    // 1) sql_connection: 결과가 리스트 형태로 반환됨. 예) [{"COL":"..."}]
    if (decoded is List) {
      if (decoded.isEmpty) return '';
      final first = decoded.first;
      if (first is Map<String, dynamic>) {
        final v = first[columnName];
        return v?.toString() ?? '';
      }
      return '';
    }

    // 2) mssql_connection: { rows: [ {col: val} ], ... } 형태
    if (decoded is Map<String, dynamic>) {
      final rows = decoded['rows'];
      if (rows is List && rows.isNotEmpty) {
        final firstRow = rows.first;
        // 2-a) 행이 Map 형태
        if (firstRow is Map<String, dynamic>) {
          final v = firstRow[columnName];
          return v?.toString() ?? '';
        }
        // 2-b) 행이 List 형태이고 columns가 제공되는 경우(보조 지원)
        final columns = decoded['columns'];
        int? idx;
        if (columns is List && columns.isNotEmpty) {
          if (columns.first is Map) {
            // [{name: 'COL', ...}] 형태 지원
            for (var i = 0; i < columns.length; i++) {
              final c = columns[i];
              if (c is Map && c['name']?.toString() == columnName) {
                idx = i;
                break;
              }
            }
          } else if (columns.first is String) {
            idx = columns.indexOf(columnName);
          }
        }
        if (idx != null && firstRow is List && idx < firstRow.length) {
          final v = firstRow[idx];
          return v?.toString() ?? '';
        }
      }
    }

    return '';
  } catch (_) {
    return '';
  }
}

/// 문자열이 "[태그] 메시지" 형태일 때, 앞쪽의 대괄호로 감싼 태그(들)과 뒤따르는 공백을 제거하고 본문만 돌려줍니다.
/// - 예) "[INFO] TEST msg" -> "TEST msg"
/// - 예) "[A][B]   메시지" -> "메시지"
/// - 괄호가 없거나 포맷이 다르면 원본 문자열을 그대로 반환합니다.
String stripLeadingBracketTags(String s) {
  if (s.isEmpty) return s;

  var i = 0;
  final len = s.length;

  while (i < len && s.codeUnitAt(i) == 0x5B /* '[' */) {
    // 태그의 닫는 대괄호 위치를 찾는다
    final close = s.indexOf(']', i + 1);
    if (close == -1) break; // 잘못된 포맷 => 중단
    i = close + 1; // 닫는 괄호 다음으로 이동

    // 닫는 괄호 뒤에 하나의 공백을 선택적으로 허용 (여러 공백/탭도 스킵)
    while (i < len) {
      final c = s.codeUnitAt(i);
      if (c == 0x20 /* space */ || c == 0x09 /* tab */) {
        i++;
      } else {
        break;
      }
    }
  }

  // 앞에 태그가 하나 이상 있었으면 i가 0보다 큼
  return i > 0 ? s.substring(i) : s;
}
