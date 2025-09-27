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
          Positioned.fill(child: Container(color: Colors.white)),
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
            child: CustomPaint(painter: _HorizontalRulerPainter(pixelsPerCm: pixelsPerCm)),
          ),
          Positioned(
            left: 0,
            top: _rulerThickness,
            bottom: 0,
            width: _rulerThickness,
            child: CustomPaint(painter: _VerticalRulerPainter(pixelsPerCm: pixelsPerCm)),
          ),
          const Positioned(
            left: 0, top: 0, width: _rulerThickness, height: _rulerThickness, child: _RulerCorner(),
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
      child: const Text('cm', style: TextStyle(fontSize: 10, color: Colors.black54)),
    );
  }
}

class _HorizontalRulerPainter extends CustomPainter {
  const _HorizontalRulerPainter({required this.pixelsPerCm});
  final double pixelsPerCm;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = _rulerBackground;
    canvas.drawRect(Offset.zero & size, bg);

    final border = Paint()..color = _rulerBorder..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height - 0.5), Offset(size.width, size.height - 0.5), border);

    if (pixelsPerCm <= 0) return;

    final major = Paint()..color = Colors.black87..strokeWidth = 1;
    final minor = Paint()..color = Colors.black45..strokeWidth = 1;

    final double majorTickTop = size.height * 0.65;

    int i = 0;
    while (true) {
      final double x = i * pixelsPerCm;
      if (x > size.width + 0.5) break;
      canvas.drawLine(Offset(x, size.height), Offset(x, size.height - (size.height - majorTickTop)), major);
      final tp = TextPainter(text: TextSpan(text: '$i', style: _rulerLabelStyle), textDirection: TextDirection.ltr)..layout();
      final labelX = (x - tp.width / 2).clamp(0.0, size.width - tp.width);
      final labelY = (majorTickTop - tp.height - 6).clamp(0.0, size.height - tp.height);
      tp.paint(canvas, Offset(labelX, labelY));
      i++;
    }

    double cm = 0.1;
    while (true) {
      final double x = cm * pixelsPerCm;
      if (x > size.width + 0.5) break;
      if ((cm * 10) % 10 != 0) {
        canvas.drawLine(Offset(x, size.height), Offset(x, size.height - size.height * 0.225), minor);
      }
      cm += 0.1;
    }
  }

  @override
  bool shouldRepaint(covariant _HorizontalRulerPainter old) => old.pixelsPerCm != pixelsPerCm;
}

class _VerticalRulerPainter extends CustomPainter {
  const _VerticalRulerPainter({required this.pixelsPerCm});
  final double pixelsPerCm;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = _rulerBackground;
    canvas.drawRect(Offset.zero & size, bg);

    final border = Paint()..color = _rulerBorder..strokeWidth = 1;
    canvas.drawLine(Offset(size.width - 0.5, 0), Offset(size.width - 0.5, size.height), border);

    if (pixelsPerCm <= 0) return;

    final major = Paint()..color = Colors.black87..strokeWidth = 1;
    final minor = Paint()..color = Colors.black45..strokeWidth = 1;

    int i = 0;
    while (true) {
      final double y = i * pixelsPerCm;
      if (y > size.height + 0.5) break;
      canvas.drawLine(Offset(size.width, y), Offset(size.width - size.width * 0.35, y), major);
      final tp = TextPainter(text: TextSpan(text: '$i', style: _rulerLabelStyle), textDirection: TextDirection.ltr)..layout();
      final labelY = (y - tp.height / 2).clamp(0.0, size.height - tp.height);
      tp.paint(canvas, Offset(2, labelY));
      i++;
    }

    double cm = 0.1;
    while (true) {
      final double y = cm * pixelsPerCm;
      if (y > size.height + 0.5) break;
      if ((cm * 10) % 10 != 0) {
        canvas.drawLine(Offset(size.width, y), Offset(size.width - size.width * 0.225, y), minor);
      }
      cm += 0.1;
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalRulerPainter old) => old.pixelsPerCm != pixelsPerCm;
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

    // 라인/화살표: 회전 사각형 X (엔드포인트 + 회전 핸들만)
    if (selected is LineDrawable || selected is ArrowDrawable) {
      final r = bounds!;
      final boxPaint = Paint()
        ..color = const Color(0xFF3F51B5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      // 바운즈(언회전 직선의 캡슐 박스)를 그대로 표시
      canvas.drawRect(r, boxPaint);

      if (showEndpoints && start != null && end != null) {
        final epPaint = Paint()..color = const Color(0xFF3F51B5);
        canvas.drawCircle(start!, endpointRadius, epPaint);
        canvas.drawCircle(end!, endpointRadius, epPaint);
        final rotateCenter = Offset(r.center.dx, r.top - rotateHandleOffset);
        canvas.drawLine(r.topCenter, rotateCenter, boxPaint);
        canvas.drawCircle(rotateCenter, endpointRadius, epPaint);
      }
      return;
    }

    // 그 외(ObjectDrawable 포함): 선택 박스를 1회 회전만 적용
    final r = bounds!;
    final boxPaint = Paint()
      ..color = const Color(0xFF3F51B5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final obj = selected;
    double angle = 0.0;
    if (obj is ObjectDrawable) {
      angle = obj.rotationAngle;
    }

    // 언회전 bounds를 기준으로 캔버스 변환 1회
    if (angle != 0) {
      canvas.save();
      canvas.translate(r.center.dx, r.center.dy);
      canvas.rotate(angle);
      canvas.translate(-r.center.dx, -r.center.dy);
    }

    // 선택 박스
    canvas.drawRect(r, boxPaint);

    // 4 코너 핸들
    final handlePaint = Paint()..color = const Color(0xFF3F51B5);
    for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      final h = Rect.fromCenter(center: c, width: handleSize, height: handleSize);
      canvas.drawRect(h, handlePaint);
    }

    // 회전 핸들 (윗 중앙에서 위로)
    final rotateCenter = Offset(r.center.dx, r.top - rotateHandleOffset);
    canvas.drawLine(r.topCenter, rotateCenter, boxPaint);
    canvas.drawCircle(rotateCenter, handleSize * 0.6, handlePaint);

    if (angle != 0) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter old) {
    return old.selected != selected ||
        old.bounds != bounds ||
        old.start != start ||
        old.end != end ||
        old.handleSize != handleSize ||
        old.isText != isText;
  }
}
