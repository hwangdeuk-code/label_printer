// UTF-8 인코딩, 주석은 한국어
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../flutter_painter_v2/flutter_painter.dart';

/// 표 드로어블: 행/열 그리드 + 셀별 Quill Delta 저장/표시(간이)
class TableDrawable extends Sized2DDrawable {
  /// 표의 행/열 및 열 너비 비율 (final로 단일 정의)
  final int rows;
  final int columns;
  final List<double> columnFractions;

  /// 셀 별 Quill Delta(JSON) 및 간단 스타일 저장
  int? editingRow;
  int? editingCol;
  final Map<String, String> cellDeltaJson = {}; // key: "r,c"
  final Map<String, Map<String, dynamic>> cellStyles = {}; // key: "r,c" => {fontSize, bold, italic, align}

  TableDrawable({
    required this.rows,
    required this.columns,
    List<double>? columnFractions,
    required super.size,
    required super.position,
    super.rotationAngle = 0,
    super.scale = 1,
    super.assists,
    super.assistPaints,
    super.locked,
    super.hidden,
  }) : columnFractions = (columnFractions ?? const []) .isNotEmpty
        ? (columnFractions!)
        : (rows > 0 && columns > 0
            ? List<double>.filled(columns, 1.0 / columns)
            : <double>[]);

  
  // ===== 인라인 편집 표시(렌더링 제어용) =====
  void beginEdit(int row, int col) {
    editingRow = row;
    editingCol = col;
  }
  void endEdit() {
    editingRow = null;
    editingCol = null;
  }
// ===== 셀/스타일 헬퍼 =====

  /// 셀 키 유틸 ("r,c")
  String _k(int r, int c) => "$r,$c";

  /// 셀 스타일 조회(기본값 제공)
  Map<String, dynamic> styleOf(int r, int c) {
    final m = cellStyles[_k(r,c)] ?? const {};
    return {
      "fontSize": (m["fontSize"] ?? 12.0) as double,
      "bold": (m["bold"] ?? false) as bool,
      "italic": (m["italic"] ?? false) as bool,
      "align": (m["align"] ?? "left") as String,
    };
  }

  /// 셀 스타일 저장
  void setStyle(int r, int c, Map<String, dynamic> style) {
    cellStyles[_k(r,c)] = Map<String, dynamic>.from(style);
  }

  /// 셀 Delta 저장/조회 (Quill JSON)
  void setDeltaJson(int r, int c, String jsonStr) {
    cellDeltaJson[_k(r,c)] = jsonStr;
  }
  String? deltaJson(int r, int c) => cellDeltaJson[_k(r,c)];

  /// 로컬(자기 중심) 좌표계 기준 셀 사각형
  Rect localCellRect(int r, int c, Size scaledSize) {
    final rect = Rect.fromCenter(center: Offset.zero, width: scaledSize.width, height: scaledSize.height);
    final widths = <double>[];
    for (final f in columnFractions) {
      widths.add(rect.width * f);
    }
    final left = rect.left + widths.take(c).fold(0.0, (a,b)=>a+b);
    final right = left + (c < widths.length ? widths[c] : 0.0);
    final rowH = rows > 0 ? rect.height / rows : rect.height;
    final top = rect.top + r * rowH;
    final bottom = top + rowH;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Quill Delta(JSON) → 단순 텍스트 추출
  String _deltaToPlain(String jsonStr) {
    try {
      final obj = json.decode(jsonStr);
      final ops = obj["ops"] as List<dynamic>;
      final sb = StringBuffer();
      for (final op in ops) {
        final ins = (op as Map<String, dynamic>)["insert"];
        if (ins is String) sb.write(ins);
      }
      return sb.toString();
    } catch (_) {
      return jsonStr;
    }
  }

  
  /// 한글 주석: Quill Delta(JSON)를 TextSpan으로 변환 (bold/italic/size 지원)
  TextSpan _buildTextSpanFromDelta(String? jsonStr, {required double fallbackSize}) {
    if (jsonStr == null || jsonStr.isEmpty) {
      return const TextSpan(text: '');
    }
    try {
      final obj = json.decode(jsonStr);
      final List ops = (obj is List) ? obj : (obj is Map && obj['ops'] is List ? obj['ops'] as List : const []);
      final List<InlineSpan> children = [];
      for (final raw in ops) {
        if (raw is! Map) continue;
        final ins = raw['insert'];
        if (ins is! String) continue;
        final attrs = (raw['attributes'] is Map) ? (raw['attributes'] as Map) : const {};
        final bool isBold = attrs['bold'] == true;
        final bool isItalic = attrs['italic'] == true;
        final String? sizeStr = attrs['size'] is String ? attrs['size'] as String : null;
        double fontSize = fallbackSize;
        if (sizeStr != null) {
          final parsed = double.tryParse(sizeStr);
          if (parsed != null && parsed > 0) fontSize = parsed;
        }
        children.add(TextSpan(
          text: ins,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            color: Colors.black,
          ),
        ));
      }
      return TextSpan(children: children);
    } catch (_) {
      return const TextSpan(text: '');
    }
  }

  // ===== 필수 구현 =====

  /// 실제 그리기(회전/이동은 상위 ObjectDrawable.draw에서 처리됨)
  @override
  void drawObject(Canvas canvas, Size _) {
    // 1) 그리드 라인
    final rect = Rect.fromCenter(center: position, width: size.width, height: size.height);
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black;

    // 외곽
    canvas.drawRect(rect, gridPaint);

    if (rows > 1) {
      final rowH = size.height / rows;
      for (int r = 1; r < rows; r++) {
        final y = rect.top + r * rowH;
        canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
      }
    }

    if (columns > 1) {
      // 열 분할: columnFractions 비율 기반
      final totalW = size.width;
      double acc = rect.left;
      for (int c = 0; c < columns - 1; c++) {
        final frac = c < columnFractions.length ? columnFractions[c] : (1.0 / columns);
        final w = totalW * frac;
        acc += w;
        canvas.drawLine(Offset(acc, rect.top), Offset(acc, rect.bottom), gridPaint);
      }
    }

    // 2) 셀 텍스트 간이 렌더
    if (rows <= 0 || columns <= 0) return;
    final scaledSize = size; // scale은 상위에서 좌표계에 이미 반영됨
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        // 편집 중인 셀은 캔버스 페인트를 생략 (에디터 위젯이 표시됨)
        if (editingRow != null && editingCol != null && r == editingRow && c == editingCol) {
          continue;
        }
        final jsonStr = deltaJson(r, c);
        if (jsonStr == null || jsonStr.isEmpty) continue;

        final plain = _deltaToPlain(jsonStr);
        final st = styleOf(r, c);
        final fs = (st["fontSize"] as double);
        final bold = (st["bold"] as bool);
        final italic = (st["italic"] as bool);
        final alignStr = (st["align"] as String);

        final cellLocal = localCellRect(r, c, scaledSize);
        // localCellRect는 로컬(중심 기준) → 월드로 보정
        final cellWorld = cellLocal.shift(position);

        // === B안 적용: 캔버스에 직접 텍스트 페인트 ===


        final align = (alignStr == 'center')


            ? TextAlign.center


            : (alignStr == 'right' ? TextAlign.right : TextAlign.left);


        final span = _buildTextSpanFromDelta(jsonStr, fallbackSize: fs);


        final tp = TextPainter(


          text: span,


          textAlign: align,


          textDirection: TextDirection.ltr,


          maxLines: null,


        );


        tp.layout(maxWidth: cellWorld.width);


        double dx = cellWorld.left;


        if (align == TextAlign.center) {


          dx = cellWorld.left + (cellWorld.width - tp.width) / 2.0;


        } else if (align == TextAlign.right) {


          dx = cellWorld.right - tp.width;


        }


        canvas.save();


        canvas.clipRect(cellWorld);


        tp.paint(canvas, Offset(dx, cellWorld.top));


        canvas.restore();
}
    }
  }

  /// 표 드로어블 복사 (필수 시그니처 + 확장 파라미터)
  @override
  TableDrawable copyWith({
    bool? hidden,
    Set<ObjectDrawableAssist>? assists,
    Offset? position,
    double? rotation,
    double? scale,
    Size? size,
    bool? locked,
    // 확장: 표 전용 필드
    int? rows,
    int? columns,
    List<double>? columnFractions,
    Map<ObjectDrawableAssist, Paint>? assistPaints,
    Map<String, String>? cellDeltaJson,
    Map<String, Map<String, dynamic>>? cellStyles,
  }) {
    final next = TableDrawable(
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
      columnFractions: columnFractions ?? this.columnFractions,
      size: size ?? this.size,
      position: position ?? this.position,
      rotationAngle: rotation ?? rotationAngle,
      scale: scale ?? this.scale,
      assists: assists ?? this.assists,
      assistPaints: assistPaints ?? this.assistPaints,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
    );
    // 셀 데이터는 얕은 복사(내용 유지)
    next.cellDeltaJson.addAll(cellDeltaJson ?? this.cellDeltaJson);
    next.cellStyles.addAll(cellStyles ?? this.cellStyles);
    next.editingRow = editingRow;
    next.editingCol = editingCol;
    return next;
  }
}
