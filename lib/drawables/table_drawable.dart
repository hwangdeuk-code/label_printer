// UTF-8 인코딩, 주석은 한국어
import 'dart:convert';

import 'package:flutter/material.dart';

import '../flutter_painter_v2/flutter_painter.dart';

class CellMergeSpan {
  final int rowSpan;
  final int colSpan;

  const CellMergeSpan({required this.rowSpan, required this.colSpan});
}

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
  final Map<String, Map<String, dynamic>> cellStyles =
      {}; // key: "r,c" => {fontSize, bold, italic, align}
  final Map<String, CellMergeSpan> mergedSpans = {};
  final Map<String, String> mergedParents = {}; // child -> root key

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
  }) : columnFractions = (columnFractions ?? const []).isNotEmpty
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
    final m = cellStyles[_k(r, c)] ?? const {};
    return {
      "fontSize": (m["fontSize"] ?? 12.0) as double,
      "bold": (m["bold"] ?? false) as bool,
      "italic": (m["italic"] ?? false) as bool,
      "align": (m["align"] ?? "left") as String,
    };
  }

  /// 셀 스타일 저장
  void setStyle(int r, int c, Map<String, dynamic> style) {
    cellStyles[_k(r, c)] = Map<String, dynamic>.from(style);
  }

  /// 셀 Delta 저장/조회 (Quill JSON)
  void setDeltaJson(int r, int c, String jsonStr) {
    cellDeltaJson[_k(r, c)] = jsonStr;
  }

  String? deltaJson(int r, int c) => cellDeltaJson[_k(r, c)];

  bool isMergeRoot(int r, int c) => mergedSpans.containsKey(_k(r, c));

  bool isMergeChild(int r, int c) => mergedParents.containsKey(_k(r, c));

  CellMergeSpan? spanForRoot(int r, int c) => mergedSpans[_k(r, c)];

  String _rootKeyFor(int r, int c) {
    final key = _k(r, c);
    return mergedParents[key] ?? key;
  }

  (int, int) resolveRoot(int r, int c) {
    final rootKey = _rootKeyFor(r, c);
    if (!mergedSpans.containsKey(rootKey) && _k(r, c) == rootKey) {
      return (r, c);
    }
    return (_rowFromKey(rootKey), _colFromKey(rootKey));
  }

  CellMergeSpan? spanForCell(int r, int c) {
    final root = resolveRoot(r, c);
    return spanForRoot(root.$1, root.$2);
  }

  bool canMergeRegion(int topRow, int leftCol, int bottomRow, int rightCol) {
    if (topRow < 0 || leftCol < 0 || bottomRow >= rows || rightCol >= columns) {
      return false;
    }
    final rowSpan = bottomRow - topRow + 1;
    final colSpan = rightCol - leftCol + 1;
    if (rowSpan <= 1 && colSpan <= 1) return false;

    for (int r = topRow; r <= bottomRow; r++) {
      for (int c = leftCol; c <= rightCol; c++) {
        final key = _k(r, c);
        if (mergedParents.containsKey(key)) return false;
        final span = mergedSpans[key];
        if (span != null) {
          // 이미 다른 병합 루트가 포함됨
          return false;
        }
      }
    }
    return true;
  }

  bool mergeRegion(int topRow, int leftCol, int bottomRow, int rightCol) {
    if (!canMergeRegion(topRow, leftCol, bottomRow, rightCol)) return false;
    final rowSpan = bottomRow - topRow + 1;
    final colSpan = rightCol - leftCol + 1;
    final rootKey = _k(topRow, leftCol);
    mergedSpans[rootKey] = CellMergeSpan(rowSpan: rowSpan, colSpan: colSpan);
    for (int r = topRow; r <= bottomRow; r++) {
      for (int c = leftCol; c <= rightCol; c++) {
        final key = _k(r, c);
        if (key == rootKey) continue;
        mergedParents[key] = rootKey;
      }
    }
    return true;
  }

  bool canUnmergeAt(int row, int col) {
    final root = resolveRoot(row, col);
    final span = spanForRoot(root.$1, root.$2);
    return span != null && (span.rowSpan > 1 || span.colSpan > 1);
  }

  bool unmergeAt(int row, int col) {
    final root = resolveRoot(row, col);
    final rootKey = _k(root.$1, root.$2);
    final span = mergedSpans[rootKey];
    if (span == null) return false;
    for (int r = root.$1; r < root.$1 + span.rowSpan; r++) {
      for (int c = root.$2; c < root.$2 + span.colSpan; c++) {
        mergedParents.remove(_k(r, c));
      }
    }
    mergedSpans.remove(rootKey);
    return true;
  }

  Rect mergedLocalRect(int row, int col, Size scaledSize) {
    final span = spanForCell(row, col);
    final root = resolveRoot(row, col);
    final topLeft = localCellRect(root.$1, root.$2, scaledSize);
    if (span == null) {
      return topLeft;
    }
    final bottomRight = localCellRect(
      root.$1 + span.rowSpan - 1,
      root.$2 + span.colSpan - 1,
      scaledSize,
    );
    return Rect.fromLTRB(
      topLeft.left,
      topLeft.top,
      bottomRight.right,
      bottomRight.bottom,
    );
  }

  Rect mergedWorldRect(int row, int col, Size scaledSize) {
    return mergedLocalRect(row, col, scaledSize).shift(position);
  }

  bool _spansHorizontalBoundary(int rowBoundary, int col) {
    if (rowBoundary <= 0 || rowBoundary >= rows) return false;
    final topRoot = resolveRoot(rowBoundary - 1, col);
    final bottomRoot = resolveRoot(rowBoundary, col);
    if (topRoot != bottomRoot) return false;
    final span = spanForRoot(topRoot.$1, topRoot.$2);
    if (span == null) return false;
    final spanBottom = topRoot.$1 + span.rowSpan - 1;
    return rowBoundary > topRoot.$1 && rowBoundary <= spanBottom;
  }

  bool _spansVerticalBoundary(int columnBoundary, int row) {
    if (columnBoundary <= 0 || columnBoundary >= columns) return false;
    final leftRoot = resolveRoot(row, columnBoundary - 1);
    final rightRoot = resolveRoot(row, columnBoundary);
    if (leftRoot != rightRoot) return false;
    final span = spanForRoot(leftRoot.$1, leftRoot.$2);
    if (span == null) return false;
    final spanRight = leftRoot.$2 + span.colSpan - 1;
    return columnBoundary > leftRoot.$2 && columnBoundary <= spanRight;
  }

  int _rowFromKey(String key) {
    final parts = key.split(',');
    return int.parse(parts[0]);
  }

  int _colFromKey(String key) {
    final parts = key.split(',');
    return int.parse(parts[1]);
  }

  List<double> _columnBoundaries(Rect rect) {
    final xs = <double>[rect.left];
    double acc = rect.left;
    for (int c = 0; c < columns; c++) {
      double width;
      if (c < columnFractions.length) {
        width = size.width * columnFractions[c];
      } else {
        final remaining = rect.right - acc;
        final remainingCols = columns - c;
        width = remainingCols > 0 ? remaining / remainingCols : 0;
      }
      acc += width;
      xs.add(c == columns - 1 ? rect.right : acc);
    }
    xs[xs.length - 1] = rect.right;
    return xs;
  }

  /// 로컬(자기 중심) 좌표계 기준 셀 사각형
  Rect localCellRect(int r, int c, Size scaledSize) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: scaledSize.width,
      height: scaledSize.height,
    );
    final widths = <double>[];
    for (final f in columnFractions) {
      widths.add(rect.width * f);
    }
    final left = rect.left + widths.take(c).fold(0.0, (a, b) => a + b);
    final right = left + (c < widths.length ? widths[c] : 0.0);
    final rowH = rows > 0 ? rect.height / rows : rect.height;
    final top = rect.top + r * rowH;
    final bottom = top + rowH;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// 한글 주석: Quill Delta(JSON)를 TextSpan으로 변환 (bold/italic/size 지원)
  TextSpan _buildTextSpanFromDelta(
    String? jsonStr, {
    required double fallbackSize,
  }) {
    if (jsonStr == null || jsonStr.isEmpty) {
      return const TextSpan(text: '');
    }
    try {
      final obj = json.decode(jsonStr);
      final List ops = (obj is List)
          ? obj
          : (obj is Map && obj['ops'] is List ? obj['ops'] as List : const []);
      final List<InlineSpan> children = [];
      for (final raw in ops) {
        if (raw is! Map) continue;
        final ins = raw['insert'];
        if (ins is! String) continue;
        final attrs = (raw['attributes'] is Map)
            ? (raw['attributes'] as Map)
            : const {};
        final bool isBold = attrs['bold'] == true;
        final bool isItalic = attrs['italic'] == true;
        final String? sizeStr = attrs['size'] is String
            ? attrs['size'] as String
            : null;
        double fontSize = fallbackSize;
        if (sizeStr != null) {
          final parsed = double.tryParse(sizeStr);
          if (parsed != null && parsed > 0) fontSize = parsed;
        }
        children.add(
          TextSpan(
            text: ins,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              color: Colors.black,
            ),
          ),
        );
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
    final rect = Rect.fromCenter(
      center: position,
      width: size.width,
      height: size.height,
    );
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black;

    canvas.drawRect(rect, gridPaint);

    if (rows <= 0 || columns <= 0) return;

    final rowHeight = size.height / rows;
    final columnBoundaries = _columnBoundaries(rect);
    final rowBoundaries = List<double>.generate(
      rows + 1,
      (index) => rect.top + rowHeight * index,
    );

    if (rows > 1) {
      for (int r = 1; r < rows; r++) {
        final y = rowBoundaries[r];
        double segmentStart = rect.left;
        for (int c = 0; c < columns; c++) {
          final segmentEnd = columnBoundaries[c + 1];
          if (!_spansHorizontalBoundary(r, c)) {
            canvas.drawLine(
              Offset(segmentStart, y),
              Offset(segmentEnd, y),
              gridPaint,
            );
          }
          segmentStart = segmentEnd;
        }
      }
    }

    if (columns > 1) {
      for (int c = 1; c < columns; c++) {
        final x = columnBoundaries[c];
        double segmentStart = rect.top;
        for (int r = 0; r < rows; r++) {
          final segmentEnd = rowBoundaries[r + 1];
          if (!_spansVerticalBoundary(c, r)) {
            canvas.drawLine(
              Offset(x, segmentStart),
              Offset(x, segmentEnd),
              gridPaint,
            );
          }
          segmentStart = segmentEnd;
        }
      }
    }

    final scaledSize = size;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        if (editingRow != null &&
            editingCol != null &&
            r == editingRow &&
            c == editingCol) {
          continue;
        }
        if (isMergeChild(r, c)) continue;

        final jsonStr = deltaJson(r, c);
        if (jsonStr == null || jsonStr.isEmpty) continue;

        final st = styleOf(r, c);
        final fs = (st["fontSize"] as double);
        final alignStr = (st["align"] as String);

        final cellWorld = mergedWorldRect(r, c, scaledSize);

        final align = alignStr == 'center'
            ? TextAlign.center
            : (alignStr == 'right' ? TextAlign.right : TextAlign.left);

        final span = _buildTextSpanFromDelta(jsonStr, fallbackSize: fs);
        final tp = TextPainter(
          text: span,
          textAlign: align,
          textDirection: TextDirection.ltr,
          maxLines: null,
        )..layout(maxWidth: cellWorld.width);

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
    next.mergedSpans.addAll(mergedSpans);
    next.mergedParents.addAll(mergedParents);
    return next;
  }
}
