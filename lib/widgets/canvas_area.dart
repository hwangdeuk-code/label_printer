import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../flutter_painter_v2/flutter_painter.dart';
import '../models/tool.dart';

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

  @override
  Widget build(BuildContext context) {
    final overlayIgnored = currentTool == Tool.pen || currentTool == Tool.eraser;
    final absorbPainter = currentTool == Tool.rect ||
        currentTool == Tool.oval ||
        currentTool == Tool.line ||
        currentTool == Tool.arrow ||
        currentTool == Tool.select ||
        currentTool == Tool.text;
    return Center(
      child: SizedBox(
        width: 640,
        height: 640,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
          child: Stack(
            children: [
              AbsorbPointer(
                absorbing: absorbPainter,
                child: RepaintBoundary(
                  key: painterKey,
                  child: FlutterPainter(controller: controller),
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
            ],
          ),
        ),
      ),
    );
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
