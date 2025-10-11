import 'dart:ui' show PointerDeviceKind; // 더블클릭 감지용
import 'package:flutter/gestures.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../flutter_painter_v2/flutter_painter.dart';
import '../models/tool.dart';
import '../drawables/table_drawable.dart';

const double _canvasDimension = 640;
const double _rulerThickness = 24;
const Color _rulerBackground = Color(0xFFEDEDED);
const Color _rulerBorder = Color(0xFFBDBDBD);
const TextStyle _rulerLabelStyle = TextStyle(
  fontSize: 8,
  color: Colors.black87,
);

class CanvasArea extends StatefulWidget {
  const CanvasArea({
    super.key,
    required this.currentTool,
    required this.controller,
    this.isEditingCell = false,
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
    this.selectionAnchorCell,
    this.selectionFocusCell,
    required this.selectionStart,
    required this.selectionEnd,
    required this.handleSize,
    required this.rotateHandleOffset,
    required this.showEndpoints,
    required this.isTextSelected,
    this.onCanvasDoubleTapDown,
    this.inlineEditorRect,
    this.inlineEditor,
    this.printerDpi = 300,
    this.scalePercent = 100.0,
    required this.labelPixelSize,
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
  final (int, int)? selectionAnchorCell;
  final (int, int)? selectionFocusCell;
  final Offset? selectionStart;
  final Offset? selectionEnd;
  final double handleSize;
  final double rotateHandleOffset;
  final bool showEndpoints;
  final bool isTextSelected;
  final double printerDpi;
  final double scalePercent;
  final Size labelPixelSize;
  final bool isEditingCell;
  final void Function(TapDownDetails)? onCanvasDoubleTapDown;
  final Rect? inlineEditorRect;
  final Widget? inlineEditor;

  @override
  State<CanvasArea> createState() => _CanvasAreaState();
}

class _CanvasAreaState extends State<CanvasArea> {
  // 데스크톱 더블클릭 수동 감지
  DateTime? _lastClickAt;
  Offset? _lastClickPos;
  static const _dblThreshold = Duration(milliseconds: 300);
  static const _dblDistance = 6.0;

  void _handlePointerDown(PointerDownEvent e) {
    // 기존 선택 로직 유지
    widget.onPointerDownSelect(e);

    // 마우스 좌클릭에 대해서만 더블클릭 수동 감지
    if (e.kind == PointerDeviceKind.mouse && e.buttons == kPrimaryMouseButton) {
      final now = DateTime.now();
      final isDbl = _lastClickAt != null &&
          now.difference(_lastClickAt!) <= _dblThreshold &&
          _lastClickPos != null &&
          (e.position - _lastClickPos!).distance <= _dblDistance;

      if (isDbl && widget.onCanvasDoubleTapDown != null) {
        widget.onCanvasDoubleTapDown!(
          TapDownDetails(globalPosition: e.position, kind: PointerDeviceKind.mouse),
        );
      }
      _lastClickAt = now;
      _lastClickPos = e.position;
    }
  }

  @override
  Widget build(BuildContext context) {
    final overlayIgnored = widget.currentTool == Tool.pen || widget.currentTool == Tool.eraser;
    final absorbPainter = widget.currentTool == Tool.rect ||
        widget.currentTool == Tool.oval ||
        widget.currentTool == Tool.line ||
        widget.currentTool == Tool.arrow ||
        widget.currentTool == Tool.select ||
        widget.currentTool == Tool.text ||
        widget.currentTool == Tool.image;

    final double pixelsPerCm = widget.printerDpi > 0
        ? (widget.printerDpi / 2.54) * (widget.scalePercent / 100.0)
        : 0;

    final double scaleFactor = widget.scalePercent / 100.0;
    final double paintWidth = widget.labelPixelSize.width * scaleFactor;
    final double paintHeight = widget.labelPixelSize.height * scaleFactor;
    final double canvasWidth = math.max(_canvasDimension, paintWidth + _rulerThickness + 32);
    final double canvasHeight = math.max(_canvasDimension, paintHeight + _rulerThickness + 32);

    final content = SizedBox(
      width: canvasWidth,
      height: canvasHeight,
      child: Stack(
        children: [
          // 바탕
          Positioned.fill(child: Container(color: Colors.white)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
            ),
          ),
          // 눈금자
          Positioned(
            left: _rulerThickness,
            top: 0,
            width: paintWidth,
            height: _rulerThickness,
            child: CustomPaint(painter: _HorizontalRulerPainter(pixelsPerCm: pixelsPerCm)),
          ),
          Positioned(
            left: 0,
            top: _rulerThickness,
            width: _rulerThickness,
            height: paintHeight,
            child: CustomPaint(painter: _VerticalRulerPainter(pixelsPerCm: pixelsPerCm)),
          ),
          const Positioned(
            left: 0, top: 0, width: _rulerThickness, height: _rulerThickness, child: _RulerCorner(),
          ),

          // 캔버스 + 오버레이
          Positioned(
            left: _rulerThickness,
            top: _rulerThickness,
            width: paintWidth,
            height: paintHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
              child: Stack(
                children: [
                  // 실제 페인터(컨텐츠)는 라벨 영역 -1px 인셋으로만 클립
                  AbsorbPointer(
                    absorbing: absorbPainter,
                    child: RepaintBoundary(
                      key: widget.painterKey,
                      child: Transform.scale(
                        scale: scaleFactor,
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: widget.labelPixelSize.width,
                          height: widget.labelPixelSize.height,
                          child: ClipRect(
                            clipper: _InsetClipper(1.0),
                            child: FlutterPainter(controller: widget.controller),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Quill read-only overlay for table cells (always visible, even during inline edit)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: true,
                      child: const SizedBox.shrink(),
                    ),
                  ),

                  // 선택/드래그 오버레이 (핸들은 경계 밖으로도 그려지도록 클립 없음)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: overlayIgnored,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _handlePointerDown, // ← 더블클릭 보강
                        child: GestureDetector(
                          dragStartBehavior: DragStartBehavior.down,
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.onCanvasTap,
                          // onDoubleTapDown은 모바일/웹에서도 계속 사용
                          onDoubleTapDown: widget.onCanvasDoubleTapDown,
                          onPanStart: (details) {
                            if (widget.currentTool == Tool.select) {
                              widget.onOverlayPanStart(details);
                            } else {
                              widget.onCreatePanStart(details);
                            }
                          },
                          onPanUpdate: (details) {
                            if (widget.currentTool == Tool.select) {
                              widget.onOverlayPanUpdate(details);
                            } else {
                              widget.onCreatePanUpdate(details);
                            }
                          },
                          onPanEnd: (_) {
                            if (widget.currentTool == Tool.select) {
                              widget.onOverlayPanEnd();
                            } else {
                              widget.onCreatePanEnd();
                            }
                          },
                          child: Transform.scale(
                            scale: scaleFactor,
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              width: widget.labelPixelSize.width,
                              height: widget.labelPixelSize.height,
                              child: CustomPaint(
                                painter: _SelectionPainter(
                                  selected: widget.selectedDrawable,
                                  anchorCell: widget.selectionAnchorCell,
                                  focusCell: widget.selectionFocusCell,
                                  bounds: widget.selectionBounds,
                                  handleSize: widget.handleSize,
                                  rotateHandleOffset: widget.rotateHandleOffset,
                                  showEndpoints: widget.showEndpoints,
                                  start: widget.selectionStart,
                                  end: widget.selectionEnd,
                                  endpointRadius: widget.handleSize * 0.7,
                                  isText: widget.isTextSelected,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ✅ 인라인 편집기 오버레이는 가장 위에!
                  if (widget.inlineEditor != null && widget.inlineEditorRect != null)
                    Positioned(
                      left: widget.inlineEditorRect!.left * (widget.scalePercent / 100.0),
                      top: widget.inlineEditorRect!.top * (widget.scalePercent / 100.0),
                      width: widget.inlineEditorRect!.width * (widget.scalePercent / 100.0),
                      height: widget.inlineEditorRect!.height * (widget.scalePercent / 100.0),
                      child: widget.inlineEditor!,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(scrollbars: true),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: content,
        ),
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
  final (int, int)? anchorCell;
  final (int, int)? focusCell;
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
    this.anchorCell,
    this.focusCell,
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

    // 셀 선택 하이라이트 그리기
    if (selected is TableDrawable && anchorCell != null && focusCell != null) {
      final table = selected as TableDrawable;
      final anchor = anchorCell!;
      final focus = focusCell!;

      final r1 = math.min(anchor.$1, focus.$1);
      final r2 = math.max(anchor.$1, focus.$1);
      final c1 = math.min(anchor.$2, focus.$2);
      final c2 = math.max(anchor.$2, focus.$2);

      final paint = Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      for (int r = r1; r <= r2; r++) {
        for (int c = c1; c <= c2; c++) {
          // 1. 테이블의 로컬 좌표계 기준 셀 사각형을 구합니다.
          final localRect = table.localCellRect(r, c, bounds!.size);

          // 2. 셀 사각형을 월드 좌표계로 변환합니다.
          final path = Path()..addRect(localRect);
          final matrix = Matrix4.identity()
            ..translate(table.position.dx, table.position.dy)
            ..rotateZ(table.rotationAngle);
          final transformedPath = path.transform(matrix.storage);

          canvas.drawPath(transformedPath, paint);
        }
      }
    }

    // --- 기존 선택 핸들 그리기 ---

    if (selected is LineDrawable || selected is ArrowDrawable) {
      final r = bounds!;
      final boxPaint = Paint()
        ..color = const Color(0xFF3F51B5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

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

    final r = bounds!;
    final boxPaint = Paint()
      ..color = const Color(0xFF3F51B5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    double angle = 0.0;
    if (selected is ObjectDrawable) {
      angle = (selected as ObjectDrawable).rotationAngle;
    }

    if (angle != 0) {
      canvas.save();
      canvas.translate(r.center.dx, r.center.dy);
      canvas.rotate(angle);
      canvas.translate(-r.center.dx, -r.center.dy);
    }

    canvas.drawRect(r, boxPaint);

    final handlePaint = Paint()..color = const Color(0xFF3F51B5);
    for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      final h = Rect.fromCenter(center: c, width: handleSize, height: handleSize);
      canvas.drawRect(h, handlePaint);
    }

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
        old.anchorCell != anchorCell ||
        old.focusCell != focusCell ||
        old.start != start ||
        old.end != end ||
        old.handleSize != handleSize ||
        old.isText != isText;
  }
}

class _InsetClipper extends CustomClipper<Rect> {
  final double inset;
  _InsetClipper(this.inset);

  @override
  Rect getClip(Size size) {
    final left = inset.clamp(0.0, size.width / 2);
    final top = inset.clamp(0.0, size.height / 2);
    final width = (size.width - 2 * left).clamp(0.0, size.width);
    final height = (size.height - 2 * top).clamp(0.0, size.height);
    return Rect.fromLTWH(left, top, width, height);
  }

  @override
  bool shouldReclip(covariant _InsetClipper oldClipper) => oldClipper.inset != inset;
}
