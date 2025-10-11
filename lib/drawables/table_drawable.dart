// UTF-8 인코딩, 주석은 한국어
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../flutter_painter_v2/flutter_painter.dart';

class CellMergeSpan {
  final int rowSpan;
  final int colSpan;

  const CellMergeSpan({required this.rowSpan, required this.colSpan});
}

class CellBorderThickness {
  final double top;
  final double right;
  final double bottom;
  final double left;

  const CellBorderThickness({
    this.top = 1.0,
    this.right = 1.0,
    this.bottom = 1.0,
    this.left = 1.0,
  });

  CellBorderThickness copyWith({
    double? top,
    double? right,
    double? bottom,
    double? left,
  }) {
    return CellBorderThickness(
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
      left: left ?? this.left,
    );
  }

  bool get isDefault =>
      _approx(top, 1.0) &&
      _approx(right, 1.0) &&
      _approx(bottom, 1.0) &&
      _approx(left, 1.0);

  static bool _approx(double a, double b) => (a - b).abs() < 1e-4;
}

/// 테두리 선 종류
enum CellBorderStyle { solid, dashed }

/// 셀 테두리 선 종류(사방)
class CellBorderStyles {
  final CellBorderStyle top;
  final CellBorderStyle right;
  final CellBorderStyle bottom;
  final CellBorderStyle left;

  const CellBorderStyles({
    this.top = CellBorderStyle.solid,
    this.right = CellBorderStyle.solid,
    this.bottom = CellBorderStyle.solid,
    this.left = CellBorderStyle.solid,
  });

  CellBorderStyles copyWith({
    CellBorderStyle? top,
    CellBorderStyle? right,
    CellBorderStyle? bottom,
    CellBorderStyle? left,
  }) {
    return CellBorderStyles(
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
      left: left ?? this.left,
    );
  }

  bool get isDefault =>
      top == CellBorderStyle.solid &&
      right == CellBorderStyle.solid &&
      bottom == CellBorderStyle.solid &&
      left == CellBorderStyle.solid;
}

class CellPadding {
  final double top;
  final double right;
  final double bottom;
  final double left;

  const CellPadding({
    this.top = 0.0,
    this.right = 0.0,
    this.bottom = 0.0,
    this.left = 0.0,
  });

  CellPadding copyWith({
    double? top,
    double? right,
    double? bottom,
    double? left,
  }) {
    return CellPadding(
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
      left: left ?? this.left,
    );
  }

  bool get isDefault =>
      _approx(top, 0.0) &&
      _approx(right, 0.0) &&
      _approx(bottom, 0.0) &&
      _approx(left, 0.0);

  static bool _approx(double a, double b) => (a - b).abs() < 1e-4;
}

/// 표 드로어블: 행/열 그리드 + 셀별 Quill Delta 저장/표시(간이)
class TableDrawable extends Sized2DDrawable {
  /// 표의 행/열 및 열 너비 비율 (final로 단일 정의)
  final int rows;
  final int columns;
  final List<double> columnFractions;
  final List<double> rowFractions;

  /// 셀 별 Quill Delta(JSON) 및 간단 스타일 저장
  int? editingRow;
  int? editingCol;
  final Map<String, String> cellDeltaJson = {}; // key: "r,c"
  final Map<String, Map<String, dynamic>> cellStyles =
      {}; // key: "r,c" => {fontSize, bold, italic, align}
  final Map<String, CellMergeSpan> mergedSpans = {};
  final Map<String, String> mergedParents = {}; // child -> root key
  final Map<String, CellBorderThickness> cellBorders =
      <String, CellBorderThickness>{};
  final Map<String, CellPadding> cellPaddings = <String, CellPadding>{};
  final Map<String, CellBorderStyles> cellBorderStyles =
    <String, CellBorderStyles>{};

  TableDrawable({
    required this.rows,
    required this.columns,
    List<double>? columnFractions,
    List<double>? rowFractions,
    Map<String, CellBorderThickness>? cellBorders,
  Map<String, CellBorderStyles>? cellBorderStyles,
    Map<String, CellPadding>? cellPaddings,
    required super.size,
    required super.position,
    super.rotationAngle = 0,
    super.scale = 1,
    super.assists,
    super.assistPaints,
    super.locked,
    super.hidden,
  }) : rowFractions = (rowFractions ?? const []).isNotEmpty
           ? (rowFractions!)
           : (rows > 0 && columns > 0
                 ? List<double>.filled(rows, 1.0 / rows)
                 : <double>[]),
       columnFractions = (columnFractions ?? const []).isNotEmpty
           ? (columnFractions!)
           : (rows > 0 && columns > 0
                 ? List<double>.filled(columns, 1.0 / columns)
                 : <double>[]) {
    if (cellBorders != null && cellBorders.isNotEmpty) {
      this.cellBorders.addAll(cellBorders);
    }
    if (cellBorderStyles != null && cellBorderStyles.isNotEmpty) {
      this.cellBorderStyles.addAll(cellBorderStyles);
    }
    if (cellPaddings != null && cellPaddings.isNotEmpty) {
      this.cellPaddings.addAll(cellPaddings);
    }
  }

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
  /// 셀 배경색 조회(단일 셀 기준, 병합 고려 안 함)
  Color? backgroundColorOf(int r, int c) {
    final m = cellStyles[_k(r, c)];
    if (m == null) return null;
    final v = m['bgColor'];
    if (v == null) return null;
    if (v is int) return Color(v);
    if (v is String) {
      var s = v.trim();
      if (s.startsWith('#')) s = s.substring(1);
      final intVal = int.tryParse(s, radix: 16);
      if (intVal == null) return null;
      if (s.length == 6) return Color(0xFF000000 | intVal);
      if (s.length == 8) return Color(intVal);
      return null;
    }
    return null;
  }

  /// 셀 배경색 설정
  void setBackgroundColor(int r, int c, Color? color) {
    final key = _k(r, c);
    final m = Map<String, dynamic>.from(cellStyles[key] ?? const {});
    if (color == null || color.alpha == 0) {
      m.remove('bgColor');
    } else {
      final hex = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
      m['bgColor'] = '#$hex';
    }
    if (m.isEmpty) {
      cellStyles.remove(key);
    } else {
      cellStyles[key] = m;
    }
  }

  /// 여러 셀(병합 포함)에 일괄 적용. 내부적으로 root 셀에만 기록.
  void setBackgroundForCells(Iterable<(int,int)> cells, Color? color) {
    final roots = <String, (int,int)>{};
    for (final cell in cells) {
      final root = resolveRoot(cell.$1, cell.$2);
      roots[_k(root.$1, root.$2)] = root;
    }
    for (final root in roots.values) {
      setBackgroundColor(root.$1, root.$2, color);
    }
  }


  /// 셀 스타일 저장
  
  void setStyle(int r, int c, Map<String, dynamic> style) {
    final key = _k(r, c);
    final prev = Map<String, dynamic>.from(cellStyles[key] ?? const {});
    prev.addAll(style);
    if (style.containsKey('bgColor') && style['bgColor'] == null) {
      prev.remove('bgColor');
    }
    if (prev.isEmpty) {
      cellStyles.remove(key);
    } else {
      cellStyles[key] = prev;
    }
  }


  CellBorderThickness borderOf(int r, int c) {
    final root = resolveRoot(r, c);
    return cellBorders[_k(root.$1, root.$2)] ?? const CellBorderThickness();
  }

  CellBorderStyles borderStyleOf(int r, int c) {
    final root = resolveRoot(r, c);
    return cellBorderStyles[_k(root.$1, root.$2)] ?? const CellBorderStyles();
  }

  CellPadding paddingOf(int r, int c) {
    final root = resolveRoot(r, c);
    return cellPaddings[_k(root.$1, root.$2)] ?? const CellPadding();
  }

  void updateBorderThickness(
    int r,
    int c, {
    double? top,
    double? right,
    double? bottom,
    double? left,
  }) {
    final root = resolveRoot(r, c);
    final key = _k(root.$1, root.$2);
    final current = cellBorders[key] ?? const CellBorderThickness();
    final next = current.copyWith(
      top: _clampThickness(top ?? current.top),
      right: _clampThickness(right ?? current.right),
      bottom: _clampThickness(bottom ?? current.bottom),
      left: _clampThickness(left ?? current.left),
    );
    if (next.isDefault) {
      cellBorders.remove(key);
    } else {
      cellBorders[key] = next;
    }
  }

  void updateBorderThicknessForCells(
    Iterable<(int, int)> cells, {
    double? top,
    double? right,
    double? bottom,
    double? left,
  }) {
    for (final cell in cells) {
      updateBorderThickness(
        cell.$1,
        cell.$2,
        top: top,
        right: right,
        bottom: bottom,
        left: left,
      );
    }
  }

  double _clampThickness(double value) => value.clamp(0.0, 24.0).toDouble();

  void updateBorderStyle(
    int r,
    int c, {
    CellBorderStyle? top,
    CellBorderStyle? right,
    CellBorderStyle? bottom,
    CellBorderStyle? left,
  }) {
    final root = resolveRoot(r, c);
    final key = _k(root.$1, root.$2);
    final current = cellBorderStyles[key] ?? const CellBorderStyles();
    final next = current.copyWith(
      top: top ?? current.top,
      right: right ?? current.right,
      bottom: bottom ?? current.bottom,
      left: left ?? current.left,
    );
    if (next.isDefault) {
      cellBorderStyles.remove(key);
    } else {
      cellBorderStyles[key] = next;
    }
  }

  void updateBorderStyleForCells(
    Iterable<(int, int)> cells, {
    CellBorderStyle? top,
    CellBorderStyle? right,
    CellBorderStyle? bottom,
    CellBorderStyle? left,
  }) {
    for (final cell in cells) {
      updateBorderStyle(
        cell.$1,
        cell.$2,
        top: top,
        right: right,
        bottom: bottom,
        left: left,
      );
    }
  }

  void updatePadding(
    int r,
    int c, {
    double? top,
    double? right,
    double? bottom,
    double? left,
  }) {
    final root = resolveRoot(r, c);
    final key = _k(root.$1, root.$2);
    final current = cellPaddings[key] ?? const CellPadding();
    final next = current.copyWith(
      top: _clampPadding(top ?? current.top),
      right: _clampPadding(right ?? current.right),
      bottom: _clampPadding(bottom ?? current.bottom),
      left: _clampPadding(left ?? current.left),
    );
    if (next.isDefault) {
      cellPaddings.remove(key);
    } else {
      cellPaddings[key] = next;
    }
  }

  void updatePaddingForCells(
    Iterable<(int, int)> cells, {
    double? top,
    double? right,
    double? bottom,
    double? left,
  }) {
    for (final cell in cells) {
      updatePadding(
        cell.$1,
        cell.$2,
        top: top,
        right: right,
        bottom: bottom,
        left: left,
      );
    }
  }

  double _clampPadding(double value) => value.clamp(0.0, 400.0).toDouble();

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

  List<double> _rowBoundaries(Rect rect) {
    final ys = <double>[rect.top];
    double sum = 0.0;
    for (final v in rowFractions) {
      if (v.isFinite && v > 0) sum += v;
    }
    if (sum <= 0 || rowFractions.length < rows) {
      final double h = size.height / rows;
      for (int i = 1; i <= rows; i++) {
        ys.add(i == rows ? rect.bottom : rect.top + h * i);
      }
    } else {
      double acc = rect.top;
      for (int r = 0; r < rows; r++) {
        final double rh = size.height * (rowFractions[r] / sum);
        acc += rh;
        ys.add(r == rows - 1 ? rect.bottom : acc);
      }
      ys[ys.length - 1] = rect.bottom;
    }
    if (ys.length != rows + 1) {
      ys
        ..clear()
        ..add(rect.top)
        ..add(rect.bottom);
    }
    return ys;
  }

  double _horizontalBorderThickness(int boundaryRow, int column) {
    if (columns <= 0 || rows <= 0) return 0.0;
    final int col = column.clamp(0, columns - 1);
    if (boundaryRow <= 0) {
      return borderOf(0, col).top;
    }
    if (boundaryRow >= rows) {
      return borderOf(rows - 1, col).bottom;
    }
    final double above = borderOf(boundaryRow - 1, col).bottom;
    final double below = borderOf(boundaryRow, col).top;
    return math.max(above, below);
  }

  CellBorderStyle _horizontalBorderStyle(int boundaryRow, int column) {
    // 경계선이 그려질 때, 두 셀의 해당 변 중 두께가 큰 쪽의 스타일을 우선.
    // 두께가 동일하고 스타일이 다르면 dashed 우선.
    if (columns <= 0 || rows <= 0) return CellBorderStyle.solid;
    final int col = column.clamp(0, columns - 1);
    if (boundaryRow <= 0) {
      return borderStyleOf(0, col).top;
    }
    if (boundaryRow >= rows) {
      return borderStyleOf(rows - 1, col).bottom;
    }
    final aboveB = borderOf(boundaryRow - 1, col).bottom;
    final belowT = borderOf(boundaryRow, col).top;
    final aboveS = borderStyleOf(boundaryRow - 1, col).bottom;
    final belowS = borderStyleOf(boundaryRow, col).top;
    if (aboveB > belowT) return aboveS;
    if (belowT > aboveB) return belowS;
    // equal thickness
    return (aboveS == CellBorderStyle.dashed || belowS == CellBorderStyle.dashed)
        ? CellBorderStyle.dashed
        : CellBorderStyle.solid;
  }

  double _verticalBorderThickness(int boundaryColumn, int row) {
    if (columns <= 0 || rows <= 0) return 0.0;
    final int r = row.clamp(0, rows - 1);
    if (boundaryColumn <= 0) {
      return borderOf(r, 0).left;
    }
    if (boundaryColumn >= columns) {
      return borderOf(r, columns - 1).right;
    }
    final double left = borderOf(r, boundaryColumn - 1).right;
    final double right = borderOf(r, boundaryColumn).left;
    return math.max(left, right);
  }

  CellBorderStyle _verticalBorderStyle(int boundaryColumn, int row) {
    if (columns <= 0 || rows <= 0) return CellBorderStyle.solid;
    final int r = row.clamp(0, rows - 1);
    if (boundaryColumn <= 0) {
      return borderStyleOf(r, 0).left;
    }
    if (boundaryColumn >= columns) {
      return borderStyleOf(r, columns - 1).right;
    }
    final leftR = borderOf(r, boundaryColumn - 1).right;
    final rightL = borderOf(r, boundaryColumn).left;
    final leftS = borderStyleOf(r, boundaryColumn - 1).right;
    final rightS = borderStyleOf(r, boundaryColumn).left;
    if (leftR > rightL) return leftS;
    if (rightL > leftR) return rightS;
    return (leftS == CellBorderStyle.dashed || rightS == CellBorderStyle.dashed)
        ? CellBorderStyle.dashed
        : CellBorderStyle.solid;
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
    // Normalize columns and rows to ensure stable layout
    final double rowSum = rowFractions.isEmpty
        ? 0.0
        : rowFractions.fold(0.0, (a, b) => a + (b.isFinite ? b : 0.0));
    final List<double> heights = rowSum > 0
        ? rowFractions.map((f) => rect.height * (f / rowSum)).toList()
        : List<double>.filled(
            rows > 0 ? rows : 1,
            rect.height / (rows > 0 ? rows : 1),
          );
    final left =
        rect.left + (c > 0 ? widths.take(c).fold(0.0, (a, b) => a + b) : 0.0);
    final right = left + ((c < widths.length) ? widths[c] : 0.0);
    final top =
        rect.top + (r > 0 ? heights.take(r).fold(0.0, (a, b) => a + b) : 0.0);
    final bottom =
        top +
        ((r < heights.length)
            ? heights[r]
            : (rows > 0 ? rect.height / rows : rect.height));
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
      ..color = Colors.black;

    
    // === (추가) 셀 배경색 채우기 ===
    final xs = _columnBoundaries(rect);
    final ys = _rowBoundaries(rect);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < columns; c++) {
        final key = _k(r, c);
        if (mergedParents.containsKey(key)) continue; // root만 채움
        final span = spanForRoot(r, c);
        final int br = span != null ? (r + span.rowSpan - 1) : r;
        final int bc = span != null ? (c + span.colSpan - 1) : c;
        final Rect cellRect = Rect.fromLTRB(
          xs[c],
          ys[r],
          xs[(bc + 1).clamp(0, xs.length - 1)],
          ys[(br + 1).clamp(0, ys.length - 1)],
        );
        final bg = backgroundColorOf(r, c);
        if (bg != null && bg.alpha > 0) {
          final p = Paint()
            ..style = PaintingStyle.fill
            ..color = bg;
          canvas.drawRect(cellRect, p);
        }
      }
    }

    if (rows <= 0 || columns <= 0) {
      gridPaint.strokeWidth = 1;
      canvas.drawRect(rect, gridPaint);
      return;
    }

    final columnBoundaries = _columnBoundaries(rect);
    final rowBoundaries = _rowBoundaries(rect);

    // 내부 유틸: 대시 라인 그리기
    void drawDashedLine(Offset a, Offset b, Paint p) {
      final dx = b.dx - a.dx;
      final dy = b.dy - a.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len <= 0.0) return;
      final dir = Offset(dx / len, dy / len);
      final double dash = p.strokeWidth * 3.0; // 길이
      final double gap = p.strokeWidth * 1.5; // 간격
      double t = 0.0;
      while (t < len) {
        final double tEnd = math.min(t + dash, len);
        final o1 = a + dir * t;
        final o2 = a + dir * tEnd;
        canvas.drawLine(o1, o2, p);
        t = tEnd + gap;
      }
    }

    for (int r = 0; r <= rows; r++) {
      final double y = rowBoundaries[r];
      double segmentStart = rect.left;
      for (int c = 0; c < columns; c++) {
        final double segmentEnd = columnBoundaries[c + 1];
        final bool isOuter = r == 0 || r == rows;
        if (isOuter || !_spansHorizontalBoundary(r, c)) {
          final double thickness = _horizontalBorderThickness(r, c);
          if (thickness > 0) {
            gridPaint.strokeWidth = thickness;
            final style = _horizontalBorderStyle(r, c);
            if (style == CellBorderStyle.dashed) {
              drawDashedLine(
                Offset(segmentStart, y),
                Offset(segmentEnd, y),
                gridPaint,
              );
            } else {
              canvas.drawLine(
                Offset(segmentStart, y),
                Offset(segmentEnd, y),
                gridPaint,
              );
            }
          }
        }
        segmentStart = segmentEnd;
      }
    }

    for (int c = 0; c <= columns; c++) {
      final double x = columnBoundaries[c];
      double segmentStart = rect.top;
      for (int r = 0; r < rows; r++) {
        final double segmentEnd = rowBoundaries[r + 1];
        final bool isOuter = c == 0 || c == columns;
        if (isOuter || !_spansVerticalBoundary(c, r)) {
          final double thickness = _verticalBorderThickness(c, r);
          if (thickness > 0) {
            gridPaint.strokeWidth = thickness;
            final style = _verticalBorderStyle(c, r);
            if (style == CellBorderStyle.dashed) {
              drawDashedLine(
                Offset(x, segmentStart),
                Offset(x, segmentEnd),
                gridPaint,
              );
            } else {
              canvas.drawLine(
                Offset(x, segmentStart),
                Offset(x, segmentEnd),
                gridPaint,
              );
            }
          }
        }
        segmentStart = segmentEnd;
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

        final padding = paddingOf(r, c);
        final jsonStr = deltaJson(r, c);
        if (jsonStr == null || jsonStr.isEmpty) continue;

        final st = styleOf(r, c);
        final fs = (st["fontSize"] as double);
        final alignStr = (st["align"] as String);

        final cellWorld = mergedWorldRect(r, c, scaledSize);
        final padded = Rect.fromLTRB(
          cellWorld.left + padding.left,
          cellWorld.top + padding.top,
          cellWorld.right - padding.right,
          cellWorld.bottom - padding.bottom,
        );
        if (padded.width <= 0 || padded.height <= 0) {
          continue;
        }

        final align = alignStr == 'center'
            ? TextAlign.center
            : (alignStr == 'right' ? TextAlign.right : TextAlign.left);

        final span = _buildTextSpanFromDelta(jsonStr, fallbackSize: fs);
        final tp = TextPainter(
          text: span,
          textAlign: align,
          textDirection: TextDirection.ltr,
          maxLines: null,
        )..layout(maxWidth: padded.width);

        double dx = padded.left;
        if (align == TextAlign.center) {
          dx = padded.left + (padded.width - tp.width) / 2.0;
        } else if (align == TextAlign.right) {
          dx = padded.right - tp.width;
        }

        canvas.save();
        canvas.clipRect(padded);
        tp.paint(canvas, Offset(dx, padded.top));
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
    List<double>? rowFractions,
    Map<ObjectDrawableAssist, Paint>? assistPaints,
    Map<String, String>? cellDeltaJson,
    Map<String, Map<String, dynamic>>? cellStyles,
    Map<String, CellBorderThickness>? cellBorders,
    Map<String, CellBorderStyles>? cellBorderStyles,
    Map<String, CellPadding>? cellPaddings,
  }) {
    final next = TableDrawable(
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
      columnFractions: columnFractions ?? this.columnFractions,
      rowFractions: rowFractions ?? this.rowFractions,
      cellBorders: cellBorders ?? this.cellBorders,
      cellBorderStyles: cellBorderStyles ?? this.cellBorderStyles,
      cellPaddings: cellPaddings ?? this.cellPaddings,
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
    next.cellBorders.addAll(cellBorders ?? this.cellBorders);
  next.cellBorderStyles.addAll(cellBorderStyles ?? this.cellBorderStyles);
    next.cellPaddings.addAll(cellPaddings ?? this.cellPaddings);
    next.editingRow = editingRow;
    next.editingCol = editingCol;
    next.mergedSpans.addAll(mergedSpans);
    next.mergedParents.addAll(mergedParents);
    return next;
  }
}
