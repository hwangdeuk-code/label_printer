import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:barcode/barcode.dart';

import '../drawables/constrained_text_drawable.dart';
import '../drawables/barcode_drawable.dart';
import '../flutter_painter_v2/flutter_painter.dart';
import '../models/tool.dart';
import 'color_dot.dart';

class TextDefaults {
  const TextDefaults({
    required this.fontFamily,
    required this.fontSize,
    required this.bold,
    required this.italic,
    required this.align,
    required this.maxWidth,
  });

  final String fontFamily;
  final double fontSize;
  final bool bold;
  final bool italic;
  final TxtAlign align;
  final double maxWidth;
}

class InspectorPanel extends StatelessWidget {
  const InspectorPanel({
    super.key,
    required this.selected,
    required this.strokeWidth,
    required this.onApplyStroke,
    required this.onReplaceDrawable,
    required this.angleSnap,
    required this.snapAngle,
    required this.textDefaults,
  });

  final Drawable? selected;
  final double strokeWidth;
  final void Function({Color? newStrokeColor, double? newStrokeWidth, double? newCornerRadius}) onApplyStroke;
  final void Function(Drawable original, Drawable replacement) onReplaceDrawable;
  final bool angleSnap;
  final double Function(double) snapAngle;
  final TextDefaults textDefaults;

  static const _swatchColors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('Inspector', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (selected == null)
            const Text('Nothing selected.\nUse Select tool and tap a shape.')
          else ...[
            _kv('Type', selected!.runtimeType.toString()),
            const SizedBox(height: 12),
            if (selected is! ConstrainedTextDrawable && selected is! TextDrawable && selected is! BarcodeDrawable)
              ..._buildShapeControls(selected!),
            if (selected is ConstrainedTextDrawable)
              ..._buildConstrainedTextControls(selected as ConstrainedTextDrawable),
            if (selected is TextDrawable)
              ..._buildPlainTextControls(selected as TextDrawable),
            if (selected is BarcodeDrawable)
              ..._buildBarcodeControls(selected as BarcodeDrawable),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildShapeControls(Drawable drawable) {
    return [
      const Text('Stroke Color'),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in _swatchColors)
            ColorDot(
              color: c,
              onTap: () => onApplyStroke(newStrokeColor: c),
            ),
        ],
      ),
      const SizedBox(height: 12),
      const Text('Stroke Width'),
      Slider(
        min: 1,
        max: 24,
        value: strokeWidth,
        onChanged: (v) => onApplyStroke(newStrokeWidth: v),
      ),
      if (drawable is RectangleDrawable) ...[
        const SizedBox(height: 12),
        const Text('Corner Radius (Rect)'),
        Slider(
          min: 0,
          max: 40,
          value: drawable.borderRadius.topLeft.x.clamp(0.0, 40.0),
          onChanged: (v) => onApplyStroke(newCornerRadius: v),
        ),
      ],
    ];
  }

  List<Widget> _buildConstrainedTextControls(ConstrainedTextDrawable td) {
    final controller = TextEditingController(text: td.text);
    Color currentColor = td.style.color ?? Colors.black;
    double currentSize = td.style.fontSize ?? textDefaults.fontSize;
    bool currentBold =
        (td.style.fontWeight ?? FontWeight.normal) == FontWeight.bold;
    bool currentItalic =
        (td.style.fontStyle ?? FontStyle.normal) == FontStyle.italic;
    String currentFamily = td.style.fontFamily ?? textDefaults.fontFamily;
    TxtAlign currentAlign = td.align;
    double currentMaxWidth = td.maxWidth;
    double currentAngle = td.rotationAngle;

    void commit() {
      final style = TextStyle(
        color: currentColor,
        fontSize: currentSize,
        fontWeight: currentBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: currentItalic ? FontStyle.italic : FontStyle.normal,
        fontFamily: currentFamily,
      );
      final replacement = td.copyWith(
        text: controller.text,
        style: style,
        align: currentAlign,
        maxWidth: currentMaxWidth,
        rotation: currentAngle,
      );
      onReplaceDrawable(td, replacement);
    }

    return [
      const Text('Content'),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        minLines: 1,
        maxLines: 6,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onSubmitted: (_) => commit(),
      ),
      const SizedBox(height: 12),
      const Text('Color'),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in _swatchColors)
            ColorDot(
              color: c,
              selected: currentColor == c,
              onTap: () {
                currentColor = c;
                commit();
              },
            ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Text('Size'),
          Expanded(
            child: Slider(
              min: 8,
              max: 96,
              value: currentSize,
              onChanged: (v) {
                currentSize = v;
                commit();
              },
            ),
          ),
          SizedBox(width: 42, child: Text(currentSize.toStringAsFixed(0))),
        ],
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilterChip(
            label: const Text('Bold'),
            selected: currentBold,
            onSelected: (v) {
              currentBold = v;
              commit();
            },
          ),
          FilterChip(
            label: const Text('Italic'),
            selected: currentItalic,
            onSelected: (v) {
              currentItalic = v;
              commit();
            },
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          const Text('Font'),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: currentFamily,
            items: const [
              DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
              DropdownMenuItem(value: 'NotoSans', child: Text('NotoSans')),
              DropdownMenuItem(value: 'Monospace', child: Text('Monospace')),
            ],
            onChanged: (v) {
              if (v != null) {
                currentFamily = v;
                commit();
              }
            },
          ),
        ],
      ),
      Row(
        children: [
          const Text('Align'),
          const SizedBox(width: 8),
          DropdownButton<TxtAlign>(
            value: currentAlign,
            items: const [
              DropdownMenuItem(value: TxtAlign.left, child: Text('Left')),
              DropdownMenuItem(value: TxtAlign.center, child: Text('Center')),
              DropdownMenuItem(value: TxtAlign.right, child: Text('Right')),
            ],
            onChanged: (v) {
              if (v != null) {
                currentAlign = v;
                commit();
              }
            },
          ),
        ],
      ),
      Row(
        children: [
          const Text('Max Width'),
          Expanded(
            child: Slider(
              min: 40,
              max: 1200,
              value: currentMaxWidth,
              onChanged: (v) {
                currentMaxWidth = v;
                commit();
              },
            ),
          ),
          SizedBox(width: 56, child: Text(currentMaxWidth.toStringAsFixed(0))),
        ],
      ),
      Row(
        children: [
          const Text('Angle'),
          Expanded(
            child: Slider(
              min: -180,
              max: 180,
              value: currentAngle * 180 / math.pi,
              onChanged: (v) {
                final rad = v * math.pi / 180.0;
                currentAngle = angleSnap ? snapAngle(rad) : rad;
                commit();
              },
            ),
          ),
          SizedBox(
            width: 52,
            child: Text('${(currentAngle * 180 / math.pi).toStringAsFixed(0)} deg'),
          ),
        ],
      ),
    ];
  }

  static const _barcodeTypes = [
    BarcodeType.Code128,
    BarcodeType.Code39,
    BarcodeType.QrCode,
    BarcodeType.PDF417,
    BarcodeType.DataMatrix,
  ];

  static const _barcodeLabels = <BarcodeType, String>{
    BarcodeType.Code128: 'Code 128',
    BarcodeType.Code39: 'Code 39',
    BarcodeType.QrCode: 'QR Code',
    BarcodeType.PDF417: 'PDF417',
    BarcodeType.DataMatrix: 'Data Matrix',
  };

  static const _barcodeBgChoices = <Color>[
    Color(0x00FFFFFF),
    Color(0xFFFFFFFF),
    Color(0xFFF4F4F4),
    Color(0xFFE8F0FE),
    Color(0xFFFFF8E1),
    Color(0xFFE8F5E9),
  ];

  List<Widget> _buildPlainTextControls(TextDrawable td) {
    final controller = TextEditingController(text: td.text);
    Color currentColor = td.style.color ?? Colors.black;
    double currentSize = td.style.fontSize ?? textDefaults.fontSize;
    bool currentBold =
        (td.style.fontWeight ?? FontWeight.normal) == FontWeight.bold;
    bool currentItalic =
        (td.style.fontStyle ?? FontStyle.normal) == FontStyle.italic;
    String currentFamily = td.style.fontFamily ?? textDefaults.fontFamily;
    double currentAngle = td.rotationAngle;

    void commit() {
      final style = TextStyle(
        color: currentColor,
        fontSize: currentSize,
        fontWeight: currentBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: currentItalic ? FontStyle.italic : FontStyle.normal,
        fontFamily: currentFamily,
      );
      final replacement = td.copyWith(
        text: controller.text,
        style: style,
        rotation: currentAngle,
      );
      onReplaceDrawable(td, replacement);
    }

    return [
      const Text('Content'),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        minLines: 1,
        maxLines: 6,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onSubmitted: (_) => commit(),
      ),
      const SizedBox(height: 12),
      const Text('Color'),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in _swatchColors)
            ColorDot(
              color: c,
              selected: currentColor == c,
              onTap: () {
                currentColor = c;
                commit();
              },
            ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Text('Size'),
          Expanded(
            child: Slider(
              min: 8,
              max: 96,
              value: currentSize,
              onChanged: (v) {
                currentSize = v;
                commit();
              },
            ),
          ),
          SizedBox(width: 42, child: Text(currentSize.toStringAsFixed(0))),
        ],
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilterChip(
            label: const Text('Bold'),
            selected: currentBold,
            onSelected: (v) {
              currentBold = v;
              commit();
            },
          ),
          FilterChip(
            label: const Text('Italic'),
            selected: currentItalic,
            onSelected: (v) {
              currentItalic = v;
              commit();
            },
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          const Text('Font'),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: currentFamily,
            items: const [
              DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
              DropdownMenuItem(value: 'NotoSans', child: Text('NotoSans')),
              DropdownMenuItem(value: 'Monospace', child: Text('Monospace')),
            ],
            onChanged: (v) {
              if (v != null) {
                currentFamily = v;
                commit();
              }
            },
          ),
        ],
      ),
      Row(
        children: [
          const Text('Angle'),
          Expanded(
            child: Slider(
              min: -180,
              max: 180,
              value: currentAngle * 180 / math.pi,
              onChanged: (v) {
                final rad = v * math.pi / 180.0;
                currentAngle = angleSnap ? snapAngle(rad) : rad;
                commit();
              },
            ),
          ),
          SizedBox(
            width: 52,
            child: Text('${(currentAngle * 180 / math.pi).toStringAsFixed(0)} deg'),
          ),
        ],
      ),
      const SizedBox(height: 4),
      const Text(
        'TextDrawable (simple text) does not honour alignment/max width.\nUse constrained text if those properties are required.',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      ),
    ];
  }

  List<Widget> _buildBarcodeControls(BarcodeDrawable barcode) {
    final valueController = TextEditingController(text: barcode.data);
    String currentValue = barcode.data;
    BarcodeType currentType = barcode.type;
    bool showValue = barcode.showValue;
    double currentFontSize = barcode.fontSize;
    Color currentForeground = barcode.foreground;
    Color currentBackground = barcode.background;

    void commit() {
      onReplaceDrawable(
        barcode,
        barcode.copyWith(
          data: currentValue,
          type: currentType,
          showValue: showValue,
          fontSize: currentFontSize,
          foreground: currentForeground,
          background: currentBackground,
        ),
      );
    }

    return [
      const Text('Barcode Value'),
      const SizedBox(height: 4),
      TextField(
        controller: valueController,
        minLines: 1,
        maxLines: 4,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) {
          currentValue = v;
          commit();
        },
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Text('Type'),
          const SizedBox(width: 8),
          DropdownButton<BarcodeType>(
            value: currentType,
            items: [
              for (final type in _barcodeTypes)
                DropdownMenuItem(
                  value: type,
                  child: Text(_barcodeLabel(type)),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                currentType = value;
                commit();
              }
            },
          ),
        ],
      ),
      SwitchListTile(
        value: showValue,
        onChanged: (v) {
          showValue = v;
          commit();
        },
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: const Text('Show human-readable value'),
      ),
      Row(
        children: [
          const Text('Font Size'),
          Expanded(
            child: Slider(
              min: 8,
              max: 64,
              value: currentFontSize,
              onChanged: (v) {
                currentFontSize = v;
                commit();
              },
            ),
          ),
          SizedBox(width: 48, child: Text(currentFontSize.toStringAsFixed(0))),
        ],
      ),
      const SizedBox(height: 12),
      const Text('Foreground'),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in _swatchColors)
            ColorDot(
              color: c,
              selected: currentForeground == c,
              onTap: () {
                currentForeground = c;
                commit();
              },
            ),
        ],
      ),
      const SizedBox(height: 12),
      const Text('Background'),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in _barcodeBgChoices)
            ColorDot(
              color: c,
              selected: currentBackground.value == c.value,
              showChecker: c.alpha < 0xFF,
              onTap: () {
                currentBackground = c;
                commit();
              },
            ),
        ],
      ),
    ];
  }

  String _barcodeLabel(BarcodeType type) => _barcodeLabels[type] ?? type.name;
}

Widget _kv(String k, String v) => Row(
    children: [
      Expanded(child: Text(k, style: const TextStyle(color: Colors.black54))),
      Text(v),
    ],
  );