import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_zxing/flutter_zxing.dart' as zxing;
import 'package:flutter/material.dart';

import '../flutter_painter_v2/flutter_painter.dart';
import '../models/barcode.dart';

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
    this.microModule,
    this.strictValidation = false,
    this.humanReadableGrouped = false,
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
  // Optional override for Micro QR module size in EZPL W command (2..10)
  final int? microModule;
  // If true, UI may surface validation errors for data by symbology rules.
  final bool strictValidation;
  // If true, showValue text is grouped (EAN-13: 1 6 6, UPC-A: 1 5 5 1, EAN-8: 4 4, ITF: pairs).
  final bool humanReadableGrouped;

  // note: text padding handled by printer pipeline
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
    int? microModule,
    bool? strictValidation,
    bool? humanReadableGrouped,
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
      microModule: microModule ?? this.microModule,
      strictValidation: strictValidation ?? this.strictValidation,
      humanReadableGrouped:
          humanReadableGrouped ?? this.humanReadableGrouped,
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

    // flutter_zxing 인코더로 간단 프리뷰 생성 (동기 래스터 드로잉)
    // 텍스트 표시 영역 확보
    double textReserve = 0;
    if (showValue) {
      textReserve = fontSize * 1.35; // 간단한 추정치
    }
    final contentRect = Rect.fromLTWH(
      rect.left,
      rect.top,
      rect.width,
      math.max(0, rect.height - textReserve),
    );

    // 너무 작은 영역이면 플레이스홀더로 대체
    if (contentRect.width < 8 || contentRect.height < 8) {
      _drawPlaceholder(canvas, rect, 'Too small');
      return;
    }

    final targetW = contentRect.width.clamp(16.0, 2000.0).floor();
    final targetH = contentRect.height.clamp(16.0, 2000.0).floor();

    final format = _toZxingFormat(type);
    if (format == null) {
      _drawPlaceholder(canvas, rect, 'Unsupported: ${type.name}');
      return;
    }

    final enc = zxing.zx.encodeBarcode(
      contents: data,
      params: zxing.EncodeParams(
        format: format,
        width: targetW,
        height: targetH,
        margin: 0,
      ),
    );
    if (!enc.isValid || enc.data == null || targetW == 0 || targetH == 0) {
      _drawPlaceholder(canvas, rect, 'Encode failed');
      return;
    }

    // ZXing은 1채널(grayscale) 바이트를 반환한다. 0=검정, 255=흰색 가정.
    final int srcW = targetW;
    final int srcH = targetH;
    final ByteBuffer buf = enc.data!.buffer;
    final Uint8List mono = Uint8List.view(buf, enc.data!.offsetInBytes, srcW * srcH);

    // 콘텐츠 영역에 맞게 스케일/센터링
    final scale = math.min(contentRect.width / srcW, contentRect.height / srcH);
    final drawW = srcW * scale;
    final drawH = srcH * scale;
    final drawLeft = contentRect.left + (contentRect.width - drawW) / 2;
    final drawTop = contentRect.top + (contentRect.height - drawH) / 2;

    // 검은 픽셀만 Path로 누적하여 한 번에 그리기
    final Path path = Path();
    final double cell = scale;
    for (int y = 0; y < srcH; y++) {
      final int rowBase = y * srcW;
      for (int x = 0; x < srcW; x++) {
        final int v = mono[rowBase + x];
        if (v < 128) {
          final double l = drawLeft + x * cell;
          final double t = drawTop + y * cell;
          path.addRect(Rect.fromLTWH(l, t, cell, cell));
        }
      }
    }

    final barPaint = Paint()..color = foreground;
    if (!path.getBounds().isEmpty) {
      canvas.drawPath(path, barPaint);
    }

    // 아래 텍스트(휴먼리더블)
    if (showValue && textReserve > 0) {
      final String displayText = humanReadableGrouped
          ? _formatHumanReadable(type, data)
          : data;
      final tp = TextPainter(
        text: TextSpan(
          text: displayText,
          style: TextStyle(
            color: foreground,
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            fontFamily: fontFamily,
          ),
        ),
        textAlign: textAlign ?? TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: rect.width - 6);

      final textX = rect.left + (rect.width - tp.width) / 2;
      final textY = rect.bottom - tp.height - (textReserve - tp.height) / 2;
      tp.paint(canvas, Offset(textX, textY));
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

  int? _toZxingFormat(BarcodeType t) {
    switch (t) {
      case BarcodeType.Code128:
        return zxing.Format.code128;
      case BarcodeType.Code39:
        return zxing.Format.code39;
      case BarcodeType.Code93:
        return zxing.Format.code93;
      case BarcodeType.QrCode:
        return zxing.Format.qrCode;
      case BarcodeType.MicroQrCode:
        return zxing.Format.microQRCode;
      case BarcodeType.DataMatrix:
        return zxing.Format.dataMatrix;
      case BarcodeType.CodeEAN13:
        return zxing.Format.ean13;
      case BarcodeType.UpcA:
        return zxing.Format.upca;
      case BarcodeType.Itf:
        return zxing.Format.itf;
      case BarcodeType.CodeEAN8:
        return zxing.Format.ean8; // 남겨두되 UI에서는 미노출
      case BarcodeType.PDF417:
        return zxing.Format.pdf417; // 남겨두되 UI에서는 미노출
    }
  }

  String _formatHumanReadable(BarcodeType t, String raw) {
    // Keep it simple and predictable for on-canvas preview; don't compute check digit here.
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    switch (t) {
      case BarcodeType.CodeEAN13:
        if (digits.length >= 13) {
          return '${digits[0]} ${digits.substring(1, 7)} ${digits.substring(7, 13)}';
        }
        break;
      case BarcodeType.UpcA:
        if (digits.length >= 12) {
          return '${digits.substring(0, 1)} ${digits.substring(1, 6)} ${digits.substring(6, 11)} ${digits.substring(11, 12)}';
        }
        break;
      case BarcodeType.CodeEAN8:
        if (digits.length >= 8) {
          return '${digits.substring(0, 4)} ${digits.substring(4, 8)}';
        }
        break;
      case BarcodeType.Itf:
        if (digits.isNotEmpty) {
          final buf = StringBuffer();
          for (int i = 0; i < digits.length; i += 2) {
            final end = math.min(i + 2, digits.length);
            if (buf.isNotEmpty) buf.write(' ');
            buf.write(digits.substring(i, end));
          }
          return buf.toString();
        }
        break;
      default:
        break;
    }
    // Fallback: chunk every 4 characters for long strings
    if (digits.length >= 8) {
      final buf = StringBuffer();
      for (int i = 0; i < digits.length; i += 4) {
        final end = math.min(i + 4, digits.length);
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(digits.substring(i, end));
      }
      return buf.toString();
    }
    return raw;
  }
}
