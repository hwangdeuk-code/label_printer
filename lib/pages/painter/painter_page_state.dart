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

  final Map<Drawable, String> _drawableIds = {};
  final Map<Drawable, String> _pendingIdOverrides = {};
  List<Drawable> _previousDrawables = const [];
  int _idSequence = 0;

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
  Timer? _inspectorGuardTimer;

  @override
  void initState() {
    super.initState();
    controller = PainterController(background: Colors.white.backgroundDrawable);
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
      if (!mounted) return;
      _syncDrawableRegistry();
      setState(() {});
    });
    _previousDrawables = List<Drawable>.from(controller.value.drawables);

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
    _inspectorGuardTimer?.cancel();
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

  bool _hitTest(Drawable drawable, Offset point) =>
      hitTest(this, drawable, point);

  double _distanceToSegment(Offset p, Offset a, Offset b) =>
      distanceToSegment(p, a, b);

  bool _hitSelectionChromeScene(Offset point) =>
      hitSelectionChromeScene(this, point);

  DragAction _hitHandle(Rect bounds, Offset point) =>
      hitHandle(this, bounds, point);

  void _syncDrawableRegistry() {
    final current = List<Drawable>.from(controller.value.drawables);
    final previous = _previousDrawables;

    final minLen = math.min(previous.length, current.length);
    for (var i = 0; i < minLen; i++) {
      final oldDrawable = previous[i];
      final newDrawable = current[i];
      if (identical(oldDrawable, newDrawable)) continue;
      if (!_drawableIds.containsKey(newDrawable) &&
          !current.contains(oldDrawable) &&
          _drawableIds.containsKey(oldDrawable)) {
        final id = _drawableIds.remove(oldDrawable);
        if (id != null) {
          _drawableIds[newDrawable] =
              _pendingIdOverrides.remove(newDrawable) ?? id;
        }
      }
    }

    for (final old in previous) {
      if (!current.contains(old)) {
        _drawableIds.remove(old);
      }
    }

    for (final drawable in current) {
      if (!_drawableIds.containsKey(drawable)) {
        final override = _pendingIdOverrides.remove(drawable);
        _drawableIds[drawable] = override ?? _generateIdFor(drawable);
      }
    }

    _previousDrawables = current;
  }

  String _ensureDrawableId(Drawable drawable) {
    return _drawableIds.putIfAbsent(drawable, () => _generateIdFor(drawable));
  }

  String _generateIdFor(Drawable drawable) {
    final base = _baseNameFor(drawable);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final seq = (_idSequence++).toRadixString(36);
    return '$base-$timestamp-$seq';
  }

  String _baseNameFor(Drawable drawable) {
    if (drawable is RectangleDrawable) return 'rectangle';
    if (drawable is OvalDrawable) return 'oval';
    if (drawable is LineDrawable) return 'line';
    if (drawable is ArrowDrawable) return 'arrow';
    if (drawable is DoubleArrowDrawable) return 'double-arrow';
    if (drawable is FreeStyleDrawable) return 'stroke';
    if (drawable is EraseDrawable) return 'eraser';
    if (drawable is ConstrainedTextDrawable) return 'text-block';
    if (drawable is TextDrawable) return 'text';
    if (drawable is BarcodeDrawable) return 'barcode';
    if (drawable is ImageBoxDrawable) return 'image-box';
    if (drawable is ImageDrawable) return 'image';
    if (drawable is TableDrawable) return 'table';
    return drawable.runtimeType.toString().toLowerCase();
  }

  void _prepareOverrideId(Drawable drawable, String id) {
    _pendingIdOverrides[drawable] = id;
    _drawableIds[drawable] = id;
  }

  Future<void> _saveProject(BuildContext context) async {
    try {
      final location = await getSaveLocation(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON', extensions: ['json']),
        ],
      );
      if (location == null) return;

      final objects = <Map<String, dynamic>>[];
      for (final drawable in controller.value.drawables) {
        final id = _ensureDrawableId(drawable);
        final json = await DrawableSerializer.toJson(drawable, id);
        objects.add(json);
      }
      final bundle = DrawableSerializer.wrapScene(
        printerDpi: printerDpi,
        objects: objects,
      );
      final path = location.path.endsWith('.json')
          ? location.path
          : '${location.path}.json';
      final file = File(path);
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(bundle));
      _showSnackBar(context, '저장 완료: ${objects.length}개 객체');
    } catch (e, stack) {
      debugPrint('Save project error: $e\n$stack');
      _showSnackBar(context, '저장 실패: $e', isError: true);
    }
  }

  Future<void> _loadProject(BuildContext context) async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON', extensions: ['json']),
        ],
      );
      if (file == null) return;
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('올바르지 않은 JSON 형식입니다.');
      }
      final objects = decoded['objects'];
      if (objects is! List) {
        throw const FormatException('objects 배열이 존재하지 않습니다.');
      }

      int added = 0;
      for (final entry in objects) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry as Map);
        final result = await DrawableSerializer.fromJson(map);
        if (result == null) continue;
        final drawable = result.drawable;
        _pendingIdOverrides[drawable] = result.id;
        controller.addDrawables([drawable]);
        added++;
      }
      if (added > 0) {
        _showSnackBar(context, '불러오기 완료: $added개 객체 추가');
      } else {
        _showSnackBar(context, '불러온 객체가 없습니다.');
      }
    } catch (e, stack) {
      debugPrint('Load project error: $e\n$stack');
      _showSnackBar(context, '불러오기 실패: $e', isError: true);
    }
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

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

  void _applyInspector({
    Color? newStrokeColor,
    double? newStrokeWidth,
    double? newCornerRadius,
  }) => applyInspector(
    this,
    newStrokeColor: newStrokeColor,
    newStrokeWidth: newStrokeWidth,
    newCornerRadius: newCornerRadius,
  );

  Future<void> _createTextAt(Offset scenePoint) =>
      createTextAt(this, scenePoint);

  void _handleTableInsert(int rows, int columns) =>
      handleTableInsert(this, rows, columns);

  void _createTableDrawable(int rows, int columns) =>
      createTableDrawable(this, rows, columns);

  void _clearAll() => clearAll(this);

  Future<void> _saveAsPng(BuildContext context) => saveAsPng(this, context);

  Future<void> _pickImageAndAdd() => pickImageAndAdd(this);

  _CellSelectionRange? _currentCellSelectionRange() {
    final table = selectedDrawable;
    if (table is! TableDrawable) return null;
    final anchor = _selectionAnchorCell;
    final focus = _selectionFocusCell;
    if (anchor == null || focus == null) return null;
    var range = _CellSelectionRange(
      math.min(anchor.$1, focus.$1),
      math.min(anchor.$2, focus.$2),
      math.max(anchor.$1, focus.$1),
      math.max(anchor.$2, focus.$2),
    );
    range = _expandRangeForMerges(table, range);
    return range;
  }

  bool get _canMergeCells => _canMergeSelectedCells();

  bool get _canUnmergeCells => _canUnmergeSelectedCells();

  _CellSelectionRange _rangeForCell(TableDrawable table, int row, int col) {
    final root = table.resolveRoot(row, col);
    final span = table.spanForRoot(root.$1, root.$2);
    final bottom = span != null ? root.$1 + span.rowSpan - 1 : root.$1;
    final right = span != null ? root.$2 + span.colSpan - 1 : root.$2;
    return _CellSelectionRange(root.$1, root.$2, bottom, right);
  }

  _CellSelectionRange _expandRangeForMerges(
    TableDrawable table,
    _CellSelectionRange range,
  ) {
    var expanded = range;
    bool changed;
    do {
      changed = false;
      for (int r = expanded.topRow; r <= expanded.bottomRow; r++) {
        for (int c = expanded.leftCol; c <= expanded.rightCol; c++) {
          final cellRange = _rangeForCell(table, r, c);
          final merged = expanded.union(cellRange);
          if (merged != expanded) {
            expanded = merged;
            changed = true;
          }
        }
      }
    } while (changed);

    return expanded.clamp(table.rows, table.columns);
  }

  bool _canMergeSelectedCells() {
    final table = selectedDrawable;
    if (table is! TableDrawable) return false;
    final range = _currentCellSelectionRange();
    if (range == null) return false;
    if (range.isSingleCell) return false;
    return table.canMergeRegion(
      range.topRow,
      range.leftCol,
      range.bottomRow,
      range.rightCol,
    );
  }

  bool _canUnmergeSelectedCells() {
    final table = selectedDrawable;
    if (table is! TableDrawable) return false;
    final range = _currentCellSelectionRange();
    if (range == null) return false;
    final root = table.resolveRoot(range.topRow, range.leftCol);
    final span = table.spanForRoot(root.$1, root.$2);
    if (span == null) return false;
    return root.$1 == range.topRow &&
        root.$2 == range.leftCol &&
        span.rowSpan == range.rowCount &&
        span.colSpan == range.colCount &&
        table.canUnmergeAt(root.$1, root.$2);
  }

  void _mergeSelectedCells() {
    final table = selectedDrawable;
    if (table is! TableDrawable) return;
    final range = _currentCellSelectionRange();
    if (range == null) return;
    if (!table.mergeRegion(
      range.topRow,
      range.leftCol,
      range.bottomRow,
      range.rightCol,
    )) {
      return;
    }
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    controller.notifyListeners();
    setState(() {
      _selectionAnchorCell = (range.topRow, range.leftCol);
      _selectionFocusCell = (range.bottomRow, range.rightCol);
    });
  }

  void _unmergeSelectedCells() {
    final table = selectedDrawable;
    if (table is! TableDrawable) return;
    final range = _currentCellSelectionRange();
    if (range == null) return;
    final root = table.resolveRoot(range.topRow, range.leftCol);
    if (!table.unmergeAt(root.$1, root.$2)) {
      return;
    }
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    controller.notifyListeners();
    setState(() {
      _selectionAnchorCell = (root.$1, root.$2);
      _selectionFocusCell = (root.$1, root.$2);
    });
  }
}

class _CellSelectionRange {
  final int topRow;
  final int leftCol;
  final int bottomRow;
  final int rightCol;

  const _CellSelectionRange(
    this.topRow,
    this.leftCol,
    this.bottomRow,
    this.rightCol,
  );

  int get rowCount => bottomRow - topRow + 1;
  int get colCount => rightCol - leftCol + 1;
  bool get isSingleCell => rowCount == 1 && colCount == 1;

  _CellSelectionRange union(_CellSelectionRange other) {
    return _CellSelectionRange(
      math.min(topRow, other.topRow),
      math.min(leftCol, other.leftCol),
      math.max(bottomRow, other.bottomRow),
      math.max(rightCol, other.rightCol),
    );
  }

  _CellSelectionRange clamp(int maxRows, int maxCols) {
    return _CellSelectionRange(
      topRow.clamp(0, maxRows - 1),
      leftCol.clamp(0, maxCols - 1),
      bottomRow.clamp(0, maxRows - 1),
      rightCol.clamp(0, maxCols - 1),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _CellSelectionRange &&
        other.topRow == topRow &&
        other.leftCol == leftCol &&
        other.bottomRow == bottomRow &&
        other.rightCol == rightCol;
  }

  @override
  int get hashCode => Object.hash(topRow, leftCol, bottomRow, rightCol);
}
