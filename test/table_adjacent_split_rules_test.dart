import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:label_printer/drawables/table_drawable.dart';

void main() {
  test(
    'Row insertion: adjacent insertion stacks below, increasing total rows',
    () {
      final td0 = TableDrawable(
        rows: 1,
        columns: 4,
        size: const Size(200, 100),
        position: const Offset(0, 0),
      );

      // First insert 2 rows at (0,0)
      final td1 = td0.splitRowsAt(0, 0, 2);
      expect(td1.rows, 3);

      // Adjacent insert adds two more rows
      final td2 = td1.splitRowsAt(0, 1, 2);
      expect(td2.rows, 5);
    },
  );
}
