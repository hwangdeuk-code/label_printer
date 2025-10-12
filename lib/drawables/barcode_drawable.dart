import 'dart:math' as math;
import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';

import '../flutter_painter_v2/flutter_painter.dart';

class BarcodeDrawable extends Sized2DDrawable {
  const BarcodeDrawable({
    required this.data,
    required this.type,
    this.showValue = true,
    this.fontSize = 16,
    this.foreground = Colors.black,
    this.background = Colors.white,
    this.bold = false,
    this.italic = false,
    this.fontFamily = 'Roboto',
    this.textAlign,
    this.maxTextWidth = 0,
    required super.size,
    required super.position,
    super.rotationAngle = 0,
    super.scale = 1,
    super.assists,
    super.assistPaints,
    super.locked,
    super.hidden,
  });

  final String data;
  final BarcodeType type;
  final bool showValue;
  final double fontSize;
  final Color foreground;
  final Color background;
  final bool bold;
  final bool italic;
  final String fontFamily;
  final TextAlign? textAlign;
  final double maxTextWidth;

  static const double _textPadding = 4;
  static const Object _noTextAlign = Object();

  @override
  BarcodeDrawable copyWith({
    bool? hidden,
    Set<ObjectDrawableAssist>? assists,
    Offset? position,
    double? rotation,
    double? scale,
    Size? size,
    bool? locked,
    String? data,
    BarcodeType? type,
    bool? showValue,
    double? fontSize,
    Color? foreground,
    Color? background,
    bool? bold,
    bool? italic,
    String? fontFamily,
    Object? textAlign = _noTextAlign,
    double? maxTextWidth,
  }) {
    return BarcodeDrawable(
      data: data ?? this.data,
      type: type ?? this.type,
      showValue: showValue ?? this.showValue,
      fontSize: fontSize ?? this.fontSize,
      foreground: foreground ?? this.foreground,
      background: background ?? this.background,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      fontFamily: fontFamily ?? this.fontFamily,
      textAlign: identical(textAlign, _noTextAlign)
          ? this.textAlign
          : textAlign as TextAlign?,
      maxTextWidth: maxTextWidth ?? this.maxTextWidth,
      size: size ?? this.size,
      position: position ?? this.position,
      rotationAngle: rotation ?? rotationAngle,
      scale: scale ?? this.scale,
      assists: assists ?? this.assists,
      assistPaints: assistPaints,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
    );
  }

  @override
  void drawObject(Canvas canvas, Size _) {
    final rect = Rect.fromCenter(
      center: position,
      width: size.width,
      height: size.height,
    );

    if (background.a > 0) {
      canvas.drawRect(rect, Paint()..color = background);
    }

    if (data.isEmpty) {
      _drawPlaceholder(canvas, rect, 'Empty data');
      return;
    }

    final barcode = Barcode.fromType(type);
    late final List<BarcodeElement> elements;
    try {
      elements = barcode
          .makeBytes(
            Uint8List.fromList(data.codeUnits),
            width: size.width,
            height: size.height,
            drawText: showValue,
            fontHeight: showValue ? fontSize : null,
            textPadding: showValue ? _textPadding : null,
          )
          .toList();
    } catch (_) {
      _drawPlaceholder(canvas, rect, 'Invalid data');
      return;
    }

    final origin = rect.topLeft;
    final barPaint = Paint()..color = foreground;

    for (final e in elements) {
      if (e is BarcodeBar) {
        if (!e.black) continue;
        final r = Rect.fromLTWH(
          origin.dx + e.left,
          origin.dy + e.top,
          e.width,
          e.height,
        );
        canvas.drawRect(r, barPaint);
      } else if (e is BarcodeText && showValue) {
        final w = math.max(
          1.0,
          maxTextWidth > 0 ? math.min(maxTextWidth, e.width) : e.width,
        );
        final align = textAlign ?? _toTextAlign(e.align);
        final tp = TextPainter(
          text: TextSpan(
            text: e.text,
            style: TextStyle(
              fontSize: fontSize,
              color: foreground,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              fontFamily: fontFamily,
            ),
          ),
          textAlign: align,
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(minWidth: w, maxWidth: w);

        final dy = origin.dy + e.top + (e.height - tp.height) / 2;
        tp.paint(canvas, Offset(origin.dx + e.left, dy));
      }
    }
  }

  TextAlign _toTextAlign(BarcodeTextAlign a) {
    switch (a) {
      case BarcodeTextAlign.left:
        return TextAlign.left;
      case BarcodeTextAlign.center:
        return TextAlign.center;
      case BarcodeTextAlign.right:
        return TextAlign.right;
    }
  }

  void _drawPlaceholder(Canvas canvas, Rect rect, String msg) {
    final stroke = Paint()
      ..color = foreground.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(rect, stroke);

    final maxW = maxTextWidth > 0
        ? math.min(maxTextWidth, rect.width - 8)
        : rect.width - 8;
    final layoutW = math.max(8.0, maxW);

    final tp = TextPainter(
      text: TextSpan(
        text: msg,
        style: TextStyle(
          color: foreground.withValues(alpha: 0.6),
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          fontFamily: fontFamily,
        ),
      ),
      textAlign: textAlign ?? TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: layoutW);

    final ofs = Offset(
      rect.left + (rect.width - tp.width) / 2,
      rect.top + (rect.height - tp.height) / 2,
    );
    tp.paint(canvas, ofs);
  }
}
