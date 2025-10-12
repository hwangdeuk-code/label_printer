import 'package:flutter/material.dart';

import '../models/tool.dart';
import '../flutter_painter_v2/flutter_painter.dart';

/// 커스텀 텍스트 드로어블(정렬/최대폭 지원)
/// - 바코드/텍스트와 동일하게 "센터 기준" 배치
/// - drawObject(): 전역 position을 중심으로 중앙 정렬로 페인트
/// - 선택 박스: position + getSize() (회전은 SelectionPainter/ObjectDrawable에서 1회)
class ConstrainedTextDrawable extends ObjectDrawable {
  final String text;
  final TextStyle style;
  final TextDirection direction;
  final TxtAlign align;
  final double maxWidth;

  const ConstrainedTextDrawable({
    required this.text,
    required super.position,
    required super.rotationAngle,
    this.style = const TextStyle(fontSize: 14, color: Colors.black),
    this.direction = TextDirection.ltr,
    this.align = TxtAlign.left,
    this.maxWidth = 300,
    super.scale = 1.0,
    super.assists = const <ObjectDrawableAssist>{},
    super.assistPaints = const <ObjectDrawableAssist, Paint>{},
    super.locked = false,
    super.hidden = false,
  });

  TextAlign get _textAlign => switch (align) {
    TxtAlign.left => TextAlign.left,
    TxtAlign.center => TextAlign.center,
    TxtAlign.right => TextAlign.right,
  };

  @override
  ConstrainedTextDrawable copyWith({
    String? text,
    Offset? position,
    double? rotation,
    double? scale,
    TextStyle? style,
    TextDirection? direction,
    TxtAlign? align,
    double? maxWidth,
    bool? hidden,
    Set<ObjectDrawableAssist>? assists,
    bool? locked,
  }) {
    return ConstrainedTextDrawable(
      text: text ?? this.text,
      position: position ?? this.position,
      rotationAngle: rotation ?? rotationAngle,
      scale: scale ?? this.scale,
      style: style ?? this.style,
      direction: direction ?? this.direction,
      align: align ?? this.align,
      maxWidth: maxWidth ?? this.maxWidth,
      assists: assists ?? this.assists,
      assistPaints: assistPaints,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
    );
  }

  /// 선택 박스용 사이즈(스케일 미적용).
  @override
  Size getSize({double minWidth = 0.0, double maxWidth = double.infinity}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: _textAlign,
      textDirection: direction,
      maxLines: 1000,
    )..layout(minWidth: 0, maxWidth: this.maxWidth.clamp(0, maxWidth));
    return tp.size;
  }

  /// 실제 그리기:
  /// - 전역 position을 중심으로 중앙 정렬 배치(최대폭은 maxWidth).
  @override
  void drawObject(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: _textAlign,
      textDirection: direction,
      maxLines: 1000,
    )..layout(minWidth: 0, maxWidth: maxWidth);

    final topLeft = position - Offset(tp.width / 2, tp.height / 2);
    tp.paint(canvas, topLeft);
  }
}
