import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:label_printer/drawables/table_drawable.dart';
import 'package:label_printer/utils/drawable_serialization.dart';

void main() {
  group('TableDrawable internal subcells', () {
    test(
      'internal split, set/get data, and serialization round-trip',
      () async {
        // Create a simple 2x2 table
        final table = TableDrawable(
          rows: 2,
          columns: 2,
          size: const Size(200, 100),
          position: const Offset(0, 0),
        );

        // Split inside cell (0,0) into 3 internal columns
        final withSplit = table.splitColumnsInsideCell(0, 0, 3);
        expect(withSplit.internalColsCount(0, 0), 3);
        final fracs = withSplit.internalFractionsOf(0, 0)!;
        expect(fracs.length, 3);
        expect((fracs[0] + fracs[1] + fracs[2]).toStringAsFixed(6), '1.000000');

        // Set per-subcell delta/style/padding on index 1
        const delta = '{"ops":[{"insert":"Hello"}]}';
        withSplit.setInternalDeltaJson(0, 0, 1, delta);
        withSplit.setInternalStyle(0, 0, 1, {
          'bgColor': const Color(0xFFABCDEF).value,
          'fontSize': 18.0,
          'align': 'center',
          'bold': true,
        });
        withSplit.setInternalPadding(
          0,
          0,
          1,
          const CellPadding(top: 2, right: 3, bottom: 4, left: 5),
        );

        expect(withSplit.internalDeltaJsonOf(0, 0, 1), delta);
        final style = withSplit.internalStyleOf(0, 0, 1);
        expect(style['bgColor'], const Color(0xFFABCDEF).value);
        expect(style['fontSize'], 18.0);
        expect(style['align'], 'center');
        expect(style['bold'], true);
        final pad = withSplit.internalPaddingOf(0, 0, 1);
        expect(pad.top, 2);
        expect(pad.right, 3);
        expect(pad.bottom, 4);
        expect(pad.left, 5);

        // Serialize & deserialize
        final json = await DrawableSerializer.toJson(withSplit, 'tbl1');
        final result = await DrawableSerializer.fromJson(json);
        expect(result, isNotNull);
        expect(result!.id, 'tbl1');
        expect(result.drawable, isA<TableDrawable>());
        final round = result.drawable as TableDrawable;

        expect(round.internalColsCount(0, 0), 3);
        final fr2 = round.internalFractionsOf(0, 0)!;
        expect(fr2.length, 3);
        expect((fr2[0] + fr2[1] + fr2[2]).toStringAsFixed(6), '1.000000');
        expect(round.internalDeltaJsonOf(0, 0, 1), delta);
        final style2 = round.internalStyleOf(0, 0, 1);
        expect(style2['bgColor'], const Color(0xFFABCDEF).value);
        expect(style2['fontSize'], 18.0);
        expect(style2['align'], 'center');
        expect(style2['bold'], true);
        final pad2 = round.internalPaddingOf(0, 0, 1);
        expect(pad2.top, 2);
        expect(pad2.right, 3);
        expect(pad2.bottom, 4);
        expect(pad2.left, 5);
      },
    );
  });
}
