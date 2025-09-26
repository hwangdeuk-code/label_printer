import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../flutter_painter_v2/flutter_painter.dart';
import '../models/tool.dart';

const double _canvasDimension = 640;
const double _rulerThickness = 24;
const Color _rulerBackground = Color(0xFFEDEDED);
const Color _rulerBorder = Color(0xFFBDBDBD);
const TextStyle _rulerLabelStyle = TextStyle(
  fontSize: 8,
  color: Colors.black87,
);

class CanvasArea extends StatelessWidget {
  const CanvasArea({
    super.key,
    required this.currentTool,
    required this.controller,
    required this.painterKey,
    required this.onPointerDownSelect,
    required this.onCanvasTap,
    required this.onOverlayPanStart,
    required this.onOverlayPanUpdate,
    required this.onOverlayPanEnd,
    required this.onCreatePanStart,
    required this.onCreatePanUpdate,
    required this.onCreatePanEnd,
    required this.selectedDrawable,
    required this.selectionBounds,
    required this.selectionStart,
    required this.selectionEnd,
    required this.handleSize,
    required this.rotateHandleOffset,
    required this.showEndpoints,
    required this.isTextSelected,
  this.printerDpi = 300,
  this.scalePercent = 100.0,
  });

  final Tool currentTool;
  final PainterController controller;
  final GlobalKey painterKey;
  final void Function(PointerDownEvent) onPointerDownSelect;
  final VoidCallback onCanvasTap;
  final void Function(DragStartDetails) onOverlayPanStart;
  final void Function(DragUpdateDetails) onOverlayPanUpdate;
  final VoidCallback onOverlayPanEnd;
  final void Function(DragStartDetails) onCreatePanStart;
  final void Function(DragUpdateDetails) onCreatePanUpdate;
  final VoidCallback onCreatePanEnd;
  final Drawable? selectedDrawable;
  final Rect? selectionBounds;
  final Offset? selectionStart;
  final Offset? selectionEnd;
  final double handleSize;
  final double rotateHandleOffset;
  final bool showEndpoints;
  final bool isTextSelected;
  final double printerDpi;
  final double scalePercent;

  @override
  Widget build(BuildContext context) {
    final overlayIgnored = currentTool == Tool.pen || currentTool == Tool.eraser;
    final absorbPainter = currentTool == Tool.rect ||
        currentTool == Tool.oval ||
        currentTool == Tool.line ||
        currentTool == Tool.arrow ||
        currentTool == Tool.select ||
        currentTool == Tool.text;

  final double pixelsPerCm = printerDpi > 0 ? (printerDpi / 2.54) * (scalePercent / 100.0) : 0;

    return SizedBox(
      width: _canvasDimension,
      height: _canvasDimension,
      child: Stack(
        children: [
          // 항상 흰색 배경이 깔리도록 추가
          Positioned.fill(
            child: Container(color: Colors.white),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
            ),
          ),
          Positioned(
            left: _rulerThickness,
            right: 0,
            top: 0,
            height: _rulerThickness,
            child: CustomPaint(
              painter: _HorizontalRulerPainter(pixelsPerCm: pixelsPerCm),
            ),
          ),
          Positioned(
            left: 0,
            top: _rulerThickness,
            bottom: 0,
            width: _rulerThickness,
            child: CustomPaint(
              painter: _VerticalRulerPainter(pixelsPerCm: pixelsPerCm),
            ),
          ),
          const Positioned(
            left: 0,
            top: 0,
            width: _rulerThickness,
            height: _rulerThickness,
            child: _RulerCorner(),
          ),
          Positioned(
            left: _rulerThickness,
            top: _rulerThickness,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
              child: Stack(
                children: [
                  AbsorbPointer(
                    absorbing: absorbPainter,
                    child: RepaintBoundary(
                      key: painterKey,
                      child: Transform.scale(
                        scale: scalePercent / 100.0,
                        alignment: Alignment.topLeft,
                        child: FlutterPainter(controller: controller),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: overlayIgnored,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: onPointerDownSelect,
                        child: GestureDetector(
                          dragStartBehavior: DragStartBehavior.down,
                          behavior: HitTestBehavior.opaque,
                          onTap: onCanvasTap,
                          onPanStart: (details) {
                            if (currentTool == Tool.select) {
                              onOverlayPanStart(details);
                            } else {
                              onCreatePanStart(details);
                            }
                          },
                          onPanUpdate: (details) {
                            if (currentTool == Tool.select) {
                              onOverlayPanUpdate(details);
                            } else {
                              onCreatePanUpdate(details);
                            }
                          },
                          onPanEnd: (_) {
                            if (currentTool == Tool.select) {
                              onOverlayPanEnd();
                            } else {
                              onCreatePanEnd();
                            }
                          },
                          child: Transform.scale(
                            scale: scalePercent / 100.0,
                            alignment: Alignment.topLeft,
                            child: CustomPaint(
                              painter: _SelectionPainter(
                                selected: selectedDrawable,
                                bounds: selectionBounds,
                                handleSize: handleSize,
                                rotateHandleOffset: rotateHandleOffset,
                                showEndpoints: showEndpoints,
                                start: selectionStart,
                                end: selectionEnd,
                                endpointRadius: handleSize * 0.7,
                                isText: isTextSelected,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
  );
  }
}

class _RulerCorner extends StatelessWidget {
  const _RulerCorner();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _rulerBackground,
      alignment: Alignment.center,
      child: const Text(
        'cm',
        style: TextStyle(fontSize: 10, color: Colors.black54),
      ),
    );
  }
}

class _HorizontalRulerPainter extends CustomPainter {
  const _HorizontalRulerPainter({
    required this.pixelsPerCm,
  });

  final double pixelsPerCm;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint background = Paint()..color = _rulerBackground;
    canvas.drawRect(Offset.zero & size, background);

    final Paint border = Paint()
      ..color = _rulerBorder
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      border,
    );

    if (pixelsPerCm <= 0) {
      return;
    }

    final Paint major = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1;
    final Paint minor = Paint()
      ..color = Colors.black45
      ..strokeWidth = 1;

  final double majorTickTop = size.height * 0.65;

    // 주요 눈금 (정수 cm)
    int i = 0;
    while (true) {
      final double x = i * pixelsPerCm;
      if (x > size.width + 0.5) break;
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x, size.height - (size.height - majorTickTop)),
        major,
      );
      final textPainter = TextPainter(
        text: TextSpan(text: i.toString(), style: _rulerLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final double labelX = (x - textPainter.width / 2).clamp(0.0, size.width - textPainter.width);
      // 라벨을 눈금 위(majorTickTop보다 위쪽)로 이동
      final double labelY = (majorTickTop - textPainter.height - 6).clamp(0.0, size.height - textPainter.height);
      textPainter.paint(canvas, Offset(labelX, labelY));
      i++;
    }

    // 보조 눈금 (0.1cm)
    double cm = 0.1;
    while (true) {
      final double x = cm * pixelsPerCm;
      if (x > size.width + 0.5) break;
      // 주요 눈금(정수 cm)과 겹치지 않게 0.1, 0.2, ..., 0.9cm만 그림
      if ((cm * 10) % 10 != 0) {
        canvas.drawLine(
          Offset(x, size.height),
          Offset(x, size.height - size.height * 0.225),
          minor,
        );
      }
      cm += 0.1;
    }
  }

  @override
  bool shouldRepaint(covariant _HorizontalRulerPainter oldDelegate) {
    return oldDelegate.pixelsPerCm != pixelsPerCm;
  }
}
class _VerticalRulerPainter extends CustomPainter {
  const _VerticalRulerPainter({required this.pixelsPerCm});

  final double pixelsPerCm;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint background = Paint()..color = _rulerBackground;
    canvas.drawRect(Offset.zero & size, background);

    final Paint border = Paint()
      ..color = _rulerBorder
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width - 0.5, 0),
      Offset(size.width - 0.5, size.height),
      border,
    );

    if (pixelsPerCm <= 0) {
      return;
    }

    final Paint major = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1;
    final Paint minor = Paint()
      ..color = Colors.black45
      ..strokeWidth = 1;

    // 주요 눈금 (정수 cm)
    int i = 0;
    while (true) {
      final double y = i * pixelsPerCm;
      if (y > size.height + 0.5) break;
      canvas.drawLine(
        Offset(size.width, y),
        Offset(size.width - size.width * 0.35, y),
        major,
      );
      final textPainter = TextPainter(
        text: TextSpan(text: '$i', style: _rulerLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final double labelY =
          (y - textPainter.height / 2).clamp(0.0, size.height - textPainter.height);
      textPainter.paint(canvas, Offset(2, labelY));
      i++;
    }

    // 보조 눈금 (0.1cm)
    double cm = 0.1;
    while (true) {
      final double y = cm * pixelsPerCm;
      if (y > size.height + 0.5) break;
      // 주요 눈금(정수 cm)과 겹치지 않게 0.1, 0.2, ..., 0.9cm만 그림
      if ((cm * 10) % 10 != 0) {
        canvas.drawLine(
          Offset(size.width, y),
          Offset(size.width - size.width * 0.225, y),
          minor,
        );
      }
      cm += 0.1;
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalRulerPainter oldDelegate) {
    return oldDelegate.pixelsPerCm != pixelsPerCm;
  }
}

class _SelectionPainter extends CustomPainter {
  final Drawable? selected;
  final Rect? bounds;
  final double handleSize;
  final double rotateHandleOffset;
  final bool showEndpoints;
  final double endpointRadius;
  final Offset? start;
  final Offset? end;
  final bool isText;

  const _SelectionPainter({
    required this.selected,
    required this.bounds,
    required this.handleSize,
    required this.rotateHandleOffset,
    this.showEndpoints = false,
    this.endpointRadius = 6,
    this.start,
    this.end,
    this.isText = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (selected == null || bounds == null) return;
    final r = bounds!;
    final boxPaint = Paint()
      ..color = const Color(0xFF3F51B5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    bool shouldRotate = false;
    double angle = 0;
    // BarcodeDrawable(또는 ObjectDrawable이면서 rotationAngle!=0)만 회전 적용
    if ((selected.runtimeType.toString().contains('BarcodeDrawable') ||
         (selected is ObjectDrawable && (selected as ObjectDrawable).rotationAngle != 0)) &&
        !(selected is LineDrawable || selected is ArrowDrawable)) {
      shouldRotate = true;
      angle = (selected as dynamic).rotationAngle ?? 0;
    }

    if (shouldRotate) {
      final center = r.center;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.translate(-center.dx, -center.dy);
    }

    canvas.drawRect(r, boxPaint);

    if (!(selected is LineDrawable || selected is ArrowDrawable)) {
      final handlePaint = Paint()..color = const Color(0xFF3F51B5);
      for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
        final h = Rect.fromCenter(center: c, width: handleSize, height: handleSize);
        canvas.drawRect(h, handlePaint);
      }
      final rotateCenter = Offset(r.center.dx, r.top - rotateHandleOffset);
      canvas.drawLine(r.topCenter, rotateCenter, boxPaint);
      canvas.drawCircle(rotateCenter, handleSize * 0.6, handlePaint);
    } else {
      if (showEndpoints && start != null && end != null) {
        final epPaint = Paint()..color = const Color(0xFF3F51B5);
        canvas.drawCircle(start!, endpointRadius, epPaint);
        canvas.drawCircle(end!, endpointRadius, epPaint);
        final rotateCenter = Offset(r.center.dx, r.top - rotateHandleOffset);
        canvas.drawLine(r.topCenter, rotateCenter, boxPaint);
        canvas.drawCircle(rotateCenter, endpointRadius, epPaint);
      }
    }

    if (shouldRotate) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter oldDelegate) {
    return oldDelegate.selected != selected ||
        oldDelegate.bounds != bounds ||
        oldDelegate.start != start ||
        oldDelegate.end != end ||
        oldDelegate.handleSize != handleSize ||
        oldDelegate.isText != isText;
  }
}







