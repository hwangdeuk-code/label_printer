// ignore_for_file: invalid_use_of_protected_member, unnecessary_type_check, dead_code
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
            fontSize: 13.0,
            height: 1.2,
            color: Colors.black,
          );
          try {
            final row = state._editingCellRow!;
            final col = state._editingCellCol!;
            final inner = state._editingInnerColIndex;
            final style = inner != null
                ? state._editingTable!.internalStyleOf(row, col, inner)
                : state._editingTable!.styleOf(row, col);
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

          final customStyles = quill_helper.defaultStylesWithBaseFontSize(
            context,
            baseStyle.fontSize ?? 12.0,
          );

          return MediaQuery(
            data: mq.copyWith(textScaler: const TextScaler.linear(1.0)),
            child: DefaultTextStyle.merge(
              style: baseStyle,
              child: quill.QuillEditor.basic(
                controller: state._quillController!,
                focusNode: state._quillFocus,
                config: quill.QuillEditorConfig(
                  customStyles: customStyles,
                  scrollable: false,
                  padding: EdgeInsets.zero,
                ),
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

  final table = state._editingTable!;
  final row = state._editingCellRow!;
  final col = state._editingCellCol!;
  final inner = state._editingInnerColIndex; // null 또는 내부 인덱스
  final style = (inner != null)
      ? table.internalStyleOf(row, col, inner)
      : table.styleOf(row, col);
  final fallbackFontSize = (style['fontSize'] as double?) ?? 12.0;
  final sanitized = _ensureBaseFontSize(controller.document, fallbackFontSize);
  state._pendingQuillDeltaOps = sanitized.toDelta().toJson();
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
  final cellStyle = state._editingTable!.styleOf(row, col);
  final fallbackFontSize =
      (cellStyle['fontSize'] as double?) ?? state._inspFontSize;
  List<dynamic>? ops = state._pendingQuillDeltaOps;
  if (ops == null) {
    ops = state._quillController!.document.toDelta().toJson();
  }
  state._pendingQuillDeltaOps = null;

  quill.Document document;
  try {
    document = quill.Document.fromJson(ops.cast<dynamic>());
  } catch (_) {
    document = state._quillController!.document;
  }
  document = _ensureBaseFontSize(document, fallbackFontSize);
  final sanitizedOps = document.toDelta().toJson();

  final jsonStr = json.encode({"ops": sanitizedOps});
  if (state._editingInnerColIndex != null) {
    state._editingTable!.setInternalDeltaJson(
      row,
      col,
      state._editingInnerColIndex!,
      jsonStr,
    );
  } else {
    state._editingTable!.setDeltaJson(row, col, jsonStr);
  }

  final updatedFontSize = _lastContentFontSize(document) ?? fallbackFontSize;
  if (state._editingInnerColIndex != null) {
    state._editingTable!.setInternalStyle(
      row,
      col,
      state._editingInnerColIndex!,
      {'fontSize': updatedFontSize},
    );
  } else {
    final nextStyle = Map<String, dynamic>.from(cellStyle)
      ..['fontSize'] = updatedFontSize;
    state._editingTable!.setStyle(row, col, nextStyle);
  }
  state._inspFontSize = updatedFontSize;

  state.setState(() {
    try {
      state._editingTable?.endEdit();
    } catch (_) {}
    state._editingTable = null;
    state._editingCellRow = null;
    state._editingCellCol = null;
    state._inlineEditorRectScene = null;
    state._quillController = null;
    state._editingInnerColIndex = null;
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
  final cellStyle = drawable.styleOf(row, column);
  // 내부 서브셀 판정: 클릭한 위치가 내부 어느 서브셀인지 계산
  final innerFracs = drawable.internalFractionsOf(row, column);
  int? innerIndex;
  final merged = drawable.mergedWorldRect(row, column, drawable.size);
  Rect editorRect = merged;
  if (innerFracs != null && innerFracs.length >= 2) {
    double acc = merged.left;
    for (int i = 0; i < innerFracs.length; i++) {
      final w = merged.width * innerFracs[i];
      final sub = Rect.fromLTWH(acc, merged.top, w, merged.height);
      if (sub.contains(state._sceneFromGlobal(details.globalPosition))) {
        innerIndex = i;
        editorRect = sub;
        break;
      }
      acc += w;
    }
  } else {
    editorRect = merged;
  }
  // 패딩: 내부 서브셀 전용 패딩이 있으면 우선 사용
  final pad = (innerIndex != null)
      ? drawable.internalPaddingOf(row, column, innerIndex)
      : drawable.paddingOf(row, column);
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
  final jsonStr = innerIndex != null
      ? drawable.internalDeltaJsonOf(row, column, innerIndex)
      : drawable.cellDeltaJson[key];
  var document = _loadDocument(jsonStr);

  document = _ensureBaseFontSize(document, fallbackFontSize);
  final hasUserContent = _documentHasUserContent(document);
  final effectiveFontSize = hasUserContent
      ? (_lastContentFontSize(document) ?? fallbackFontSize)
      : fallbackFontSize;

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

  final bool cellBold = cellStyle['bold'] == true;
  final bool cellItalic = cellStyle['italic'] == true;
  final tool.TxtAlign cellAlign = _alignFromCellStyle(cellStyle['align']);

  if (!hasUserContent) {
    try {
      final controller = state._quillController!;
      final endOffset = controller.document.length;
      controller.updateSelection(
        TextSelection.collapsed(offset: endOffset),
        quill.ChangeSource.local,
      );
      controller.formatSelection(
        quill.Attribute.fromKeyValue(
          'size',
          effectiveFontSize.toStringAsFixed(0),
        ),
      );
      controller.formatSelection(
        cellBold
            ? quill.Attribute.bold
            : quill.Attribute.clone(quill.Attribute.bold, null),
      );
      controller.formatSelection(
        cellItalic
            ? quill.Attribute.italic
            : quill.Attribute.clone(quill.Attribute.italic, null),
      );
      controller.formatSelection(quill_helper.alignToAttr(cellAlign));
    } catch (_) {}
  }

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
    state._inspBold = cellBold;
    state._inspItalic = cellItalic;
    state._inspFontSize = effectiveFontSize;
    state._inspAlign = cellAlign;
    state._editingTable = drawable;
    state._editingCellRow = row;
    state._editingCellCol = column;
    state._editingInnerColIndex = innerIndex;
  });

  try {
    drawable.beginEdit(row, column);
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

bool _documentHasUserContent(quill.Document document) {
  final ops = document.toDelta().toJson();
  for (final op in ops) {
    if (op is! Map) continue;
    final insert = op['insert'];
    if (insert is String && insert.trim().isNotEmpty && insert != '\n') {
      return true;
    }
  }
  return false;
}

double? _lastContentFontSize(quill.Document document) {
  final ops = document.toDelta().toJson();
  for (var i = ops.length - 1; i >= 0; i--) {
    final op = ops[i];
    if (op is! Map) continue;
    final insert = op['insert'];
    if (insert is! String || insert.trim().isEmpty || insert == '\n') {
      continue;
    }
    final attrs = op['attributes'];
    if (attrs is Map && attrs.containsKey('size')) {
      final parsed = _parseSizeValue(attrs['size']);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

double? _parseSizeValue(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

tool.TxtAlign _alignFromCellStyle(dynamic align) {
  switch (align) {
    case 'center':
      return tool.TxtAlign.center;
    case 'right':
      return tool.TxtAlign.right;
    default:
      return tool.TxtAlign.left;
  }
}

