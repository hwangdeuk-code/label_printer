part of 'painter_page.dart';

Widget? buildInlineEditor(_PainterPageState state) {
  if (state._editingTable == null ||
      state._editingCellRow == null ||
      state._editingCellCol == null ||
      state._quillController == null ||
      state._inlineEditorRectScene == null) {
    return null;
  }

  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.blueAccent, width: 1),
    ),
    child: FocusScope(
      child: Builder(
        builder: (context) {
          final mq = MediaQuery.of(context);
          TextStyle baseStyle = const TextStyle(
            fontSize: 12.0,
            height: 1.2,
            color: Colors.black,
          );
          try {
            final style = state._editingTable!.styleOf(
              state._editingCellRow!,
              state._editingCellCol!,
            );
            baseStyle = TextStyle(
              fontSize: (style['fontSize'] as double?) ?? 12.0,
              fontWeight: style['bold'] == true
                  ? FontWeight.bold
                  : FontWeight.normal,
              fontStyle: style['italic'] == true
                  ? FontStyle.italic
                  : FontStyle.normal,
              height: 1.2,
              color: Colors.black,
            );
          } catch (_) {}

          return MediaQuery(
            data: mq.copyWith(textScaler: const TextScaler.linear(1.0)),
            child: DefaultTextStyle.merge(
              style: baseStyle,
              child: quill.QuillEditor.basic(
                controller: state._quillController!,
                focusNode: state._quillFocus,
              ),
            ),
          );
        },
      ),
    ),
  );
}

void persistInlineDelta(_PainterPageState state) {
  final controller = state._quillController;
  if (state._editingTable == null ||
      state._editingCellRow == null ||
      state._editingCellCol == null ||
      controller == null) {
    return;
  }

  state._pendingQuillDeltaOps = controller.document.toDelta().toJson();
}

void commitInlineEditor(_PainterPageState state) {
  try {
    state._inlineEditor?.remove();
  } catch (_) {}
  try {
    state._inlineEditorEntry?.remove();
  } catch (_) {}
  try {
    state._editorOverlay?.remove();
  } catch (_) {}

  if (state._editingTable == null ||
      state._editingCellRow == null ||
      state._editingCellCol == null ||
      state._quillController == null) {
    return;
  }

  final row = state._editingCellRow!;
  final col = state._editingCellCol!;
  List<dynamic>? ops = state._pendingQuillDeltaOps;
  if (ops == null) {
    ops = state._quillController!.document.toDelta().toJson();
  }
  state._pendingQuillDeltaOps = null;

  final jsonStr = json.encode({"ops": ops});
  state._editingTable!.setDeltaJson(row, col, jsonStr);

  state.setState(() {
    try {
      state._editingTable?.endEdit();
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      state.controller.notifyListeners();
    } catch (_) {}
    state._editingTable = null;
    state._editingCellRow = null;
    state._editingCellCol = null;
    state._inlineEditorRectScene = null;
    state._quillController = null;
    state._clearCellSelection();
  });
}

void handleCanvasDoubleTapDown(
  _PainterPageState state,
  TapDownDetails details,
) {
  if (state._quillController != null) {
    state._commitInlineEditor();
  }

  final scenePoint = state._sceneFromGlobal(details.globalPosition);
  final drawable = state._pickTopAt(scenePoint);
  if (drawable is! TableDrawable) return;

  state._pendingQuillDeltaOps = null;

  final local = state._toLocal(
    scenePoint,
    drawable.position,
    drawable.rotationAngle,
  );
  final scaledSize = drawable.size;
  final rect = Rect.fromCenter(
    center: Offset.zero,
    width: scaledSize.width,
    height: scaledSize.height,
  );
  if (!rect.contains(local)) return;

  var x = rect.left;
  var column = 0;
  for (var c = 0; c < drawable.columns; c++) {
    final double width = c < drawable.columnFractions.length
        ? rect.width * drawable.columnFractions[c]
        : rect.right - x;
    final double right = (c == drawable.columns - 1) ? rect.right : x + width;
    if (local.dx >= x && local.dx <= right) {
      column = c;
      break;
    }
    x = right;
  }

  final rowHeight = rect.height / drawable.rows;
  var row = ((local.dy - rect.top) / rowHeight).floor();
  row = row.clamp(0, drawable.rows - 1);

  final root = drawable.resolveRoot(row, column);
  row = root.$1;
  column = root.$2;
  final editorRect = drawable.mergedWorldRect(row, column, drawable.size);
  final pad = drawable.paddingOf(row, column);
  final cellStyle = drawable.styleOf(row, column);
  final fallbackFontSize = (cellStyle['fontSize'] as double?) ?? 12.0;
  final paddedEditorRect = Rect.fromLTRB(
    editorRect.left + pad.left,
    editorRect.top + pad.top,
    editorRect.right - pad.right,
    editorRect.bottom - pad.bottom,
  );
  state._inlineEditorRectScene =
      paddedEditorRect.width > 1 && paddedEditorRect.height > 1
      ? paddedEditorRect
      : editorRect;

  final key = '$row,$column';
  final jsonStr = drawable.cellDeltaJson[key];
  var document = _loadDocument(jsonStr);

  document = _ensureBaseFontSize(document, fallbackFontSize);

  state._quillController = quill.QuillController(
    document: document,
    selection: const TextSelection.collapsed(offset: 0),
  );

  try {
    state._quillController!.updateSelection(
      const TextSelection.collapsed(offset: 0),
      quill.ChangeSource.local,
    );
  } catch (_) {}

  state.setState(() {
    final selectionRange = state._rangeForCell(drawable, row, column);
    state._selectionAnchorCell = (
      selectionRange.topRow,
      selectionRange.leftCol,
    );
    state._selectionFocusCell = (
      selectionRange.bottomRow,
      selectionRange.rightCol,
    );
    state._editingTable = drawable;
    state._editingCellRow = row;
    state._editingCellCol = column;
  });

  try {
    drawable.beginEdit(row, column);
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    state.controller.notifyListeners();
  } catch (_) {}

  WidgetsBinding.instance.addPostFrameCallback((_) {
    state._quillFocus.requestFocus();
    try {
      final length = state._quillController?.document.length ?? 0;
      state._quillController?.updateSelection(
        TextSelection.collapsed(offset: length),
        quill.ChangeSource.local,
      );
    } catch (_) {}
  });
}

quill.Document _ensureBaseFontSize(quill.Document document, double fallback) {
  final ops = document.toDelta().toJson();
  bool mutated = false;
  for (final op in ops) {
    if (op is! Map) continue;
    final insert = op['insert'];
    if (insert is! String || insert == '\n') continue;
    Map<String, dynamic> attrs;
    if (op['attributes'] is Map) {
      attrs = Map<String, dynamic>.from(op['attributes'] as Map);
    } else {
      attrs = <String, dynamic>{};
    }
    if (!attrs.containsKey('size')) {
      attrs['size'] = fallback.toStringAsFixed(0);
      op['attributes'] = attrs;
      mutated = true;
    }
  }
  if (!mutated) return document;
  return quill.Document.fromJson(ops.cast<dynamic>());
}

quill.Document _loadDocument(String? jsonStr) {
  if (jsonStr == null || jsonStr.trim().isEmpty) {
    return quill.Document();
  }
  try {
    final decoded = json.decode(jsonStr);
    final ops = (decoded is Map<String, dynamic>) ? decoded['ops'] : null;
    if (ops is List && ops.isNotEmpty) {
      return quill.Document.fromJson(ops.cast<dynamic>());
    }
  } catch (_) {}
  return quill.Document();
}
