// main.dart 전체 파일입니다. (요약 없음)

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:barcode/barcode.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'flutter_painter_v2/flutter_painter.dart';
import 'flutter_painter_v2/flutter_painter_pure.dart';
import 'flutter_painter_v2/flutter_painter_extensions.dart';

import 'models/tool.dart';
import 'drawables/constrained_text_drawable.dart';
import 'drawables/barcode_drawable.dart';
import 'widgets/tool_panel.dart';
import 'widgets/inspector_panel.dart';
import 'widgets/canvas_area.dart';

const appTitle = 'ITS&G Label Printer';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
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

class PainterPage extends StatefulWidget {
  const PainterPage({super.key});
  @override
  State<PainterPage> createState() => _PainterPageState();
}

class _PainterPageState extends State<PainterPage> {
  String appVersion = '';
  double scalePercent = 100.0;
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

  // 바코드 기본
  String barcodeData = '123456789012';
  BarcodeType barcodeType = BarcodeType.Code128;
  bool barcodeShowValue = true;
  double barcodeFontSize = 16.0;
  Color barcodeForeground = Colors.black;
  Color barcodeBackground = Colors.white;
  double printerDpi = 300;

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
  Offset? dragStartPointer;   // 월드 좌표
  Offset? dragFixedCorner;    // 월드 좌표(회전 반영된 코너)
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final info = await PackageInfo.fromPlatform();
      setState(() { appVersion = info.version; });
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
    final renderObject = _painterKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return global;
    final local = renderObject.globalToLocal(global);
    return controller.transformationController.toScene(local);
  }

  // 페인트
  Paint _strokePaint(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * (scalePercent / 100.0);
  Paint _fillPaint(Color c) => Paint()..color = c..style = PaintingStyle.fill;

  // 라인 헬퍼/바운즈
  Offset _lineStart(Drawable d) {
    if (d is LineDrawable) {
      final dir = Offset(math.cos(d.rotationAngle), math.sin(d.rotationAngle));
      return d.position - dir * (d.length / 2);
    }
    if (d is ArrowDrawable) {
      final dir = Offset(math.cos(d.rotationAngle), math.sin(d.rotationAngle));
      return d.position - dir * (d.length / 2);
    }
    return Offset.zero;
  }

  Offset _lineEnd(Drawable d) {
    if (d is LineDrawable) {
      final dir = Offset(math.cos(d.rotationAngle), math.sin(d.rotationAngle));
      return d.position + dir * (d.length / 2);
    }
    if (d is ArrowDrawable) {
      final dir = Offset(math.cos(d.rotationAngle), math.sin(d.rotationAngle));
      return d.position + dir * (d.length / 2);
    }
    return Offset.zero;
  }

  Rect _boundsOf(Drawable d) {
    if (d is RectangleDrawable) {
      return Rect.fromCenter(center: d.position, width: d.size.width, height: d.size.height);
    }
    if (d is OvalDrawable) {
      return Rect.fromCenter(center: d.position, width: d.size.width, height: d.size.height);
    }
    if (d is BarcodeDrawable) {
      return Rect.fromCenter(center: d.position, width: d.size.width, height: d.size.height);
    }
    if (d is LineDrawable) {
      final a = _lineStart(d), b = _lineEnd(d);
      return Rect.fromPoints(a, b);
    }
    if (d is ArrowDrawable) {
      final a = _lineStart(d), b = _lineEnd(d);
      return Rect.fromPoints(a, b);
    }
    if (d is ConstrainedTextDrawable) {
      final s = d.getSize(maxWidth: d.maxWidth);
      return Rect.fromCenter(center: d.position, width: s.width, height: s.height);
    }
    if (d is TextDrawable) {
      final s = d.getSize();
      return Rect.fromCenter(center: d.position, width: s.width, height: s.height);
    }
    return Rect.zero;
  }

  // 툴 전환
  bool get _isPainterGestureTool => currentTool == Tool.pen || currentTool == Tool.eraser || currentTool == Tool.select;

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

  double _nearestStep(double raw) => (_normalizeAngle(raw / _snapStep).roundToDouble()) * _snapStep;

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
          paint: fillColor.a == 0 ? _strokePaint(strokeColor, strokeWidth) : _fillPaint(fillColor),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        );
      case Tool.oval:
        return OvalDrawable(
          position: center,
          size: Size(w, h),
          paint: fillColor.a == 0 ? _strokePaint(strokeColor, strokeWidth) : _fillPaint(fillColor),
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
          return LineDrawable(position: mid, length: length, rotationAngle: angle, paint: _strokePaint(strokeColor, strokeWidth));
        } else {
          return ArrowDrawable(position: mid, length: length, rotationAngle: angle, arrowHeadSize: 16, paint: _strokePaint(strokeColor, strokeWidth));
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

    // 바코드 + 텍스트: 포인터를 언회전 좌표로 보정해서 코너 핸들 판정
    Offset p2 = p;
    final d = selectedDrawable;
    if (d is BarcodeDrawable || d is ConstrainedTextDrawable || d is TextDrawable) {
      final angle = (d as ObjectDrawable).rotationAngle;
      if (angle != 0) {
        final center = bounds.center;
        final dx = p.dx - center.dx;
        final dy = p.dy - center.dy;
        final cosA = math.cos(-angle);
        final sinA = math.sin(-angle);
        p2 = Offset(cosA * dx - sinA * dy + center.dx, sinA * dx + cosA * dy + center.dy);
      }
    }

    final corners = [bounds.topLeft, bounds.topRight, bounds.bottomLeft, bounds.bottomRight];
    final rotCenter = _rotateHandlePos(bounds);

    if ((p2 - corners[0]).distance <= handleTouchRadius) return DragAction.resizeNW;
    if ((p2 - corners[1]).distance <= handleTouchRadius) return DragAction.resizeNE;
    if ((p2 - corners[2]).distance <= handleTouchRadius) return DragAction.resizeSW;
    if ((p2 - corners[3]).distance <= handleTouchRadius) return DragAction.resizeSE;
    if ((p2 - rotCenter).distance <= handleTouchRadius) return DragAction.rotate;

    final distToLine = _distanceToSegment(p2, bounds.topCenter, rotCenter);
    if (distToLine <= handleTouchRadius * 0.7) return DragAction.rotate;
    if (bounds.inflate(4).contains(p2)) return DragAction.move;
    return DragAction.none;
  }

  Offset _rotateHandlePos(Rect r) => Offset(r.center.dx, r.top - rotateHandleOffset);

  // 도우미: 한 점을 center 기준 +angle로 회전
  Offset _rotPoint(Offset point, Offset center, double angle) {
    final v = point - center;
    final ca = math.cos(angle), sa = math.sin(angle);
    return Offset(ca * v.dx - sa * v.dy, sa * v.dx + ca * v.dy) + center;
  }

  // 로컬(언회전) 벡터 변환
  Offset _toLocalVec(Offset worldPoint, Offset center, double angle) {
    final v = worldPoint - center;
    final cosA = math.cos(-angle), sinA = math.sin(-angle);
    return Offset(cosA * v.dx - sinA * v.dy, sinA * v.dx + cosA * v.dy);
  }

  Offset _fromLocalVec(Offset localVec, Offset center, double angle) {
    final cosA = math.cos(angle), sinA = math.sin(angle);
    final w = Offset(cosA * localVec.dx - sinA * localVec.dy, sinA * localVec.dx + cosA * localVec.dy);
    return center + w;
  }

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
      if (drawable is LineDrawable || drawable is ArrowDrawable) {
        final start = _lineStart(drawable);
        final end = _lineEnd(drawable);
        _laFixedEnd = action == DragAction.resizeStart ? end : start;
        final rotation = (drawable as ObjectDrawable).rotationAngle;
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

      // 바코드 + 텍스트: 리사이즈 시작 시 고정 코너를 "회전된 코너"로 저장
      if (current is BarcodeDrawable ||
          current is ConstrainedTextDrawable ||
          current is TextDrawable) {
        if (action == DragAction.resizeNW ||
            action == DragAction.resizeNE ||
            action == DragAction.resizeSW ||
            action == DragAction.resizeSE) {
          final angle = (current as ObjectDrawable).rotationAngle;
          final opp = _fixedCornerForAction(rect, action);
          dragFixedCorner = _rotPoint(opp, rect.center, angle);
        } else {
          dragFixedCorner = null;
        }
      } else {
        dragFixedCorner = null;
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

          if (hit is BarcodeDrawable ||
              hit is ConstrainedTextDrawable ||
              hit is TextDrawable) {
            if (a2 == DragAction.resizeNW ||
                a2 == DragAction.resizeNE ||
                a2 == DragAction.resizeSW ||
                a2 == DragAction.resizeSE) {
              final angle = (hit as ObjectDrawable).rotationAngle;
              final opp = _fixedCornerForAction(r2, a2);
              dragFixedCorner = _rotPoint(opp, r2.center, angle);
            } else {
              dragFixedCorner = null;
            }
          } else {
            dragFixedCorner = null;
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

        if (hit is BarcodeDrawable ||
            hit is ConstrainedTextDrawable ||
            hit is TextDrawable) {
          if (a2 == DragAction.resizeNW ||
              a2 == DragAction.resizeNE ||
              a2 == DragAction.resizeSW ||
              a2 == DragAction.resizeSE) {
            final angle = (hit as ObjectDrawable).rotationAngle;
            final opp = _fixedCornerForAction(r2, a2);
            dragFixedCorner = _rotPoint(opp, r2.center, angle);
          } else {
            dragFixedCorner = null;
          }
        } else {
          dragFixedCorner = null;
        }

        prepareLineResize(hit, a2);
      } else {
        dragAction = DragAction.none;
        dragStartBounds = null;
        dragStartPointer = null;
        startAngle = null;
        dragFixedCorner = null;
        clearLineResize();
      }
    }

    setState(() {});
  }

  void _onOverlayPanUpdate(DragUpdateDetails details) {
    if (selectedDrawable == null || dragAction == DragAction.none) return;
    _movedSinceDown = true;

    // ---- 월드/로컬 좌표 분리 (핵심 수정) ----
    final scenePtWorld = _sceneFromGlobal(details.globalPosition);
    var scenePtLocal = scenePtWorld;

    final original = selectedDrawable!;
    final startRect = dragStartBounds!;
    final startPtWorld = dragStartPointer!;
    Drawable? replaced;

    // 바코드/텍스트의 "리사이즈"에서만 로컬 좌표(언회전) 사용
    final isTextLike = original is BarcodeDrawable || original is ConstrainedTextDrawable || original is TextDrawable;
    final isCornerResize = (dragAction == DragAction.resizeNW || dragAction == DragAction.resizeNE || dragAction == DragAction.resizeSW || dragAction == DragAction.resizeSE);

    if (isTextLike && isCornerResize) {
      final angle = (original as ObjectDrawable).rotationAngle;
      if (angle != 0) {
        final c = startRect.center;
        final dx = scenePtWorld.dx - c.dx, dy = scenePtWorld.dy - c.dy;
        final ca = math.cos(-angle), sa = math.sin(-angle);
        scenePtLocal = Offset(ca * dx - sa * dy + c.dx, sa * dx + ca * dy + c.dy);
      }
    }

    // --- MOVE (항상 월드 좌표) ---
    if (dragAction == DragAction.move) {
      final delta = scenePtWorld - startPtWorld;
      if (original is RectangleDrawable) {
        replaced = RectangleDrawable(position: startRect.center + delta, size: startRect.size, paint: original.paint, borderRadius: original.borderRadius);
      } else if (original is OvalDrawable) {
        replaced = OvalDrawable(position: startRect.center + delta, size: startRect.size, paint: original.paint);
      } else if (original is BarcodeDrawable) {
        replaced = original.copyWith(position: startRect.center + delta);
      } else if (original is LineDrawable) {
        replaced = LineDrawable(position: startRect.center + delta, length: original.length, rotationAngle: original.rotationAngle, paint: original.paint);
      } else if (original is ArrowDrawable) {
        replaced = ArrowDrawable(position: startRect.center + delta, length: original.length, rotationAngle: original.rotationAngle, arrowHeadSize: original.arrowHeadSize, paint: original.paint);
      } else if (original is ConstrainedTextDrawable) {
        replaced = original.copyWith(position: startRect.center + delta);
      } else if (original is TextDrawable) {
        replaced = original.copyWith(position: startRect.center + delta);
      }
    }
    // --- ROTATE (항상 월드 좌표) ---
    else if (dragAction == DragAction.rotate) {
      if (original is ObjectDrawable) {
        final center = original.position;
        var ang = math.atan2((scenePtWorld - center).dy, (scenePtWorld - center).dx);
        ang = _snapAngle(ang);

        if (original is LineDrawable) {
          replaced = original.copyWith(rotation: ang);
        } else if (original is ArrowDrawable) {
          replaced = original.copyWith(rotation: ang);
        } else if (original is ConstrainedTextDrawable) {
          replaced = original.copyWith(rotation: ang);
        } else if (original is TextDrawable) {
          replaced = original.copyWith(rotation: ang);
        } else if (original is BarcodeDrawable) {
          replaced = original.copyWith(rotation: ang);
        }
      }
    }
    // --- RESIZE ---
    else {
      if (original is RectangleDrawable || original is OvalDrawable) {
        final fixed = dragFixedCorner ?? _fixedCornerForAction(startRect, dragAction);
        Rect newRect = Rect.fromPoints(fixed, scenePtWorld);

        if (lockRatio) {
          final size = newRect.size;
          final m = math.max(size.width.abs(), size.height.abs());
          final dir = (scenePtWorld - fixed);
          final ddx = dir.dx.isNegative ? -m : m;
          final ddy = dir.dy.isNegative ? -m : m;
          newRect = Rect.fromPoints(fixed, fixed + Offset(ddx, ddy));
        }

        if (original is RectangleDrawable) {
          replaced = RectangleDrawable(position: newRect.center, size: newRect.size, paint: original.paint, borderRadius: original.borderRadius);
        } else if (original is OvalDrawable) {
          replaced = OvalDrawable(position: newRect.center, size: newRect.size, paint: original.paint);
        }
      } else if (original is BarcodeDrawable) {
        if (isCornerResize) {
          final angle = original.rotationAngle;
          final center0 = startRect.center;

          final worldFixed = dragFixedCorner!;
          final worldMove = scenePtWorld;

          final vFixed = _toLocalVec(worldFixed, center0, angle);
          final vMove  = _toLocalVec(worldMove,  center0, angle);

          Offset vCenter = (vFixed + vMove) / 2;
          Size newSize = Size((vMove.dx - vFixed.dx).abs(), (vMove.dy - vFixed.dy).abs());

          if (lockRatio) {
            final m = math.max(newSize.width, newSize.height);
            final signX = (vMove.dx - vFixed.dx) >= 0 ? 1.0 : -1.0;
            final signY = (vMove.dy - vFixed.dy) >= 0 ? 1.0 : -1.0;
            final vMoveLocked = Offset(vFixed.dx + signX * m, vFixed.dy + signY * m);
            vCenter = (vFixed + vMoveLocked) / 2;
            newSize = Size(m, m);
          }

          final newCenterWorld = _fromLocalVec(vCenter, center0, angle);

          replaced = original.copyWith(
            position: newCenterWorld,
            size: newSize,
            rotation: angle,
          );
        }
      } else if (original is ConstrainedTextDrawable) {
        if (isCornerResize) {
          final angle = original.rotationAngle;
          final center0 = startRect.center;

          final worldFixed = dragFixedCorner!;
          final worldMove = scenePtWorld;

          final vFixed = _toLocalVec(worldFixed, center0, angle);
          final vMove  = _toLocalVec(worldMove,  center0, angle);

          final vCenter = (vFixed + vMove) / 2;
          final newWidth = (vMove.dx - vFixed.dx).abs().clamp(40.0, 2000.0);

          final newCenterWorld = _fromLocalVec(vCenter, center0, angle);

          replaced = original.copyWith(
            position: newCenterWorld,
            maxWidth: newWidth,
            rotation: angle,
          );
        }
      } else if (original is TextDrawable) {
        if (isCornerResize) {
          final angle = original.rotationAngle;
          final center0 = startRect.center;

          final worldFixed = dragFixedCorner!;
          final worldMove = scenePtWorld;

          final vFixed = _toLocalVec(worldFixed, center0, angle);
          final vMove  = _toLocalVec(worldMove,  center0, angle);
          final vCenter = (vFixed + vMove) / 2;

          final newCenterWorld = _fromLocalVec(vCenter, center0, angle);

          replaced = original.copyWith(position: newCenterWorld, rotation: angle);
        }
      } else if (original is LineDrawable || original is ArrowDrawable) {
        if (_laFixedEnd != null) {
          final fixed = _laFixedEnd!;
          final pnt = scenePtWorld;

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

  // 텍스트 생성(기존)
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
                  TextField(controller: controllerText, autofocus: true, decoration: const InputDecoration(labelText: 'Text', hintText: 'Enter text...'), minLines: 1, maxLines: 6),
                  const SizedBox(height: 12),
                  Row(children: [const Text('Size'), Expanded(child: Slider(min: 8, max: 96, value: tempSize, onChanged: (v) => setSS(() => tempSize = v))), SizedBox(width: 40, child: Text(tempSize.toStringAsFixed(0)))]),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilterChip(label: const Text('Bold'), selected: tempBold, onSelected: (v) => setSS(() => tempBold = v)),
                    FilterChip(label: const Text('Italic'), selected: tempItalic, onSelected: (v) => setSS(() => tempItalic = v)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
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
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
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
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('Max Width'),
                    Expanded(child: Slider(min: 40, max: 800, value: tempMaxWidth, onChanged: (v) => setSS(() => tempMaxWidth = v))),
                    SizedBox(width: 56, child: Text(tempMaxWidth.toStringAsFixed(0))),
                  ]),
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
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$appTitle ', style: const TextStyle(fontSize: 20)),
              TextSpan(text: 'v$appVersion', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal)),
            ],
          ),
        ),
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
            scalePercent: scalePercent,
            onScalePercentChanged: (v) => setState(() => scalePercent = v),
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
              printerDpi: printerDpi,
              scalePercent: scalePercent,
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
      replaced = d.copyWith(paint: _strokePaint(newStrokeColor ?? strokeColor, newStrokeWidth ?? strokeWidth));
    } else if (d is ArrowDrawable) {
      replaced = d.copyWith(paint: _strokePaint(newStrokeColor ?? strokeColor, newStrokeWidth ?? strokeWidth));
    } else if (d is ConstrainedTextDrawable || d is TextDrawable) {
      return;
    } else if (d is BarcodeDrawable) {
      return; // 바코드의 색/배경은 Inspector에서 변경하지 않음
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
