// lib/main.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:barcode/barcode.dart';

import 'flutter_painter_v2/flutter_painter.dart';
import 'flutter_painter_v2/flutter_painter_pure.dart';
import 'flutter_painter_v2/flutter_painter_extensions.dart';

import 'models/tool.dart';
import 'drawables/constrained_text_drawable.dart';
import 'drawables/barcode_drawable.dart';
import 'widgets/tool_panel.dart';
import 'widgets/inspector_panel.dart';
import 'widgets/canvas_area.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Painter v2.1.0+1 - Shapes/Lines/Arrow/Text',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PainterPage(),
    );
  }
}

enum DragAction { none, move, resizeNW, resizeNE, resizeSW, resizeSE, resizeStart, resizeEnd, rotate }

/// ??????????????????????????????????????????????????????????????????????????????????????????????????????????
class PainterPage extends StatefulWidget {
  const PainterPage({super.key});
  @override
  State<PainterPage> createState() => _PainterPageState();
}

class _PainterPageState extends State<PainterPage> {
  late final PainterController controller;
  final GlobalKey _painterKey = GlobalKey();

  Tool currentTool = Tool.pen;

  // ????????????????
  Color strokeColor = Colors.black;
  double strokeWidth = 4.0;
  Color fillColor = const Color(0x00000000);

  // ???????????????????
  String textFontFamily = 'Roboto';
  double textFontSize = 24.0;
  bool textBold = false;
  bool textItalic = false;
  TxtAlign defaultTextAlign = TxtAlign.left;
  double defaultTextMaxWidth = 300;
  // Barcode defaults
  String barcodeData = '123456789012';
  BarcodeType barcodeType = BarcodeType.Code128;
  bool barcodeShowValue = true;
  double barcodeFontSize = 16.0;
  Color barcodeForeground = Colors.black;
  Color barcodeBackground = Colors.white;


  // ??????????
  bool lockRatio = false;
  bool angleSnap = true;
  bool endpointDragRotates = true;

  // ??????????????????????????
  final double _snapStep = math.pi / 4;
  final double _snapTol = math.pi / 36;
  double? _dragSnapAngle;

  bool _isCreatingLineLike = false;
  bool _firstAngleLockPending = false;
  static const double _firstLockMinLen = 2.0;
  Timer? _pressSnapTimer;
  double _lastRawAngle = 0.0;

  // ??????????????????????????????????
  Offset? dragStart;
  Drawable? previewShape;

  // ???????????????????
  Drawable? selectedDrawable;
  DragAction dragAction = DragAction.none;
  Rect? dragStartBounds;
  Offset? dragStartPointer;
  Offset? dragFixedCorner;
  double? startAngle;

  // ?????????????????????
  final double handleSize = 10.0;
  final double handleTouchRadius = 16.0;
  final double rotateHandleOffset = 28.0;

  // ???????????????????????????????????????
  bool _pressOnSelection = false;
  bool _movedSinceDown = false;
  Offset? _downScene;
  Drawable? _downHitDrawable;

  // ??????????????????????????????????????????????????????????????????????????
  Offset? _laFixedEnd;
  double? _laAngle;
  Offset? _laDir;
  static const double _laMinLen = 2.0;

  @override
  void initState() {
    super.initState();
    controller = PainterController(
      background: Colors.white.backgroundDrawable,
    );
    controller.freeStyleMode = FreeStyleMode.draw;
    controller.freeStyleColor = strokeColor;
    controller.freeStyleStrokeWidth = strokeWidth;
    controller.scalingEnabled = true;
    controller.minScale = 1.0;
    controller.maxScale = 4.0;
    controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pressSnapTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  // ???????????????????????????????????
  Offset _sceneFromGlobal(Offset global) {
    final renderObject = _painterKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return global;
    final local = renderObject.globalToLocal(global);
    return controller.transformationController.toScene(local);
  }

  // ???????????
  Paint _strokePaint(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w;
  Paint _fillPaint(Color c) => Paint()..color = c..style = PaintingStyle.fill;

  // ??????????????????????????????????????????????????
  Offset _lineStart(Drawable d) {
    if (d is LineDrawable) {
      final line = d;
      final dir = Offset(math.cos(line.rotationAngle), math.sin(line.rotationAngle));
      return line.position - dir * (line.length / 2);
    }
    if (d is ArrowDrawable) {
      final arrow = d;
      final dir = Offset(math.cos(arrow.rotationAngle), math.sin(arrow.rotationAngle));
      return arrow.position - dir * (arrow.length / 2);
    }
    return Offset.zero;
  }

  Offset _lineEnd(Drawable d) {
    if (d is LineDrawable) {
      final line = d;
      final dir = Offset(math.cos(line.rotationAngle), math.sin(line.rotationAngle));
      return line.position + dir * (line.length / 2);
    }
    if (d is ArrowDrawable) {
      final arrow = d;
      final dir = Offset(math.cos(arrow.rotationAngle), math.sin(arrow.rotationAngle));
      return arrow.position + dir * (arrow.length / 2);
    }
    return Offset.zero;
  }

  Rect _boundsOf(Drawable d) {
    if (d is RectangleDrawable) {
      final rect = d;
      return Rect.fromCenter(center: rect.position, width: rect.size.width, height: rect.size.height);
    }
    if (d is OvalDrawable) {
      final oval = d;
      return Rect.fromCenter(center: oval.position, width: oval.size.width, height: oval.size.height);
    }
    if (d is BarcodeDrawable) {
      final barcode = d;
      return Rect.fromCenter(center: barcode.position, width: barcode.size.width, height: barcode.size.height);
    }
    if (d is LineDrawable) {
      final line = d;
      final a = _lineStart(line);
      final b = _lineEnd(line);
      return Rect.fromPoints(a, b);
    }
    if (d is ArrowDrawable) {
      final arrow = d;
      final a = _lineStart(arrow);
      final b = _lineEnd(arrow);
      return Rect.fromPoints(a, b);
    }
    if (d is ConstrainedTextDrawable) {
      final constrained = d;
      final size = constrained.getSize(maxWidth: constrained.maxWidth);
      return Rect.fromCenter(center: constrained.position, width: size.width, height: size.height);
    }
    if (d is TextDrawable) {
      final text = d;
      final size = text.getSize();
      return Rect.fromCenter(center: text.position, width: size.width, height: size.height);
    }
    return Rect.zero;
  }

  bool get _isPainterGestureTool =>
      currentTool == Tool.pen || currentTool == Tool.eraser || currentTool == Tool.select;

  void _setTool(Tool t) {
    setState(() {
      currentTool = t;
      switch (t) {
        case Tool.pen:
          controller.freeStyleMode = FreeStyleMode.draw;
          controller.scalingEnabled = true;
          break;
        case Tool.eraser:
          controller.freeStyleMode = FreeStyleMode.erase;
          controller.scalingEnabled = true;
          break;
        case Tool.select:
          controller.freeStyleMode = FreeStyleMode.none;
          controller.scalingEnabled = true;
          break;
        case Tool.text:
          controller.freeStyleMode = FreeStyleMode.none;
          controller.scalingEnabled = false;
          break;
        default:
          controller.freeStyleMode = FreeStyleMode.none;
          controller.scalingEnabled = false;
          break;
      }
    });
  }

  // ????????????????????
  double _normalizeAngle(double rad) {
    final twoPi = 2 * math.pi;
    double a = rad % twoPi;
    if (a >= math.pi) a -= twoPi;
    if (a < -math.pi) a += twoPi;
    return a;
  }
  double _nearestStep(double raw) =>
      (_normalizeAngle(raw / _snapStep).roundToDouble()) * _snapStep;
  double _snapAngle(double raw) {
    if (!angleSnap) return raw;
    final norm = _normalizeAngle(raw);
    final target = _nearestStep(norm);
    if (_isCreatingLineLike && _firstAngleLockPending) {
      _dragSnapAngle = target; _firstAngleLockPending = false; return _dragSnapAngle!;
    }
    if ((norm - target).abs() <= _snapTol) {
      _dragSnapAngle ??= target; return _dragSnapAngle!;
    }
    if (_dragSnapAngle != null) {
      final exitTol = _snapTol * 1.5;
      if ((norm - _dragSnapAngle!).abs() <= exitTol) return _dragSnapAngle!;
    }
    return norm;
  }

  // ????????????????
  void _onPanStartCreate(DragStartDetails d) {
    if (_isPainterGestureTool || currentTool == Tool.text) return;
    _dragSnapAngle = null;
    _isCreatingLineLike = (currentTool == Tool.line || currentTool == Tool.arrow);
    _firstAngleLockPending = _isCreatingLineLike;

    _pressSnapTimer?.cancel();
    if (_isCreatingLineLike) {
      _pressSnapTimer = Timer(const Duration(milliseconds: 250), () {
        if (_isCreatingLineLike && _firstAngleLockPending) {
          _dragSnapAngle = _nearestStep(_lastRawAngle);
          _firstAngleLockPending = false;
        }
      });
    }

    dragStart = _sceneFromGlobal(d.globalPosition);
    previewShape = _makeShape(dragStart!, dragStart!);
    if (previewShape != null) controller.addDrawables([previewShape!]);
  }

  void _onPanUpdateCreate(DragUpdateDetails d) {
    if (_isPainterGestureTool || currentTool == Tool.text) return;
    if (dragStart == null || previewShape == null) return;
    final current = _sceneFromGlobal(d.globalPosition);

    if (_isCreatingLineLike) {
      final v = current - dragStart!;
      if (v.distance > 0) _lastRawAngle = math.atan2(v.dy, v.dx);
    }

    final updated = _makeShape(dragStart!, current, previewOf: previewShape);
    if (updated != null) {
      controller.replaceDrawable(previewShape!, updated);
      previewShape = updated;
    }
  }

  void _onPanEndCreate() {
    if (_isPainterGestureTool || currentTool == Tool.text) return;
    _pressSnapTimer?.cancel();
    _dragSnapAngle = null;
    _isCreatingLineLike = false;
    _firstAngleLockPending = false;
    final createdDrawable = previewShape;
    dragStart = null;
    previewShape = null;

    final shouldSwitchToSelect = currentTool == Tool.rect ||
        currentTool == Tool.oval ||
        currentTool == Tool.line ||
        currentTool == Tool.arrow ||
        currentTool == Tool.barcode;

    if (shouldSwitchToSelect && createdDrawable != null) {
      setState(() => selectedDrawable = createdDrawable);
    }
    if (shouldSwitchToSelect) {
      _setTool(Tool.select);
    }
  }

  Drawable? _makeShape(Offset a, Offset b, {Drawable? previewOf}) {
    var dx = b.dx - a.dx;
    var dy = b.dy - a.dy;
    var w = dx.abs();
    var h = dy.abs();

    if (lockRatio && (currentTool == Tool.rect || currentTool == Tool.oval || currentTool == Tool.barcode)) {
      final m = math.max(w, h);
      dx = (dx.isNegative ? -m : m);
      dy = (dy.isNegative ? -m : m);
      w = m; h = m;
    }

    final cx = math.min(a.dx, a.dx + dx) + w / 2;
    final cy = math.min(a.dy, a.dy + dy) + h / 2;
    final center = Offset(cx, cy);

    switch (currentTool) {
      case Tool.rect:
        return RectangleDrawable(
          position: center,
          size: Size(w, h),
          paint: fillColor.a == 0
              ? _strokePaint(strokeColor, strokeWidth)
              : _fillPaint(fillColor),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        );
      case Tool.oval:
        return OvalDrawable(
          position: center,
          size: Size(w, h),
          paint: fillColor.a == 0
              ? _strokePaint(strokeColor, strokeWidth)
              : _fillPaint(fillColor),
        );
      case Tool.barcode:
        final existing = previewOf is BarcodeDrawable ? previewOf : null;
        final size = Size(math.max(w, 1), math.max(h, 1));
        return BarcodeDrawable(
          data: existing?.data ?? barcodeData,
          type: existing?.type ?? barcodeType,
          showValue: existing?.showValue ?? barcodeShowValue,
          fontSize: existing?.fontSize ?? barcodeFontSize,
          foreground: existing?.foreground ?? barcodeForeground,
          background: existing?.background ?? barcodeBackground,
          bold: existing?.bold ?? false,
          italic: existing?.italic ?? false,
          fontFamily: existing?.fontFamily ?? 'Roboto',
          textAlign: existing?.textAlign,
          maxTextWidth: existing?.maxTextWidth ?? 0,
          position: center,
          size: size,
        );
      case Tool.line:
      case Tool.arrow:
        final length = (b - a).distance;
        var angle = math.atan2(dy, dx);
        if (_isCreatingLineLike && _firstAngleLockPending && length >= _firstLockMinLen) {
          _dragSnapAngle = _nearestStep(angle);
          _firstAngleLockPending = false;
        }
        angle = _snapAngle(angle);

        final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        if (currentTool == Tool.line) {
          return LineDrawable(
            position: mid, length: length, rotationAngle: angle,
            paint: _strokePaint(strokeColor, strokeWidth),
          );
        } else {
          return ArrowDrawable(
            position: mid, length: length, rotationAngle: angle,
            arrowHeadSize: 16,
            paint: _strokePaint(strokeColor, strokeWidth),
          );
        }
      default:
        return null;
    }
  }

  // ?????????????????
  bool _hitTest(Drawable d, Offset p) {
    final rect = _boundsOf(d).inflate(math.max(8, strokeWidth));
    if (d is LineDrawable || d is ArrowDrawable) {
      final a = _lineStart(d);
      final b = _lineEnd(d);
      final dist = _distanceToSegment(p, a, b);
      return dist <= math.max(8, strokeWidth) || rect.contains(p);
    }
    return rect.contains(p);
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ap = p - a;
    final ab = b - a;
    final denom = ab.dx * ab.dx + ab.dy * ab.dy;
    if (denom == 0) return (p - a).distance;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / denom;
    final tt = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + ab.dx * tt, a.dy + ab.dy * tt);
    return (p - proj).distance;
  }

  bool _hitSelectionChromeScene(Offset pScene) {
    if (selectedDrawable == null) return false;

    if (selectedDrawable is LineDrawable || selectedDrawable is ArrowDrawable) {
      final a = _lineStart(selectedDrawable!);
      final b = _lineEnd(selectedDrawable!);
      if ((pScene - a).distance <= handleTouchRadius) return true;
      if ((pScene - b).distance <= handleTouchRadius) return true;
      final r = _boundsOf(selectedDrawable!);
      if (r.inflate(4).contains(pScene)) return true;
      return false;
    }

    final r = _boundsOf(selectedDrawable!);
    final corners = [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight];
    final rotCenter = _rotateHandlePos(r);
    final topCenter = r.topCenter;

    for (final c in corners) {
      if ((pScene - c).distance <= handleTouchRadius) return true;
    }
    if ((pScene - rotCenter).distance <= handleTouchRadius) return true;
    final distToLine = _distanceToSegment(pScene, topCenter, rotCenter);
    if (distToLine <= handleTouchRadius * 0.7) return true;
    if (r.inflate(4).contains(pScene)) return true;
    return false;
  }

  DragAction _hitHandle(Rect bounds, Offset p) {
    if (selectedDrawable is LineDrawable || selectedDrawable is ArrowDrawable) {
      final a = _lineStart(selectedDrawable!);
      final b = _lineEnd(selectedDrawable!);
      if ((p - a).distance <= handleTouchRadius) return DragAction.resizeStart;
      if ((p - b).distance <= handleTouchRadius) return DragAction.resizeEnd;

      final rotCenter = _rotateHandlePos(bounds);
      if ((p - rotCenter).distance <= handleTouchRadius) return DragAction.rotate;

      if (bounds.inflate(4).contains(p)) return DragAction.move;
      return DragAction.none;
    }

    final corners = [bounds.topLeft, bounds.topRight, bounds.bottomLeft, bounds.bottomRight];
    final rotCenter = _rotateHandlePos(bounds);

    if ((p - corners[0]).distance <= handleTouchRadius) return DragAction.resizeNW;
    if ((p - corners[1]).distance <= handleTouchRadius) return DragAction.resizeNE;
    if ((p - corners[2]).distance <= handleTouchRadius) return DragAction.resizeSW;
    if ((p - corners[3]).distance <= handleTouchRadius) return DragAction.resizeSE;
    if ((p - rotCenter).distance <= handleTouchRadius) return DragAction.rotate;

    final distToLine = _distanceToSegment(p, bounds.topCenter, rotCenter);
    if (distToLine <= handleTouchRadius * 0.7) return DragAction.rotate;
    if (bounds.inflate(4).contains(p)) return DragAction.move;
    return DragAction.none;
  }

  Offset _rotateHandlePos(Rect r) => Offset(r.center.dx, r.top - rotateHandleOffset);

  // PointerDown: select/text
  void _handlePointerDownSelect(PointerDownEvent e) async {
    if (currentTool == Tool.text) {
      final scenePoint = _sceneFromGlobal(e.position);
      await _createTextAt(scenePoint);
      return;
    }
    if (currentTool != Tool.select) return;

    final scenePoint = _sceneFromGlobal(e.position);
    _downScene = scenePoint;
    _movedSinceDown = false;
    _pressOnSelection = _hitSelectionChromeScene(scenePoint);

    final hit = _pickTopAt(scenePoint);
    _downHitDrawable = hit;
    if (hit != null && hit != selectedDrawable) {
      setState(() => selectedDrawable = hit);
    }
  }

  Drawable? _pickTopAt(Offset scenePoint) {
    final list = controller.drawables.reversed.toList();
    for (final d in list) {
      if (_hitTest(d, scenePoint)) return d;
    }
    return null;
  }

  // Select overlay
  void _onOverlayPanStart(DragStartDetails details) {
    if (currentTool != Tool.select) return;

    _movedSinceDown = true;
    _pressSnapTimer?.cancel();
    _dragSnapAngle = null;
    _isCreatingLineLike = false;
    _firstAngleLockPending = false;

    final localScene = _sceneFromGlobal(details.globalPosition);
    final current = selectedDrawable;

    void clearLineResize() {
      _laFixedEnd = null;
      _laAngle = null;
      _laDir = null;
    }

    void prepareLineResize(Drawable drawable, DragAction action) {
      if (action != DragAction.resizeStart && action != DragAction.resizeEnd) {
        clearLineResize();
        return;
      }

      if (drawable is LineDrawable) {
        final start = _lineStart(drawable);
        final end = _lineEnd(drawable);
        _laFixedEnd = action == DragAction.resizeStart ? end : start;
        final rotation = drawable.rotationAngle;
        _laAngle = rotation;
        _laDir = Offset(math.cos(rotation), math.sin(rotation));
        return;
      }

      if (drawable is ArrowDrawable) {
        final start = _lineStart(drawable);
        final end = _lineEnd(drawable);
        _laFixedEnd = action == DragAction.resizeStart ? end : start;
        final rotation = drawable.rotationAngle;
        _laAngle = rotation;
        _laDir = Offset(math.cos(rotation), math.sin(rotation));
        return;
      }

      clearLineResize();
    }

    clearLineResize();

    if (current != null) {
      final rect = _boundsOf(current);
      final action = _hitHandle(rect, localScene);
      dragAction = action;
      dragStartBounds = rect;
      dragStartPointer = localScene;

      if (action == DragAction.rotate && current is ObjectDrawable) {
        startAngle = current.rotationAngle;
      } else {
        startAngle = null;
      }

      prepareLineResize(current, action);

      if (action == DragAction.none && !rect.inflate(4).contains(localScene)) {
        final hit = _pickTopAt(localScene);
        if (hit != null && hit != current) {
          setState(() => selectedDrawable = hit);
          final r2 = _boundsOf(hit);
          final a2 = _hitHandle(r2, localScene);
          dragAction = a2;
          dragStartBounds = r2;
          dragStartPointer = localScene;

          if (a2 == DragAction.rotate && hit is ObjectDrawable) {
            startAngle = hit.rotationAngle;
          } else {
            startAngle = null;
          }

          prepareLineResize(hit, a2);
        }
      }
    } else {
      final hit = _pickTopAt(localScene);
      if (hit != null) {
        setState(() => selectedDrawable = hit);
        final r2 = _boundsOf(hit);
        final a2 = _hitHandle(r2, localScene);
        dragAction = a2;
        dragStartBounds = r2;
        dragStartPointer = localScene;

        if (a2 == DragAction.rotate && hit is ObjectDrawable) {
          startAngle = hit.rotationAngle;
        } else {
          startAngle = null;
        }

        prepareLineResize(hit, a2);
      } else {
        dragAction = DragAction.none;
        dragStartBounds = null;
        dragStartPointer = null;
        startAngle = null;
        clearLineResize();
      }
    }

    setState(() {});
  }
  void _onOverlayPanUpdate(DragUpdateDetails details) {
    if (selectedDrawable == null || dragAction == DragAction.none) return;
    _movedSinceDown = true;

    final localScene = _sceneFromGlobal(details.globalPosition);
    final original = selectedDrawable!;
    final startRect = dragStartBounds!;
    final startPt = dragStartPointer!;
    Drawable? replaced;

    if (dragAction == DragAction.move) {
      final delta = localScene - startPt;
      if (original is RectangleDrawable) {
        replaced = RectangleDrawable(
          position: startRect.center + delta,
          size: startRect.size,
          paint: original.paint,
          borderRadius: original.borderRadius,
        );
      } else if (original is OvalDrawable) {
        replaced = OvalDrawable(
          position: startRect.center + delta,
          size: startRect.size,
          paint: original.paint,
        );
      } else if (original is BarcodeDrawable) {
        replaced = original.copyWith(position: startRect.center + delta);
      } else if (original is LineDrawable) {
        replaced = LineDrawable(
          position: startRect.center + delta,
          length: original.length,
          rotationAngle: original.rotationAngle,
          paint: original.paint,
        );
      } else if (original is ArrowDrawable) {
        replaced = ArrowDrawable(
          position: startRect.center + delta,
          length: original.length,
          rotationAngle: original.rotationAngle,
          arrowHeadSize: original.arrowHeadSize,
          paint: original.paint,
        );
      } else if (original is ConstrainedTextDrawable) {
        replaced = original.copyWith(position: startRect.center + delta);
      } else if (original is TextDrawable) {
        replaced = original.copyWith(position: startRect.center + delta);
      }
    } else if (dragAction == DragAction.rotate) {
      if (original is ObjectDrawable) {
        final center = original.position;
        var ang = math.atan2((localScene - center).dy, (localScene - center).dx);
        ang = _snapAngle(ang);

        if (original is LineDrawable) {
          replaced = original.copyWith(rotation: ang);
        } else if (original is ArrowDrawable) {
          replaced = original.copyWith(rotation: ang);
        } else if (original is ConstrainedTextDrawable) {
          replaced = original.copyWith(rotation: ang);
        } else if (original is TextDrawable) {
          replaced = original.copyWith(rotation: ang);
        }
      }
    } else {
      if (original is RectangleDrawable || original is OvalDrawable || original is BarcodeDrawable) {
        dragFixedCorner ??= _fixedCornerForAction(startRect, dragAction);
        final fixed = dragFixedCorner!;
        Rect newRect = Rect.fromPoints(fixed, localScene);

        if (lockRatio) {
          final size = newRect.size;
          final m = math.max(size.width.abs(), size.height.abs());
          final dir = (localScene - fixed);
          final ddx = dir.dx.isNegative ? -m : m;
          final ddy = dir.dy.isNegative ? -m : m;
          newRect = Rect.fromPoints(fixed, fixed + Offset(ddx, ddy));
        }

        if (original is RectangleDrawable) {
          replaced = RectangleDrawable(
            position: newRect.center,
            size: newRect.size,
            paint: original.paint,
            borderRadius: original.borderRadius,
          );
        } else if (original is OvalDrawable) {
          replaced = OvalDrawable(
            position: newRect.center,
            size: newRect.size,
            paint: original.paint,
          );
        } else if (original is BarcodeDrawable) {
          replaced = original.copyWith(position: newRect.center, size: newRect.size);
        }
      } else if (original is ConstrainedTextDrawable) {
        dragFixedCorner ??= _fixedCornerForAction(startRect, dragAction);
        final fixed = dragFixedCorner!;
        final newRect = Rect.fromPoints(fixed, localScene);
        final newWidth = newRect.size.width.abs().clamp(40.0, 2000.0);
        final centered = Rect.fromCenter(center: newRect.center, width: newWidth, height: startRect.height);
        replaced = original.copyWith(position: centered.center, maxWidth: newWidth);
      } else if (original is LineDrawable || original is ArrowDrawable) {
        if (_laFixedEnd != null) {
          final fixed = _laFixedEnd!;
          final pnt = localScene;

          double ang;
          double len;
          if (endpointDragRotates) {
            ang = math.atan2((pnt - fixed).dy, (pnt - fixed).dx);
            ang = _snapAngle(ang);
            len = (pnt - fixed).distance.clamp(_laMinLen, double.infinity);
          } else {
            final dir = _laDir ?? Offset(math.cos(_laAngle ?? 0), math.sin(_laAngle ?? 0));
            final v = pnt - fixed;
            final t = v.dx * dir.dx + v.dy * dir.dy;
            ang = _laAngle ?? math.atan2(dir.dy, dir.dx);
            len = (dir * t).distance.clamp(_laMinLen, double.infinity);
          }

          final dir2 = Offset(math.cos(ang), math.sin(ang));
          final movingEnd = fixed + dir2 * len;
          final newCenter = (fixed + movingEnd) / 2;

          if (original is LineDrawable) {
            replaced = original.copyWith(position: newCenter, length: len, rotation: ang);
          } else if (original is ArrowDrawable) {
            replaced = original.copyWith(position: newCenter, length: len, rotation: ang);
          }

          _laAngle = ang;
          _laDir = dir2;
        }
      }
    }

    if (replaced != null) {
      controller.replaceDrawable(original, replaced);
      setState(() => selectedDrawable = replaced);
    }
  }
  void _onOverlayPanEnd() {
    _pressSnapTimer?.cancel();
    _dragSnapAngle = null;
    _isCreatingLineLike = false;
    _firstAngleLockPending = false;
    dragAction = DragAction.none;
    dragStartBounds = null;
    dragStartPointer = null;
    dragFixedCorner = null;
    startAngle = null;

    _laFixedEnd = null;
    _laAngle = null;
    _laDir = null;

    _pressOnSelection = false;
    _movedSinceDown = false;
    _downScene = null;
    _downHitDrawable = null;
  }

  Offset _fixedCornerForAction(Rect r, DragAction a) {
    switch (a) {
      case DragAction.resizeNW: return r.bottomRight;
      case DragAction.resizeNE: return r.bottomLeft;
      case DragAction.resizeSW: return r.topRight;
      case DragAction.resizeSE: return r.topLeft;
      default: return r.center;
    }
  }

  // ?????????????????????
  Future<void> _createTextAt(Offset scenePoint) async {
    final controllerText = TextEditingController();
    double tempSize = textFontSize;
    bool tempBold = textBold;
    bool tempItalic = textItalic;
    String tempFamily = textFontFamily;
    Color tempColor = strokeColor;
    TxtAlign tempAlign = defaultTextAlign;
    double tempMaxWidth = defaultTextMaxWidth;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSS) => AlertDialog(
            title: const Text('Add Text'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controllerText,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Text', hintText: 'Enter text...'),
                    minLines: 1, maxLines: 6,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Size'),
                      Expanded(
                        child: Slider(min: 8, max: 96, value: tempSize, onChanged: (v) => setSS(() => tempSize = v)),
                      ),
                      SizedBox(width: 40, child: Text(tempSize.toStringAsFixed(0))),
                    ],
                  ),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      FilterChip(label: const Text('Bold'), selected: tempBold, onSelected: (v) => setSS(() => tempBold = v)),
                      FilterChip(label: const Text('Italic'), selected: tempItalic, onSelected: (v) => setSS(() => tempItalic = v)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Font'), const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: tempFamily,
                        items: const [
                          DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
                          DropdownMenuItem(value: 'NotoSans', child: Text('NotoSans')),
                          DropdownMenuItem(value: 'Monospace', child: Text('Monospace')),
                        ],
                        onChanged: (v) => setSS(() { if (v != null) tempFamily = v; }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Align'), const SizedBox(width: 8),
                      DropdownButton<TxtAlign>(
                        value: tempAlign,
                        items: const [
                          DropdownMenuItem(value: TxtAlign.left, child: Text('Left')),
                          DropdownMenuItem(value: TxtAlign.center, child: Text('Center')),
                          DropdownMenuItem(value: TxtAlign.right, child: Text('Right')),
                        ],
                        onChanged: (v) => setSS(() { if (v != null) tempAlign = v; }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Max Width'),
                      Expanded(
                        child: Slider(min: 40, max: 800, value: tempMaxWidth, onChanged: (v) => setSS(() => tempMaxWidth = v)),
                      ),
                      SizedBox(width: 56, child: Text(tempMaxWidth.toStringAsFixed(0))),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
            ],
          ),
        );
      },
    );

    if (result != true) return;
    final txt = controllerText.text.trim();
    if (txt.isEmpty) return;

    final style = TextStyle(
      color: tempColor,
      fontSize: tempSize,
      fontWeight: tempBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: tempItalic ? FontStyle.italic : FontStyle.normal,
      fontFamily: tempFamily,
    );

    final t = ConstrainedTextDrawable(
      text: txt,
      position: scenePoint,
      rotationAngle: 0.0,
      style: style,
      align: tempAlign,
      maxWidth: tempMaxWidth,
      direction: TextDirection.ltr,
    );

    controller.addDrawables([t]);
    setState(() {
      selectedDrawable = t;
      currentTool = Tool.select;
      controller.freeStyleMode = FreeStyleMode.none;
      controller.scalingEnabled = true;
      textFontSize = tempSize;
      textBold = tempBold;
      textItalic = tempItalic;
      textFontFamily = tempFamily;
      strokeColor = tempColor;
      defaultTextAlign = tempAlign;
      defaultTextMaxWidth = tempMaxWidth;
    });
  }

  // Clear/Save
  void _clearAll() {
    controller.clearDrawables();
    selectedDrawable = null;
    dragAction = DragAction.none;

    dragStart = null;
    previewShape = null;

    dragStartBounds = null;
    dragStartPointer = null;
    dragFixedCorner = null;
    startAngle = null;

    _pressSnapTimer?.cancel();
    _dragSnapAngle = null;
    _isCreatingLineLike = false;
    _firstAngleLockPending = false;

    _laFixedEnd = null;
    _laAngle = null;
    _laDir = null;

    _pressOnSelection = false;
    _movedSinceDown = false;
    _downScene = null;
    _downHitDrawable = null;

    if (mounted) setState(() {});
  }

  Future<void> _saveAsPng(BuildContext context) async {
    final ui.Image img = await controller.renderImage(const Size(1200, 1200));
    final bytes = await img.pngBytes;
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Exported PNG Preview'),
        content: Image.memory(bytes!),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painter v2.1.0+1 - Shapes/Lines/Arrow/Text'),
        actions: [
          IconButton(onPressed: controller.canUndo ? controller.undo : null, icon: const Icon(Icons.undo)),
          IconButton(onPressed: controller.canRedo ? controller.redo : null, icon: const Icon(Icons.redo)),
          IconButton(onPressed: _clearAll, icon: const Icon(Icons.layers_clear), tooltip: 'Clear'),
          IconButton(onPressed: () => _saveAsPng(context), icon: const Icon(Icons.save_alt)),
        ],
      ),
      body: Row(
        children: [
          ToolPanel(
            currentTool: currentTool,
            onToolSelected: _setTool,
            strokeColor: strokeColor,
            onStrokeColorChanged: (c) {
              setState(() {
                strokeColor = c;
                controller.freeStyleColor = strokeColor;
              });
            },
            strokeWidth: strokeWidth,
            onStrokeWidthChanged: (v) {
              setState(() {
                strokeWidth = v;
                controller.freeStyleStrokeWidth = v;
              });
            },
            fillColor: fillColor,
            onFillColorChanged: (c) => setState(() => fillColor = c),
            lockRatio: lockRatio,
            onLockRatioChanged: (v) => setState(() => lockRatio = v),
            angleSnap: angleSnap,
            onAngleSnapChanged: (v) => setState(() => angleSnap = v),
            endpointDragRotates: endpointDragRotates,
            onEndpointDragRotatesChanged: (v) => setState(() => endpointDragRotates = v),
            textFontSize: textFontSize,
            onTextFontSizeChanged: (v) => setState(() => textFontSize = v),
            textBold: textBold,
            onTextBoldChanged: (v) => setState(() => textBold = v),
            textItalic: textItalic,
            onTextItalicChanged: (v) => setState(() => textItalic = v),
            textFontFamily: textFontFamily,
            onTextFontFamilyChanged: (v) => setState(() => textFontFamily = v),
            defaultTextAlign: defaultTextAlign,
            onDefaultTextAlignChanged: (v) => setState(() => defaultTextAlign = v),
            defaultTextMaxWidth: defaultTextMaxWidth,
            onDefaultTextMaxWidthChanged: (v) => setState(() => defaultTextMaxWidth = v),
            barcodeData: barcodeData,
            onBarcodeDataChanged: (v) => setState(() => barcodeData = v),
            barcodeType: barcodeType,
            onBarcodeTypeChanged: (v) => setState(() => barcodeType = v),
            barcodeShowValue: barcodeShowValue,
            onBarcodeShowValueChanged: (v) => setState(() => barcodeShowValue = v),
            barcodeFontSize: barcodeFontSize,
            onBarcodeFontSizeChanged: (v) => setState(() => barcodeFontSize = v),
            barcodeForeground: barcodeForeground,
            onBarcodeForegroundChanged: (c) => setState(() => barcodeForeground = c),
            barcodeBackground: barcodeBackground,
            onBarcodeBackgroundChanged: (c) => setState(() => barcodeBackground = c),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: CanvasArea(
              currentTool: currentTool,
              controller: controller,
              painterKey: _painterKey,
              onPointerDownSelect: _handlePointerDownSelect,
              onCanvasTap: _handleCanvasTap,
              onOverlayPanStart: _onOverlayPanStart,
              onOverlayPanUpdate: _onOverlayPanUpdate,
              onOverlayPanEnd: _onOverlayPanEnd,
              onCreatePanStart: _onPanStartCreate,
              onCreatePanUpdate: _onPanUpdateCreate,
              onCreatePanEnd: _onPanEndCreate,
              selectedDrawable: selectedDrawable,
              selectionBounds: selectedDrawable == null ? null : _boundsOf(selectedDrawable!),
              selectionStart: selectedDrawable is LineDrawable || selectedDrawable is ArrowDrawable ? _lineStart(selectedDrawable!) : null,
              selectionEnd: selectedDrawable is LineDrawable || selectedDrawable is ArrowDrawable ? _lineEnd(selectedDrawable!) : null,
              handleSize: handleSize,
              rotateHandleOffset: rotateHandleOffset,
              showEndpoints: selectedDrawable is LineDrawable || selectedDrawable is ArrowDrawable,
              isTextSelected: selectedDrawable is ConstrainedTextDrawable || selectedDrawable is TextDrawable,
            ),
          ),
          const VerticalDivider(width: 1),
          InspectorPanel(
            selected: selectedDrawable,
            strokeWidth: strokeWidth,
            onApplyStroke: _applyInspector,
            onReplaceDrawable: (original, replacement) {
              controller.replaceDrawable(original, replacement);
              setState(() => selectedDrawable = replacement);
            },
            angleSnap: angleSnap,
            snapAngle: _snapAngle,
            textDefaults: TextDefaults(
              fontFamily: textFontFamily,
              fontSize: textFontSize,
              bold: textBold,
              italic: textItalic,
              align: defaultTextAlign,
              maxWidth: defaultTextMaxWidth,
            ),
          ),
        ],
      ),
    );
  }

  void _handleCanvasTap() {
    if (currentTool != Tool.select) return;
    final hadHit = _downHitDrawable != null;
    if (!hadHit && !_pressOnSelection && !_movedSinceDown) {
      setState(() {
        selectedDrawable = null;
        dragAction = DragAction.none;
      });
    }
    _pressOnSelection = false;
    _movedSinceDown = false;
    _downScene = null;
    _downHitDrawable = null;
  }


  void _applyInspector({Color? newStrokeColor, double? newStrokeWidth, double? newCornerRadius}) {
    final d = selectedDrawable;
    if (d == null) return;
    Drawable? replaced;

    if (d is RectangleDrawable) {
      replaced = RectangleDrawable(
        position: d.position,
        size: d.size,
        paint: _strokePaint(newStrokeColor ?? strokeColor, newStrokeWidth ?? strokeWidth),
        borderRadius: BorderRadius.all(Radius.circular(newCornerRadius ?? d.borderRadius.topLeft.x)),
      );
    } else if (d is OvalDrawable) {
      replaced = OvalDrawable(
        position: d.position,
        size: d.size,
        paint: _strokePaint(newStrokeColor ?? strokeColor, newStrokeWidth ?? strokeWidth),
      );
    } else if (d is LineDrawable) {
      replaced = d.copyWith(
        paint: _strokePaint(newStrokeColor ?? strokeColor, newStrokeWidth ?? strokeWidth),
      );
    } else if (d is ArrowDrawable) {
      replaced = d.copyWith(
        paint: _strokePaint(newStrokeColor ?? strokeColor, newStrokeWidth ?? strokeWidth),
      );
    } else if (d is ConstrainedTextDrawable || d is TextDrawable) {
      return;
    }

    if (replaced != null) {
      controller.replaceDrawable(d, replaced);
      setState(() {
        selectedDrawable = replaced;
        if (newStrokeColor != null) strokeColor = newStrokeColor;
        if (newStrokeWidth != null) strokeWidth = newStrokeWidth;
      });
    }
  }
}

