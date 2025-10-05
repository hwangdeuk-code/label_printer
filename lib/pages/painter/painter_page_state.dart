part of 'painter_page.dart';

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
  static const double _laMinLen = 2.0;
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

  TableDrawable? _editingTable;
  int? _editingCellRow;
  int? _editingCellCol;
  quill.QuillController? _quillController;

  bool _inspBold = false;
  bool _inspItalic = false;
  double _inspFontSize = 12.0;
  tool.TxtAlign _inspAlign = tool.TxtAlign.left;

  final FocusNode _quillFocus = FocusNode();
  bool _guardSelectionDuringInspector = false;
  TextSelection? _pendingSelectionRestore;

  Timer? _quillBlurCommitTimer;
  bool _suppressCommitOnce = false;
  Rect? _inlineEditorRectScene;

  OverlayEntry? _inlineEditor;
  OverlayEntry? _inlineEditorEntry;
  OverlayEntry? _editorOverlay;

  bool _isShiftPressed = false;
  final FocusNode _keyboardFocus = FocusNode();
  (int, int)? _selectionAnchorCell;
  (int, int)? _selectionFocusCell;

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
      handleQuillFocusChange(this);
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
    _quillBlurCommitTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildPainterScaffold(this, context);

  Widget? _buildInlineEditor() => buildInlineEditor(this);

  void _persistInlineDelta() => persistInlineDelta(this);

  void _commitInlineEditor() => commitInlineEditor(this);

  Offset _sceneFromGlobal(Offset global) => sceneFromGlobal(this, global);

  void _handleCanvasDoubleTapDown(TapDownDetails details) =>
      handleCanvasDoubleTapDown(this, details);

  void _handlePointerDownSelect(PointerDownEvent event) =>
      handlePointerDownSelect(this, event);

  Drawable? _pickTopAt(Offset scenePoint) => pickTopAt(this, scenePoint);

  void _onOverlayPanStart(DragStartDetails details) =>
      handleOverlayPanStart(this, details);

  void _onOverlayPanUpdate(DragUpdateDetails details) =>
      handleOverlayPanUpdate(this, details);

  void _onOverlayPanEnd() => handleOverlayPanEnd(this);

  void _onPanStartCreate(DragStartDetails details) =>
      handlePanStartCreate(this, details);

  void _onPanUpdateCreate(DragUpdateDetails details) =>
      handlePanUpdateCreate(this, details);

  void _onPanEndCreate() => handlePanEndCreate(this);

  void _handleCanvasTap() => handleCanvasTap(this);

  Paint _strokePaint(Color color, double width) =>
      strokePaint(this, color, width);

  Paint _fillPaint(Color color) => fillPaint(color);

  Offset _lineStart(Drawable drawable) => lineStart(drawable);

  Offset _lineEnd(Drawable drawable) => lineEnd(drawable);

  Rect _boundsOf(Drawable drawable) => boundsOf(this, drawable);

  bool get _isPainterGestureTool => isPainterGestureTool(this);

  void _setTool(tool.Tool toolValue) => setTool(this, toolValue);

  double _snapAngle(double raw) => snapAngle(this, raw);

  Drawable? _makeShape(Offset a, Offset b, {Drawable? previewOf}) =>
      makeShape(this, a, b, previewOf: previewOf);

  bool _hitTest(Drawable drawable, Offset point) => hitTest(this, drawable, point);

  double _distanceToSegment(Offset p, Offset a, Offset b) =>
      distanceToSegment(p, a, b);

  bool _hitSelectionChromeScene(Offset point) =>
      hitSelectionChromeScene(this, point);

  DragAction _hitHandle(Rect bounds, Offset point) =>
      hitHandle(this, bounds, point);

  Offset _rotateHandlePos(Rect rect) => rotateHandlePos(this, rect);

  Offset _rotPoint(Offset point, Offset center, double angle) =>
      rotPoint(point, center, angle);

  Offset _toLocalVec(Offset worldPoint, Offset center, double angle) =>
      toLocalVec(worldPoint, center, angle);

  Offset _fromLocalVec(Offset localVec, Offset center, double angle) =>
      fromLocalVec(localVec, center, angle);

  Offset _toLocal(Offset worldPoint, Offset center, double angle) =>
      toLocal(worldPoint, center, angle);

  void _clearCellSelection() => clearCellSelection(this);

  void _applyInspector({Color? newStrokeColor, double? newStrokeWidth, double? newCornerRadius}) =>
      applyInspector(this,
          newStrokeColor: newStrokeColor,
          newStrokeWidth: newStrokeWidth,
          newCornerRadius: newCornerRadius);

  Future<void> _createTextAt(Offset scenePoint) => createTextAt(this, scenePoint);

  void _handleTableInsert(int rows, int columns) =>
      handleTableInsert(this, rows, columns);

  void _createTableDrawable(int rows, int columns) =>
      createTableDrawable(this, rows, columns);

  void _clearAll() => clearAll(this);

  Future<void> _saveAsPng(BuildContext context) => saveAsPng(this, context);

  Future<void> _pickImageAndAdd() => pickImageAndAdd(this);
}
