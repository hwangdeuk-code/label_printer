import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:label_printer/drawables/table_drawable.dart';

void main() {
  test(
    'Row insertion: inserting at first cell then at adjacent second cell increases rows',
    () {
      final t0 = TableDrawable(
        rows: 1,
        columns: 3,
        size: const Size(300, 100),
        position: const Offset(0, 0),
      );

      // Insert 2 rows at row 0
      final t1 = t0.splitRowsAt(0, 0, 2);
      expect(t1.rows, 3);

      // Insert again at adjacent cell (same top row, next column). Rows increase again.
      final t2 = t1.splitRowsAt(0, 1, 2);
      expect(t2.rows, 5);
    },
  );
}
