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
  void drawObject(Canvas canvas, Size size) {
    final drawingSize = this.size * scale;
    final rect = Rect.fromCenter(
      center: position,
      width: drawingSize.width,
      height: drawingSize.height,
    );

    if (background.a > 0) {
      final bgPaint = Paint()..color = background;
      canvas.drawRect(rect, bgPaint);
    }

    if (data.isEmpty) {
      _drawPlaceholder(canvas, rect, 'Empty data');
      return;
    }

    final barcode = Barcode.fromType(type);
    final bytes = Uint8List.fromList(data.codeUnits);
    List<BarcodeElement> elements;
    try {
      elements = barcode
          .makeBytes(
            bytes,
            width: drawingSize.width,
            height: drawingSize.height,
            drawText: showValue,
            fontHeight: showValue ? fontSize : null,
            textPadding: showValue ? _textPadding : null,
          )
          .toList();
    } catch (error) {
      _drawPlaceholder(canvas, rect, 'Invalid data');
      return;
    }

    final offset = rect.topLeft;
    final barPaint = Paint()..color = foreground;

    for (final element in elements) {
      if (element is BarcodeBar) {
        if (!element.black) continue;
        final barRect = Rect.fromLTWH(
          offset.dx + element.left,
          offset.dy + element.top,
          element.width,
          element.height,
        );
        canvas.drawRect(barRect, barPaint);
      } else if (element is BarcodeText && showValue) {
        final layoutWidth = math.max(
          1.0,
          maxTextWidth > 0 ? math.min(maxTextWidth, element.width) : element.width,
        );
        final resolvedAlign = textAlign ?? _toTextAlign(element.align);
        final textStyle = TextStyle(
          fontSize: fontSize,
          color: foreground,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          fontFamily: fontFamily,
        );
        final textPainter = TextPainter(
          text: TextSpan(text: element.text, style: textStyle),
          textAlign: resolvedAlign,
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )
          ..layout(minWidth: layoutWidth, maxWidth: layoutWidth);

        final dy =
            offset.dy + element.top + (element.height - textPainter.height) / 2;
        textPainter.paint(canvas, Offset(offset.dx + element.left, dy));
      }
    }
  }

  TextAlign _toTextAlign(BarcodeTextAlign align) {
    switch (align) {
      case BarcodeTextAlign.left:
        return TextAlign.left;
      case BarcodeTextAlign.center:
        return TextAlign.center;
      case BarcodeTextAlign.right:
        return TextAlign.right;
    }
  }

  void _drawPlaceholder(Canvas canvas, Rect rect, String message) {
    final borderPaint = Paint()
      ..color = foreground.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(rect, borderPaint);

    final maxWidth = maxTextWidth > 0
        ? math.min(maxTextWidth, rect.width - 8)
        : rect.width - 8;
    final layoutWidth = math.max(8.0, maxWidth);

    final textPainter = TextPainter(
      text: TextSpan(
        text: message,
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
    )
      ..layout(maxWidth: layoutWidth);

    final offset = Offset(
      rect.left + (rect.width - textPainter.width) / 2,
      rect.top + (rect.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);
  }
}
