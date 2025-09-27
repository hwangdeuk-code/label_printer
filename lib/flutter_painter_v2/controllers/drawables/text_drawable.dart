import 'package:flutter/material.dart';

import 'object_drawable.dart';

/// Text Drawable (단순 텍스트)
/// - 바코드와 동일하게 "센터 기준"으로 페인트합니다.
/// - ObjectDrawable.draw()가 position 기준으로 회전만 1회 적용하므로,
///   여기서는 전역 position을 기준으로 중앙 배치하여 그립니다(중복 변환 없음).
class TextDrawable extends ObjectDrawable {
  final String text;
  final TextStyle style;
  final TextDirection direction;

  TextDrawable({
    required this.text,
    required Offset position,
    double rotation = 0,
    double scale = 1,
    this.style = const TextStyle(
      fontSize: 14,
      color: Colors.black,
    ),
    this.direction = TextDirection.ltr,
    bool locked = false,
    bool hidden = false,
    Set<ObjectDrawableAssist> assists = const <ObjectDrawableAssist>{},
  }) : super(
          position: position,
          rotationAngle: rotation,
          scale: scale,
          assists: assists,
          locked: locked,
          hidden: hidden,
        );

  /// 선택 박스용 크기(스케일 미적용).
  @override
  Size getSize({double minWidth = 0.0, double maxWidth = double.infinity}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: direction,
      maxLines: 1000,
    )..layout(minWidth: 0, maxWidth: maxWidth);
    return tp.size;
  }

  /// 실제 그리기:
  /// - 전역 position을 중심으로 중앙 정렬 배치.
  /// - 회전/스케일/이동은 ObjectDrawable.draw()에서 일관 처리(회전만 1회).
  @override
  void drawObject(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: direction,
      maxLines: 1000,
    )..layout(minWidth: 0, maxWidth: double.infinity);

    final topLeft = position - Offset(tp.width / 2, tp.height / 2);
    tp.paint(canvas, topLeft);
  }

  @override
  TextDrawable copyWith({
    bool? hidden,
    Set<ObjectDrawableAssist>? assists,
    String? text,
    Offset? position,
    double? rotation,
    double? scale,
    TextStyle? style,
    bool? locked,
    TextDirection? direction,
  }) {
    return TextDrawable(
      text: text ?? this.text,
      position: position ?? this.position,
      rotation: rotation ?? rotationAngle,
      scale: scale ?? this.scale,
      style: style ?? this.style,
      direction: direction ?? this.direction,
      assists: assists ?? this.assists,
      hidden: hidden ?? this.hidden,
      locked: locked ?? this.locked,
    );
  }
}
