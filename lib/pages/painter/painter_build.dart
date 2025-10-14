// ignore_for_file: invalid_use_of_protected_member
part of 'painter_page.dart';

Widget buildPainterScaffold(_PainterPageState state, BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('$appTitle v${state.appVersion}'),
      actions: [
        const DbConnectionStatusIcon(),
        IconButton(
          onPressed: () => state._confirmLogout(context),
          icon: const Icon(Icons.logout),
          tooltip: '로그아웃',
        ),
        IconButton(
          onPressed: state.controller.canUndo ? state.controller.undo : null,
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          onPressed: state.controller.canRedo ? state.controller.redo : null,
          icon: const Icon(Icons.redo),
        ),
        IconButton(
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const LoginHistoryPage()));
          },
          icon: const Icon(Icons.history),
          tooltip: '로그인 이력',
        ),
        IconButton(
          onPressed: state._clearAll,
          icon: const Icon(Icons.layers_clear),
          tooltip: 'Clear',
        ),
        IconButton(
          onPressed: state._isDirty ? () => state._saveProject(context) : null,
          icon: const Icon(Icons.save),
          tooltip: 'Save Project',
        ),
        IconButton(
          onPressed: () => state._loadProject(context),
          icon: const Icon(Icons.folder_open),
          tooltip: 'Load Project',
        ),
        IconButton(
          onPressed: () => state._showPrintDialog(context),
          icon: const Icon(Icons.print),
          tooltip: 'Print Label',
        ),
        IconButton(
          onPressed: () => state._saveAsPng(context),
          icon: const Icon(Icons.save_alt),
        ),
      ],
    ),
    body: buildPainterBody(state, context),
  );
}

Widget buildPainterBody(_PainterPageState state, BuildContext context) {
  final tableDrawable = state.selectedDrawable is TableDrawable
      ? state.selectedDrawable as TableDrawable
      : null;
  final canMergeCells = tableDrawable != null && state._canMergeCells;
  final canUnmergeCells = tableDrawable != null && state._canUnmergeCells;
  final range = tableDrawable != null
      ? state._currentCellSelectionRange()
      : null;
  return KeyboardListener(
    focusNode: state._keyboardFocus,
    autofocus: true,
    onKeyEvent: (event) {
      final isShift = HardwareKeyboard.instance.isShiftPressed;
      if (isShift != state._isShiftPressed) {
        state.setState(() {
          state._isShiftPressed = isShift;
        });
      }
      // 내부 서브셀 좌/우 화살표 이동 (단일 셀 + 내부 분할 시)
      if (event is KeyDownEvent &&
          (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.arrowRight)) {
        final td = tableDrawable;
        final focus = state._selectionFocusCell;
        if (td != null && focus != null) {
          final count = td.internalColsCount(focus.$1, focus.$2);
          if (count >= 2) {
            final dir = event.logicalKey == LogicalKeyboardKey.arrowLeft
                ? -1
                : 1;
            final cur = state._editingInnerColIndex ?? 0;
            final next = (cur + dir) % count < 0
                ? (cur + dir + count) % count
                : (cur + dir) % count;
            state.setState(() {
              state._editingInnerColIndex = next;
            });
          }
        }
      }
    },
    child: Row(
      children: [
        ToolPanel(
          currentTool: state.currentTool,
          onToolSelected: state._setTool,
          onTableCreate: state._handleTableInsert,
          strokeColor: state.strokeColor,
          onStrokeColorChanged: (color) {
            state.setState(() {
              state.strokeColor = color;
              state.controller.freeStyleColor = state.strokeColor;
            });
          },
          strokeWidth: state.strokeWidth,
          onStrokeWidthChanged: (value) {
            state.setState(() {
              state.strokeWidth = value;
              state.controller.freeStyleStrokeWidth = value;
            });
          },
          fillColor: state.fillColor,
          onFillColorChanged: (color) =>
              state.setState(() => state.fillColor = color),
          lockRatio: state.lockRatio,
          onLockRatioChanged: (value) =>
              state.setState(() => state.lockRatio = value),
          angleSnap: state.angleSnap,
          onAngleSnapChanged: (value) =>
              state.setState(() => state.angleSnap = value),
          endpointDragRotates: state.endpointDragRotates,
          onEndpointDragRotatesChanged: (value) =>
              state.setState(() => state.endpointDragRotates = value),
          textFontSize: state.textFontSize,
          onTextFontSizeChanged: (value) =>
              state.setState(() => state.textFontSize = value),
          textBold: state.textBold,
          onTextBoldChanged: (value) =>
              state.setState(() => state.textBold = value),
          textItalic: state.textItalic,
          onTextItalicChanged: (value) =>
              state.setState(() => state.textItalic = value),
          textFontFamily: state.textFontFamily,
          onTextFontFamilyChanged: (value) =>
              state.setState(() => state.textFontFamily = value),
          defaultTextAlign: state.defaultTextAlign,
          onDefaultTextAlignChanged: (value) =>
              state.setState(() => state.defaultTextAlign = value),
          defaultTextMaxWidth: state.defaultTextMaxWidth,
          onDefaultTextMaxWidthChanged: (value) =>
              state.setState(() => state.defaultTextMaxWidth = value),
          barcodeData: state.barcodeData,
          onBarcodeDataChanged: (value) =>
              state.setState(() => state.barcodeData = value),
          barcodeType: state.barcodeType,
          onBarcodeTypeChanged: (value) =>
              state.setState(() => state.barcodeType = value),
          barcodeShowValue: state.barcodeShowValue,
          onBarcodeShowValueChanged: (value) =>
              state.setState(() => state.barcodeShowValue = value),
          barcodeFontSize: state.barcodeFontSize,
          onBarcodeFontSizeChanged: (value) =>
              state.setState(() => state.barcodeFontSize = value),
          barcodeForeground: state.barcodeForeground,
          onBarcodeForegroundChanged: (color) =>
              state.setState(() => state.barcodeForeground = color),
          barcodeBackground: state.barcodeBackground,
          onBarcodeBackgroundChanged: (color) =>
              state.setState(() => state.barcodeBackground = color),
          scalePercent: state.scalePercent,
          onScalePercentChanged: (value) =>
              state.setState(() => state.scalePercent = value),
          labelWidthMm: state.labelWidthMm,
          labelHeightMm: state.labelHeightMm,
          onLabelWidthChanged: (value) => state.updateLabelSpec(widthMm: value),
          onLabelHeightChanged: (value) =>
              state.updateLabelSpec(heightMm: value),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: CanvasArea(
            currentTool: state.currentTool,
            controller: state.controller,
            painterKey: state._painterKey,
            onPointerDownSelect: state._handlePointerDownSelect,
            onCanvasTap: state._handleCanvasTap,
            onCanvasDoubleTapDown: state._handleCanvasDoubleTapDown,
            inlineEditorRect: state._inlineEditorRectScene,
            inlineEditor: state._buildInlineEditor(),
            onOverlayPanStart: state._onOverlayPanStart,
            onOverlayPanUpdate: state._onOverlayPanUpdate,
            onOverlayPanEnd: state._onOverlayPanEnd,
            onCreatePanStart: state._onPanStartCreate,
            onCreatePanUpdate: state._onPanUpdateCreate,
            onCreatePanEnd: state._onPanEndCreate,
            selectedDrawable: state.selectedDrawable,
            selectionBounds: state.selectedDrawable == null
                ? null
                : state._boundsOf(state.selectedDrawable!),
            selectionAnchorCell: state._selectionAnchorCell,
            selectionFocusCell: state._selectionFocusCell,
            selectionStart:
                state.selectedDrawable is LineDrawable ||
                    state.selectedDrawable is ArrowDrawable
                ? state._lineStart(state.selectedDrawable!)
                : null,
            selectionEnd:
                state.selectedDrawable is LineDrawable ||
                    state.selectedDrawable is ArrowDrawable
                ? state._lineEnd(state.selectedDrawable!)
                : null,
            handleSize: state.handleSize,
            rotateHandleOffset: state.rotateHandleOffset,
            showEndpoints:
                state.selectedDrawable is LineDrawable ||
                state.selectedDrawable is ArrowDrawable,
            isTextSelected:
                state.selectedDrawable is ConstrainedTextDrawable ||
                state.selectedDrawable is TextDrawable,
            isEditingCell: state._quillController != null,
            printerDpi: state.printerDpi,
            scalePercent: state.scalePercent,
            labelPixelSize: state.labelPixelSize,
          ),
        ),
        const VerticalDivider(width: 1),
        InspectorPanel(
          selected: state.selectedDrawable,
          printerDpi: state.printerDpi,
          selectionFocusCell: state._selectionFocusCell,
          cellSelectionRange: range == null
              ? null
              : (
                  topRow: range.topRow,
                  leftCol: range.leftCol,
                  bottomRow: range.bottomRow,
                  rightCol: range.rightCol,
                ),
          // 내부 서브셀 선택기 연결
          currentInnerSubcellIndex: (() {
            final td = tableDrawable;
            final focus = state._selectionFocusCell;
            if (td == null || focus == null) return null;
            // 편집 중 인덱스가 있으면 그대로, 없으면 null(셀 전체)
            return state._editingInnerColIndex;
          })(),
          innerSubcellCount: (() {
            final td = tableDrawable;
            final focus = state._selectionFocusCell;
            if (td == null || focus == null) return null;
            return td.internalColsCount(focus.$1, focus.$2);
          })(),
          onChangeInnerSubcellIndex: (idx) {
            // 인덱스 상태만 반영(인라인 에디터 진입 없이 스타일 패널이 이 인덱스를 대상으로 동작)
            state.setState(() {
              state._editingInnerColIndex = idx;
            });
          },
          strokeWidth: state.strokeWidth,
          onApplyStroke: state._applyInspector,
          onReplaceDrawable: (original, replacement) {
            final adjusted = adjustInsideAllowed(
              state,
              replacement,
              inset: 1.0,
            );
            state.controller.replaceDrawable(original, adjusted);
            state.setState(() => state.selectedDrawable = adjusted);
          },
          angleSnap: state.angleSnap,
          snapAngle: state._snapAngle,
          textDefaults: TextDefaults(
            fontFamily: state.textFontFamily,
            fontSize: state.textFontSize,
            bold: state.textBold,
            italic: state.textItalic,
            align: state.defaultTextAlign,
            maxWidth: state.defaultTextMaxWidth,
          ),
          mutateSelected: (rewriter) {
            final current = state.selectedDrawable;
            if (current == null) return;
            final replacement = rewriter(current);
            if (identical(replacement, current)) return;
            final adjusted = adjustInsideAllowed(
              state,
              replacement,
              inset: 1.0,
            );
            state.controller.replaceDrawable(current, adjusted);
            state.setState(() => state.selectedDrawable = adjusted);
          },
          showCellQuillSection:
              state._editingTable != null &&
              state._editingCellRow != null &&
              state._editingCellCol != null,
          canMergeCells: canMergeCells,
          canUnmergeCells: canUnmergeCells,
          onMergeCells: canMergeCells ? state._mergeSelectedCells : null,
          onUnmergeCells: canUnmergeCells ? state._unmergeSelectedCells : null,
          quillBold: state._inspBold,
          quillItalic: state._inspItalic,
          quillFontSize: state._inspFontSize,
          quillAlign: state._inspAlign,
          onQuillStyleChanged:
              ({
                bool? bold,
                bool? italic,
                double? fontSize,
                tool.TxtAlign? align,
              }) {
                final table = state._editingTable;
                final row = state._editingCellRow;
                final col = state._editingCellCol;
                // 편집 중이면 그 인덱스, 아니면 인스펙터 선택자 값 사용
                final inner = state._editingInnerColIndex;
                if (table == null || row == null || col == null) return;

                state._guardSelectionDuringInspector = true;
                state._suppressCommitOnce = true;
                state._inspectorGuardTimer?.cancel();
                try {
                  if (bold != null) state._inspBold = bold;
                  if (italic != null) state._inspItalic = italic;
                  if (fontSize != null) state._inspFontSize = fontSize;
                  if (align != null) state._inspAlign = align;

                  final current = inner != null
                      ? table.internalStyleOf(row, col, inner)
                      : table.styleOf(row, col);
                  final updated = <String, dynamic>{
                    'bold': current['bold'],
                    'italic': current['italic'],
                    'fontSize': current['fontSize'],
                    'align': current['align'],
                  };

                  final controller = state._quillController;
                  final isInlineEditing = controller != null;

                  if (!isInlineEditing) {
                    if (bold != null) updated['bold'] = bold;
                    if (italic != null) updated['italic'] = italic;
                    if (fontSize != null) updated['fontSize'] = fontSize;
                  }

                  final effectiveAlign =
                      align ??
                      (current['align'] as String == 'center'
                          ? tool.TxtAlign.center
                          : (current['align'] as String == 'right'
                                ? tool.TxtAlign.right
                                : tool.TxtAlign.left));
                  updated['align'] = effectiveAlign == tool.TxtAlign.center
                      ? 'center'
                      : (effectiveAlign == tool.TxtAlign.right
                            ? 'right'
                            : 'left');
                  if (inner != null) {
                    table.setInternalStyle(row, col, inner, updated);
                  } else {
                    table.setStyle(row, col, updated);
                  }

                  if (controller != null) {
                    if (bold != null) {
                      controller.formatSelection(
                        bold
                            ? quill.Attribute.bold
                            : quill.Attribute.clone(quill.Attribute.bold, null),
                      );
                    }
                    if (italic != null) {
                      controller.formatSelection(
                        italic
                            ? quill.Attribute.italic
                            : quill.Attribute.clone(
                                quill.Attribute.italic,
                                null,
                              ),
                      );
                    }
                    if (fontSize != null) {
                      controller.formatSelection(
                        quill.Attribute.fromKeyValue(
                          'size',
                          fontSize.toStringAsFixed(0),
                        ),
                      );
                    }
                    if (align != null) {
                      final attr = align == tool.TxtAlign.center
                          ? quill.Attribute.centerAlignment
                          : (align == tool.TxtAlign.right
                                ? quill.Attribute.rightAlignment
                                : quill.Attribute.leftAlignment);
                      controller.formatSelection(attr);
                    }
                  }

                  try {
                    state._persistInlineDelta();
                  } catch (_) {}
                } finally {
                  state._inspectorGuardTimer = Timer(
                    const Duration(milliseconds: 300),
                    () {
                      state._guardSelectionDuringInspector = false;
                      state._suppressCommitOnce = false;
                    },
                  );
                }
              },
        ),
      ],
    ),
  );
}
