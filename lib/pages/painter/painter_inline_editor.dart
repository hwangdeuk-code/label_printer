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
          var fontSize = 12.0;
          try {
            final style = state._editingTable!.styleOf(state._editingCellRow!, state._editingCellCol!);
            fontSize = style['fontSize'] as double;
          } catch (_) {}

          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: const TextScaler.linear(1.0)),
            child: DefaultTextStyle.merge(
              style: TextStyle(fontSize: fontSize),
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
  if (state._editingTable == null ||
      state._editingCellRow == null ||
      state._editingCellCol == null ||
      state._quillController == null) {
    return;
  }

  final row = state._editingCellRow!;
  final col = state._editingCellCol!;
  try {
    final delta = state._quillController!.document.toDelta().toJson();
    final jsonStr = json.encode({"ops": delta});
    state._editingTable!.setDeltaJson(row, col, jsonStr);
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    state.controller.notifyListeners();
  } catch (_) {
    // persistence failure should not break UX
  }
}

void commitInlineEditor(_PainterPageState state) {
  try {
    state._quillController?.updateSelection(
      const TextSelection.collapsed(offset: 0),
      quill.ChangeSource.local,
    );
  } catch (_) {}

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
  final delta = state._quillController!.document.toDelta().toJson();
  final jsonStr = json.encode({"ops": delta});
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

void handleCanvasDoubleTapDown(_PainterPageState state, TapDownDetails details) {
  if (state._quillController != null) {
    state._commitInlineEditor();
  }

  final scenePoint = state._sceneFromGlobal(details.globalPosition);
  final drawable = state._pickTopAt(scenePoint);
  if (drawable is! TableDrawable) return;

  final local = state._toLocal(scenePoint, drawable.position, drawable.rotationAngle);
  final scaledSize = drawable.size;
  final rect = Rect.fromCenter(
    center: Offset.zero,
    width: scaledSize.width,
    height: scaledSize.height,
  );
  if (!rect.contains(local)) return;

  final columnFractions = drawable.columnFractions;
  final columnWidths = <double>[];
  for (final fraction in columnFractions) {
    columnWidths.add(rect.width * fraction);
  }

  var x = rect.left;
  var column = 0;
  for (var c = 0; c < columnWidths.length; c++) {
    final left = x;
    final right = x + columnWidths[c];
    if (local.dx >= left && local.dx <= right) {
      column = c;
      break;
    }
    x += columnWidths[c];
  }

  final rowHeight = rect.height / drawable.rows;
  final row = ((local.dy - rect.top) / rowHeight).floor().clamp(0, drawable.rows - 1);

  final cellLocal = drawable.localCellRect(row, column, scaledSize);
  final topLeftLocal = Offset(cellLocal.left, cellLocal.top);
  final sceneTopLeft = drawable.position + Offset(
    math.cos(drawable.rotationAngle) * topLeftLocal.dx -
        math.sin(drawable.rotationAngle) * topLeftLocal.dy,
    math.sin(drawable.rotationAngle) * topLeftLocal.dx +
        math.cos(drawable.rotationAngle) * topLeftLocal.dy,
  );
  state._inlineEditorRectScene = Rect.fromLTWH(
    sceneTopLeft.dx,
    sceneTopLeft.dy,
    cellLocal.width,
    cellLocal.height,
  );

  final key = '$row,$column';
  final jsonStr = drawable.cellDeltaJson[key];
  final document = (jsonStr != null && jsonStr.isNotEmpty)
      ? quill.Document.fromJson(
          (json.decode(jsonStr) as Map<String, dynamic>)['ops'] as List<dynamic>,
        )
      : quill.Document.fromJson([
          {
            'insert': '\n',
            'attributes': {
              'size':
                  (drawable.styleOf(row, column)['fontSize'] as double).toInt().toString(),
            }
          }
        ]);

  state._quillController = quill.QuillController(
    document: document,
    selection: const TextSelection.collapsed(offset: 0),
  );

  try {
    final style = drawable.styleOf(row, column);
    final fontSize = style['fontSize'] as double;
    final length = state._quillController!.document.length;
    state._quillController!.updateSelection(
      TextSelection(baseOffset: 0, extentOffset: length),
      quill.ChangeSource.local,
    );
    state._quillController!.formatSelection(
      quill.Attribute.fromKeyValue('size', fontSize.toStringAsFixed(0)),
    );
    state._quillController!.updateSelection(
      TextSelection.collapsed(offset: length),
      quill.ChangeSource.local,
    );
  } catch (_) {}

  state.setState(() {
    state._selectionAnchorCell = (row, column);
    state._selectionFocusCell = (row, column);
    state._editingTable = drawable;
    state._editingCellRow = row;
    state._editingCellCol = column;
    try {
      final style = drawable.styleOf(row, column);
      state._inspBold = style['bold'] as bool;
      state._inspItalic = style['italic'] as bool;
      state._inspFontSize = style['fontSize'] as double;
      final align = style['align'] as String;
      state._inspAlign = align == 'center'
          ? tool.TxtAlign.center
          : (align == 'right' ? tool.TxtAlign.right : tool.TxtAlign.left);
    } catch (_) {}
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
