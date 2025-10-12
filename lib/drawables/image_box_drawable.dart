import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../flutter_painter_v2/flutter_painter.dart';
import '../flutter_painter_v2/controllers/drawables/object_drawable.dart'
    show ObjectDrawable, ObjectDrawableAssist;

/// Rect와 동일한 조작(이동/리사이즈/회전)을 지원하는 이미지 드로어블
class ImageBoxDrawable extends ObjectDrawable {
  final ui.Image image;
  final Size size;
  final BorderRadius borderRadius;
  final Color strokeColor;
  final double strokeWidth; // 0이면 외곽선 없음

  const ImageBoxDrawable({
    required super.position,
    required this.image,
    required this.size,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.strokeColor = Colors.black,
    this.strokeWidth = 0.0,
    double rotationAngle = 0.0,
    double scale = 1.0,
    Set<ObjectDrawableAssist> assists = const {},
    Map<ObjectDrawableAssist, Paint> assistPaints = const {},
    bool hidden = false,
    bool locked = false,
  }) : super(
         rotationAngle: rotationAngle,
         scale: scale,
         assists: assists,
         assistPaints: assistPaints,
         hidden: hidden,
         locked: locked,
       );

  @override
  void drawObject(Canvas canvas, Size canvasSize) {
    final rect = Rect.fromCenter(
      center: position,
      width: size.width,
      height: size.height,
    );
    final rrect = borderRadius.toRRect(rect);

    // 이미지 라운드 클리핑 후 드로우
    canvas.save();
    canvas.clipRRect(rrect);
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(image, src, rect, Paint());
    canvas.restore();

    // 외곽선
    if (strokeWidth > 0) {
      final strokePaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawRRect(rrect, strokePaint);
    }
  }

  @override
  Size getSize({double minWidth = 0.0, double maxWidth = double.infinity}) =>
      size;

  @override
  ObjectDrawable copyWith({
    bool? hidden,
    Set<ObjectDrawableAssist>? assists,
    Offset? position,
    double? rotation,
    double? scale,
    bool? locked,
  }) {
    return ImageBoxDrawable(
      position: position ?? this.position,
      image: image,
      size: size,
      borderRadius: borderRadius,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
      rotationAngle: rotation ?? rotationAngle,
      scale: scale ?? this.scale,
      assists: assists ?? this.assists,
      assistPaints: assistPaints,
      hidden: hidden ?? this.hidden,
      locked: locked ?? this.locked,
    );
  }

  ImageBoxDrawable copyWithExt({
    Offset? position,
    ui.Image? image,
    Size? size,
    double? rotation,
    double? scale,
    BorderRadius? borderRadius,
    Color? strokeColor,
    double? strokeWidth,
    Set<ObjectDrawableAssist>? assists,
    Map<ObjectDrawableAssist, Paint>? assistPaints,
    bool? hidden,
    bool? locked,
  }) {
    return ImageBoxDrawable(
      position: position ?? this.position,
      image: image ?? this.image,
      size: size ?? this.size,
      borderRadius: borderRadius ?? this.borderRadius,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      rotationAngle: rotation ?? rotationAngle,
      scale: scale ?? this.scale,
      assists: assists ?? this.assists,
      assistPaints: assistPaints ?? this.assistPaints,
      hidden: hidden ?? this.hidden,
      locked: locked ?? this.locked,
    );
  }
}
