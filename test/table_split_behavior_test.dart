import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:label_printer/drawables/table_drawable.dart';

void main() {
  group('TableDrawable split behavior', () {
    test(
      'Row-split then adjacent column-split should only change columns (rows unchanged)',
      () {
        final td0 = TableDrawable(
          rows: 2,
          columns: 2,
          size: const Size(200, 100),
          position: const Offset(0, 0),
        );

        // 1) Insert 2 rows at (0,0) => rows increase by 2 (insertion semantics)
        final td1 = td0.splitRowsAt(0, 0, 2);
        expect(td1.rows, 4);
        expect(td1.columns, 2);

        // 2) Split adjacent cell (same top row, next column) into 2 columns
        final td2 = td1.splitColumnsAt(0, 1, 2);

        // Row count must remain the same; only columns increase by 1
        expect(td2.rows, td1.rows);
        expect(td2.columns, td1.columns + 1);
      },
    );
  });
}
