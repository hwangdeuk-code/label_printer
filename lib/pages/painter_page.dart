import 'dart:convert';
/// 한글 주석: 메인 편집 화면(PainterPage)
/// 기존 main.dart의 화면 관련 대규모 코드를 이 파일로 이동했습니다.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:barcode/barcode.dart';
import 'package:file_selector/file_selector.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../flutter_painter_v2/flutter_painter.dart';
import '../flutter_painter_v2/flutter_painter_pure.dart';
import '../flutter_painter_v2/flutter_painter_extensions.dart';
import '../models/tool.dart' as tool;
import '../models/drag_action.dart';
import '../drawables/constrained_text_drawable.dart';
import '../drawables/barcode_drawable.dart';
import '../drawables/image_box_drawable.dart';
import '../drawables/table_drawable.dart';
import '../widgets/tool_panel.dart';
import '../widgets/inspector_panel.dart';
import '../widgets/canvas_area.dart';
import '../core/constants.dart';

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

  tool.Tool currentTool = tool.Tool.pen;

  Color strokeColor = Colors.black;
  double strokeWidth = 4.0;
  Color fillColor = const Color(0x00000000);

  String textFontFamily = 'Roboto';
  double textFontSize = 24.0;
  bool textBold = false;
  bool textItalic = false;
  tool.TxtAlign defaultTextAlign = tool.TxtAlign.left;
  double defaultTextMaxWidth = 300;

  String barcodeData = '123456789012';
  BarcodeType barcodeType = BarcodeType.Code128;
  bool barcodeShowValue = true;
  double barcodeFontSize = 16.0;
  Color barcodeForeground = Colors.black;
  Color barcodeBackground = Colors.white;
  double printerDpi = 300;

  bool lockRatio = false;
  bool angleSnap = true;
  bool endpointDragRotates = true;

  final double _snapStep = math.pi / 4;
  final double _snapTol = math.pi / 36;
  double? _dragSnapAngle;

  bool _isCreatingLineLike = false;
  bool _firstAngleLockPending = false;
  static const double _firstLockMinLen = 2.0;
  Timer? _pressSnapTimer;
  double _lastRawAngle = 0.0;

  Offset? dragStart;
  Drawable? previewShape;

  Drawable? selectedDrawable;
  DragAction dragAction = DragAction.none;
  Rect? dragStartBounds;
  Offset? dragStartPointer;
  Offset? dragFixedCorner;
  double? startAngle;
  double? _startPointerAngle;

  final double handleSize = 10.0;
  final double handleTouchRadius = 16.0;
  final double rotateHandleOffset = 28.0;

  bool _pressOnSelection = false;
  bool _movedSinceDown = false;
  Offset? _downScene;
  Drawable? _downHitDrawable;

  Offset? _laFixedEnd;
  double? _laAngle;
  Offset? _laDir;
  static const double _laMinLen = 2.0;

  /// 한글 주석: 표 셀 인라인 편집 상태
  TableDrawable? _editingTable;
  int? _editingCellRow;
  int? _editingCellCol;
  quill.QuillController? _quillController;
  final FocusNode _quillFocus = FocusNode();
  bool _guardSelectionDuringInspector = false;
  TextSelection? _pendingSelectionRestore;

  Timer? _quillBlurCommitTimer;
  bool _suppressCommitOnce = false;
  Rect? _inlineEditorRectScene; // 씬 좌표 기준

  // 인라인 에디터/오버레이 엔트리 (널 허용)
  OverlayEntry? _inlineEditor;
  OverlayEntry? _inlineEditorEntry;
  OverlayEntry? _editorOverlay;


  /// 한글 주석: 표 셀 선택 상태
  bool _isShiftPressed = false;
  final FocusNode _keyboardFocus = FocusNode();
  (int, int)? _selectionAnchorCell; // (row, col)
  (int, int)? _selectionFocusCell; // (row, col)

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
    _quillFocus.addListener(() {
      if (!_quillFocus.hasFocus) {
        // If inspector is applying a format, don't disturb the selection
        if (_guardSelectionDuringInspector) return;
                // Immediately collapse selection so highlight disappears while editor is unfocused
        try {
          } catch (_) {}

_quillBlurCommitTimer?.cancel();
        _quillBlurCommitTimer = Timer(const Duration(milliseconds: 180), () {
          if (_suppressCommitOnce) { _suppressCommitOnce = false; return; }
          if (!_quillFocus.hasFocus) _commitInlineEditor();
        });
      } else {
        _quillBlurCommitTimer?.cancel();
      }
    });
    controller.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          appVersion = info.version;
        });
      }
    });
  }

  @override
  void dispose() {
    
    _keyboardFocus.dispose();
    _quillFocus.dispose();
_pressSnapTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  Offset _sceneFromGlobal(Offset global) {
    final renderObject = _painterKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return global;
    final local = renderObject.globalToLocal(global);
    return controller.transformationController.toScene(local);
  }

  /// 한글 주석: 인라인 Quill 편집기 위젯 반환
  Widget? _buildInlineEditor() {
    if (_editingTable == null ||
        _editingCellRow == null ||
        _editingCellCol == null ||
        _quillController == null ||
        _inlineEditorRectScene == null) return null;

    // QuillEditor 위젯을 직접 빌드합니다.
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blueAccent, width: 1),
      ),
      child: FocusScope( // FocusScope로 감싸서 포커스 관리를 분리합니다.
        child: quill.QuillEditor.basic(
          controller: _quillController!,
          focusNode: _quillFocus,
          // padding, autoFocus, expands 파라미터는 현재 버전에서 지원하지 않으므로 제거합니다.
        ),
      ),
    );
  }

  /// 한글 주석: 인라인 편집 종료 및 저장
  
  /// 한글 주석: 인라인 편집 중 현재 Quill 문서를 즉시 셀의 deltaJson에 반영(포커스/커밋 없이도 보존)
  void _persistInlineDelta() {
    if (_editingTable == null ||
        _editingCellRow == null ||
        _editingCellCol == null ||
        _quillController == null) return;
    final r = _editingCellRow!;
    final c = _editingCellCol!;
    try {
      final delta = _quillController!.document.toDelta().toJson();
      final jsonStr = json.encode({"ops": delta});
      _editingTable!.setDeltaJson(r, c, jsonStr);
      try { controller.notifyListeners(); } catch (_) {}
    } catch (_) {
      // ignore: any failure should not break UX
    }
  }

void _commitInlineEditor() {
    // 편집 중인 셀 캔버스 페인트 복구를 위해 마커 해제 예정
    // Collapse any selection to prevent lingering highlight
    try {
      _quillController?.updateSelection(
        const TextSelection.collapsed(offset: 0),
        quill.ChangeSource.local,
      );
    } catch (_) {}
    // Remove inline editor overlay if present
    try { _inlineEditor?.remove(); } catch (_){ }
    try { _inlineEditorEntry?.remove(); } catch (_){ }
    try { _editorOverlay?.remove(); } catch (_){ }

  // Collapse selection to prevent lingering highlight after leaving edit mode
  try {
    _quillController?.updateSelection(
      const TextSelection.collapsed(offset: 0),
      quill.ChangeSource.local,
    );
  } catch (_) {
    try {
      // Fallback for older flutter_quill versions
      // ignore: deprecated_member_use
      _quillController?.updateSelection(
        const TextSelection.collapsed(offset: 0),
        quill.ChangeSource.local,
      );
    } catch (__){ /* no-op */ }
  }
    if (_editingTable == null ||
        _editingCellRow == null ||
        _editingCellCol == null ||
        _quillController == null) return;
    final r = _editingCellRow!;
    final c = _editingCellCol!;
    final delta = _quillController!.document.toDelta().toJson();
    final jsonStr = json.encode({"ops": delta});
    _editingTable!.setDeltaJson(r, c, jsonStr);
    setState(() {
  // Collapse selection to prevent lingering highlight after leaving edit mode
  try {
    _quillController?.updateSelection(
      const TextSelection.collapsed(offset: 0),
      quill.ChangeSource.local,
    );
  } catch (_) {
    try {
      // Fallback for older flutter_quill versions
      // ignore: deprecated_member_use
      _quillController?.updateSelection(
        const TextSelection.collapsed(offset: 0),
        quill.ChangeSource.local,
      );
    } catch (__){ /* no-op */ }
  }
      try { _editingTable?.endEdit(); controller.notifyListeners(); } catch (_) {}
_editingTable = null;
_editingCellRow = null;
_editingCellCol = null;
_inlineEditorRectScene = null;
_quillController = null;
_clearCellSelection(); // ✅ 편집 종료 시 셀 선택도 초기화
    });
  }

  Paint _strokePaint(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * (scalePercent / 100.0);
  Paint _fillPaint(Color c) => Paint()..color = c..style = PaintingStyle.fill;

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
    if (d is ImageBoxDrawable) {
      return Rect.fromCenter(center: d.position, width: d.size.width, height: d.size.height);
    }
    if (d is TableDrawable) {
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

  bool get _isPainterGestureTool =>
      currentTool == tool.Tool.pen ||
      currentTool == tool.Tool.eraser ||
      currentTool == tool.Tool.select;

  void _setTool(tool.Tool t) {
    setState(() {
      currentTool = t;
      switch (t) {
        case tool.Tool.pen:
          controller.freeStyleMode = FreeStyleMode.draw;
          controller.scalingEnabled = true;
          break;
        case tool.Tool.eraser:
          controller.freeStyleMode = FreeStyleMode.erase;
          controller.scalingEnabled = true;
          break;
        case tool.Tool.select:
          controller.freeStyleMode = FreeStyleMode.none;
          controller.scalingEnabled = true;
          break;
        case tool.Tool.text:
        case tool.Tool.image:
          controller.freeStyleMode = FreeStyleMode.none;
          controller.scalingEnabled = false;
          break;
        default:
          controller.freeStyleMode = FreeStyleMode.none;
          controller.scalingEnabled = false;
          break;
      }
    });

    if (t == tool.Tool.image) {
      _pickImageAndAdd();
      _setTool(tool.Tool.select);
    }
  }

  double _normalizeAngle(double rad) {
    final twoPi = 2 * math.pi;
    double a = rad % twoPi;
    if (a >= math.pi) a -= twoPi;
    if (a < -math.pi) a += twoPi;
    return a;
  }

  double _nearestStep(double raw) =>
      (_normalizeAngle(raw / (_snapStep)).roundToDouble()) * _snapStep;

  double _snapAngle(double raw) {
    if (!angleSnap) return raw;
    final norm = _normalizeAngle(raw);
    final target = _nearestStep(norm);
    if (_isCreatingLineLike && _firstAngleLockPending) {
      _dragSnapAngle = target;
      _firstAngleLockPending = false;
      return _dragSnapAngle!;
    }
    if ((norm - target).abs() <= _snapTol) {
      _dragSnapAngle ??= target;
      return _dragSnapAngle!;
    }
    if (_dragSnapAngle != null) {
      final exitTol = _snapTol * 1.5;
      if ((norm - _dragSnapAngle!).abs() <= exitTol) return _dragSnapAngle!;
    }
    return norm;
  }

  void _onPanStartCreate(DragStartDetails d) {
    if (_isPainterGestureTool ||
        currentTool == tool.Tool.text ||
        currentTool == tool.Tool.image) return;
    _dragSnapAngle = null;
    _isCreatingLineLike =
        (currentTool == tool.Tool.line || currentTool == tool.Tool.arrow);
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
    if (_isPainterGestureTool ||
        currentTool == tool.Tool.text ||
        currentTool == tool.Tool.image) return;
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
    if (_isPainterGestureTool ||
        currentTool == tool.Tool.text ||
        currentTool == tool.Tool.image) return;
    _pressSnapTimer?.cancel();
    _dragSnapAngle = null;
    _isCreatingLineLike = false;
    _firstAngleLockPending = false;
    final createdDrawable = previewShape;
    dragStart = null;
    previewShape = null;

    final shouldSwitchToSelect = currentTool == tool.Tool.rect ||
        currentTool == tool.Tool.oval ||
        currentTool == tool.Tool.line ||
        currentTool == tool.Tool.arrow ||
        currentTool == tool.Tool.barcode;

    if (shouldSwitchToSelect && createdDrawable != null) {
      setState(() => selectedDrawable = createdDrawable);
    }
    if (shouldSwitchToSelect) {
      _setTool(tool.Tool.select);
    }
  }

  Drawable? _makeShape(Offset a, Offset b, {Drawable? previewOf}) {
    var dx = b.dx - a.dx;
    var dy = b.dy - a.dy;
    var w = dx.abs();
    var h = dy.abs();

    if (lockRatio &&
        (currentTool == tool.Tool.rect ||
            currentTool == tool.Tool.oval ||
            currentTool == tool.Tool.barcode)) {
      final m = math.max(w, h);
      dx = (dx.isNegative ? -m : m);
      dy = (dy.isNegative ? -m : m);
      w = m;
      h = m;
    }

    final cx = math.min(a.dx, a.dx + dx) + w / 2;
    final cy = math.min(a.dy, a.dy + dy) + h / 2;
    final center = Offset(cx, cy);

    switch (currentTool) {
      case tool.Tool.rect:
        return RectangleDrawable(
          position: center,
          size: Size(w, h),
          paint: fillColor.a == 0
              ? _strokePaint(strokeColor, strokeWidth)
              : _fillPaint(fillColor),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        );
      case tool.Tool.oval:
        return OvalDrawable(
          position: center,
          size: Size(w, h),
          paint: fillColor.a == 0
              ? _strokePaint(strokeColor, strokeWidth)
              : _fillPaint(fillColor),
        );
      case tool.Tool.barcode:
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
      case tool.Tool.line:
      case tool.Tool.arrow:
        final length = (b - a).distance;
        var angle = math.atan2(dy, dx);
        if (_isCreatingLineLike && _firstAngleLockPending && length >= _firstLockMinLen) {
          _dragSnapAngle = _nearestStep(angle);
          _firstAngleLockPending = false;
        }
        angle = _snapAngle(angle);

        final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        if (currentTool == tool.Tool.line) {
          return LineDrawable(
              position: mid,
              length: length,
              rotationAngle: angle,
              paint: _strokePaint(strokeColor, strokeWidth));
        } else {
          return ArrowDrawable(
              position: mid,
              length: length,
              rotationAngle: angle,
              arrowHeadSize: 16,
              paint: _strokePaint(strokeColor, strokeWidth));
        }
      default:
        return null;
    }
  }

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

    Offset p2 = p;
    final d = selectedDrawable;
    if (d is BarcodeDrawable ||
        d is ConstrainedTextDrawable ||
        d is TextDrawable ||
        d is ImageBoxDrawable) {
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

  Offset _rotPoint(Offset point, Offset center, double angle) {
    final v = point - center;
    final ca = math.cos(angle), sa = math.sin(angle);
    return Offset(ca * v.dx - sa * v.dy, sa * v.dx + ca * v.dy) + center;
  }

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

  /// 월드(씬) -> 로컬 좌표 변환 유틸 (더블탭 셀 계산용)
  Offset _toLocal(Offset worldPoint, Offset center, double angle) {
    final dx = worldPoint.dx - center.dx;
    final dy = worldPoint.dy - center.dy;
    final ca = math.cos(-angle);
    final sa = math.sin(-angle);
    return Offset(ca * dx - sa * dy, sa * dx + ca * dy);
  }

  void _handleCanvasDoubleTapDown(TapDownDetails details) {
  // 새 셀 편집 진입 전에 이전 인라인 편집을 확실히 커밋해서 겹침 방지
  if (_quillController != null) { _commitInlineEditor(); }

  final scenePoint = _sceneFromGlobal(details.globalPosition);
  final d = _pickTopAt(scenePoint);
  if (d is! TableDrawable) return;

  // 로컬 좌표 변환
  final local = _toLocal(scenePoint, d.position, d.rotationAngle);
  final scaledSize = d.size;
  final rect = Rect.fromCenter(center: Offset.zero, width: scaledSize.width, height: scaledSize.height);
  if (!rect.contains(local)) return;

  // 열 인덱스 계산
  final colFractions = d.columnFractions;
  final colWidths = <double>[];
  for (final f in colFractions) { colWidths.add(rect.width * f); }
  double x = rect.left;
  int col = 0;
  for (int c=0; c<colWidths.length; c++) {
    final left = x;
    final right = x + colWidths[c];
    if (local.dx >= left && local.dx <= right) { col = c; break; }
    x += colWidths[c];
  }
  // 행 인덱스 계산
  final rowH = rect.height / d.rows;
  int row = ((local.dy - rect.top) / rowH).floor().clamp(0, d.rows-1);

  // 셀 씬 좌표 사각형 계산
  final cellLocal = d.localCellRect(row, col, scaledSize);
  // 로컬->월드(씬) 좌표 변환
  final topLeftLocal = Offset(cellLocal.left, cellLocal.top);
  final sceneTopLeft = d.position + Offset(
    math.cos(d.rotationAngle)*topLeftLocal.dx - math.sin(d.rotationAngle)*topLeftLocal.dy,
    math.sin(d.rotationAngle)*topLeftLocal.dx + math.cos(d.rotationAngle)*topLeftLocal.dy
  );
  _inlineEditorRectScene = Rect.fromLTWH(sceneTopLeft.dx, sceneTopLeft.dy, cellLocal.width, cellLocal.height);

  // Quill 컨트롤러 구성
  final key = "$row,$col";
  final jsonStr = d.cellDeltaJson[key];
  final doc = (jsonStr != null && jsonStr.isNotEmpty) // ✅ JSON 구조 수정
      ? quill.Document.fromJson(
          (json.decode(jsonStr) as Map<String, dynamic>)['ops']
              as List<dynamic>,
        )
      : quill.Document();
  _quillController = quill.QuillController(
    document: doc,
    selection: const TextSelection.collapsed(offset: 0),
    );

    setState(() {
      _selectionAnchorCell = (row, col);
      _selectionFocusCell = (row, col);
  });

  setState(() {
      _editingTable = d;
      _editingCellRow = row;
      _editingCellCol = col;
    });
    try { d.beginEdit(row, col); controller.notifyListeners(); } catch (_) {}
// ✅ 더블클릭 직후 바로 편집 가능: 포커스 & 커서 이동
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _quillFocus.requestFocus();
    try {
      final len = _quillController?.document.length ?? 0;
      _quillController?.updateSelection(
        TextSelection.collapsed(offset: len),
        quill.ChangeSource.local,
      );
    } catch (_) {}
  });
}

  void _handlePointerDownSelect(PointerDownEvent e) async {
    if (currentTool == tool.Tool.text) {
      final scenePoint = _sceneFromGlobal(e.position);
      await _createTextAt(scenePoint);
      return;
    }
    if (currentTool != tool.Tool.select) return;

    final scenePoint = _sceneFromGlobal(e.position);
    _downScene = scenePoint;
    _movedSinceDown = false;
    _pressOnSelection = _hitSelectionChromeScene(scenePoint);

    final hit = _pickTopAt(scenePoint);
    _downHitDrawable = hit;
    
    // Shift 키를 누르고 테이블을 클릭하는 경우는 다중 선택이므로, selectedDrawable을 변경하지 않습니다.
    final isMultiSelectingTable = _isShiftPressed && hit is TableDrawable;
    if (hit != null && hit != selectedDrawable && !isMultiSelectingTable) {
      setState(() => selectedDrawable = hit);
    }
    // 다른 객체를 선택하면 셀 선택 해제
    // Shift 키를 누르고 테이블을 클릭하는 경우는 다중 선택을 위한 것이므로 셀 선택을 유지합니다.
    if (hit is! TableDrawable && !isMultiSelectingTable) {
      _clearCellSelection();
    }
  }

  Drawable? _pickTopAt(Offset scenePoint) {
    final list = controller.drawables.reversed.toList();
    for (final d in list) {
      if (_hitTest(d, scenePoint)) return d;
    }
    return null;
  }

  void _onOverlayPanStart(DragStartDetails details) {
    if (currentTool != tool.Tool.select) return;

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

    void prime(ObjectDrawable obj, Rect rect, DragAction action) {
      dragAction = action;
      dragStartBounds = rect;
      dragStartPointer = localScene;

      if (action == DragAction.rotate) {
        startAngle = obj.rotationAngle;
        final center = obj.position;
        _startPointerAngle = math.atan2(
          (localScene - center).dy,
          (localScene - center).dx,
        );
      } else {
        startAngle = null;
        _startPointerAngle = null;
      }

      if (obj is BarcodeDrawable ||
          obj is ConstrainedTextDrawable ||
          obj is TextDrawable ||
          obj is ImageBoxDrawable ||
          obj is TableDrawable) {
        if (action == DragAction.resizeNW ||
            action == DragAction.resizeNE ||
            action == DragAction.resizeSW ||
            action == DragAction.resizeSE) {
          final angle = obj.rotationAngle;
          final opp = _fixedCornerForAction(rect, action);
          dragFixedCorner = _rotPoint(opp, rect.center, angle);
        } else {
          dragFixedCorner = null;
        }
      } else {
        dragFixedCorner = null;
      }
    }

    if (current is ObjectDrawable) {
      final rect = _boundsOf(current);
      final action = _hitHandle(rect, localScene);
      prime(current, rect, action);
      prepareLineResize(current, action);

      if (action == DragAction.none && !rect.inflate(4).contains(localScene)) {
        final hit = _pickTopAt(localScene);
        if (hit is ObjectDrawable && hit != current) {
          setState(() => selectedDrawable = hit);
          final r2 = _boundsOf(hit);
          final a2 = _hitHandle(r2, localScene);
          prime(hit, r2, a2);
          prepareLineResize(hit, a2);
        }
      }
    } else {
      final hit = _pickTopAt(localScene);
      if (hit is ObjectDrawable) {
        setState(() => selectedDrawable = hit);
        final r2 = _boundsOf(hit);
        final a2 = _hitHandle(r2, localScene);
        prime(hit, r2, a2);
        prepareLineResize(hit, a2);
      } else {
        dragAction = DragAction.none;
        dragStartBounds = null;
        dragStartPointer = null;
        startAngle = null;
        _startPointerAngle = null;
        dragFixedCorner = null;
      }
    }

    setState(() {});
  }

  Drawable? _updateDrawableOnPan(
      Drawable original, DragAction action, Rect startRect, Offset scenePtWorld, Offset scenePtLocal) {
    if (action == DragAction.move) {
      return _updateDrawablePosition(original, startRect, scenePtWorld, dragStartPointer!);
    } else if (action == DragAction.rotate) {
      return _updateDrawableRotation(original as ObjectDrawable, scenePtWorld);
    } else if (original is RectangleDrawable || original is OvalDrawable) {
      return _updateSimpleShapeOnResize(original, action, startRect, scenePtWorld);
    }
    // 다른 타입의 Drawable 업데이트 로직을 위한 헬퍼 메서드 호출 추가
    return null; // 임시 반환
  }

  void _onOverlayPanUpdate(DragUpdateDetails details) {
    if (selectedDrawable == null || dragAction == DragAction.none) return;
    _movedSinceDown = true;

    final scenePtWorld = _sceneFromGlobal(details.globalPosition);
    var scenePtLocal = scenePtWorld;

    final original = selectedDrawable!;
    final startRect = dragStartBounds!;
    final startPtWorld = dragStartPointer!;
    Drawable? replaced;

    final isTextLike = original is BarcodeDrawable || original is ConstrainedTextDrawable || original is TextDrawable || original is ImageBoxDrawable || original is TableDrawable;
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

    if (dragAction == DragAction.move) {
      final delta = scenePtWorld - startPtWorld;
      if (original is ObjectDrawable) { // ObjectDrawable은 position을 가짐
        replaced = (original as dynamic).copyWith(position: startRect.center + delta);
        // copyWith가 없는 경우를 대비한 분기 처리 필요
        // 예:
        // if (original is RectangleDrawable) { ... }
        // else if (original is OvalDrawable) { ... }
        // ...
      }
      else if (original is LineDrawable) {
        replaced = original.copyWith(position: startRect.center + delta);
      } else if (original is ConstrainedTextDrawable) {
        replaced = original.copyWith(position: startRect.center + delta);
      } else if (original is TextDrawable) {
        replaced = original.copyWith(position: startRect.center + delta);
      } else if (original is ImageBoxDrawable) {
        replaced = original.copyWithExt(position: startRect.center + delta);
      } else if (original is TableDrawable) {
        replaced = original.copyWith(position: startRect.center + delta);
      }
    } else if (dragAction == DragAction.rotate) {
      // 이 로직은 _updateDrawableRotation 헬퍼 메서드로 이동 가능
      if (original is ObjectDrawable) {
        final center = original.position;

        final curPointerAngle = math.atan2(
          (scenePtWorld - center).dy,
          (scenePtWorld - center).dx,
        );
        final baseObjAngle = startAngle ?? original.rotationAngle;
        final basePointerAngle = _startPointerAngle ?? curPointerAngle;

        var newAngle = baseObjAngle + (curPointerAngle - basePointerAngle);
        newAngle = _snapAngle(newAngle);

        if (original is LineDrawable) {
          replaced = original.copyWith(rotation: newAngle);
        } else if (original is ArrowDrawable) {
          replaced = original.copyWith(rotation: newAngle);
        } else if (original is ConstrainedTextDrawable) {
          replaced = original.copyWith(rotation: newAngle);
        } else if (original is TextDrawable) {
          replaced = original.copyWith(rotation: newAngle);
        } else if (original is BarcodeDrawable) {
          replaced = original.copyWith(rotation: newAngle);
        } else if (original is ImageBoxDrawable) {
          replaced = original.copyWithExt(rotation: newAngle);
        }
      }
    } else {
      // 이 로직은 타입별 헬퍼 메서드로 이동 가능
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
          final vMove = _toLocalVec(worldMove, center0, angle);

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
          final vMove = _toLocalVec(worldMove, center0, angle);

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
          final vMove = _toLocalVec(worldMove, center0, angle);
          final vCenter = (vFixed + vMove) / 2;

          final newCenterWorld = _fromLocalVec(vCenter, center0, angle);

          replaced = original.copyWith(position: newCenterWorld, rotation: angle);
        }
      } else if (original is ImageBoxDrawable) {
        if (isCornerResize) {
          final angle = original.rotationAngle;
          final center0 = startRect.center;

          final worldFixed = dragFixedCorner!;
          final worldMove = scenePtWorld;

          final vFixed = _toLocalVec(worldFixed, center0, angle);
          final vMove = _toLocalVec(worldMove, center0, angle);

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

          replaced = original.copyWithExt(
            position: newCenterWorld,
            size: newSize,
            rotation: angle,
          );
        }
      } else if (original is TableDrawable) {
        if (isCornerResize) {
          final angle = original.rotationAngle;
          final center0 = startRect.center;

          final worldFixed = dragFixedCorner!;
          final worldMove = scenePtWorld;

          final vFixed = _toLocalVec(worldFixed, center0, angle);
          final vMove = _toLocalVec(worldMove, center0, angle);

          final minWidth = original.columns * 16.0;
          final minHeight = original.rows * 16.0;
          final width = (vMove.dx - vFixed.dx).abs().clamp(minWidth, double.infinity);
          final height = (vMove.dy - vFixed.dy).abs().clamp(minHeight, double.infinity);
          final signX = (vMove.dx - vFixed.dx) >= 0 ? 1.0 : -1.0;
          final signY = (vMove.dy - vFixed.dy) >= 0 ? 1.0 : -1.0;
          final vMoveAdjusted = Offset(vFixed.dx + signX * width, vFixed.dy + signY * height);
          final vCenter = (vFixed + vMoveAdjusted) / 2;

          final newCenterWorld = _fromLocalVec(vCenter, center0, angle);

          replaced = original.copyWith(
            position: newCenterWorld,
            size: Size(width, height),
            rotation: angle,
          );
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
      controller.notifyListeners(); // ✅ 인스펙트/드래그 모두에서 캔버스 즉시 리렌더
      setState(() => selectedDrawable = replaced);
    }
  }

  Drawable _updateDrawablePosition(Drawable original, Rect startRect, Offset scenePtWorld, Offset startPtWorld) {
    final delta = scenePtWorld - startPtWorld;
    final newPosition = startRect.center + delta;

    // dynamic dispatch를 사용하거나, 각 타입에 맞게 copyWith를 호출합니다.
    // 이 예제에서는 dynamic을 사용하지만, 실제 구현에서는 타입 체크가 더 안전합니다.
    if (original is ObjectDrawable) {
      return (original as dynamic).copyWith(position: newPosition);
    }
    // 다른 타입들에 대한 처리...
    return original; // 변경 불가 시 원본 반환
  }

  Drawable _updateDrawableRotation(ObjectDrawable original, Offset scenePtWorld) {
    final center = original.position;
    final curPointerAngle = math.atan2((scenePtWorld - center).dy, (scenePtWorld - center).dx);
    final baseObjAngle = startAngle ?? original.rotationAngle;
    final basePointerAngle = _startPointerAngle ?? curPointerAngle;

    var newAngle = baseObjAngle + (curPointerAngle - basePointerAngle);
    newAngle = _snapAngle(newAngle);

    return (original as dynamic).copyWith(rotation: newAngle);
  }

  Drawable _updateSimpleShapeOnResize(Drawable original, DragAction action, Rect startRect, Offset scenePtWorld) {
    final fixed = dragFixedCorner ?? _fixedCornerForAction(startRect, action);
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
      return RectangleDrawable(position: newRect.center, size: newRect.size, paint: original.paint, borderRadius: original.borderRadius);
    } else if (original is OvalDrawable) {
      return OvalDrawable(position: newRect.center, size: newRect.size, paint: original.paint);
    }
    return original;
  }

  // _updateBarcodeOnResize, _updateTextOnResize 등 추가...


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
    _startPointerAngle = null;

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
      case DragAction.resizeNW:
        return r.bottomRight;
      case DragAction.resizeNE:
        return r.bottomLeft;
      case DragAction.resizeSW:
        return r.topRight;
      case DragAction.resizeSE:
        return r.topLeft;
      default:
        return r.center;
    }
  }

  Future<void> _createTextAt(Offset scenePoint) async {
    final controllerText = TextEditingController();
    double tempSize = textFontSize;
    bool tempBold = textBold;
    bool tempItalic = textItalic;
    String tempFamily = textFontFamily;
    Color tempColor = strokeColor;
    tool.TxtAlign tempAlign = defaultTextAlign;
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
                      decoration: const InputDecoration(
                          labelText: 'Text', hintText: 'Enter text...'),
                      minLines: 1,
                      maxLines: 6),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Text('Size'),
                    Expanded(
                        child: Slider(
                            min: 8,
                            max: 96,
                            value: tempSize,
                            onChanged: (v) => setSS(() => tempSize = v))),
                    SizedBox(width: 40, child: Text(tempSize.toStringAsFixed(0)))
                  ]),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilterChip(
                        label: const Text('Bold'),
                        selected: tempBold,
                        onSelected: (v) => setSS(() => tempBold = v)),
                    FilterChip(
                        label: const Text('Italic'),
                        selected: tempItalic,
                        onSelected: (v) => setSS(() => tempItalic = v)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('Font'),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: tempFamily,
                      items: const [
                        DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
                        DropdownMenuItem(value: 'NotoSans', child: Text('NotoSans')),
                        DropdownMenuItem(value: 'Monospace', child: Text('Monospace')),
                      ],
                      onChanged: (v) => setSS(() {
                        if (v != null) tempFamily = v;
                      }),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('Align'),
                    const SizedBox(width: 8),
                    DropdownButton<tool.TxtAlign>(
                      value: tempAlign,
                      items: const [
                        DropdownMenuItem(value: tool.TxtAlign.left, child: Text('Left')),
                        DropdownMenuItem(value: tool.TxtAlign.center, child: Text('Center')),
                        DropdownMenuItem(value: tool.TxtAlign.right, child: Text('Right')),
                      ],
                      onChanged: (v) => setSS(() {
                        if (v != null) tempAlign = v;
                      }),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('Max Width'),
                    Expanded(
                        child: Slider(
                            min: 40,
                            max: 800,
                            value: tempMaxWidth,
                            onChanged: (v) => setSS(() => tempMaxWidth = v))),
                    SizedBox(
                        width: 56, child: Text(tempMaxWidth.toStringAsFixed(0))),
                  ]),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Add')),
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
      currentTool = tool.Tool.select;
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

  void _handleTableInsert(int rows, int columns) {
    if (rows <= 0 || columns <= 0) return;
    _createTableDrawable(rows, columns);
  }

  void _createTableDrawable(int rows, int columns) {
    final renderObject = _painterKey.currentContext?.findRenderObject();
    Size painterSize;
    if (renderObject is RenderBox && renderObject.hasSize) {
      painterSize = renderObject.size;
    } else {
      painterSize = const Size(640, 640);
    }

    // 표의 너비는 캔버스 전체 너비로, 높이는 행 개수에 따라 동적으로 계산합니다.
    final tableSize = Size(
      painterSize.width,
      math.max(32.0, rows * 32.0),
    );

    final fractions = List<double>.filled(columns, 1.0 / columns);

    final table = TableDrawable(
      rows: rows,
      columns: columns,
      columnFractions: fractions,
      position: Offset(tableSize.width / 2, tableSize.height / 2), // 캔버스 좌상단에 위치하도록 중심점 계산
      size: tableSize,
    );

    controller.addDrawables([table]);
    controller.notifyListeners();
    setState(() {
      selectedDrawable = table;
    });
    _setTool(tool.Tool.select);
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }

  Future<void> _pickImageAndAdd() async {
    final typeGroup = const XTypeGroup(
      label: 'images',
      extensions: ['png', 'jpg', 'jpeg', 'bmp', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    final data = await file.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(Uint8List.fromList(data));
    final ui.FrameInfo fi = await codec.getNextFrame();
    final ui.Image image = fi.image;

    const double maxSide = 320;
    double w = image.width.toDouble();
    double h = image.height.toDouble();
    final scale = (w > h) ? (maxSide / w) : (maxSide / h);
    if (scale < 1.0) {
      w *= scale;
      h *= scale;
    }

    final imgDrawable = ImageBoxDrawable(
      position: const Offset(320, 320),
      image: image,
      size: Size(w, h),
      rotationAngle: 0,
      strokeWidth: 0,
    );

    controller.addDrawables([imgDrawable]);
    setState(() {
      selectedDrawable = imgDrawable;
      currentTool = tool.Tool.select;
      controller.freeStyleMode = FreeStyleMode.none;
      controller.scalingEnabled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$appTitle v$appVersion'), actions: [
        IconButton(onPressed: controller.canUndo ? controller.undo : null, icon: const Icon(Icons.undo)),
        IconButton(onPressed: controller.canRedo ? controller.redo : null, icon: const Icon(Icons.redo)),
        IconButton(onPressed: _clearAll, icon: const Icon(Icons.layers_clear), tooltip: 'Clear'),
        IconButton(onPressed: () => _saveAsPng(context), icon: const Icon(Icons.save_alt)),
      ]),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _keyboardFocus,
      autofocus: true,
      onKey: (event) {
        final isShift = event.isShiftPressed;
        if (isShift != _isShiftPressed) {
          setState(() {
            _isShiftPressed = isShift;
          });
        }
      },
      child: Row(
        children: [
          ToolPanel(
            currentTool: currentTool,
            onToolSelected: _setTool,
            onTableCreate: _handleTableInsert,
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
              controller: controller, isEditingCell: _quillController != null, 
              painterKey: _painterKey,
              onPointerDownSelect: _handlePointerDownSelect,
              onCanvasTap: _handleCanvasTap,
              onCanvasDoubleTapDown: _handleCanvasDoubleTapDown,
              inlineEditorRect: _inlineEditorRectScene,
              inlineEditor: _buildInlineEditor(),
              onOverlayPanStart: _onOverlayPanStart,
              onOverlayPanUpdate: _onOverlayPanUpdate,
              onOverlayPanEnd: _onOverlayPanEnd,
              onCreatePanStart: _onPanStartCreate,
              onCreatePanUpdate: _onPanUpdateCreate,
              onCreatePanEnd: _onPanEndCreate,
              selectedDrawable: selectedDrawable,
              selectionBounds: selectedDrawable == null ? null : _boundsOf(selectedDrawable!),
              selectionAnchorCell: _selectionAnchorCell,
              selectionFocusCell: _selectionFocusCell,
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
            mutateSelected: (rewriter) {
              final cur = selectedDrawable;
              if (cur == null) return;
              final replacement = rewriter(cur);
              if (identical(replacement, cur)) return;
              controller.replaceDrawable(cur, replacement);
              setState(() => selectedDrawable = replacement);
            },
            // ★ Quill 편집기 연동
            showCellQuillSection: _editingTable != null && _editingCellRow != null && _editingCellCol != null,
            quillBold: (() {
              final d = _editingTable;
              final r = _editingCellRow;
              final c = _editingCellCol;
              if (d == null || r == null || c == null) return false;
              return (d.styleOf(r, c)['bold'] as bool);
            })(),
            quillItalic: (() {
              final d = _editingTable;
              final r = _editingCellRow;
              final c = _editingCellCol;
              if (d == null || r == null || c == null) return false;
              return (d.styleOf(r, c)['italic'] as bool);
            })(),
            quillFontSize: (() {
              final d = _editingTable;
              final r = _editingCellRow;
              final c = _editingCellCol;
              if (d == null || r == null || c == null) return 12.0;
              return (d.styleOf(r, c)['fontSize'] as double);
            })(),
            quillAlign: (() {
              final d = _editingTable;
              final r = _editingCellRow;
              final c = _editingCellCol;
              if (d == null || r == null || c == null) return tool.TxtAlign.left;
              final a = (d.styleOf(r, c)['align'] as String);
              return a == 'center'
                  ? tool.TxtAlign.center
                  : a == 'right'
                      ? tool.TxtAlign.right
                      : tool.TxtAlign.left;
            })(),
            onQuillStyleChanged: ({bool? bold, bool? italic, double? fontSize, tool.TxtAlign? align}) {
              // Guard selection during inspector formatting
              _guardSelectionDuringInspector = true;
              _suppressCommitOnce = true;
              // Save selection to restore after focus juggling
              if (_quillController != null) {
                final sel = _quillController!.selection;
                if (sel.start != -1 && sel.end != -1 && sel.start != sel.end) {
                  _pendingSelectionRestore = sel;
                }
              }

              final d = _editingTable;
              final r = _editingCellRow;
              final c = _editingCellCol;
              if (d == null || r == null || c == null) return;

              final cur = d.styleOf(r, c);
              final next = {
                'fontSize': (fontSize ?? cur['fontSize']) as double,
                'bold': (bold ?? cur['bold']) as bool,
                'italic': (italic ?? cur['italic']) as bool,
                'align': (align != null)
                    ? (align == tool.TxtAlign.center ? 'center' : (align == tool.TxtAlign.right ? 'right' : 'left'))
                    : (cur['align'] as String),
              };
              d.setStyle(r, c, next);

              // ✅ 스타일 적용 즉시 Delta 보존
              _persistInlineDelta();

              _suppressCommitOnce = true;
              _suppressCommitOnce = true;
              if (_quillController != null) {
                if (bold != null) _quillController!.formatSelection(bold ? quill.Attribute.bold : quill.Attribute.clone(quill.Attribute.bold, null));
                if (italic != null) _quillController!.formatSelection(italic ? quill.Attribute.italic : quill.Attribute.clone(quill.Attribute.italic, null));
                if (fontSize != null) _quillController!.formatSelection(quill.SizeAttribute(fontSize.round().toString()));
                if (align != null) _quillController!.formatSelection(align == tool.TxtAlign.left ? quill.Attribute.leftAlignment : (align == tool.TxtAlign.center ? quill.Attribute.centerAlignment : quill.Attribute.rightAlignment));
              }
              
              // 1. 포커스 리스너가 _commitInlineEditor를 호출하지 못하도록 먼저 포커스를 해제합니다.
              // keep focus on editor to preserve selection
              // 2. InspectorPanel의 UI를 업데이트합니다.
              // no-op: avoid triggering commit via rebuild
              // 3. UI 빌드가 완료된 후, 다시 편집기로 포커스를 복원합니다.
              //    이렇게 하면 사용자는 포커스 변화를 인지하지 못하고 편집을 계속할 수 있습니다.
              WidgetsBinding.instance.addPostFrameCallback((_) => _quillFocus.requestFocus());
            
              // After applying format, refocus and restore selection
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _quillFocus.requestFocus();
                  if (_pendingSelectionRestore != null && _quillController != null) {
                    _quillController!.updateSelection(
                      _pendingSelectionRestore!,
                      quill.ChangeSource.local,
                    );
                  }
                }
                _pendingSelectionRestore = null;
                _guardSelectionDuringInspector = false;
                _suppressCommitOnce = false;
              });
},
          ),
        ],
      ),
    );
  }

  void _handleCanvasTap() {
    // ✅ 다른 셀/객체를 탭하기 직전에 현재 인라인 편집 내용을 보존
    if (_quillController != null) { _commitInlineEditor(); }
    if (currentTool != tool.Tool.select) return;

    final hadHit = _downHitDrawable != null;

    // Case 1: 객체를 클릭하지 않은 경우 -> 모든 선택 해제
    if (!hadHit && !_pressOnSelection && !_movedSinceDown) {
      setState(() {
        selectedDrawable = null;
        dragAction = DragAction.none;
        _clearCellSelection();
      });
    }
    // Case 2: 테이블 객체를 클릭한 경우 -> 셀 선택 처리
    else if (hadHit && _downHitDrawable is TableDrawable) {
      final table = _downHitDrawable as TableDrawable;
      final scenePoint = _downScene!;

      // 로컬 좌표로 변환하여 셀 인덱스 계산
      final local = _toLocal(scenePoint, table.position, table.rotationAngle);
      final rect = Rect.fromCenter(center: Offset.zero, width: table.size.width, height: table.size.height);

      if (rect.contains(local)) {
        final colFractions = table.columnFractions;
        final colWidths = colFractions.map((f) => rect.width * f).toList();
        double x = rect.left;
        int col = -1;
        for (int c = 0; c < colWidths.length; c++) {
          if (local.dx >= x && local.dx <= x + colWidths[c]) {
            col = c;
            break;
          }
          x += colWidths[c];
        }
        final rowH = rect.height / table.rows;
        int row = ((local.dy - rect.top) / rowH).floor().clamp(0, table.rows - 1);

        if (col != -1) {
          setState(() {
            if (_isShiftPressed && _selectionAnchorCell != null) {
              // Shift 키 누른 상태: 포커스 셀만 업데이트
              _selectionFocusCell = (row, col);
            } else {
              // 일반 클릭: 앵커와 포커스 모두 업데이트
              _selectionAnchorCell = (row, col);
              _selectionFocusCell = (row, col);
            }
          });
        }
      }
    }

    _pressOnSelection = false;
    _movedSinceDown = false;
    _downScene = null;
    _downHitDrawable = null;
  }

  void _clearCellSelection() {
    if (_selectionAnchorCell != null || _selectionFocusCell != null) {
      setState(() {
        _selectionAnchorCell = null;
        _selectionFocusCell = null;
      });
    }
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
      return;
    } else if (d is ImageBoxDrawable) {
      return;
    }

    if (replaced != null) {
      controller.replaceDrawable(d, replaced);
      controller.notifyListeners(); // ✅
      setState(() {
        selectedDrawable = replaced;
        if (newStrokeColor != null) strokeColor = newStrokeColor;
        if (newStrokeWidth != null) strokeWidth = newStrokeWidth;
      });
    }
  }
}