import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class TableCellQuillView extends StatelessWidget {
  final String? deltaJson;
  final double maxWidth;
  final TextAlign textAlign;

  const TableCellQuillView({
    super.key,
    required this.deltaJson,
    required this.maxWidth,
    this.textAlign = TextAlign.left,
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
    return IgnorePointer(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: quill.QuillEditor.basic(
          controller: controller,
        ),
      ),
    );
  }
}
