import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../flutter_painter_v2/flutter_painter.dart';
import '../drawables/table_drawable.dart';
import 'table_cell_quill_view.dart';

class TableQuillOverlayLayer extends StatelessWidget {
  final PainterController controller;
  final double scalePercent;

  const TableQuillOverlayLayer({
    super.key,
    required this.controller,
    required this.scalePercent,
  });

  List<double> _normalize(List<double> input, int columns) {
    if (columns <= 0) return const <double>[];
    final List<double> w = input.length >= columns ? input.take(columns).toList() : [...input];
    while (w.length < columns) w.add(1.0);
    double sum = 0.0;
    for (final v in w) {
      if (v.isFinite && v > 0) sum += v;
    }
    if (sum <= 0) return List<double>.filled(columns, 1.0 / columns);
    return w.map((v) => (v.isFinite && v > 0) ? v / sum : 0.0).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> stackChildren = <Widget>[];

    for (final d in controller.drawables) {
      if (d is! TableDrawable) continue;
      final table = d as TableDrawable;

      final rect = Rect.fromCenter(center: table.position, width: table.size.width, height: table.size.height);
      final weights = _normalize(table.columnFractions, table.columns);
      final rowH = rect.height / math.max(1, table.rows);

      for (int r = 0; r < table.rows; r++) {
        double cx = rect.left;
        for (int c = 0; c < table.columns; c++) {
          final cw = rect.width * weights[c];
          final cellRect = Rect.fromLTWH(cx, rect.top + r * rowH, cw, rowH).deflate(4);
          final key = "$r,$c";
          final delta = table.cellDeltaJson[key];
          final alignStr = (table.styleOf(r, c)['align'] as String?) ?? 'left';
          final TextAlign ta = alignStr == 'center'
              ? TextAlign.center
              : (alignStr == 'right' ? TextAlign.right : TextAlign.left);

          stackChildren.add(Positioned(
            left: cellRect.left,
            top: cellRect.top,
            width: cellRect.width,
            height: cellRect.height,
            child: TableCellQuillView(
              deltaJson: delta,
              maxWidth: cellRect.width,
              textAlign: ta,
            ),
          ));

          cx += cw;
        }
      }
    }

    return IgnorePointer(
      child: Stack(children: stackChildren),
    );
  }
}
