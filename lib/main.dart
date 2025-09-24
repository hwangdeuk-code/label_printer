// lib/main.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'flutter_painter_v2/flutter_painter.dart';
import 'flutter_painter_v2/flutter_painter_pure.dart';
import 'flutter_painter_v2/flutter_painter_extensions.dart';
void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Painter v2.1.0+1 — Shapes/Lines/Arrow/Text',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PainterPage(),
    );
  }
}

enum Tool { select, pen, eraser, rect, oval, line, arrow, text }
enum DragAction { none, move, resizeNW, resizeNE, resizeSW, resizeSE, resizeStart, resizeEnd, rotate }
enum TxtAlign { left, center, right }

/// 커스텀 텍스트 드로어블(정렬/최대폭 지원)
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

  @override
  void drawObject(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: _textAlign,
      textDirection: direction,
      maxLines: 1000,
    )..layout(minWidth: 0, maxWidth: maxWidth);
    final boxSize = tp.size;

    canvas.save();
    canvas.translate(position.dx, position.dy);
    if (rotationAngle != 0) canvas.rotate(rotationAngle);
    if (scale != 1.0) canvas.scale(scale);
    final topLeft = Offset(-boxSize.width / 2, -boxSize.height / 2);
    tp.paint(canvas, topLeft);
    canvas.restore();
  }
}

class PainterPage extends StatefulWidget {
  const PainterPage({super.key});
  @override
  State<PainterPage> createState() => _PainterPageState();
}

class _PainterPageState extends State<PainterPage> {
  late final PainterController controller;
  final GlobalKey _painterKey = GlobalKey();

  Tool currentTool = Tool.pen;

  // 스타일
  Color strokeColor = Colors.black;
  double strokeWidth = 4.0;
  Color fillColor = const Color(0x00000000);

  // 텍스트 기본
  String textFontFamily = 'Roboto';
  double textFontSize = 24.0;
  bool textBold = false;
  bool textItalic = false;
  TxtAlign defaultTextAlign = TxtAlign.left;
  double defaultTextMaxWidth = 300;

  // 옵션
  bool lockRatio = false;
  bool angleSnap = true;
  bool endpointDragRotates = true;

  // 스냅 상태
  final double _snapStep = math.pi / 4;
  final double _snapTol = math.pi / 36;
  double? _dragSnapAngle;

  bool _isCreatingLineLike = false;
  bool _firstAngleLockPending = false;
  static const double _firstLockMinLen = 2.0;
  Timer? _pressSnapTimer;
  double _lastRawAngle = 0.0;

  // 생성 드래그
  Offset? dragStart;
  Drawable? previewShape;

  // 선택/조작
  Drawable? selectedDrawable;
  DragAction dragAction = DragAction.none;
  Rect? dragStartBounds;
  Offset? dragStartPointer;
  Offset? dragFixedCorner;
  double? startAngle;

  // 핸들 렌더
  final double handleSize = 10.0;
  final double handleTouchRadius = 16.0;
  final double rotateHandleOffset = 28.0;

  // 탭/드래그 가드
  bool _pressOnSelection = false;
  bool _movedSinceDown = false;
  Offset? _downScene;
  Drawable? _downHitDrawable;

  // 라인/화살표 리사이즈 상태
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

  // 좌표 변환
  Offset _sceneFromGlobal(Offset global) {
    final box = _painterKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return global;
    final local = box.globalToLocal(global);
    return controller.transformationController.toScene(local);
  }

  // 페인트
  Paint _strokePaint(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w;
  Paint _fillPaint(Color c) => Paint()..color = c..style = PaintingStyle.fill;

  // 라인 헬퍼/바운즈
  Offset _lineStart(dynamic d) {
    final center = (d as ObjectDrawable).position;
    final len = (d is LineDrawable) ? d.length : (d as ArrowDrawable).length;
    final ang = (d is LineDrawable) ? d.rotationAngle : (d as ArrowDrawable).rotationAngle;
    final dir = Offset(math.cos(ang), math.sin(ang));
    return center - dir * (len / 2);
  }

  Offset _lineEnd(dynamic d) {
    final center = (d as ObjectDrawable).position;
    final len = (d is LineDrawable) ? d.length : (d as ArrowDrawable).length;
    final ang = (d is LineDrawable) ? d.rotationAngle : (d as ArrowDrawable).rotationAngle;
    final dir = Offset(math.cos(ang), math.sin(ang));
    return center + dir * (len / 2);
  }

  Rect _boundsOf(Drawable d) {
    if (d is RectangleDrawable || d is OvalDrawable) {
      final pos = (d as ObjectDrawable).position;
      final size = (d as dynamic).size as Size;
      return Rect.fromCenter(center: pos, width: size.width, height: size.height);
    } else if (d is LineDrawable || d is ArrowDrawable) {
      final a = _lineStart(d); final b = _lineEnd(d);
      return Rect.fromPoints(a, b);
    } else if (d is ConstrainedTextDrawable) {
      final size = d.getSize(maxWidth: d.maxWidth);
      return Rect.fromCenter(center: d.position, width: size.width, height: size.height);
    } else if (d is TextDrawable) {
      final size = d.getSize();
      return Rect.fromCenter(center: d.position, width: size.width, height: size.height);
    }
    return Rect.zero;
  }

  // 툴 전환
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

  // 스냅
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

  // 도형 생성
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
        currentTool == Tool.arrow;

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

    if (lockRatio && (currentTool == Tool.rect || currentTool == Tool.oval)) {
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
          paint: _strokePaint(strokeColor, strokeWidth),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        );
      case Tool.oval:
        return OvalDrawable(
          position: center,
          size: Size(w, h),
          paint: fillColor.opacity == 0
              ? _strokePaint(strokeColor, strokeWidth)
              : _fillPaint(fillColor),
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

  // 히트 테스트
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

    if (selectedDrawable != null) {
      final rect = _boundsOf(selectedDrawable!);
      final action = _hitHandle(rect, localScene);
      dragAction = action;
      dragStartBounds = rect;
      dragStartPointer = localScene;

      if (action == DragAction.rotate) {
        startAngle = (selectedDrawable as ObjectDrawable).rotationAngle;
      }

      if ((selectedDrawable is LineDrawable || selectedDrawable is ArrowDrawable) &&
          (action == DragAction.resizeStart || action == DragAction.resizeEnd)) {
        final d0 = selectedDrawable!;
        final a = _lineStart(d0);
        final b = _lineEnd(d0);
        final fixedEnd  = (action == DragAction.resizeStart) ? b : a;
        _laFixedEnd = fixedEnd;
        _laAngle    = (d0 as ObjectDrawable).rotationAngle;
        _laDir      = Offset(math.cos(_laAngle!), math.sin(_laAngle!));
      }

      if (action == DragAction.none && !rect.inflate(4).contains(localScene)) {
        final hit = _pickTopAt(localScene);
        if (hit != null && hit != selectedDrawable) {
          setState(() => selectedDrawable = hit);
          final r2 = _boundsOf(selectedDrawable!);
          final a2 = _hitHandle(r2, localScene);
          dragAction = a2;
          dragStartBounds = r2;
          dragStartPointer = localScene;

          if (a2 == DragAction.rotate) {
            startAngle = (selectedDrawable as ObjectDrawable).rotationAngle;
          }

          if ((selectedDrawable is LineDrawable || selectedDrawable is ArrowDrawable) &&
              (a2 == DragAction.resizeStart || a2 == DragAction.resizeEnd)) {
            final d0 = selectedDrawable!;
            final a = _lineStart(d0);
            final b = _lineEnd(d0);
            final fixedEnd  = (a2 == DragAction.resizeStart) ? b : a;
            _laFixedEnd = fixedEnd;
            _laAngle    = (d0 as ObjectDrawable).rotationAngle;
            _laDir      = Offset(math.cos(_laAngle!), math.sin(_laAngle!));
          }
        }
      }
    } else {
      final hit = _pickTopAt(localScene);
      if (hit != null) {
        setState(() => selectedDrawable = hit);
        final r2 = _boundsOf(selectedDrawable!);
        final a2 = _hitHandle(r2, localScene);
        dragAction = a2;
        dragStartBounds = r2;
        dragStartPointer = localScene;

        if (a2 == DragAction.rotate) {
          startAngle = (selectedDrawable as ObjectDrawable).rotationAngle;
        }

        if ((selectedDrawable is LineDrawable || selectedDrawable is ArrowDrawable) &&
            (a2 == DragAction.resizeStart || a2 == DragAction.resizeEnd)) {
          final d0 = selectedDrawable!;
          final a = _lineStart(d0);
          final b = _lineEnd(d0);
          final fixedEnd  = (a2 == DragAction.resizeStart) ? b : a;
          _laFixedEnd = fixedEnd;
          _laAngle    = (d0 as ObjectDrawable).rotationAngle;
          _laDir      = Offset(math.cos(_laAngle!), math.sin(_laAngle!));
        }
      } else {
        dragAction = DragAction.none;
        dragStartBounds = null;
        dragStartPointer = null;
      }
    }

    setState(() {});
  }

  void _onOverlayPanUpdate(DragUpdateDetails details) {
    if (selectedDrawable == null || dragAction == DragAction.none) return;
    _movedSinceDown = true;

    final localScene = _sceneFromGlobal(details.globalPosition);
    final d0 = selectedDrawable!;
    final startRect = dragStartBounds!;
    final startPt = dragStartPointer!;
    Drawable? replaced;

    if (dragAction == DragAction.move) {
      final delta = localScene - startPt;
      if (d0 is RectangleDrawable) {
        replaced = RectangleDrawable(
          position: startRect.center + delta,
          size: startRect.size,
          paint: (d0 as RectangleDrawable).paint,
          borderRadius: (d0 as RectangleDrawable).borderRadius,
        );
      } else if (d0 is OvalDrawable) {
        replaced = OvalDrawable(
          position: startRect.center + delta,
          size: startRect.size,
          paint: (d0 as OvalDrawable).paint,
        );
      } else if (d0 is LineDrawable) {
        replaced = LineDrawable(
          position: startRect.center + delta,
          length: (d0 as LineDrawable).length,
          rotationAngle: (d0 as LineDrawable).rotationAngle,
          paint: (d0 as LineDrawable).paint,
        );
      } else if (d0 is ArrowDrawable) {
        replaced = ArrowDrawable(
          position: startRect.center + delta,
          length: (d0 as ArrowDrawable).length,
          rotationAngle: (d0 as ArrowDrawable).rotationAngle,
          arrowHeadSize: (d0 as ArrowDrawable).arrowHeadSize,
          paint: (d0 as ArrowDrawable).paint,
        );
      } else if (d0 is ConstrainedTextDrawable) {
        replaced = d0.copyWith(position: startRect.center + delta);
      } else if (d0 is TextDrawable) {
        replaced = d0.copyWith(position: startRect.center + delta);
      }
    } else if (dragAction == DragAction.rotate) {
      final center = (d0 as ObjectDrawable).position;
      var ang = math.atan2((localScene - center).dy, (localScene - center).dx);
      ang = _snapAngle(ang);
      if (d0 is LineDrawable) {
        replaced = (d0 as LineDrawable).copyWith(rotation: ang);
      } else if (d0 is ArrowDrawable) {
        replaced = (d0 as ArrowDrawable).copyWith(rotation: ang);
      } else if (d0 is ConstrainedTextDrawable) {
        replaced = (d0 as ConstrainedTextDrawable).copyWith(rotation: ang);
      } else if (d0 is TextDrawable) {
        replaced = (d0 as TextDrawable).copyWith(rotation: ang);
      }
    } else {
      // resize
      if (d0 is RectangleDrawable || d0 is OvalDrawable) {
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

        if (d0 is RectangleDrawable) {
          replaced = RectangleDrawable(
            position: newRect.center,
            size: newRect.size,
            paint: (d0 as RectangleDrawable).paint,
            borderRadius: (d0 as RectangleDrawable).borderRadius,
          );
        } else {
          replaced = OvalDrawable(
            position: newRect.center,
            size: newRect.size,
            paint: (d0 as OvalDrawable).paint,
          );
        }
      } else if (d0 is ConstrainedTextDrawable) {
        dragFixedCorner ??= _fixedCornerForAction(startRect, dragAction);
        final fixed = dragFixedCorner!;
        final newRect = Rect.fromPoints(fixed, localScene);
        final newWidth = newRect.size.width.abs().clamp(40.0, 2000.0);
        final centered = Rect.fromCenter(center: newRect.center, width: newWidth, height: startRect.height);
        replaced = (d0 as ConstrainedTextDrawable).copyWith(position: centered.center, maxWidth: newWidth);
      } else if (d0 is LineDrawable || d0 is ArrowDrawable) {
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
            final dir = _laDir ?? Offset(math.cos(_laAngle!), math.sin(_laAngle!));
            final v = pnt - fixed;
            final t = v.dx * dir.dx + v.dy * dir.dy;
            ang = _laAngle!;
            len = (dir * t).distance.clamp(_laMinLen, double.infinity);
          }

          final dir2 = Offset(math.cos(ang), math.sin(ang));
          final movingEnd = fixed + dir2 * len;
          final newCenter = (fixed + movingEnd) / 2;

          if (d0 is LineDrawable) {
            replaced = (d0 as LineDrawable).copyWith(position: newCenter, length: len, rotation: ang);
          } else {
            replaced = (d0 as ArrowDrawable).copyWith(position: newCenter, length: len, rotation: ang);
          }

          _laAngle = ang;
          _laDir = dir2;
        }
      }
    }

    if (replaced != null) {
      controller.replaceDrawable(d0, replaced);
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

  // 텍스트 생성
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
                      SizedBox(width: 40, child: Text('${tempSize.toStringAsFixed(0)}')),
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
                      SizedBox(width: 56, child: Text('${tempMaxWidth.toStringAsFixed(0)}')),
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
        title: const Text('Painter v2.1.0+1 — Shapes/Lines/Arrow/Text'),
        actions: [
          IconButton(onPressed: controller.canUndo ? controller.undo : null, icon: const Icon(Icons.undo)),
          IconButton(onPressed: controller.canRedo ? controller.redo : null, icon: const Icon(Icons.redo)),
          IconButton(onPressed: _clearAll, icon: const Icon(Icons.layers_clear), tooltip: 'Clear'),
          IconButton(onPressed: () => _saveAsPng(context), icon: const Icon(Icons.save_alt)),
        ],
      ),
      body: Row(
        children: [
          _leftToolPanel(),
          const VerticalDivider(width: 1),
          Expanded(child: _canvasArea()),
          const VerticalDivider(width: 1),
          _rightInspector(),
        ],
      ),
    );
  }

  Widget _leftToolPanel() {
    return SizedBox(
      width: 320,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('Tools', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _toolChip(Tool.select, 'Select', Icons.near_me),
              _toolChip(Tool.pen, 'Pen', Icons.draw),
              _toolChip(Tool.eraser, 'Eraser', Icons.auto_fix_off),
              _toolChip(Tool.rect, 'Rect', Icons.crop_square),
              _toolChip(Tool.oval, 'Oval', Icons.circle),
              _toolChip(Tool.line, 'Line', Icons.show_chart),
              _toolChip(Tool.arrow, 'Arrow', Icons.arrow_right_alt),
              _toolChip(Tool.text, 'Text', Icons.title),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Draw Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Stroke'), const SizedBox(width: 8),
              for (final c in [Colors.black, Colors.red, Colors.blue, Colors.green, Colors.orange])
                _colorDot(c, selected: strokeColor == c, onTap: () {
                  setState(() {
                    strokeColor = c;
                    controller.freeStyleColor = strokeColor;
                  });
                }),
            ],
          ),
          Row(
            children: [
              const Text('Width'),
              Expanded(
                child: Slider(
                  min: 1, max: 24,
                  value: strokeWidth,
                  onChanged: (v) {
                    setState(() {
                      strokeWidth = v;
                      controller.freeStyleStrokeWidth = v;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Fill'), const SizedBox(width: 8),
              _colorDot(Colors.transparent,
                  selected: fillColor.opacity == 0,
                  checker: true,
                  onTap: () => setState(() => fillColor = Colors.transparent)),
              for (final c in [
                Colors.black12,
                Colors.red.withOpacity(0.2),
                Colors.blue.withOpacity(0.2),
                Colors.green.withOpacity(0.2),
                Colors.orange.withOpacity(0.2),
              ])
                _colorDot(c, selected: fillColor == c, onTap: () => setState(() => fillColor = c)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Snap / Behavior', style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(
            value: lockRatio,
            onChanged: (v) => setState(() => lockRatio = v),
            title: const Text('Lock Ratio (Rect/Oval → Square/Circle)'),
            dense: true,
          ),
          SwitchListTile(
            value: angleSnap,
            onChanged: (v) => setState(() => angleSnap = v),
            title: const Text('Angle Snap (0° / 45° / 90° …)'),
            dense: true,
          ),
          SwitchListTile(
            value: endpointDragRotates,
            onChanged: (v) => setState(() => endpointDragRotates = v),
            title: const Text('Endpoint drag rotates (Line/Arrow)'),
            dense: true,
          ),

          const SizedBox(height: 16),
          const Text('Text Defaults', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              const Text('Size'),
              Expanded(
                child: Slider(min: 8, max: 96, value: textFontSize, onChanged: (v) => setState(() => textFontSize = v)),
              ),
              SizedBox(width: 40, child: Text('${textFontSize.toStringAsFixed(0)}')),
            ],
          ),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              FilterChip(label: const Text('Bold'), selected: textBold, onSelected: (v) => setState(() => textBold = v)),
              FilterChip(label: const Text('Italic'), selected: textItalic, onSelected: (v) => setState(() => textItalic = v)),
            ],
          ),
          Row(
            children: [
              const Text('Font'), const SizedBox(width: 8),
              DropdownButton<String>(
                value: textFontFamily,
                items: const [
                  DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
                  DropdownMenuItem(value: 'NotoSans', child: Text('NotoSans')),
                  DropdownMenuItem(value: 'Monospace', child: Text('Monospace')),
                ],
                onChanged: (v) => setState(() { if (v != null) textFontFamily = v; }),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Default Align'), const SizedBox(width: 8),
              DropdownButton<TxtAlign>(
                value: defaultTextAlign,
                items: const [
                  DropdownMenuItem(value: TxtAlign.left, child: Text('Left')),
                  DropdownMenuItem(value: TxtAlign.center, child: Text('Center')),
                  DropdownMenuItem(value: TxtAlign.right, child: Text('Right')),
                ],
                onChanged: (v) => setState(() { if (v != null) defaultTextAlign = v; }),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Default MaxW'),
              Expanded(
                child: Slider(min: 40, max: 800, value: defaultTextMaxWidth, onChanged: (v) => setState(() => defaultTextMaxWidth = v)),
              ),
              SizedBox(width: 56, child: Text('${defaultTextMaxWidth.toStringAsFixed(0)}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _canvasArea() {
    return Center(
      child: SizedBox(
        width: 640,
        height: 640,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
          child: Stack(
            children: [
              AbsorbPointer(
                absorbing: currentTool == Tool.rect ||
                          currentTool == Tool.oval ||
                          currentTool == Tool.line ||
                          currentTool == Tool.arrow ||
                          currentTool == Tool.select ||
                          currentTool == Tool.text,
                child: RepaintBoundary(
                  key: _painterKey,
                  child: FlutterPainter(controller: controller),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: currentTool == Tool.pen || currentTool == Tool.eraser,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _handlePointerDownSelect,
                    child: GestureDetector(
                      dragStartBehavior: DragStartBehavior.down,
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
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
                      },
                      onPanStart: (details) {
                        if (currentTool == Tool.select) {
                          _onOverlayPanStart(details);
                        } else {
                          _onPanStartCreate(details);
                        }
                      },
                      onPanUpdate: (details) {
                        if (currentTool == Tool.select) {
                          _onOverlayPanUpdate(details);
                        } else {
                          _onPanUpdateCreate(details);
                        }
                      },
                      onPanEnd: (_) {
                        if (currentTool == Tool.select) {
                          _onOverlayPanEnd();
                        } else {
                          _onPanEndCreate();
                        }
                      },
                      child: CustomPaint(
                        painter: _SelectionPainter(
                          selected: selectedDrawable,
                          bounds: selectedDrawable == null ? null : _boundsOf(selectedDrawable!),
                          handleSize: handleSize,
                          rotateHandleOffset: rotateHandleOffset,
                          endpointRadius: handleSize * 0.7,
                          showEndpoints: selectedDrawable is LineDrawable || selectedDrawable is ArrowDrawable,
                          start: selectedDrawable == null ? null : (selectedDrawable is LineDrawable || selectedDrawable is ArrowDrawable) ? _lineStart(selectedDrawable!) : null,
                          end: selectedDrawable == null ? null : (selectedDrawable is LineDrawable || selectedDrawable is ArrowDrawable) ? _lineEnd(selectedDrawable!) : null,
                          isText: selectedDrawable is ConstrainedTextDrawable || selectedDrawable is TextDrawable,
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

  Widget _rightInspector() {
    return SizedBox(
      width: 340,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('Inspector', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (selectedDrawable == null)
            const Text('Nothing selected.\nUse Select tool and tap a shape.')
          else ...[
            _kv('Type', selectedDrawable.runtimeType.toString()),
            const SizedBox(height: 12),

            if (selectedDrawable is! ConstrainedTextDrawable && selectedDrawable is! TextDrawable) ...[
              const Text('Stroke Color'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  for (final c in [Colors.black, Colors.red, Colors.blue, Colors.green, Colors.orange])
                    _colorDot(c, onTap: () {
                      _applyInspector(newStrokeColor: c);
                    }),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Stroke Width'),
              Slider(min: 1, max: 24, value: strokeWidth, onChanged: (v) => _applyInspector(newStrokeWidth: v)),
              if (selectedDrawable is RectangleDrawable) ...[
                const SizedBox(height: 12),
                const Text('Corner Radius (Rect)'),
                Slider(
                  min: 0, max: 40,
                  value: (selectedDrawable as RectangleDrawable).borderRadius.topLeft.x.clamp(0.0, 40.0),
                  onChanged: (v) => _applyInspector(newCornerRadius: v),
                ),
              ],
            ],

            if (selectedDrawable is ConstrainedTextDrawable) ..._textInspectorConstrained(selectedDrawable as ConstrainedTextDrawable),
            if (selectedDrawable is TextDrawable) ..._textInspectorPlain(selectedDrawable as TextDrawable),
          ],
        ],
      ),
    );
  }

  List<Widget> _textInspectorConstrained(ConstrainedTextDrawable td) {
    final tc = TextEditingController(text: td.text);
    Color currentColor = td.style.color ?? Colors.black;
    double currentSize = td.style.fontSize ?? 24.0;
    bool currentBold = (td.style.fontWeight ?? FontWeight.normal) == FontWeight.bold;
    bool currentItalic = (td.style.fontStyle ?? FontStyle.normal) == FontStyle.italic;
    String currentFamily = td.style.fontFamily ?? textFontFamily;
    TxtAlign currentAlign = td.align;
    double currentMaxWidth = td.maxWidth;
    double currentAngle = td.rotationAngle;

    void apply() {
      final style = TextStyle(
        color: currentColor,
        fontSize: currentSize,
        fontWeight: currentBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: currentItalic ? FontStyle.italic : FontStyle.normal,
        fontFamily: currentFamily,
      );
      final replaced = td.copyWith(
        text: tc.text,
        style: style,
        align: currentAlign,
        maxWidth: currentMaxWidth,
        rotation: currentAngle,
      );
      controller.replaceDrawable(td, replaced);
      setState(() => selectedDrawable = replaced);
    }

    return [
      const Text('Content'), const SizedBox(height: 4),
      TextField(
        controller: tc,
        minLines: 1, maxLines: 6,
        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
        onSubmitted: (_) => apply(),
      ),
      const SizedBox(height: 12),
      const Text('Color'), const SizedBox(height: 4),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: [
          for (final c in [Colors.black, Colors.red, Colors.blue, Colors.green, Colors.orange])
            _colorDot(c, selected: currentColor == c, onTap: () { currentColor = c; apply(); }),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Text('Size'),
          Expanded(child: Slider(min: 8, max: 96, value: currentSize, onChanged: (v) { currentSize = v; apply(); })),
          SizedBox(width: 42, child: Text('${currentSize.toStringAsFixed(0)}')),
        ],
      ),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: [
          FilterChip(label: const Text('Bold'), selected: currentBold, onSelected: (v) { currentBold = v; apply(); }),
          FilterChip(label: const Text('Italic'), selected: currentItalic, onSelected: (v) { currentItalic = v; apply(); }),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          const Text('Font'), const SizedBox(width: 8),
          DropdownButton<String>(
            value: currentFamily,
            items: const [
              DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
              DropdownMenuItem(value: 'NotoSans', child: Text('NotoSans')),
              DropdownMenuItem(value: 'Monospace', child: Text('Monospace')),
            ],
            onChanged: (v) { if (v != null) { currentFamily = v; apply(); } },
          ),
        ],
      ),
      Row(
        children: [
          const Text('Align'), const SizedBox(width: 8),
          DropdownButton<TxtAlign>(
            value: currentAlign,
            items: const [
              DropdownMenuItem(value: TxtAlign.left, child: Text('Left')),
              DropdownMenuItem(value: TxtAlign.center, child: Text('Center')),
              DropdownMenuItem(value: TxtAlign.right, child: Text('Right')),
            ],
            onChanged: (v) { if (v != null) { currentAlign = v; apply(); } },
          ),
        ],
      ),
      Row(
        children: [
          const Text('Max Width'),
          Expanded(child: Slider(min: 40, max: 1200, value: currentMaxWidth, onChanged: (v) { currentMaxWidth = v; apply(); })),
          SizedBox(width: 56, child: Text('${currentMaxWidth.toStringAsFixed(0)}')),
        ],
      ),
      Row(
        children: [
          const Text('Angle'),
          Expanded(
            child: Slider(
              min: -180, max: 180, value: currentAngle * 180 / math.pi,
              onChanged: (v) {
                double ang = v * math.pi / 180.0;
                currentAngle = angleSnap ? _snapAngle(ang) : ang;
                apply();
              },
            ),
          ),
          SizedBox(width: 52, child: Text('${(currentAngle * 180 / math.pi).toStringAsFixed(0)}°')),
        ],
      ),
    ];
  }

  List<Widget> _textInspectorPlain(TextDrawable td) {
    final tc = TextEditingController(text: td.text);
    Color currentColor = td.style.color ?? Colors.black;
    double currentSize = td.style.fontSize ?? 24.0;
    bool currentBold = (td.style.fontWeight ?? FontWeight.normal) == FontWeight.bold;
    bool currentItalic = (td.style.fontStyle ?? FontStyle.normal) == FontStyle.italic;
    String currentFamily = td.style.fontFamily ?? textFontFamily;
    double currentAngle = td.rotationAngle;

    void apply() {
      final style = TextStyle(
        color: currentColor,
        fontSize: currentSize,
        fontWeight: currentBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: currentItalic ? FontStyle.italic : FontStyle.normal,
        fontFamily: currentFamily,
      );
      final replaced = td.copyWith(text: tc.text, style: style, rotation: currentAngle);
      controller.replaceDrawable(td, replaced);
      setState(() => selectedDrawable = replaced);
    }

    return [
      const Text('Content'), const SizedBox(height: 4),
      TextField(
        controller: tc,
        minLines: 1, maxLines: 6,
        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
        onSubmitted: (_) => apply(),
      ),
      const SizedBox(height: 12),
      const Text('Color'), const SizedBox(height: 4),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: [
          for (final c in [Colors.black, Colors.red, Colors.blue, Colors.green, Colors.orange])
            _colorDot(c, selected: currentColor == c, onTap: () { currentColor = c; apply(); }),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Text('Size'),
          Expanded(child: Slider(min: 8, max: 96, value: currentSize, onChanged: (v) { currentSize = v; apply(); })),
          SizedBox(width: 42, child: Text('${currentSize.toStringAsFixed(0)}')),
        ],
      ),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: [
          FilterChip(label: const Text('Bold'), selected: currentBold, onSelected: (v) { currentBold = v; apply(); }),
          FilterChip(label: const Text('Italic'), selected: currentItalic, onSelected: (v) { currentItalic = v; apply(); }),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          const Text('Angle'),
          Expanded(
            child: Slider(
              min: -180, max: 180, value: currentAngle * 180 / math.pi,
              onChanged: (v) {
                double ang = v * math.pi / 180.0;
                currentAngle = angleSnap ? _snapAngle(ang) : ang;
                apply();
              },
            ),
          ),
          SizedBox(width: 52, child: Text('${(currentAngle * 180 / math.pi).toStringAsFixed(0)}°')),
        ],
      ),
      const SizedBox(height: 4),
      const Text(
        '※ TextDrawable(순정)에는 textAlign/maxWidth가 없습니다. '
        '정렬/최대폭이 필요하면 커스텀 텍스트를 사용하세요.',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      ),
    ];
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

  Widget _toolChip(Tool t, String label, IconData icon) {
    final selected = currentTool == t;
    return ChoiceChip(
      label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)]),
      selected: selected,
      onSelected: (_) => _setTool(t),
    );
  }

  Widget _colorDot(Color c, {bool selected = false, bool checker = false, VoidCallback? onTap}) {
    final child = Container(
      width: 22, height: 22,
      decoration: BoxDecoration(
        color: c.opacity == 0 && !checker ? null : c,
        border: Border.all(color: selected ? Colors.black : Colors.black26),
        borderRadius: BorderRadius.circular(20),
      ),
      child: c.opacity == 0 && checker ? CustomPaint(painter: _CheckerPainter()) : null,
    );
    return InkWell(onTap: onTap, child: child);
  }

  Widget _kv(String k, String v) => Row(
        children: [Expanded(child: Text(k, style: const TextStyle(color: Colors.black54))), Text(v)],
      );
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

  _SelectionPainter({
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

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 4;
    final p1 = Paint()..color = const Color(0xFFE0E0E0);
    final p2 = Paint()..color = const Color(0xFFFFFFFF);
    for (int y = 0; y < 4; y++) {
      for (int x = 0; x < 4; x++) {
        final r = Rect.fromLTWH(x * s, y * s, s, s);
        canvas.drawRect(r, ((x + y) % 2 == 0) ? p1 : p2);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
