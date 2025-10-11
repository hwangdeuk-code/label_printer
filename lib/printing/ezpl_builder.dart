import 'dart:math' as math;

import 'package:barcode/barcode.dart';
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
import '../models/tool.dart';

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

  double get _scaleX => labelSizeDots.width / sourceSize.width;
  double get _scaleY => labelSizeDots.height / sourceSize.height;

  EzplBuildResult build(Iterable<Drawable> drawables) {
    final buffer = StringBuffer()
      ..write('^XA\r\n')
      ..write('^PW${labelSizeDots.width.round()}\r\n')
      ..write('^LL${labelSizeDots.height.round()}\r\n');

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

    buffer
      ..write('^PQ1\r\n')
      ..write('^XZ\r\n');

    return EzplBuildResult(commands: buffer.toString(), fullyVector: allSupported);
  }

  int _x(double value) => (value * _scaleX).round();
  int _y(double value) => (value * _scaleY).round();
  int _w(double value) => math.max(1, (value * _scaleX).round());
  int _h(double value) => math.max(1, (value * _scaleY).round());
  int _avgStroke(double value) => math.max(1, (value * (_scaleX + _scaleY) / 2).round());

  String? _encodeDrawable(Drawable drawable) {
    if (drawable is RectangleDrawable) {
      return _encodeRectangle(drawable);
    }
    if (drawable is OvalDrawable) {
      return _encodeOval(drawable);
    }
    if (drawable is LineDrawable) {
      return _encodeLine(drawable.position, drawable.length, drawable.rotationAngle,
          drawable.paint.strokeWidth);
    }
    if (drawable is ArrowDrawable) {
      return _encodeLine(drawable.position, drawable.length, drawable.rotationAngle,
          drawable.paint.strokeWidth);
    }
    if (drawable is DoubleArrowDrawable) {
      return _encodeLine(drawable.position, drawable.length, drawable.rotationAngle,
          drawable.paint.strokeWidth);
    }
    if (drawable is ConstrainedTextDrawable) {
      return _encodeConstrainedText(drawable);
    }
    if (drawable is TextDrawable) {
      return _encodeText(drawable);
    }
    if (drawable is BarcodeDrawable) {
      return _encodeBarcode(drawable);
    }
    if (drawable is TableDrawable) {
      return null;
    }
    if (drawable is FreeStyleDrawable ||
        drawable is EraseDrawable ||
        drawable is ImageBoxDrawable ||
        drawable is ImageDrawable) {
      return null;
    }
    return null;
  }

  String? _encodeRectangle(RectangleDrawable rect) {
    if (!_isAxisAligned(rect.rotationAngle)) return null;
    final size = rect.size;
    final center = rect.position;
    final topLeft = center - Offset(size.width / 2, size.height / 2);
    final left = _x(topLeft.dx);
    final top = _y(topLeft.dy);
    final width = _w(size.width);
    final height = _h(size.height);
    final stroke = _avgStroke(rect.paint.strokeWidth);
    final int roundness = rect.borderRadius.topLeft.x > 0
        ? math.min(8, (_w(rect.borderRadius.topLeft.x) / 2).round())
        : 0;
    final color = _colorCode(rect.paint.color);

    final buffer = StringBuffer()
      ..write('^FO$left,$top')
      ..write('^GB$width,$height,$stroke,$color,$roundness^FS\r\n');

    if (rect.paint.style == PaintingStyle.fill) {
      final fillStroke = math.max(width, height);
      buffer
        ..write('^FO$left,$top')
        ..write('^GB$width,$height,$fillStroke,$color,$roundness^FS\r\n');
    }
    return buffer.toString();
  }

  String? _encodeOval(OvalDrawable oval) {
    if (!_isAxisAligned(oval.rotationAngle)) return null;
    final size = oval.size;
    final center = oval.position;
    final topLeft = center - Offset(size.width / 2, size.height / 2);
    final left = _x(topLeft.dx);
    final top = _y(topLeft.dy);
    final width = _w(size.width);
    final height = _h(size.height);
    final stroke = _avgStroke(oval.paint.strokeWidth);
    final color = _colorCode(oval.paint.color);

    final buffer = StringBuffer()
      ..write('^FO$left,$top')
      ..write('^GE$width,$height,$stroke,$color^FS\r\n');
    if (oval.paint.style == PaintingStyle.fill) {
      final fillStroke = math.max(width, height);
      buffer
        ..write('^FO$left,$top')
        ..write('^GE$width,$height,$fillStroke,$color^FS\r\n');
    }
    return buffer.toString();
  }

  String? _encodeLine(
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
    final left = _x(math.min(start.dx, end.dx));
    final top = _y(math.min(start.dy, end.dy));
    final width = _w((start.dx - end.dx).abs());
    final height = _h((start.dy - end.dy).abs());
    final stroke = _avgStroke(strokeWidth);

    if (width == 0 && height == 0) return '';
    if (height == 0) {
      return '^FO$left,${_y(start.dy)}^GB$width,0,$stroke,B,0^FS\r\n';
    }
    if (width == 0) {
      return '^FO${_x(start.dx)},$top^GB0,$height,$stroke,B,0^FS\r\n';
    }

    final orientation = (start.dy > end.dy) ? 'R' : 'L';
    return '^FO$left,$top^GD$width,$height,$stroke,B,$orientation^FS\r\n';
  }

  String? _encodeConstrainedText(ConstrainedTextDrawable text) {
    if (!_isAxisAligned(text.rotationAngle)) return null;
    if (text.text.isEmpty) return '';
    final size = text.getSize();
    final center = text.position;
    final topLeft = center - Offset(size.width / 2, size.height / 2);
    final left = _x(topLeft.dx);
    final top = _y(topLeft.dy);
    final width = _w(math.max(text.maxWidth, size.width));
    final font = _fontCommand(text.style);
    final align = switch (text.align) {
      TxtAlign.left => 'L',
      TxtAlign.center => 'C',
      TxtAlign.right => 'R',
    };
    final content = _sanitizeText(text.text);

    return '^FO$left,$top$font^FB$width,1000,0,$align,0^FD$content^FS\r\n';
  }

  String? _encodeText(TextDrawable text) {
    if (!_isAxisAligned(text.rotationAngle)) return null;
    if (text.text.isEmpty) return '';
    final size = text.getSize();
    final center = text.position;
    final topLeft = center - Offset(size.width / 2, size.height / 2);
    final left = _x(topLeft.dx);
    final top = _y(topLeft.dy);
    final width = _w(size.width);
    final font = _fontCommand(text.style);
    final content = _sanitizeText(text.text);

    return '^FO$left,$top$font^FB$width,1000,0,C,0^FD$content^FS\r\n';
  }

  String? _encodeBarcode(BarcodeDrawable barcode) {
    if (!_isAxisAligned(barcode.rotationAngle)) return null;
    if (barcode.data.isEmpty) return null;

    final center = barcode.position;
    final topLeft = center - Offset(barcode.size.width / 2, barcode.size.height / 2);
    final left = _x(topLeft.dx);
    final top = _y(topLeft.dy);
    final width = _w(barcode.size.width);
    final height = _h(barcode.size.height);
    final module = math.max(1, (width / 16).round());
    final showValueFlag = barcode.showValue ? 'Y' : 'N';

    final buffer = StringBuffer();
    if (barcode.background.alpha > 0) {
      buffer
        ..write('^FO$left,$top')
        ..write('^GB$width,$height,$width,${_colorCode(barcode.background)},0^FS\r\n');
    }

    switch (barcode.type) {
      case BarcodeType.Code128:
        buffer
          ..write('^BY$module,2,$height\r\n')
          ..write('^FO$left,$top^BCN,$height,$showValueFlag,N,N^FD${_sanitizeBarcodeData(barcode.data)}^FS\r\n');
        return buffer.toString();
      case BarcodeType.Code39:
        buffer
          ..write('^BY$module,2,$height\r\n')
          ..write('^FO$left,$top^B3N,$height,$showValueFlag,N,N^FD${_sanitizeBarcodeData(barcode.data)}^FS\r\n');
        return buffer.toString();
      case BarcodeType.CodeEAN13:
        buffer
          ..write('^BY$module,2,$height\r\n')
          ..write('^FO$left,$top^BEN,$height,$showValueFlag^FD${_sanitizeBarcodeData(barcode.data)}^FS\r\n');
        return buffer.toString();
      case BarcodeType.CodeEAN8:
        buffer
          ..write('^BY$module,2,$height\r\n')
          ..write('^FO$left,$top^B8N,$height,$showValueFlag^FD${_sanitizeBarcodeData(barcode.data)}^FS\r\n');
        return buffer.toString();
      case BarcodeType.QrCode:
        final data = _sanitizeBarcodeData(barcode.data);
        buffer
          ..write('^FO$left,$top^BQN,2,10^FDLA,$data^FS\r\n');
        return buffer.toString();
      default:
        return null;
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

  String _colorCode(Color color) => color.computeLuminance() > 0.5 ? 'W' : 'B';

  String _fontCommand(TextStyle style) {
    final height = math.max(10, _h(style.fontSize ?? 12));
    final width = math.max(1, (height * 0.6).round());
    return '^A0N,$height,$width';
  }

  String _sanitizeText(String text) {
    return text
        .replaceAll('\r\n', '\\&')
        .replaceAll('\n', '\\&')
        .replaceAll('^', '\\^');
  }

  String _sanitizeBarcodeData(String data) => data.replaceAll('^', '\\^');
}
