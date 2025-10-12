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
  // 표 구조
  int rows;
  int columns;
  List<double> columnFractions;
  List<double> rowFractions;

  // 생성 시 기준 행 높이(픽셀). 이후 행 삽입 시 새 행의 높이로 사용.
  final double initialRowHeight;

  // 편집 상태
  int? editingRow;
  int? editingCol;

  // 셀 속성/콘텐츠 저장
  final Map<String, String> cellDeltaJson = {};
  final Map<String, Map<String, dynamic>> cellStyles = {};
  final Map<String, CellBorderThickness> cellBorders = {};
  final Map<String, CellBorderStyles> cellBorderStyles = {};
  final Map<String, CellPadding> cellPaddings = {};

  // 병합 정보
  final Map<String, CellMergeSpan> mergedSpans = {};
  final Map<String, String> mergedParents = {};

  // 셀-내부 열 분할: 루트 셀 키 -> 내부 분할 분율 리스트(합=1). 길이가 2 이상이면 내부 분할 활성
  final Map<String, List<double>> internalColFractions = {};

  // 내부 서브셀 콘텐츠/스타일/패딩: 루트 셀 키별로 내부 열 수만큼의 리스트를 유지(null 허용)
  // - internalCellDeltaJson[key] = List<String?> (각 내부 서브셀의 Quill JSON)
  // - internalCellStyles[key] = List<Map<String,dynamic>?> (텍스트 스타일 등)
  // - internalCellPaddings[key] = List<CellPadding?> (내부 서브셀 개별 패딩)
  final Map<String, List<String?>> internalCellDeltaJson = {};
  final Map<String, List<Map<String, dynamic>?>> internalCellStyles = {};
  final Map<String, List<CellPadding?>> internalCellPaddings = {};

  // Key 유틸
  String _k(int r, int c) => "$r,$c";

  // 기본 스타일 제공
  Map<String, dynamic> styleOf(int r, int c) {
    final rt = resolveRoot(r, c);
    final key = _k(rt.$1, rt.$2);
    final m = Map<String, dynamic>.from(cellStyles[key] ?? const {});
    m.putIfAbsent('fontSize', () => 12.0);
    m.putIfAbsent('align', () => 'left');
    m.putIfAbsent('bold', () => false);
    m.putIfAbsent('italic', () => false);
    return m;
  }

  // 편집 세션 훅: 위젯 편집기에서 호출하므로 최소 구현 제공
  void beginEdit(int row, int col) {
    final rt = resolveRoot(row, col);
    editingRow = rt.$1.clamp(0, math.max(0, rows - 1));
    editingCol = rt.$2.clamp(0, math.max(0, columns - 1));
  }

  void endEdit() {
    editingRow = null;
    editingCol = null;
  }

  TableDrawable({
    required this.rows,
    required this.columns,
    List<double>? columnFractions,
    List<double>? rowFractions,
    double? initialRowHeight,
    required Size size,
    required Offset position,
    double rotationAngle = 0,
    double scale = 1,
    Set<ObjectDrawableAssist> assists = const <ObjectDrawableAssist>{},
    Map<ObjectDrawableAssist, Paint> assistPaints =
        const <ObjectDrawableAssist, Paint>{},
    bool locked = false,
    bool hidden = false,
    Map<String, String>? cellDeltaJson,
    Map<String, Map<String, dynamic>>? cellStyles,
    Map<String, CellBorderThickness>? cellBorders,
    Map<String, CellBorderStyles>? cellBorderStyles,
    Map<String, CellPadding>? cellPaddings,
  }) : columnFractions = columnFractions == null
           ? List<double>.filled(columns, columns > 0 ? 1.0 / columns : 0.0)
           : List<double>.from(columnFractions),
       rowFractions = rowFractions == null
           ? List<double>.filled(rows, rows > 0 ? 1.0 / rows : 0.0)
           : List<double>.from(rowFractions),
       initialRowHeight =
           initialRowHeight ?? ((size.height) / math.max(1, rows)),
       super(
         size: size,
         position: position,
         rotationAngle: rotationAngle,
         scale: scale,
         assists: assists,
         assistPaints: assistPaints,
         locked: locked,
         hidden: hidden,
       ) {
    if (cellDeltaJson != null) this.cellDeltaJson.addAll(cellDeltaJson);
    if (cellStyles != null) this.cellStyles.addAll(cellStyles);
    if (cellBorders != null) this.cellBorders.addAll(cellBorders);
    if (cellBorderStyles != null)
      this.cellBorderStyles.addAll(cellBorderStyles);
    if (cellPaddings != null) this.cellPaddings.addAll(cellPaddings);
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

  // 배경색: inspector 등에서 사용. style map에 bgColor(int)로 저장/조회한다.
  Color? backgroundColorOf(int r, int c) {
    final root = resolveRoot(r, c);
    final key = _k(root.$1, root.$2);
    final m = cellStyles[key];
    if (m == null) return null;
    final v = m['bgColor'];
    if (v == null) return null;
    if (v is int) return Color(v);
    if (v is String) {
      var s = v.trim();
      if (s.startsWith('#')) s = s.substring(1);
      final n = int.tryParse(s, radix: 16);
      if (n == null) return null;
      if (s.length == 6) return Color(0xFF000000 | n);
      if (s.length == 8) return Color(n);
    }
    return null;
  }

  void setBackgroundColor(int r, int c, Color? color) {
    final root = resolveRoot(r, c);
    final key = _k(root.$1, root.$2);
    final prev = Map<String, dynamic>.from(cellStyles[key] ?? const {});
    if (color == null) {
      prev.remove('bgColor');
    } else {
      // Store as ARGB 32-bit int using explicit conversion to avoid deprecated Color.value
      prev['bgColor'] = color.toARGB32();
    }
    if (prev.isEmpty) {
      cellStyles.remove(key);
    } else {
      cellStyles[key] = prev;
    }
  }

  // 내부 열 분할 설정/조회
  void setInternalColumnsEqual(int r, int c, int n) {
    final rt = resolveRoot(r, c);
    final key = _k(rt.$1, rt.$2);
    if (n <= 1) {
      internalColFractions.remove(key);
      // 내부 데이터도 함께 제거
      internalCellDeltaJson.remove(key);
      internalCellStyles.remove(key);
      internalCellPaddings.remove(key);
      return;
    }
    final frac = 1.0 / n;
    internalColFractions[key] = List<double>.filled(n, frac);
    // 기존 내부 데이터 보존하며 길이 맞추기
    void resizeListForKey<T>(Map<String, List<T?>> store) {
      final prev = store[key];
      if (prev == null) {
        store[key] = List<T?>.filled(n, null);
        return;
      }
      if (prev.length == n) return;
      if (prev.length > n) {
        store[key] = List<T?>.from(prev.take(n));
      } else {
        store[key] = [...prev, ...List<T?>.filled(n - prev.length, null)];
      }
    }

    resizeListForKey<String>(internalCellDeltaJson);
    resizeListForKey<Map<String, dynamic>>(internalCellStyles);
    resizeListForKey<CellPadding>(internalCellPaddings);
  }

  List<double>? internalFractionsOf(int r, int c) {
    final rt = resolveRoot(r, c);
    return internalColFractions[_k(rt.$1, rt.$2)];
  }

  int internalColsCount(int r, int c) {
    final f = internalFractionsOf(r, c);
    return (f == null || f.isEmpty) ? 1 : f.length;
  }

  // 내부 서브셀 Delta 접근자
  String? internalDeltaJsonOf(int r, int c, int innerIndex) {
    final rt = resolveRoot(r, c);
    final list = internalCellDeltaJson[_k(rt.$1, rt.$2)];
    if (list == null || innerIndex < 0 || innerIndex >= list.length)
      return null;
    return list[innerIndex];
  }

  void setInternalDeltaJson(int r, int c, int innerIndex, String? jsonStr) {
    final rt = resolveRoot(r, c);
    final key = _k(rt.$1, rt.$2);
    final n = internalColsCount(rt.$1, rt.$2);
    if (n <= 1) return; // 내부 분할 없으면 무시
    final list = internalCellDeltaJson.putIfAbsent(
      key,
      () => List<String?>.filled(n, null),
    );
    if (innerIndex < 0 || innerIndex >= n) return;
    list[innerIndex] = jsonStr;
  }

  // 내부 서브셀 스타일 접근자(루트 스타일로 폴백)
  Map<String, dynamic> internalStyleOf(int r, int c, int innerIndex) {
    final rt = resolveRoot(r, c);
    final key = _k(rt.$1, rt.$2);
    final base = styleOf(rt.$1, rt.$2);
    final styles = internalCellStyles[key];
    final Map<String, dynamic>? inner =
        (styles != null && innerIndex >= 0 && innerIndex < styles.length)
        ? styles[innerIndex]
        : null;
    if (inner == null) return base;
    final merged = Map<String, dynamic>.from(base);
    merged.addAll(inner);
    return merged;
  }

  void setInternalStyle(
    int r,
    int c,
    int innerIndex,
    Map<String, dynamic> patch,
  ) {
    final rt = resolveRoot(r, c);
    final key = _k(rt.$1, rt.$2);
    final n = internalColsCount(rt.$1, rt.$2);
    if (n <= 1 || innerIndex < 0 || innerIndex >= n) return;
    final list = internalCellStyles.putIfAbsent(
      key,
      () => List<Map<String, dynamic>?>.filled(n, null),
    );
    final prev = Map<String, dynamic>.from(list[innerIndex] ?? const {});
    prev.addAll(patch);
    // bgColor null 같은 정리 로직
    if (prev.containsKey('bgColor') && prev['bgColor'] == null)
      prev.remove('bgColor');
    list[innerIndex] = prev.isEmpty ? null : prev;
  }

  // 내부 서브셀 패딩(루트 패딩 폴백)
  CellPadding internalPaddingOf(int r, int c, int innerIndex) {
    final rt = resolveRoot(r, c);
    final key = _k(rt.$1, rt.$2);
    final list = internalCellPaddings[key];
    final inner = (list != null && innerIndex >= 0 && innerIndex < list.length)
        ? list[innerIndex]
        : null;
    return inner ?? paddingOf(rt.$1, rt.$2);
  }

  void setInternalPadding(int r, int c, int innerIndex, CellPadding padding) {
    final rt = resolveRoot(r, c);
    final key = _k(rt.$1, rt.$2);
    final n = internalColsCount(rt.$1, rt.$2);
    if (n <= 1 || innerIndex < 0 || innerIndex >= n) return;
    final list = internalCellPaddings.putIfAbsent(
      key,
      () => List<CellPadding?>.filled(n, null),
    );
    list[innerIndex] = padding;
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

  /// 주어진 영역(r0..r1, c0..c1)을 하나의 셀로 병합 가능한지 검사
  bool canMergeRegion(int r0, int c0, int r1, int c1) {
    if (rows <= 0 || columns <= 0) return false;
    int rr0 = r0.clamp(0, rows - 1);
    int rr1 = r1.clamp(0, rows - 1);
    int cc0 = c0.clamp(0, columns - 1);
    int cc1 = c1.clamp(0, columns - 1);
    if (rr0 > rr1) {
      final t = rr0;
      rr0 = rr1;
      rr1 = t;
    }
    if (cc0 > cc1) {
      final t = cc0;
      cc0 = cc1;
      cc1 = t;
    }
    // 영역 내 모든 셀이 가지는 루트가 영역 안에 있고, 루트 스팬이 영역을 넘지 않아야 함
    for (int r = rr0; r <= rr1; r++) {
      for (int c = cc0; c <= cc1; c++) {
        final rt = resolveRoot(r, c);
        if (rt.$1 < rr0 || rt.$1 > rr1 || rt.$2 < cc0 || rt.$2 > cc1) {
          return false;
        }
        final sp = spanForRoot(rt.$1, rt.$2);
        if (sp != null) {
          final br = rt.$1 + sp.rowSpan - 1;
          final bc = rt.$2 + sp.colSpan - 1;
          if (br > rr1 || bc > cc1) return false;
        }
      }
    }
    return true;
  }

  /// 선택한 영역(r0..r1, c0..c1)을 하나의 셀로 병합. 성공 여부 반환.
  bool mergeRegion(int r0, int c0, int r1, int c1) {
    if (!canMergeRegion(r0, c0, r1, c1)) return false;
    int rr0 = r0.clamp(0, rows - 1);
    int rr1 = r1.clamp(0, rows - 1);
    int cc0 = c0.clamp(0, columns - 1);
    int cc1 = c1.clamp(0, columns - 1);
    if (rr0 > rr1) {
      final t = rr0;
      rr0 = rr1;
      rr1 = t;
    }
    if (cc0 > cc1) {
      final t = cc0;
      cc0 = cc1;
      cc1 = t;
    }
    final rowSpan = rr1 - rr0 + 1;
    final colSpan = cc1 - cc0 + 1;
    // 영역 내 기존 병합 제거
    final toRemoveRoots = <String>[];
    final toRemoveParents = <String>[];
    mergedSpans.forEach((key, span) {
      final r = _rowFromKey(key);
      final c = _colFromKey(key);
      if (r >= rr0 && r <= rr1 && c >= cc0 && c <= cc1) {
        toRemoveRoots.add(key);
      }
    });
    mergedParents.forEach((key, parent) {
      final r = _rowFromKey(key);
      final c = _colFromKey(key);
      if (r >= rr0 && r <= rr1 && c >= cc0 && c <= cc1) {
        toRemoveParents.add(key);
      }
    });
    for (final k in toRemoveRoots) {
      mergedSpans.remove(k);
    }
    for (final k in toRemoveParents) {
      mergedParents.remove(k);
    }
    // 새 병합 설정
    mergedSpans[_k(rr0, cc0)] = CellMergeSpan(
      rowSpan: rowSpan,
      colSpan: colSpan,
    );
    for (int r = rr0; r <= rr1; r++) {
      for (int c = cc0; c <= cc1; c++) {
        if (r == rr0 && c == cc0) continue;
        mergedParents[_k(r, c)] = _k(rr0, cc0);
      }
    }
    return true;
  }

  bool canUnmergeAt(int r, int c) {
    return isMergeRoot(r, c);
  }

  bool unmergeAt(int r, int c) {
    if (!isMergeRoot(r, c)) return false;
    final span = spanForRoot(r, c);
    if (span == null) return false;
    final rr0 = r;
    final cc0 = c;
    final rr1 = rr0 + span.rowSpan - 1;
    final cc1 = cc0 + span.colSpan - 1;
    // 부모/루트 제거
    for (int rr = rr0; rr <= rr1; rr++) {
      for (int cc = cc0; cc <= cc1; cc++) {
        mergedParents.remove(_k(rr, cc));
      }
    }
    mergedSpans.remove(_k(rr0, cc0));
    return true;
  }

  /// 월드 좌표(캔버스 상) 기준 병합된 셀의 사각형 반환
  Rect mergedWorldRect(int r, int c, Size scaledSize) {
    final rect = Rect.fromCenter(
      center: position,
      width: scaledSize.width,
      height: scaledSize.height,
    );
    final root = resolveRoot(r, c);
    final span = spanForRoot(root.$1, root.$2);
    final int r0 = root.$1;
    final int c0 = root.$2;
    final int r1 = r0 + (span?.rowSpan ?? 1) - 1;
    final int c1 = c0 + (span?.colSpan ?? 1) - 1;
    final xs = _columnBoundaries(rect);
    final ys = _rowBoundaries(rect);
    return Rect.fromLTRB(
      xs[c0],
      ys[r0],
      xs[(c1 + 1).clamp(0, xs.length - 1)],
      ys[(r1 + 1).clamp(0, ys.length - 1)],
    );
  }

  // 병합 영역이 특정 수평 경계(r)와 열 c 구간을 가로지르는지
  bool _spansHorizontalBoundary(int boundaryRow, int column) {
    // 경계는 행 사이의 선(0..rows). 병합 영역이 경계를 가로지르면 true
    for (final e in mergedSpans.entries) {
      final r0 = _rowFromKey(e.key);
      final c0 = _colFromKey(e.key);
      final rs = e.value.rowSpan;
      final cs = e.value.colSpan;
      final r1 = r0 + rs - 1;
      final c1 = c0 + cs - 1;
      if (column >= c0 && column <= c1) {
        if (boundaryRow > r0 && boundaryRow <= r1) {
          return true;
        }
      }
    }
    return false;
  }

  // 병합 영역이 특정 수직 경계(c)와 행 r 구간을 가로지르는지
  bool _spansVerticalBoundary(int boundaryColumn, int row) {
    for (final e in mergedSpans.entries) {
      final r0 = _rowFromKey(e.key);
      final c0 = _colFromKey(e.key);
      final rs = e.value.rowSpan;
      final cs = e.value.colSpan;
      final r1 = r0 + rs - 1;
      final c1 = c0 + cs - 1;
      if (row >= r0 && row <= r1) {
        if (boundaryColumn > c0 && boundaryColumn <= c1) {
          return true;
        }
      }
    }
    return false;
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
    // 경계선 스타일 판정: 어느 한쪽이라도 dashed면 dashed 우선.
    // (두께 크기와 무관하게 점선을 우선 적용하여 이웃 셀에서도 스타일이 일관되게 보이도록)
    if (columns <= 0 || rows <= 0) return CellBorderStyle.solid;
    final int col = column.clamp(0, columns - 1);
    if (boundaryRow <= 0) {
      return borderStyleOf(0, col).top;
    }
    if (boundaryRow >= rows) {
      return borderStyleOf(rows - 1, col).bottom;
    }
    final aboveS = borderStyleOf(boundaryRow - 1, col).bottom;
    final belowS = borderStyleOf(boundaryRow, col).top;
    if (aboveS == CellBorderStyle.dashed || belowS == CellBorderStyle.dashed) {
      return CellBorderStyle.dashed;
    }
    // 모두 solid인 경우에는 아무 쪽이나 solid
    return CellBorderStyle.solid;
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
    // 세로 경계도 동일 정책: 한쪽이라도 dashed면 dashed
    if (columns <= 0 || rows <= 0) return CellBorderStyle.solid;
    final int r = row.clamp(0, rows - 1);
    if (boundaryColumn <= 0) {
      return borderStyleOf(r, 0).left;
    }
    if (boundaryColumn >= columns) {
      return borderStyleOf(r, columns - 1).right;
    }
    final leftS = borderStyleOf(r, boundaryColumn - 1).right;
    final rightS = borderStyleOf(r, boundaryColumn).left;
    if (leftS == CellBorderStyle.dashed || rightS == CellBorderStyle.dashed) {
      return CellBorderStyle.dashed;
    }
    return CellBorderStyle.solid;
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
        final innerFracs = internalFractionsOf(r, c);
        if (innerFracs != null && innerFracs.length >= 2) {
          // 내부 서브셀 배경 우선 렌더
          double accL = cellRect.left;
          for (int i = 0; i < innerFracs.length; i++) {
            final w = cellRect.width * innerFracs[i];
            final sub = Rect.fromLTWH(accL, cellRect.top, w, cellRect.height);
            accL += w;
            final style = internalStyleOf(r, c, i);
            final bg = () {
              final v = style['bgColor'];
              if (v == null) return null;
              if (v is int) return Color(v);
              if (v is String) {
                var s = v.trim();
                if (s.startsWith('#')) s = s.substring(1);
                final n = int.tryParse(s, radix: 16);
                if (n == null) return null;
                if (s.length == 6) return Color(0xFF000000 | n);
                if (s.length == 8) return Color(n);
              }
              return null;
            }();
            final color = bg ?? backgroundColorOf(r, c);
            if (color != null && color.a > 0) {
              final p = Paint()
                ..style = PaintingStyle.fill
                ..color = color;
              canvas.drawRect(sub, p);
            }
          }
        } else {
          final bg = backgroundColorOf(r, c);
          if (bg != null && bg.a > 0) {
            final p = Paint()
              ..style = PaintingStyle.fill
              ..color = bg;
            canvas.drawRect(cellRect, p);
          }
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

    // 내부(셀-내부) 열 분할 보조선 그리기: 루트 셀에 internalColFractions가 설정된 경우만
    if (internalColFractions.isNotEmpty) {
      final Paint innerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.black54
        ..strokeWidth = 1;
      internalColFractions.forEach((rootKey, fracs) {
        if (fracs.isEmpty || fracs.length < 2) return;
        final r0 = _rowFromKey(rootKey);
        final c0 = _colFromKey(rootKey);
        // 루트 기준 병합 영역의 월드 사각형
        final Rect cellWorld = mergedWorldRect(r0, c0, size);
        final double w = cellWorld.width;
        double accX = cellWorld.left;
        for (int i = 0; i < fracs.length; i++) {
          final segW = w * fracs[i];
          final nextX = accX + segW;
          // 구분선: 각 세그먼트 경계(마지막은 그리지 않음)
          if (i < fracs.length - 1) {
            final double x = nextX;
            canvas.drawLine(
              Offset(x, cellWorld.top),
              Offset(x, cellWorld.bottom),
              innerPaint,
            );
          }
          accX = nextX;
        }
      });
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

        final cellWorld = mergedWorldRect(r, c, scaledSize);
        final innerFracs = internalFractionsOf(r, c);
        if (innerFracs != null && innerFracs.length >= 2) {
          // 내부 서브셀 각각 렌더링
          double accX = cellWorld.left;
          for (int i = 0; i < innerFracs.length; i++) {
            final segW = cellWorld.width * innerFracs[i];
            final subRect = Rect.fromLTWH(
              accX,
              cellWorld.top,
              segW,
              cellWorld.height,
            );
            accX += segW;
            final jsonStr =
                internalDeltaJsonOf(r, c, i) ??
                (i == 0 ? deltaJson(r, c) : null);
            if (jsonStr == null || jsonStr.isEmpty) continue;
            final style = internalStyleOf(r, c, i);
            final fs = (style['fontSize'] as double);
            final alignStr = (style['align'] as String);
            final padding = internalPaddingOf(r, c, i);
            final padded = Rect.fromLTRB(
              subRect.left + padding.left,
              subRect.top + padding.top,
              subRect.right - padding.right,
              subRect.bottom - padding.bottom,
            );
            if (padded.width <= 0 || padded.height <= 0) continue;
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
        } else {
          // 기존: 루트 셀 내용 렌더링
          final padding = paddingOf(r, c);
          final jsonStr = deltaJson(r, c);
          if (jsonStr == null || jsonStr.isEmpty) continue;
          final st = styleOf(r, c);
          final fs = (st['fontSize'] as double);
          final alignStr = (st['align'] as String);
          final padded = Rect.fromLTRB(
            cellWorld.left + padding.left,
            cellWorld.top + padding.top,
            cellWorld.right - padding.right,
            cellWorld.bottom - padding.bottom,
          );
          if (padded.width <= 0 || padded.height <= 0) continue;
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
      initialRowHeight: this.initialRowHeight,
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
    // 내부 분할/데이터 복사
    next.internalColFractions.addAll(this.internalColFractions);
    this.internalCellDeltaJson.forEach((k, v) {
      next.internalCellDeltaJson[k] = List<String?>.from(v);
    });
    this.internalCellStyles.forEach((k, v) {
      next.internalCellStyles[k] = v
          .map((e) => e == null ? null : Map<String, dynamic>.from(e))
          .toList();
    });
    this.internalCellPaddings.forEach((k, v) {
      next.internalCellPaddings[k] = v
          .map((e) => e == null ? null : e)
          .toList();
    });
    return next;
  }

  // ===== 행/열 분할 유틸 =====
  List<double> _rowPixels() {
    if (rows <= 0) return const [];
    double sum = 0.0;
    for (final v in rowFractions) {
      if (v.isFinite && v > 0) sum += v;
    }
    if (sum <= 0 || rowFractions.length < rows) {
      return List<double>.filled(rows, size.height / math.max(1, rows));
    }
    return List<double>.generate(
      rows,
      (i) => size.height * (rowFractions[i] / sum),
    );
  }

  List<double> _colPixels() {
    if (columns <= 0) return const [];
    double sum = 0.0;
    for (final v in columnFractions) {
      if (v.isFinite && v > 0) sum += v;
    }
    if (sum <= 0 || columnFractions.length < columns) {
      return List<double>.filled(columns, size.width / math.max(1, columns));
    }
    return List<double>.generate(
      columns,
      (i) => size.width * (columnFractions[i] / sum),
    );
  }

  // 행 커버리지 체크는 행 전체 삽입 분할에서만 필요했으나, 현재 구현에서는 사용되지 않습니다.

  // 사용 안 함: 가로 병합 커버리지 체크(이전 전체-열 분할 구현에서 사용)

  /// 행 삽입: 선택된 셀의 루트 행(r0) 위치에 count개의 새 행을 삽입하고, 기존 r0 및 아래 행들을 아래로 민다.
  TableDrawable splitRowsAt(int row, int col, int count) {
    final n = count;
    if (n <= 0 || rows <= 0) return this;
    final root = resolveRoot(row, col);
    final int r0 = root.$1.clamp(0, math.max(0, rows - 1));

    // 1) 기존 행 픽셀 및 삽입 높이 계산: 새 행은 "생성 시" 기준 높이로 삽입
    final rowPx = _rowPixels();
    if (rowPx.isEmpty) return this;
    final double insertH = initialRowHeight > 0
        ? initialRowHeight
        : (size.height / math.max(1, rows));
    final newRowPx = <double>[]
      ..addAll(rowPx.take(r0))
      ..addAll(List<double>.filled(n, insertH))
      ..addAll(rowPx.skip(r0));
    final int newRows = rows + n;
    final double addedH = insertH * n;
    final double newTotalH = size.height + addedH;
    final List<double> newRowFractions = newRowPx
        .map((h) => h / newTotalH)
        .toList();

    // 2) 셀 데이터/스타일/테두리/패딩: r>=r0는 r+n으로 시프트
    Map<String, String> newDeltaJson = {};
    Map<String, Map<String, dynamic>> newCellStyles = {};
    Map<String, CellBorderThickness> newCellBorders = {};
    Map<String, CellBorderStyles> newCellBorderStyles = {};
    Map<String, CellPadding> newCellPaddings = {};
    String k(int r, int c) => "$r,$c";

    void shiftMapRows<K>(
      Map<String, K> src,
      void Function(int r, int c, K v) put,
    ) {
      src.forEach((key, value) {
        final rr = _rowFromKey(key);
        final cc = _colFromKey(key);
        if (rr < r0) {
          put(rr, cc, value);
        } else {
          put(rr + n, cc, value);
        }
      });
    }

    shiftMapRows<String>(cellDeltaJson, (r, c, v) => newDeltaJson[k(r, c)] = v);
    shiftMapRows<Map<String, dynamic>>(
      cellStyles,
      (r, c, v) => newCellStyles[k(r, c)] = v,
    );
    shiftMapRows<CellBorderThickness>(
      cellBorders,
      (r, c, v) => newCellBorders[k(r, c)] = v,
    );
    shiftMapRows<CellBorderStyles>(
      cellBorderStyles,
      (r, c, v) => newCellBorderStyles[k(r, c)] = v,
    );
    shiftMapRows<CellPadding>(
      cellPaddings,
      (r, c, v) => newCellPaddings[k(r, c)] = v,
    );

    // 내부 데이터 맵들도 루트 키의 행 인덱스를 시프트
    Map<String, List<String?>> newInternalDelta = {};
    Map<String, List<Map<String, dynamic>?>> newInternalStyles = {};
    Map<String, List<CellPadding?>> newInternalPads = {};
    void shiftInternalRows<K>(
      Map<String, List<K?>> src,
      void Function(int r, int c, List<K?> v) put,
    ) {
      src.forEach((key, value) {
        final rr = _rowFromKey(key);
        final cc = _colFromKey(key);
        if (rr < r0) {
          put(rr, cc, value);
        } else {
          put(rr + n, cc, value);
        }
      });
    }

    shiftInternalRows<String>(
      internalCellDeltaJson,
      (r, c, v) => newInternalDelta[k(r, c)] = List<String?>.from(v),
    );
    shiftInternalRows<Map<String, dynamic>>(
      internalCellStyles,
      (r, c, v) => newInternalStyles[k(r, c)] = v
          .map((e) => e == null ? null : Map<String, dynamic>.from(e))
          .toList(),
    );
    shiftInternalRows<CellPadding>(
      internalCellPaddings,
      (r, c, v) => newInternalPads[k(r, c)] = List<CellPadding?>.from(v),
    );

    // 3) 병합 스팬 재구성: 삽입 경계 내부에 걸친 스팬은 rowSpan 확장, 이후 루트는 아래로 시프트
    final Map<String, CellMergeSpan> updatedSpans = {};
    mergedSpans.forEach((key, sp) {
      final rr = _rowFromKey(key);
      final cc = _colFromKey(key);
      final rEnd = rr + sp.rowSpan - 1;
      if (rr >= r0) {
        updatedSpans[k(rr + n, cc)] = CellMergeSpan(
          rowSpan: sp.rowSpan,
          colSpan: sp.colSpan,
        );
      } else if (r0 >= rr && r0 <= rEnd) {
        updatedSpans[k(rr, cc)] = CellMergeSpan(
          rowSpan: sp.rowSpan + n,
          colSpan: sp.colSpan,
        );
      } else {
        updatedSpans[k(rr, cc)] = sp;
      }
    });

    // 4) 새 인스턴스 생성 및 부모 맵 재작성
    // 4) 새 인스턴스 생성: 표 전체 높이를 삽입된 만큼 늘리고, 상단을 고정하기 위해 중심을 아래로 addedH/2만큼 이동
    final next = copyWith(
      rows: newRows,
      rowFractions: newRowFractions,
      size: Size(size.width, newTotalH),
      position: position + Offset(0, addedH / 2),
      cellDeltaJson: newDeltaJson,
      cellStyles: newCellStyles,
      cellBorders: newCellBorders,
      cellBorderStyles: newCellBorderStyles,
      cellPaddings: newCellPaddings,
    );
    next.mergedSpans
      ..clear()
      ..addAll(updatedSpans);
    next.mergedParents.clear();
    updatedSpans.forEach((key, sp) {
      final rr = _rowFromKey(key);
      final cc = _colFromKey(key);
      for (int r = rr; r < rr + sp.rowSpan; r++) {
        for (int c = cc; c < cc + sp.colSpan; c++) {
          if (r == rr && c == cc) continue;
          next.mergedParents[k(r, c)] = key;
        }
      }
    });

    // 내부 데이터 반영
    next.internalCellDeltaJson
      ..clear()
      ..addAll(newInternalDelta);
    next.internalCellStyles
      ..clear()
      ..addAll(newInternalStyles);
    next.internalCellPaddings
      ..clear()
      ..addAll(newInternalPads);

    // 내부 분할 분율 키도 시프트
    final Map<String, List<double>> shiftedFracs = {};
    internalColFractions.forEach((key, fracs) {
      final rr = _rowFromKey(key);
      final cc = _colFromKey(key);
      if (rr < r0) {
        shiftedFracs[k(rr, cc)] = List<double>.from(fracs);
      } else {
        shiftedFracs[k(rr + n, cc)] = List<double>.from(fracs);
      }
    });
    next.internalColFractions
      ..clear()
      ..addAll(shiftedFracs);

    return next;
  }

  /// 여러 셀을 한 번에 행 삽입합니다. 같은 루트 행(r0)은 한 번만 처리합니다.
  TableDrawable splitRowsAtBatch(List<(int, int)> cells, int count) {
    final n = count;
    if (n <= 0 || rows <= 0 || cells.isEmpty) return this;
    final roots = <int>{};
    for (final cell in cells) {
      final rt = resolveRoot(cell.$1, cell.$2);
      roots.add(rt.$1);
    }
    final ordered = roots.toList()..sort((a, b) => b.compareTo(a)); // 아래에서 위 순서
    TableDrawable cur = this;
    for (final r0 in ordered) {
      cur = cur.splitRowsAt(r0, 0, n); // r0 기준 삽입
    }
    return cur;
  }

  /// 독립 처리: 전달된 셀 각각(루트 기준)을 순차적으로 행 삽입합니다.
  /// - 인접/겹침 여부와 무관하게 독립 동작
  /// - 아래쪽 r0부터 처리하여 인덱스 시프트 영향 최소화
  TableDrawable splitRowsAtEach(List<(int, int)> cells, int count) {
    if (cells.isEmpty || count <= 0 || rows <= 0) return this;
    // 중복 루트 제거
    final roots = <String, (int, int)>{};
    for (final (r, c) in cells) {
      final rt = resolveRoot(r, c);
      roots[_k(rt.$1, rt.$2)] = rt;
    }
    final ordered = roots.values.toList()
      ..sort((a, b) => b.$1.compareTo(a.$1)); // r0 내림차순
    TableDrawable cur = this;
    for (final rt in ordered) {
      cur = cur.splitRowsAt(rt.$1, rt.$2, count);
    }
    return cur;
  }
  // 이전 분할 유틸은 제거됨

  /// 열 분할(단일 셀 전용): 선택된 셀 내부만 N개로 분할하고, 다른 행들은 수평 병합으로 시각을 유지합니다.
  TableDrawable splitColumnsAt(int row, int col, int count) {
    final n = count;
    if (n <= 1 || columns <= 0) return this;
    final root = resolveRoot(row, col);
    final span = spanForRoot(root.$1, root.$2);
    final int c0 = root.$2.clamp(0, math.max(0, columns - 1));
    final int colSpan = span?.colSpan ?? 1;
    final int rTop = root.$1;
    final int rBottom = rTop + (span?.rowSpan ?? 1) - 1;
    // 선택된 셀의 세로 범위만 true인 마스크
    final mask = List<bool>.filled(rows, false);
    final s = rTop.clamp(0, rows - 1);
    final e = rBottom.clamp(0, rows - 1);
    for (int r = s; r <= e; r++) mask[r] = true;
    final next = _splitColRegionWithMask(c0, colSpan, mask, n);
    // 원래 세로 병합(rowSpan>1)이었던 경우에만 동일 세로 범위를 복원
    final int rowSpan = (span?.rowSpan ?? 1);
    if (rowSpan > 1) {
      for (int i = 0; i < n; i++) {
        next.mergeRegion(rTop, c0 + i, rBottom, c0 + i);
      }
    }
    return next;
  }

  /// 비활성화됨: 열 분할은 단일 셀 선택에서만 지원
  TableDrawable splitColumnsAtBatch(List<(int, int)> cells, int count) {
    return this;
  }

  /// 비활성화됨: 열 분할은 단일 셀 선택에서만 지원
  TableDrawable splitColumnsAtEach(List<(int, int)> cells, int count) {
    return this;
  }

  /// 셀 내부 열 분할: 전역 컬럼 수/경계를 바꾸지 않고, 선택한 셀 내부만 N개로 균등 분할한다.
  /// N<=1이면 내부 분할을 해제한다.
  TableDrawable splitColumnsInsideCell(int row, int col, int count) {
    // 새 인스턴스를 만들어 반환함으로써 상위 mutateSelected 경로에서
    // 동일 인스턴스 반환으로 인해 리빌드/리페인트가 누락되는 것을 방지한다.
    final next = copyWith();
    if (count <= 1) {
      final rt = next.resolveRoot(row, col);
      final key = next._k(rt.$1, rt.$2);
      next.internalColFractions.remove(key);
      // 내부 데이터도 함께 제거
      next.internalCellDeltaJson.remove(key);
      next.internalCellStyles.remove(key);
      next.internalCellPaddings.remove(key);
      return next;
    }
    // 내부 분할을 새 인스턴스에 적용
    next.setInternalColumnsEqual(row, col, count);
    return next;
  }

  /// 여러 사각형 영역을 각각 병합합니다(독립 처리).
  TableDrawable mergeRegionsBatch(List<(int, int, int, int)> regions) {
    if (regions.isEmpty) return this;
    TableDrawable cur = this;
    for (final reg in regions) {
      cur = cur..mergeRegion(reg.$1, reg.$2, reg.$3, reg.$4);
    }
    return cur;
  }

  /// 여러 위치를 각각의 루트 기준으로 병합 해제합니다(독립 처리).
  TableDrawable unmergeAtBatch(List<(int, int)> cells) {
    if (cells.isEmpty) return this;
    final roots = <String, (int, int)>{};
    for (final (r, c) in cells) {
      final rt = resolveRoot(r, c);
      roots[_k(rt.$1, rt.$2)] = rt;
    }
    TableDrawable cur = this;
    for (final rt in roots.values) {
      cur = cur..unmergeAt(rt.$1, rt.$2);
    }
    return cur;
  }

  // 내부 유틸: 특정 컬럼 구간 [c0..c1]을 n개로 치환하고, selectedRowsMask가 true인 행만
  // 실제로 분할(복제)되도록 처리. 그 외 행은 수평 병합으로 시각 유지.
  TableDrawable _splitColRegionWithMask(
    int c0,
    int colSpan,
    List<bool> selectedRowsMask,
    int n,
  ) {
    if (n <= 1 || columns <= 0) return this;
    final int c1 = (c0 + colSpan - 1).clamp(0, columns - 1);
    if (c0 < 0 || c0 >= columns) return this;
    final colPx = _colPixels();
    if (colPx.isEmpty) return this;
    // 원래 각 열의 픽셀 폭 수집
    final oldW = <double>[];
    double targetW = 0;
    for (int i = 0; i < colSpan; i++) {
      final w = (c0 + i) < colPx.length ? colPx[c0 + i] : 0.0;
      oldW.add(w);
      targetW += w;
    }
    // 새 n개 서브열을 colSpan개의 그룹으로 배분하여, 각 그룹 합계가 해당 oldW[i]와 정확히 같도록 구성
    double wSum = targetW;
    final rawTargets = [
      for (final w in oldW)
        (wSum > 0 ? (n * w / wSum) : (n / math.max(1, colSpan))),
    ];
    final base = rawTargets.map((v) => v.floor()).toList();
    int assigned = base.fold(0, (a, b) => a + b);
    // 최소 1 보장
    for (int i = 0; i < base.length; i++) {
      if (base[i] < 1) {
        assigned += (1 - base[i]);
        base[i] = 1;
      }
    }
    // 총합을 n에 맞추기
    if (assigned < n) {
      final remainders = List.generate(colSpan, (i) => rawTargets[i] - base[i]);
      final order = List.generate(colSpan, (i) => i)
        ..sort((a, b) => remainders[b].compareTo(remainders[a]));
      int left = n - assigned;
      for (final idx in order) {
        if (left == 0) break;
        base[idx] += 1;
        left -= 1;
      }
    } else if (assigned > n) {
      int over = assigned - n;
      final order = List.generate(colSpan, (i) => i)
        ..sort((a, b) => base[b].compareTo(base[a]));
      for (final idx in order) {
        if (over == 0) break;
        if (base[idx] > 1) {
          base[idx] -= 1;
          over -= 1;
        }
      }
    }
    // 그룹별 서브열 폭 생성: 각 그룹의 서브열 합계가 oldW[i]가 되도록 마지막 서브열에서 보정
    final subWidths = <double>[];
    for (int i = 0; i < colSpan; i++) {
      final cnt = base[i];
      final wTotal = oldW[i];
      if (cnt <= 0) continue;
      final wEach = cnt > 0 ? (wTotal / cnt) : 0.0;
      double acc = 0.0;
      for (int j = 0; j < cnt; j++) {
        if (j < cnt - 1) {
          subWidths.add(wEach);
          acc += wEach;
        } else {
          subWidths.add((wTotal - acc).clamp(0.0, double.infinity));
        }
      }
    }
    final newColPx = <double>[]
      ..addAll(colPx.take(c0))
      ..addAll(subWidths)
      ..addAll(colPx.skip(c1 + 1));
    final int delta = n - (c1 - c0 + 1);
    final int newCols = columns + delta;
    final double w0 = size.width;
    final List<double> newColFractions = newColPx.map((w) => w / w0).toList();

    Map<String, String> newDeltaJson = {};
    Map<String, Map<String, dynamic>> newCellStyles = {};
    Map<String, CellBorderThickness> newCellBorders = {};
    Map<String, CellBorderStyles> newCellBorderStyles = {};
    Map<String, CellPadding> newCellPaddings = {};
    String k(int r, int c) => "$r,$c";
    bool inside(int c) => c >= c0 && c <= c1;
    bool rowSelected(int r) =>
        r >= 0 && r < selectedRowsMask.length && selectedRowsMask[r];

    void copyMapColScoped<K>(
      Map<String, K> src,
      void Function(int r, int c, K v) put,
    ) {
      src.forEach((key, value) {
        final rr = _rowFromKey(key);
        final cc = _colFromKey(key);
        if (cc < c0) {
          put(rr, cc, value);
        } else if (inside(cc)) {
          final int offset = cc - c0; // 0..(colSpan-1)
          final bool selectedRow = rowSelected(rr);
          if (src == cellDeltaJson) {
            if (selectedRow) {
              // 선택 행: 내용은 첫 번째 새 열에만 유지
              put(rr, c0, value);
            } else {
              // 비선택 행: 기존 각 열을 새 구간의 동일한 오프셋 위치에 보존
              put(rr, c0 + offset, value);
            }
          } else {
            if (selectedRow) {
              // 선택 행: 스타일/테두리/패딩은 모든 새 열에 복제
              for (int i = 0; i < n; i++) {
                put(rr, c0 + i, value);
              }
            } else {
              // 비선택 행: 기존 각 열을 새 구간의 동일한 오프셋 위치에 보존
              put(rr, c0 + offset, value);
            }
          }
        } else {
          put(rr, cc + delta, value);
        }
      });
    }

    copyMapColScoped<String>(
      cellDeltaJson,
      (r, c, v) => newDeltaJson[k(r, c)] = v,
    );
    copyMapColScoped<Map<String, dynamic>>(
      cellStyles,
      (r, c, v) => newCellStyles[k(r, c)] = v,
    );
    copyMapColScoped<CellBorderThickness>(
      cellBorders,
      (r, c, v) => newCellBorders[k(r, c)] = v,
    );
    copyMapColScoped<CellBorderStyles>(
      cellBorderStyles,
      (r, c, v) => newCellBorderStyles[k(r, c)] = v,
    );
    copyMapColScoped<CellPadding>(
      cellPaddings,
      (r, c, v) => newCellPaddings[k(r, c)] = v,
    );

    // 내부 데이터의 루트 키도 같은 규칙으로 이동
    final Map<String, List<String?>> newInternalDelta = {};
    final Map<String, List<Map<String, dynamic>?>> newInternalStyles = {};
    final Map<String, List<CellPadding?>> newInternalPads = {};
    internalCellDeltaJson.forEach((key, list) {
      final rr = _rowFromKey(key);
      final cc = _colFromKey(key);
      if (cc < c0) {
        newInternalDelta[k(rr, cc)] = List<String?>.from(list);
      } else if (inside(cc)) {
        final int offset = cc - c0;
        newInternalDelta[k(rr, c0 + offset)] = List<String?>.from(list);
      } else {
        newInternalDelta[k(rr, cc + delta)] = List<String?>.from(list);
      }
    });
    internalCellStyles.forEach((key, list) {
      final rr = _rowFromKey(key);
      final cc = _colFromKey(key);
      if (cc < c0) {
        newInternalStyles[k(rr, cc)] = list
            .map((e) => e == null ? null : Map<String, dynamic>.from(e))
            .toList();
      } else if (inside(cc)) {
        final int offset = cc - c0;
        newInternalStyles[k(rr, c0 + offset)] = list
            .map((e) => e == null ? null : Map<String, dynamic>.from(e))
            .toList();
      } else {
        newInternalStyles[k(rr, cc + delta)] = list
            .map((e) => e == null ? null : Map<String, dynamic>.from(e))
            .toList();
      }
    });
    internalCellPaddings.forEach((key, list) {
      final rr = _rowFromKey(key);
      final cc = _colFromKey(key);
      if (cc < c0) {
        newInternalPads[k(rr, cc)] = List<CellPadding?>.from(list);
      } else if (inside(cc)) {
        final int offset = cc - c0;
        newInternalPads[k(rr, c0 + offset)] = List<CellPadding?>.from(list);
      } else {
        newInternalPads[k(rr, cc + delta)] = List<CellPadding?>.from(list);
      }
    });

    // 내부 분할 분율 키 이동
    final Map<String, List<double>> newInternalFracs = {};
    internalColFractions.forEach((key, fracs) {
      final rr = _rowFromKey(key);
      final cc = _colFromKey(key);
      if (cc < c0) {
        newInternalFracs[k(rr, cc)] = List<double>.from(fracs);
      } else if (inside(cc)) {
        final int offset = cc - c0;
        newInternalFracs[k(rr, c0 + offset)] = List<double>.from(fracs);
      } else {
        newInternalFracs[k(rr, cc + delta)] = List<double>.from(fracs);
      }
    });

    final Map<String, CellMergeSpan> newMergedSpans = {};
    final Map<String, String> newMergedParents = {};
    mergedSpans.forEach((key, span0) {
      final rr = _rowFromKey(key);
      final cc = _colFromKey(key);
      final oldEnd = cc + span0.colSpan - 1;
      if (oldEnd < c0) {
        newMergedSpans[k(rr, cc)] = span0;
      } else if (cc > c1) {
        newMergedSpans[k(rr, cc + delta)] = span0;
      }
      // 겹치는 경우는 재구성 대상이므로 스킵
    });
    mergedParents.forEach((key, parent) {
      final rr = _rowFromKey(key);
      final cc = _colFromKey(key);
      final pr = _rowFromKey(parent);
      final pc = _colFromKey(parent);
      final pSpan = mergedSpans[parent];
      if (pSpan == null) return;
      final pEnd = pc + pSpan.colSpan - 1;
      if (pEnd < c0) {
        newMergedParents[k(rr, cc)] = k(pr, pc);
      } else if (pc > c1) {
        newMergedParents[k(rr, cc + delta)] = k(pr, pc + delta);
      }
    });

    final next = copyWith(
      columns: newCols,
      columnFractions: newColFractions,
      cellDeltaJson: newDeltaJson,
      cellStyles: newCellStyles,
      cellBorders: newCellBorders,
      cellBorderStyles: newCellBorderStyles,
      cellPaddings: newCellPaddings,
    );
    next.mergedSpans
      ..clear()
      ..addAll(newMergedSpans);
    next.mergedParents
      ..clear()
      ..addAll(newMergedParents);

    // 내부 데이터 반영
    next.internalCellDeltaJson
      ..clear()
      ..addAll(newInternalDelta);
    next.internalCellStyles
      ..clear()
      ..addAll(newInternalStyles);
    next.internalCellPaddings
      ..clear()
      ..addAll(newInternalPads);
    next.internalColFractions
      ..clear()
      ..addAll(newInternalFracs);

    // 비선택 행의 "구간 내부에 완전히 포함된" 기존 가로 병합은 동일 오프셋으로 복원하여 시각 유지
    mergedSpans.forEach((key, span0) {
      final rr = _rowFromKey(key);
      final cc = _colFromKey(key);
      final oldEnd = cc + span0.colSpan - 1;
      final bool insideRegion = cc >= c0 && oldEnd <= c1;
      if (insideRegion && !rowSelected(rr)) {
        final int newCc = c0 + (cc - c0);
        final int newEnd = newCc + span0.colSpan - 1;
        final int rEnd = rr + span0.rowSpan - 1;
        next.mergeRegion(rr, newCc, rEnd, newEnd);
      }
    });

    // 비선택 행에 대해: 분할로 생긴 n개의 새 열을 원래 colSpan 조각 수만큼 묶어서
    // 각 원래 열에 해당하는 서브그룹으로 수평 병합하여 기존 시각(분할 개수) 유지
    if (columns > 0 && n > 1 && colSpan > 0) {
      // 원래 각 열의 폭 비율대로 새 열 개수를 배분 (최소 1개 보장)
      final oldWidths = <double>[];
      double wSum = 0.0;
      for (int i = 0; i < colSpan; i++) {
        final w = (c0 + i) < colPx.length ? colPx[c0 + i] : 0.0;
        oldWidths.add(w);
        wSum += w;
      }
      // 초기 배분은 바닥 값, 남는 몫은 소수점 큰 순으로 분배
      final rawTargets = [
        for (final w in oldWidths) (wSum > 0 ? (n * w / wSum) : (n / colSpan)),
      ];
      final base = rawTargets.map((v) => v.floor()).toList();
      int assigned = base.fold(0, (a, b) => a + b);
      // 최소 1 보장
      for (int i = 0; i < base.length; i++) {
        if (base[i] < 1) {
          assigned += (1 - base[i]);
          base[i] = 1;
        }
      }
      // 총합을 n에 맞추기
      if (assigned < n) {
        final remainders = List.generate(
          colSpan,
          (i) => rawTargets[i] - base[i],
        );
        final order = List.generate(colSpan, (i) => i)
          ..sort((a, b) => remainders[b].compareTo(remainders[a]));
        int left = n - assigned;
        for (final idx in order) {
          if (left == 0) break;
          base[idx] += 1;
          left -= 1;
        }
      } else if (assigned > n) {
        // 너무 많이 배분된 경우, 남는 만큼 1 이상인 곳에서 줄임
        int over = assigned - n;
        final order = List.generate(colSpan, (i) => i)
          ..sort((a, b) => base[b].compareTo(base[a]));
        for (final idx in order) {
          if (over == 0) break;
          if (base[idx] > 1) {
            base[idx] -= 1;
            over -= 1;
          }
        }
      }
      // 누적하여 각 원래 열의 서브구간 범위 계산 후, 비선택 행에만 병합 적용
      final starts = <int>[];
      int acc = c0;
      for (int i = 0; i < base.length; i++) {
        starts.add(acc);
        acc += base[i];
      }
      for (int rr = 0; rr < rows; rr++) {
        if (rowSelected(rr)) continue;
        for (int i = 0; i < base.length; i++) {
          final sCol = starts[i];
          final eCol = sCol + base[i] - 1;
          if (eCol > sCol) {
            next.mergeRegion(rr, sCol, rr, eCol);
          }
        }
      }
    }

    // 다른 행은 그 외 변경하지 않음(자동 수평 병합 제거)
    return next;
  }
}
