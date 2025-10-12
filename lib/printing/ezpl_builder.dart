import 'dart:math' as math;
import 'dart:convert';

import '../models/barcode.dart';
import 'package:flutter/material.dart';

import '../drawables/barcode_drawable.dart';
import '../drawables/constrained_text_drawable.dart';
import '../drawables/image_box_drawable.dart';
import '../drawables/table_drawable.dart';
import '../flutter_painter_v2/controllers/drawables/drawable.dart';
import '../flutter_painter_v2/controllers/drawables/image_drawable.dart';
import '../flutter_painter_v2/controllers/drawables/path/erase_drawable.dart';
import '../flutter_painter_v2/controllers/drawables/path/free_style_drawable.dart';
import '../flutter_painter_v2/controllers/drawables/shape/arrow_drawable.dart';
import '../flutter_painter_v2/controllers/drawables/shape/double_arrow_drawable.dart';
import '../flutter_painter_v2/controllers/drawables/shape/line_drawable.dart';
import '../flutter_painter_v2/controllers/drawables/shape/oval_drawable.dart';
import '../flutter_painter_v2/controllers/drawables/shape/rectangle_drawable.dart';
import '../flutter_painter_v2/controllers/drawables/text_drawable.dart';

class EzplBuildResult {
  final String commands;
  final bool fullyVector;

  const EzplBuildResult({required this.commands, required this.fullyVector});
}

class EzplBuilder {
  EzplBuilder({
    required this.labelSizeDots,
    required this.sourceSize,
    required this.dpi,
  });

  final Size labelSizeDots;
  final Size sourceSize;
  final double dpi;
  // When true, we should prefer raster fallback (e.g., background fills not supported in EZPL vector path)
  bool _requiresRaster = false;

  double get _scaleX => labelSizeDots.width / sourceSize.width;
  double get _scaleY => labelSizeDots.height / sourceSize.height;

  EzplBuildResult build(Iterable<Drawable> drawables) {
    // Special-case: EZPL Micro QR (W command) when the page has only a single Micro QR barcode.
    final visible = [
      for (final d in drawables)
        if (!d.hidden) d,
    ];
    if (visible.length == 1 && visible.first is BarcodeDrawable) {
      final b = visible.first as BarcodeDrawable;
      if (b.type == BarcodeType.MicroQrCode && _isAxisAligned(b.rotationAngle)) {
        final commands = _buildEzplMicroQrStandalone(b);
        if (commands != null && commands.isNotEmpty) {
          return EzplBuildResult(commands: commands, fullyVector: true);
        }
      }
    }

    // EZPL framing
    final double heightMm = labelSizeDots.height / dpi * 25.4;
    final int qHeightMm = heightMm.isFinite && heightMm > 0 ? heightMm.round() : 50;
    final buffer = StringBuffer()
      ..write('^Q$qHeightMm,0,0\r\n')
      ..write('^L\r\n');

    bool allSupported = true;
    for (final drawable in drawables) {
      if (drawable.hidden) continue;
      final segment = _encodeDrawable(drawable);
      if (segment == null) {
        allSupported = false;
        break;
      }
      if (segment.isNotEmpty) {
        buffer.write(segment);
      }
    }

    buffer.write('E\r\n');

    return EzplBuildResult(
      commands: buffer.toString(),
      // If any drawable was unsupported or vector path can't represent something (e.g., backgrounds),
      // mark as not fully vector so callers can default to raster.
      fullyVector: allSupported && !_requiresRaster,
    );
  }

  // Build an EZPL label using the W command for Micro QR, when the page contains only this barcode.
  String? _buildEzplMicroQrStandalone(BarcodeDrawable b) {
    // Compute label height in millimeters for ^Q parameter (approximation)
    final double heightMm = labelSizeDots.height / dpi * 25.4;
    final int qHeightMm = heightMm.isFinite && heightMm > 0 ? heightMm.round() : 50;

    // Compute top-left in dots
    final size = b.size;
    final center = b.position;
    final topLeft = center - Offset(size.width / 2, size.height / 2);
    final int x = _x(topLeft.dx);
    final int y = _y(topLeft.dy);

    // Rotation mapping: 0,90,180,270 -> 0,1,2,3
    int rotationIndex = 0;
    final a = (_normalizeAngle(b.rotationAngle)).abs();
    if ((a - (math.pi / 2)).abs() < 0.0001) rotationIndex = 1;
    if ((a - math.pi).abs() < 0.0001) rotationIndex = 2;
    if ((a - (3 * math.pi / 2)).abs() < 0.0001) rotationIndex = 3;

  // Module size: use drawable override if provided, else derive from width
  int module = b.microModule ?? (_w(size.width) / 32).round();
  module = math.max(2, math.min(10, module));

    // Data length in bytes
    final data = _sanitizeBarcodeData(b.data);
    final int len = utf8.encode(data).length;

    // EZPL Micro QR constraints
    // mode=1 (auto), type=3 (Micro QR), ec=M (H not supported), mask=0 as required
    const int mode = 1;
    const int type = 3;
    const String ec = 'M';
    const int mask = 0;

    final sb = StringBuffer()
      ..write('^Q$qHeightMm,0,0\r\n')
      ..write('^L\r\n')
      ..write('W$x,$y,$mode,$type,$ec,$mask,$module,$len,$rotationIndex\r\n')
      ..write('$data\r\n')
      ..write('E\r\n');
    return sb.toString();
  }

  int _x(double value) => (value * _scaleX).round();
  int _y(double value) => (value * _scaleY).round();
  int _w(double value) => math.max(1, (value * _scaleX).round());
  int _h(double value) => math.max(1, (value * _scaleY).round());
  int _avgStroke(double value) =>
      math.max(1, (value * (_scaleX + _scaleY) / 2).round());

  String? _encodeDrawable(Drawable drawable) {
    if (drawable is RectangleDrawable) {
      return _encodeRectangleEzpl(drawable);
    }
    if (drawable is OvalDrawable) {
      return null; // not supported in EZPL vector path currently
    }
    if (drawable is LineDrawable) {
      return _encodeLineEzpl(
        drawable.position,
        drawable.length,
        drawable.rotationAngle,
        drawable.paint.strokeWidth,
      );
    }
    if (drawable is ArrowDrawable) {
      return _encodeLineEzpl(
        drawable.position,
        drawable.length,
        drawable.rotationAngle,
        drawable.paint.strokeWidth,
      );
    }
    if (drawable is DoubleArrowDrawable) {
      return _encodeLineEzpl(
        drawable.position,
        drawable.length,
        drawable.rotationAngle,
        drawable.paint.strokeWidth,
      );
    }
    if (drawable is ConstrainedTextDrawable) {
      return _encodeConstrainedTextEzpl(drawable);
    }
    if (drawable is TextDrawable) {
      return _encodeTextEzpl(drawable);
    }
    if (drawable is BarcodeDrawable) {
      return _encodeBarcodeEzpl(drawable);
    }
    if (drawable is TableDrawable) {
      return _encodeTableEzpl(drawable);
    }
    if (drawable is FreeStyleDrawable ||
        drawable is EraseDrawable ||
        drawable is ImageBoxDrawable ||
        drawable is ImageDrawable) {
      return null;
    }
    return null;
  }

  String? _encodeTableEzpl(TableDrawable table) {
    // 테이블은 회전 없이 축 정렬일 때만 벡터로 출력 지원
    if (!_isAxisAligned(table.rotationAngle)) return null;

    // 테이블의 박스 위치/크기(도트 단위)
    final size = table.size;
    final center = table.position;
    final topLeft = center - Offset(size.width / 2, size.height / 2);
    final left = _x(topLeft.dx);
    final top = _y(topLeft.dy);
    final width = _w(size.width);
    final height = _h(size.height);

    if (width <= 0 || height <= 0 || table.rows <= 0 || table.columns <= 0) {
      return '';
    }

    // 누적 분할 경계(정수 도트) 계산 - 합이 정확히 width/height가 되도록 누적 비율 기반으로 산출
    List<int> _buildStops(int start, int totalLen, List<double> fractions) {
      final sum = fractions.fold<double>(0.0, (a, b) => a + b);
      final norm = sum == 0
          ? fractions
          : fractions.map((f) => f / sum).toList();
      final stops = <int>[start];
      double acc = 0;
      for (int i = 0; i < norm.length; i++) {
        acc += norm[i] * totalLen;
        int pos = start + acc.round();
        // 경계가 감소하지 않도록 보정
        if (pos <= stops.last) pos = stops.last + 1;
        stops.add(pos);
      }
      // 마지막 경계는 정확히 start + totalLen에 맞춤(초과/부족 보정)
      stops[stops.length - 1] = start + totalLen;
      return stops;
    }

    final xs = _buildStops(left, width, table.columnFractions);
    final ys = _buildStops(top, height, table.rowFractions);

    final sb = StringBuffer();

    // 보더 그리기 유틸리티
    void _drawSolidH(int x1, int x2, int y, int stroke) {
      if (x2 <= x1 || stroke <= 0) return;
      sb.write('La,$x1,$y,$x2,$y\r\n');
    }

    void _drawSolidV(int x, int y1, int y2, int stroke) {
      if (y2 <= y1 || stroke <= 0) return;
      sb.write('La,$x,$y1,$x,$y2\r\n');
    }

    void _drawDashedH(int x1, int x2, int y, int stroke) {
      if (x2 <= x1 || stroke <= 0) return;
      // EZPL doesn't have dashed primitive directly; approximate with small segments
      final total = x2 - x1;
      final dash = math.max(6, (stroke * 6).round());
      final gap = math.max(4, (stroke * 3).round());
      int offset = 0;
      while (offset < total) {
        final seg = math.min(dash, total - offset);
        if (seg <= 0) break;
        _drawSolidH(x1 + offset, x1 + offset + seg, y, stroke);
        offset += dash + gap;
      }
    }

    void _drawDashedV(int x, int y1, int y2, int stroke) {
      if (y2 <= y1 || stroke <= 0) return;
      final total = y2 - y1;
      final dash = math.max(6, (stroke * 6).round());
      final gap = math.max(4, (stroke * 3).round());
      int offset = 0;
      while (offset < total) {
        final seg = math.min(dash, total - offset);
        if (seg <= 0) break;
        _drawSolidV(x, y1 + offset, y1 + offset + seg, stroke);
        offset += dash + gap;
      }
    }

    bool _sameMergeRoot(int r1, int c1, int r2, int c2) {
      final a = table.resolveRoot(r1, c1);
      final b = table.resolveRoot(r2, c2);
      return a.$1 == b.$1 && a.$2 == b.$2;
    }

    // 수평 에지: 각 행 경계 i(0..rows)에서 열별 세그먼트 출력
    for (int i = 0; i <= table.rows - 0; i++) {
      if (i < 0 || i > table.rows) continue;
      final y = ys[i];
      for (int c = 0; c < table.columns; c++) {
        final x1 = xs[c];
        final x2 = xs[c + 1];

        double thick = 0;
        bool dashed = false;
        if (i == 0) {
          // 최상단: 위쪽 보더
          final t = table.borderOf(0, c).top;
          final s = table.borderStyleOf(0, c).top;
          thick = math.max(thick, t);
          dashed = dashed || (s == CellBorderStyle.dashed);
        } else if (i == table.rows) {
          // 최하단: 아래쪽 보더
          final t = table.borderOf(table.rows - 1, c).bottom;
          final s = table.borderStyleOf(table.rows - 1, c).bottom;
          thick = math.max(thick, t);
          dashed = dashed || (s == CellBorderStyle.dashed);
        } else {
          // 내부 경계: 위/아래 셀을 본다. 같은 머지 루트면 내부선 생략
          if (_sameMergeRoot(i - 1, c, i, c)) {
            continue;
          }
          final tTop = table.borderOf(i - 1, c).bottom;
          final tBot = table.borderOf(i, c).top;
          final sTop = table.borderStyleOf(i - 1, c).bottom;
          final sBot = table.borderStyleOf(i, c).top;
          thick = math.max(tTop, tBot);
          dashed =
              (sTop == CellBorderStyle.dashed) ||
              (sBot == CellBorderStyle.dashed);
        }

        final stroke = _avgStroke(thick);
        if (stroke <= 0) continue;
        if (dashed) {
          _drawDashedH(x1, x2, y, stroke);
        } else {
          _drawSolidH(x1, x2, y, stroke);
        }
      }
    }

    // 수직 에지: 각 열 경계 j(0..columns)에서 행별 세그먼트 출력
    for (int j = 0; j <= table.columns - 0; j++) {
      if (j < 0 || j > table.columns) continue;
      final x = xs[j];
      for (int r = 0; r < table.rows; r++) {
        final y1 = ys[r];
        final y2 = ys[r + 1];

        double thick = 0;
        bool dashed = false;
        if (j == 0) {
          // 좌측 외곽
          final t = table.borderOf(r, 0).left;
          final s = table.borderStyleOf(r, 0).left;
          thick = math.max(thick, t);
          dashed = dashed || (s == CellBorderStyle.dashed);
        } else if (j == table.columns) {
          // 우측 외곽
          final t = table.borderOf(r, table.columns - 1).right;
          final s = table.borderStyleOf(r, table.columns - 1).right;
          thick = math.max(thick, t);
          dashed = dashed || (s == CellBorderStyle.dashed);
        } else {
          // 내부 경계: 좌/우 셀 비교. 같은 머지 루트면 내부선 생략
          if (_sameMergeRoot(r, j - 1, r, j)) {
            continue;
          }
          final tL = table.borderOf(r, j - 1).right;
          final tR = table.borderOf(r, j).left;
          final sL = table.borderStyleOf(r, j - 1).right;
          final sR = table.borderStyleOf(r, j).left;
          thick = math.max(tL, tR);
          dashed =
              (sL == CellBorderStyle.dashed) || (sR == CellBorderStyle.dashed);
        }

        final stroke = _avgStroke(thick);
        if (stroke <= 0) continue;
        if (dashed) {
          _drawDashedV(x, y1, y2, stroke);
        } else {
          _drawSolidV(x, y1, y2, stroke);
        }
      }
    }

    // === 셀/서브셀 컨텐츠 및 배경 ===
    // helper: 셀 루트 여부
    bool _isRoot(int r, int c) {
      final rt = table.resolveRoot(r, c);
      return rt.$1 == r && rt.$2 == c;
    }

    // alignment is not mapped in this EZPL text path; ignored for now

    // helper: plain text from quill delta json
    String _plainFromDelta(String? jsonStr) {
      if (jsonStr == null || jsonStr.isEmpty) return '';
      try {
        final decoded = json.decode(jsonStr);
        final List ops;
        if (decoded is List) {
          ops = decoded.cast<dynamic>();
        } else if (decoded is Map && decoded['ops'] is List) {
          ops = (decoded['ops'] as List).cast<dynamic>();
        } else {
          return '';
        }
        final buf = StringBuffer();
        for (final op in ops) {
          if (op is Map && op['insert'] != null) {
            buf.write(op['insert'].toString());
          }
        }
        return _sanitizeText(buf.toString());
      } catch (_) {
        return '';
      }
    }

    // 반복: 루트 셀 단위로 컨텐츠 인코딩
    for (int r = 0; r < table.rows; r++) {
      for (int c = 0; c < table.columns; c++) {
        if (!_isRoot(r, c)) continue;
        final span = table.spanForRoot(r, c);
        final rowSpan = span?.rowSpan ?? 1;
        final colSpan = span?.colSpan ?? 1;

        // 셀의 도트 좌표(rect)
        final int leftDot = xs[c];
        final int rightDot = xs[c + colSpan];
        final int topDot = ys[r];
        final int bottomDot = ys[r + rowSpan];
        final int cellW = rightDot - leftDot;
        final int cellH = bottomDot - topDot;
        if (cellW <= 0 || cellH <= 0) continue;

        // 내부 분할 여부 판단
  final innerFracs = table.internalFractionsOf(r, c);
  final bool hasInner = innerFracs != null && innerFracs.length > 1;

        if (hasInner) {
          // 내부 서브셀 폭 경계(도트)
          final innerStops = () {
            final fracs = innerFracs; // not null when hasInner == true
            final sum = fracs.fold<double>(0.0, (a, b) => a + b);
            final fr = sum == 0 ? fracs : fracs.map((f) => f / sum).toList();
            final stops = <int>[leftDot];
            double acc = 0;
            for (int i = 0; i < fr.length; i++) {
              acc += fr[i] * cellW;
              int pos = leftDot + acc.round();
              if (pos <= stops.last) pos = stops.last + 1;
              stops.add(pos);
            }
            stops[stops.length - 1] = rightDot;
            return stops;
          }();

          for (int i = 0; i < innerFracs.length; i++) {
            final subL = innerStops[i];
            final subR = innerStops[i + 1];
            final subT = topDot;
            final subB = bottomDot;
            final subW = subR - subL;
            final subH = subB - subT;
            if (subW <= 0 || subH <= 0) continue;

            // 배경색 (내부 스타일의 bgColor 우선)
            final subStyle = table.internalStyleOf(r, c, i);
            final bgVal = subStyle['bgColor'];
            if (bgVal is int) {
              final color = Color(bgVal);
              if (color.a > 0) {
                // EZPL: no direct fill primitive here; request raster fallback
                _requiresRaster = true;
              }
            }

            // 텍스트 컨텐츠
            final padding = table.internalPaddingOf(r, c, i);
            final int padL = _w(padding.left);
            final int padT = _h(padding.top);
            final int padR = _w(padding.right);
            final int padB = _h(padding.bottom);
            final int textL = subL + padL;
            final int textT = subT + padT;
            final int textW = subW - padL - padR;
            final int textH = subH - padT - padB;
            if (textW <= 0 || textH <= 0) continue;
            final String content = _plainFromDelta(
              table.internalDeltaJsonOf(r, c, i),
            );
            if (content.isEmpty) continue;
            final double fs = (subStyle['fontSize'] as double?) ?? 12.0;
            final int fontH = math.max(10, _h(fs));
            final int fontW = math.max(1, (fontH * 0.6).round());
            // EZPL AT: x,y,w,h,g,s,d,m,data (rough mapping; alignment ignored)
            sb.write('AT,$textL,$textT,$fontW,$fontH,0,0,0,0,$content\r\n');
          }
        } else {
          // 셀 배경
          final bg = table.backgroundColorOf(r, c);
          if (bg != null && bg.a > 0) {
            // EZPL: no direct fill primitive here; request raster fallback
            _requiresRaster = true;
          }

          // 텍스트 컨텐츠
          final padding = table.paddingOf(r, c);
          final int padL = _w(padding.left);
          final int padT = _h(padding.top);
          final int padR = _w(padding.right);
          final int padB = _h(padding.bottom);
          final int textL = leftDot + padL;
          final int textT = topDot + padT;
          final int textW = cellW - padL - padR;
          final int textH = cellH - padT - padB;
          if (textW > 0 && textH > 0) {
            final String content = _plainFromDelta(table.deltaJson(r, c));
            if (content.isNotEmpty) {
              final style = table.styleOf(r, c);
              final double fs = (style['fontSize'] as double?) ?? 12.0;
              final int fontH = math.max(10, _h(fs));
              final int fontW = math.max(1, (fontH * 0.6).round());
              sb.write('AT,$textL,$textT,$fontW,$fontH,0,0,0,0,$content\r\n');
            }
          }
        }
      }
    }

    return sb.toString();
  }
  String? _encodeRectangleEzpl(RectangleDrawable rect) {
    if (!_isAxisAligned(rect.rotationAngle)) return null;
    final size = rect.size;
    final center = rect.position;
    final topLeft = center - Offset(size.width / 2, size.height / 2);
    final left = _x(topLeft.dx);
    final top = _y(topLeft.dy);
    final right = left + _w(size.width);
    final bottom = top + _h(size.height);
    // Stroke width ignored; EZPL La draws 1-pixel lines typically; approximate with 1
    return 'Rx,$left,$top,$right,$bottom,1,0\r\n';
  }

  String? _encodeLineEzpl(
    Offset center,
    double length,
    double angle,
    double strokeWidth,
  ) {
    final half = length / 2;
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    final start = center - Offset(cos * half, sin * half);
    final end = center + Offset(cos * half, sin * half);
    final x1 = _x(start.dx);
    final y1 = _y(start.dy);
    final x2 = _x(end.dx);
    final y2 = _y(end.dy);
    return 'La,$x1,$y1,$x2,$y2\r\n';
  }

  String? _encodeConstrainedTextEzpl(ConstrainedTextDrawable text) {
    if (!_isAxisAligned(text.rotationAngle)) return null;
    if (text.text.isEmpty) return '';
    final size = text.getSize();
    final center = text.position;
    final topLeft = center - Offset(size.width / 2, size.height / 2);
    final left = _x(topLeft.dx);
    final top = _y(topLeft.dy);
    final content = _sanitizeText(text.text);
    final height = math.max(10, _h(text.style.fontSize ?? 12));
    final width = math.max(1, (height * 0.6).round());
    return 'AT,$left,$top,$width,$height,0,0,0,0,$content\r\n';
  }

  String? _encodeTextEzpl(TextDrawable text) {
    if (!_isAxisAligned(text.rotationAngle)) return null;
    if (text.text.isEmpty) return '';
    final size = text.getSize();
    final center = text.position;
    final topLeft = center - Offset(size.width / 2, size.height / 2);
    final left = _x(topLeft.dx);
    final top = _y(topLeft.dy);
    final content = _sanitizeText(text.text);
    final height = math.max(10, _h(text.style.fontSize ?? 12));
    final width = math.max(1, (height * 0.6).round());
    return 'AT,$left,$top,$width,$height,0,0,0,0,$content\r\n';
  }

  String? _encodeBarcodeEzpl(BarcodeDrawable barcode) {
    if (!_isAxisAligned(barcode.rotationAngle)) return null;
    if (barcode.data.isEmpty) return null;

    final center = barcode.position;
    final topLeft =
        center - Offset(barcode.size.width / 2, barcode.size.height / 2);
    final left = _x(topLeft.dx);
    final top = _y(topLeft.dy);
    final width = _w(barcode.size.width);
    final height = _h(barcode.size.height);
    final String data = _sanitizeBarcodeData(
      BarcodeDataHelper.normalizeForPrint(barcode.type, barcode.data),
    );
    switch (barcode.type) {
      case BarcodeType.QrCode:
        {
          // Use W command with type=2 (QR), ec=M, mask=0, mode=1
          final a = (_normalizeAngle(barcode.rotationAngle)).abs();
          int rotationIndex = 0;
          if ((a - (math.pi / 2)).abs() < 0.0001) rotationIndex = 1;
          if ((a - math.pi).abs() < 0.0001) rotationIndex = 2;
          if ((a - (3 * math.pi / 2)).abs() < 0.0001) rotationIndex = 3;
          final int module = math.max(2, math.min(10, (width / 32).round()));
          final int len = utf8.encode(data).length;
          return 'W$left,$top,1,2,M,0,$module,$len,$rotationIndex\r\n$data\r\n';
        }
      case BarcodeType.MicroQrCode:
        {
          final a = (_normalizeAngle(barcode.rotationAngle)).abs();
          int rotationIndex = 0;
          if ((a - (math.pi / 2)).abs() < 0.0001) rotationIndex = 1;
          if ((a - math.pi).abs() < 0.0001) rotationIndex = 2;
          if ((a - (3 * math.pi / 2)).abs() < 0.0001) rotationIndex = 3;
          int module = barcode.microModule ?? (width / 32).round();
          module = math.max(2, math.min(10, module));
          final int len = utf8.encode(data).length;
          return 'W$left,$top,1,3,M,0,$module,$len,$rotationIndex\r\n$data\r\n';
        }
      case BarcodeType.DataMatrix:
        {
          final int enlarge = math.max(1, math.min(20, (math.min(width, height) / 12).round()));
          // XRBx,y,enlarge,rotation,length<CR>data
          final a = (_normalizeAngle(barcode.rotationAngle)).abs();
          int rotationIndex = 0;
          if ((a - (math.pi / 2)).abs() < 0.0001) rotationIndex = 1;
          if ((a - math.pi).abs() < 0.0001) rotationIndex = 2;
          if ((a - (3 * math.pi / 2)).abs() < 0.0001) rotationIndex = 3;
          final int len = utf8.encode(data).length;
          return 'XRB$left,$top,$enlarge,$rotationIndex,$len\r\n$data\r\n';
        }
      case BarcodeType.Code128:
        {
          final a = (_normalizeAngle(barcode.rotationAngle)).abs();
          int rotationIndex = 0;
          if ((a - (math.pi / 2)).abs() < 0.0001) rotationIndex = 1;
          if ((a - math.pi).abs() < 0.0001) rotationIndex = 2;
          if ((a - (3 * math.pi / 2)).abs() < 0.0001) rotationIndex = 3;
          final int narrow = math.max(1, (width / 120).round());
          final int wide = math.max(narrow * 3, 3);
          final int h = math.max(20, height);
          final int readable = barcode.showValue ? 1 : 0;
          // BC,x,y,narrow,wide,height,rotation,readable,data
          return 'BC,$left,$top,$narrow,$wide,$h,$rotationIndex,$readable,$data\r\n';
        }
      case BarcodeType.Code39:
        {
          final a = (_normalizeAngle(barcode.rotationAngle)).abs();
          int rotationIndex = 0;
          if ((a - (math.pi / 2)).abs() < 0.0001) rotationIndex = 1;
          if ((a - math.pi).abs() < 0.0001) rotationIndex = 2;
          if ((a - (3 * math.pi / 2)).abs() < 0.0001) rotationIndex = 3;
          final int narrow = math.max(1, (width / 120).round());
          final int wide = math.max(narrow * 3, 3);
          final int h = math.max(20, height);
          final int readable = barcode.showValue ? 1 : 0;
          // B3,x,y,narrow,wide,height,rotation,readable,data
          return 'B3,$left,$top,$narrow,$wide,$h,$rotationIndex,$readable,$data\r\n';
        }
      case BarcodeType.Code93:
        {
          final a = (_normalizeAngle(barcode.rotationAngle)).abs();
          int rotationIndex = 0;
          if ((a - (math.pi / 2)).abs() < 0.0001) rotationIndex = 1;
          if ((a - math.pi).abs() < 0.0001) rotationIndex = 2;
          if ((a - (3 * math.pi / 2)).abs() < 0.0001) rotationIndex = 3;
          final int narrow = math.max(1, (width / 120).round());
          final int wide = math.max(narrow * 3, 3);
          final int h = math.max(20, height);
          final int readable = barcode.showValue ? 1 : 0;
          // BA,x,y,narrow,wide,height,rotation,readable,data
          return 'BA,$left,$top,$narrow,$wide,$h,$rotationIndex,$readable,$data\r\n';
        }
      case BarcodeType.CodeEAN13:
        {
          final a = (_normalizeAngle(barcode.rotationAngle)).abs();
          int rotationIndex = 0;
          if ((a - (math.pi / 2)).abs() < 0.0001) rotationIndex = 1;
          if ((a - math.pi).abs() < 0.0001) rotationIndex = 2;
          if ((a - (3 * math.pi / 2)).abs() < 0.0001) rotationIndex = 3;
          final int narrow = math.max(1, (width / 150).round());
          final int wide = math.max(narrow * 3, 3);
          final int h = math.max(30, height);
          final int readable = barcode.showValue ? 1 : 0;
          // BE,x,y,narrow,wide,height,rotation,readable,data
          return 'BE,$left,$top,$narrow,$wide,$h,$rotationIndex,$readable,$data\r\n';
        }
      case BarcodeType.CodeEAN8:
        {
          final a = (_normalizeAngle(barcode.rotationAngle)).abs();
          int rotationIndex = 0;
          if ((a - (math.pi / 2)).abs() < 0.0001) rotationIndex = 1;
          if ((a - math.pi).abs() < 0.0001) rotationIndex = 2;
          if ((a - (3 * math.pi / 2)).abs() < 0.0001) rotationIndex = 3;
          final int narrow = math.max(1, (width / 150).round());
          final int wide = math.max(narrow * 3, 3);
          final int h = math.max(30, height);
          final int readable = barcode.showValue ? 1 : 0;
          // B8,x,y,narrow,wide,height,rotation,readable,data
          return 'B8,$left,$top,$narrow,$wide,$h,$rotationIndex,$readable,$data\r\n';
        }
      case BarcodeType.UpcA:
        {
          final a = (_normalizeAngle(barcode.rotationAngle)).abs();
          int rotationIndex = 0;
          if ((a - (math.pi / 2)).abs() < 0.0001) rotationIndex = 1;
          if ((a - math.pi).abs() < 0.0001) rotationIndex = 2;
          if ((a - (3 * math.pi / 2)).abs() < 0.0001) rotationIndex = 3;
          final int narrow = math.max(1, (width / 150).round());
          final int wide = math.max(narrow * 3, 3);
          final int h = math.max(30, height);
          final int readable = barcode.showValue ? 1 : 0;
          // BU,x,y,narrow,wide,height,rotation,readable,data
          return 'BU,$left,$top,$narrow,$wide,$h,$rotationIndex,$readable,$data\r\n';
        }
      case BarcodeType.Itf:
        {
          final a = (_normalizeAngle(barcode.rotationAngle)).abs();
          int rotationIndex = 0;
          if ((a - (math.pi / 2)).abs() < 0.0001) rotationIndex = 1;
          if ((a - math.pi).abs() < 0.0001) rotationIndex = 2;
          if ((a - (3 * math.pi / 2)).abs() < 0.0001) rotationIndex = 3;
          final int narrow = math.max(1, (width / 120).round());
          final int wide = math.max(narrow * 3, 3);
          final int h = math.max(20, height);
          final int readable = barcode.showValue ? 1 : 0;
          // B2,x,y,narrow,wide,height,rotation,readable,data
          return 'B2,$left,$top,$narrow,$wide,$h,$rotationIndex,$readable,$data\r\n';
        }
      default:
        return null; // 1D 바코드(EAN/UPC/ITF/Code39/93/128)는 다음 단계에서 매핑 추가
    }
  }

  bool _isAxisAligned(double angle) {
    final normalized = _normalizeAngle(angle);
    const eps = 0.0001;
    return normalized.abs() < eps ||
        (normalized - math.pi / 2).abs() < eps ||
        (normalized + math.pi / 2).abs() < eps;
  }

  double _normalizeAngle(double angle) {
    final twoPi = 2 * math.pi;
    double normalized = angle % twoPi;
    if (normalized > math.pi) normalized -= twoPi;
    if (normalized < -math.pi) normalized += twoPi;
    return normalized.abs() < 1e-9 ? 0 : normalized;
  }


  String _sanitizeText(String text) {
    return text
        .replaceAll('\r\n', '\\&')
        .replaceAll('\n', '\\&')
        .replaceAll('^', '\\^');
  }

  String _sanitizeBarcodeData(String data) => data.replaceAll('^', '\\^');
}
