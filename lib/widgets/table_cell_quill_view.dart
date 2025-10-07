import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../helpers/quill_helpers.dart' as quill_helper;

class TableCellQuillView extends StatelessWidget {
  final String? deltaJson;
  final double maxWidth;
  final TextAlign textAlign;
  final double fontSize;
  final bool bold;
  final bool italic;

  const TableCellQuillView({
    super.key,
    required this.deltaJson,
    required this.maxWidth,
    this.textAlign = TextAlign.left,
    this.fontSize = 12.0,
    this.bold = false,
    this.italic = false,
  });

  quill.Document _doc() {
    if (deltaJson == null || deltaJson!.isEmpty) return quill.Document();
    final decoded = json.decode(deltaJson!);
    if (decoded is List) {
      return quill.Document.fromJson(decoded as List);
    } else if (decoded is Map && decoded['ops'] is List) {
      return quill.Document.fromJson(decoded['ops'] as List);
    }
    return quill.Document();
  }

  @override
  Widget build(BuildContext context) {
    final controller = quill.QuillController(
      document: _doc(),
      selection: const TextSelection.collapsed(offset: 0),
    );
    final customStyles =
        quill_helper.defaultStylesWithBaseFontSize(context, fontSize);
    final baseStyle = TextStyle(
      fontSize: fontSize,
      height: 1.2,
      color: Colors.black,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    );
    return IgnorePointer(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DefaultTextStyle(
          style: baseStyle,
          textAlign: textAlign,
          child: quill.QuillEditor.basic(
            controller: controller,
            config: quill.QuillEditorConfig(
              customStyles: customStyles,
              enableInteractiveSelection: false,
              scrollable: false,
              expands: false,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}
