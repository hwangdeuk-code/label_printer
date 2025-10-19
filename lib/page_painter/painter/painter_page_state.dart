part of 'painter_page.dart';

class _PainterPageState extends State<PainterPage> {
  String appVersion = '';
  double scalePercent = 100.0;
  late final PainterController controller;
  final GlobalKey _painterKey = GlobalKey();

  tool.Tool currentTool = tool.Tool.select;

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
  double printerDpi = 203;
  double labelWidthMm = 80.0;
  double labelHeightMm = 60.0;

  double _mmToPixels(double mm) => (mm / 25.4) * printerDpi;

  Size get labelPixelSize =>
      Size(_mmToPixels(labelWidthMm), _mmToPixels(labelHeightMm));

  Offset clampToLabel(Offset point) {
    final Size size = labelPixelSize;
    return Offset(
      point.dx.clamp(0.0, size.width),
      point.dy.clamp(0.0, size.height),
    );
  }

  void updateLabelSpec({double? widthMm, double? heightMm, double? dpi}) {
    final double newWidth = widthMm ?? labelWidthMm;
    final double newHeight = heightMm ?? labelHeightMm;
    final double newDpi = dpi ?? printerDpi;
    debugPrint('Printer DPI: $newDpi');
    setState(() {
      labelWidthMm = newWidth;
      labelHeightMm = newHeight;
      printerDpi = newDpi;
    });
  }

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
  int? _editingInnerColIndex; // 내부 서브셀 편집 시 대상 내부 열 인덱스
  quill.QuillController? _quillController;
  List<dynamic>? _pendingQuillDeltaOps;

  final Map<Drawable, String> _drawableIds = {};
  final Map<Drawable, String> _pendingIdOverrides = {};
  List<Drawable> _previousDrawables = const [];
  int _idSequence = 0;
  bool _isDirty = false;
  String? _lastProjectPath; // 최근 저장/불러오기 경로
  String? _lastSavedSignature; // 마지막 저장/불러오기 시점의 장면 시그니처
  Timer? _sigTimer; // 시그니처 계산 디바운스 타이머

  bool _inspBold = false;
  bool _inspItalic = false;
  double _inspFontSize = 12.0;
  tool.TxtAlign _inspAlign = tool.TxtAlign.left;

  final FocusNode _quillFocus = FocusNode();
  bool _guardSelectionDuringInspector = false;
  // removed unused: _pendingSelectionRestore

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
    controller.freeStyleMode = FreeStyleMode.none;
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
      _scheduleSignatureRecompute();
    });
    _previousDrawables = List<Drawable>.from(controller.value.drawables);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          appVersion = info.version;
        });
      }
      // 최근 경로 로드
      try {
        _lastProjectPath = await UserPrefs.getLastProjectPath();
      } catch (_) {}
      // 초기 시그니처 계산(빈 장면 포함)으로 초기 dirty=false 보장
      await _recomputeSignature();
    });
  }

  @override
  void dispose() {
    _sigTimer?.cancel();
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

  // Safe wrapper for setState to be used by external helper functions.
  void safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

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

  // removed unused: _fillPaint

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

  // removed unused: _distanceToSegment

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

  // removed unused: _prepareOverrideId

  Future<void> _saveProject(BuildContext context) async {
    try {
      final initialDir = _lastProjectPath == null
          ? null
          : File(_lastProjectPath!).parent.path;
      final location = await getSaveLocation(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON', extensions: ['json']),
        ],
        initialDirectory: initialDir,
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
        labelWidthMm: labelWidthMm,
        labelHeightMm: labelHeightMm,
        objects: objects,
      );
      final path = location.path.endsWith('.json')
          ? location.path
          : '${location.path}.json';
      final file = File(path);
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(bundle));
      _lastProjectPath = file.path;
      // 최근 경로 저장
      try { await UserPrefs.setLastProjectPath(_lastProjectPath!); } catch (_) {}
      // 저장 후 시그니처 최신화
      _lastSavedSignature = await _computeSceneSignature();
      _isDirty = false;
      showSnackBar(context, '저장 완료: ${objects.length}개 객체');
    } catch (e, stack) {
      debugPrint('Save project error: $e\n$stack');
      showSnackBar(context, '저장 실패: $e', isError: true);
    }
  }

  Future<void> _loadProject(BuildContext context) async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON', extensions: ['json']),
        ],
        initialDirectory: _lastProjectPath == null
            ? null
            : File(_lastProjectPath!).parent.path,
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

      final double? savedDpi = (decoded['printerDpi'] as num?)?.toDouble();
      final double? savedWidthMm = (decoded['labelWidthMm'] as num?)
          ?.toDouble();
      final double? savedHeightMm = (decoded['labelHeightMm'] as num?)
          ?.toDouble();

      setState(() {
        if (savedDpi != null && savedDpi > 0) {
          printerDpi = savedDpi;
        }
        if (savedWidthMm != null && savedWidthMm > 0) {
          labelWidthMm = savedWidthMm;
        }
        if (savedHeightMm != null && savedHeightMm > 0) {
          labelHeightMm = savedHeightMm;
        }
      });

      int added = 0;
      for (final entry in objects) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        final result = await DrawableSerializer.fromJson(map);
        if (result == null) continue;
        final drawable = result.drawable;
        _pendingIdOverrides[drawable] = result.id;
        controller.addDrawables([drawable]);
        added++;
      }
      if (added > 0) {
        showSnackBar(context, '불러오기 완료: $added개 객체 추가');
      } else {
        showSnackBar(context, '불러온 객체가 없습니다.');
      }
      _lastProjectPath = file.path;
      try { await UserPrefs.setLastProjectPath(_lastProjectPath!); } catch (_) {}
      // 불러오기 후 시그니처 최신화
      _lastSavedSignature = await _computeSceneSignature();
      _isDirty = false; // 새로 로드된 상태를 기준으로 깨끗함
    } catch (e, stack) {
      debugPrint('Load project error: $e\n$stack');
        showSnackBar(context, '불러오기 실패: $e', isError: true);
    }
  }

  // removed unused: _rotateHandlePos

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

  Future<void> _showPrintDialog(BuildContext context) =>
      showPrintDialog(this, context);

  Future<void> _pickImageAndAdd() => pickImageAndAdd(this);

  void _goStartup(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage(fromLogout: true)),
      (route) => false,
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    // 변경사항이 없다면 다이얼로그 생략
    try {
      final sig = await _computeSceneSignature();
      // 그려진 객체가 하나도 없으면 변경 없음으로 간주
      if (sig.isEmpty) {
        _isDirty = false;
        _goStartup(context);
        return;
      }
      if (_lastSavedSignature != null && sig == _lastSavedSignature) {
        _isDirty = false;
        _goStartup(context);
        return;
      }
    } catch (_) {}

    final choice = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('작업 내용을 저장하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(0),
              child: const Text('취소'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(2),
              child: const Text('저장 안 함'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(1),
              child: const Text('저장 후 로그아웃'),
            ),
          ],
        );
      },
    );

    if (choice == 1) {
      // 저장 후 로그아웃
      await _saveProject(context);
      _goStartup(context);
    } else if (choice == 2) {
      // 저장하지 않고 로그아웃
      _goStartup(context);
    } else {
      // 취소 또는 닫힘
      return;
    }
  }

  // --- Dirty tracking helpers ---
  void _scheduleSignatureRecompute() {
    _sigTimer?.cancel();
    _sigTimer = Timer(const Duration(milliseconds: 250), () async {
      await _recomputeSignature();
    });
  }

  Future<void> _recomputeSignature() async {
    final sig = await _computeSceneSignature();
    if (!mounted) return;
    setState(() {
      _isDirty = _lastSavedSignature == null ? sig.isNotEmpty : (sig != _lastSavedSignature);
    });
  }

  Future<String> _computeSceneSignature() async {
    // 객체가 하나도 없으면 변경 없음으로 취급: 빈 문자열 반환
    if (controller.value.drawables.isEmpty) {
      return '';
    }
    // 저장 시와 동일한 구조의 bundle을 만들되 파일로 쓰지 않고 JSON 문자열로 비교합니다.
    final objects = <Map<String, dynamic>>[];
    for (final drawable in controller.value.drawables) {
      final id = _ensureDrawableId(drawable);
      final json = await DrawableSerializer.toJson(drawable, id);
      objects.add(json);
    }
    final bundle = DrawableSerializer.wrapScene(
      printerDpi: printerDpi,
      labelWidthMm: labelWidthMm,
      labelHeightMm: labelHeightMm,
      objects: objects,
    );
    // 공백 없는 인코딩으로 안정적인 비교
    return jsonEncode(bundle);
  }

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
