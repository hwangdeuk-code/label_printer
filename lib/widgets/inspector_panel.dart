import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:barcode/barcode.dart';

import '../drawables/constrained_text_drawable.dart';
import '../drawables/barcode_drawable.dart';
import '../drawables/image_box_drawable.dart';
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
    required this.mutateSelected,        // ★ 추가
  });

  final Drawable? selected;
  final double strokeWidth;
  final void Function({Color? newStrokeColor, double? newStrokeWidth, double? newCornerRadius}) onApplyStroke;
  final void Function(Drawable original, Drawable replacement) onReplaceDrawable;
  final bool angleSnap;
  final double Function(double) snapAngle;
  final TextDefaults textDefaults;

  /// 최신 선택 객체로 안전하게 변형/치환
  final void Function(Drawable Function(Drawable current)) mutateSelected; // ★ 추가

  static const _swatchColors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
  ];

  // 연속 회전 지원을 위한 넓은 슬라이더 범위
  static const double _angleMin = -8 * math.pi;
  static const double _angleMax =  8 * math.pi;

  String _degLabel(double radians) {
    final deg = radians * 180 / math.pi;
    final norm = ((deg % 360) + 360) % 360; // 0..360
    return '${norm.toStringAsFixed(0)}°';
    }

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
            if (selected is RectangleDrawable) ..._buildRectControls(selected as RectangleDrawable),
            if (selected is OvalDrawable) ..._buildOvalControls(selected as OvalDrawable),
            if (selected is ConstrainedTextDrawable)
              ..._buildConstrainedTextControls(selected as ConstrainedTextDrawable),
            if (selected is TextDrawable)
              ..._buildPlainTextControls(selected as TextDrawable),
            if (selected is BarcodeDrawable)
              ..._buildBarcodeControls(selected as BarcodeDrawable),
            if (selected is ImageBoxDrawable)
              ..._buildImageControls(selected as ImageBoxDrawable),
            if (selected is LineDrawable || selected is ArrowDrawable)
              ..._buildLineLikeRotation(selected as ObjectDrawable),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildRectControls(RectangleDrawable r) {
    return [
      const Text('Stroke Color'),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: [
          for (final c in _swatchColors)
            ColorDot(color: c, onTap: () => onApplyStroke(newStrokeColor: c)),
        ],
      ),
      const SizedBox(height: 12),
      const Text('Stroke Width'),
      Slider(
        min: 1, max: 24, value: strokeWidth,
        onChanged: (v) => onApplyStroke(newStrokeWidth: v),
      ),
      const SizedBox(height: 12),
      const Text('Corner Radius'),
      Slider(
        min: 0, max: 40, value: r.borderRadius.topLeft.x.clamp(0.0, 40.0),
        onChanged: (v) => onApplyStroke(newCornerRadius: v),
      ),
    ];
  }

  List<Widget> _buildOvalControls(OvalDrawable o) {
    return [
      const Text('Stroke Color'),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: [
          for (final c in _swatchColors)
            ColorDot(color: c, onTap: () => onApplyStroke(newStrokeColor: c)),
        ],
      ),
      const SizedBox(height: 12),
      const Text('Stroke Width'),
      Slider(
        min: 1, max: 24, value: strokeWidth,
        onChanged: (v) => onApplyStroke(newStrokeWidth: v),
      ),
    ];
  }

  List<Widget> _buildConstrainedTextControls(ConstrainedTextDrawable td) {
    final controller = TextEditingController(text: td.text);
    Color currentColor = td.style.color ?? Colors.black;
    double currentSize = td.style.fontSize ?? textDefaults.fontSize;
    bool currentBold = (td.style.fontWeight ?? FontWeight.normal) == FontWeight.bold;
    bool currentItalic = (td.style.fontStyle ?? FontStyle.normal) == FontStyle.italic;
    String currentFamily = td.style.fontFamily ?? textDefaults.fontFamily;
    TxtAlign currentAlign = td.align;
    double currentMaxWidth = td.maxWidth;
    double currentAngle = td.rotationAngle;

    void commitAll() {
      mutateSelected((d) {
        final cur = d as ConstrainedTextDrawable;
        final style = TextStyle(
          color: currentColor,
          fontSize: currentSize,
          fontWeight: currentBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: currentItalic ? FontStyle.italic : FontStyle.normal,
          fontFamily: currentFamily,
        );
        return cur.copyWith(
          text: controller.text,
          style: style,
          align: currentAlign,
          maxWidth: currentMaxWidth,
          rotation: currentAngle,
        );
      });
    }

    return [
      const Text('Content'),
      const SizedBox(height: 4),
      TextField(
        controller: controller, minLines: 1, maxLines: 6,
        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
        onSubmitted: (_) => commitAll(),
        onChanged: (_) => commitAll(),
      ),
      const SizedBox(height: 12),
      const Text('Color'),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: [
          for (final c in _swatchColors)
            ColorDot(
              color: c, selected: currentColor == c,
              onTap: () { currentColor = c; commitAll(); },
            ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Text('Size'),
          Expanded(child: Slider(min: 8, max: 96, value: currentSize, onChanged: (v) { currentSize = v; commitAll(); })),
          SizedBox(width: 42, child: Text(currentSize.toStringAsFixed(0))),
        ],
      ),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: [
          FilterChip(label: const Text('Bold'), selected: currentBold, onSelected: (v) { currentBold = v; commitAll(); }),
          FilterChip(label: const Text('Italic'), selected: currentItalic, onSelected: (v) { currentItalic = v; commitAll(); }),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          const Text('Font'), const SizedBox(width: 8),
          DropdownButton<String>(
            value: currentFamily,
            items: const [
              DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
              DropdownMenuItem(value: 'NotoSans', child: Text('NotoSans')),
              DropdownMenuItem(value: 'Monospace', child: Text('Monospace')),
            ],
            onChanged: (v) { if (v != null) { currentFamily = v; commitAll(); } },
          ),
        ],
      ),
      Row(
        children: [
          const Text('Align'), const SizedBox(width: 8),
          DropdownButton<TxtAlign>(
            value: currentAlign,
            items: const [
              DropdownMenuItem(value: TxtAlign.left, child: Text('Left')),
              DropdownMenuItem(value: TxtAlign.center, child: Text('Center')),
              DropdownMenuItem(value: TxtAlign.right, child: Text('Right')),
            ],
            onChanged: (v) { if (v != null) { currentAlign = v; commitAll(); } },
          ),
        ],
      ),
      Row(
        children: [
          const Text('Max Width'),
          Expanded(child: Slider(min: 40, max: 1200, value: currentMaxWidth, onChanged: (v) { currentMaxWidth = v; commitAll(); })),
          SizedBox(width: 56, child: Text(currentMaxWidth.toStringAsFixed(0))),
        ],
      ),
      Row(
        children: [
          const Text('Angle'),
          IconButton(icon: const Icon(Icons.rotate_right), tooltip: 'Rotate 90°', onPressed: () { currentAngle = ((currentAngle + (math.pi / 2)) % (2 * math.pi)); commitAll(); }),
          Expanded(
            child: Slider(
              min: _angleMin, max: _angleMax, value: currentAngle.clamp(_angleMin, _angleMax),
              onChanged: (v) { currentAngle = v; commitAll(); },
            ),
          ),
          SizedBox(width: 44, child: Text(_degLabel(currentAngle))),
        ],
      ),
    ];
  }

  List<Widget> _buildPlainTextControls(TextDrawable td) {
    final controller = TextEditingController(text: td.text);
    Color currentColor = td.style.color ?? Colors.black;
    double currentSize = td.style.fontSize ?? textDefaults.fontSize;
    bool currentBold = (td.style.fontWeight ?? FontWeight.normal) == FontWeight.bold;
    bool currentItalic = (td.style.fontStyle ?? FontStyle.normal) == FontStyle.italic;
    String currentFamily = td.style.fontFamily ?? textDefaults.fontFamily;
    double currentAngle = td.rotationAngle;

    void commitAll() {
      mutateSelected((d) {
        final cur = d as TextDrawable;
        final style = TextStyle(
          color: currentColor,
          fontSize: currentSize,
          fontWeight: currentBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: currentItalic ? FontStyle.italic : FontStyle.normal,
          fontFamily: currentFamily,
        );
        return cur.copyWith(text: controller.text, style: style, rotation: currentAngle);
      });
    }

    return [
      const Text('Content'),
      const SizedBox(height: 4),
      TextField(
        controller: controller, minLines: 1, maxLines: 6,
        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
        onSubmitted: (_) => commitAll(),
        onChanged: (_) => commitAll(),
      ),
      const SizedBox(height: 12),
      const Text('Color'),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: [
          for (final c in _swatchColors)
            ColorDot(color: c, selected: currentColor == c, onTap: () { currentColor = c; commitAll(); }),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Text('Size'),
          Expanded(child: Slider(min: 8, max: 96, value: currentSize, onChanged: (v) { currentSize = v; commitAll(); })),
          SizedBox(width: 42, child: Text(currentSize.toStringAsFixed(0))),
        ],
      ),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: [
          FilterChip(label: const Text('Bold'), selected: currentBold, onSelected: (v) { currentBold = v; commitAll(); }),
          FilterChip(label: const Text('Italic'), selected: currentItalic, onSelected: (v) { currentItalic = v; commitAll(); }),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          const Text('Font'), const SizedBox(width: 8),
          DropdownButton<String>(
            value: currentFamily,
            items: const [
              DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
              DropdownMenuItem(value: 'NotoSans', child: Text('NotoSans')),
              DropdownMenuItem(value: 'Monospace', child: Text('Monospace')),
            ],
            onChanged: (v) { if (v != null) { currentFamily = v; commitAll(); } },
          ),
        ],
      ),
      Row(
        children: [
          const Text('Angle'),
          IconButton(icon: const Icon(Icons.rotate_right), tooltip: 'Rotate 90°', onPressed: () { currentAngle = ((currentAngle + (math.pi / 2)) % (2 * math.pi)); commitAll(); }),
          Expanded(
            child: Slider(
              min: _angleMin, max: _angleMax, value: currentAngle.clamp(_angleMin, _angleMax),
              onChanged: (v) { currentAngle = v; commitAll(); },
            ),
          ),
          SizedBox(width: 44, child: Text(_degLabel(currentAngle))),
        ],
      ),
      const SizedBox(height: 4),
      const Text(
        'TextDrawable는 크기박스/정렬/최대폭을 지원하지 않습니다.\n폭 제어는 ConstrainedText를 사용하세요.',
        style: TextStyle(fontSize: 12, color: Colors.black54),
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
  static String _barcodeLabel(BarcodeType type) => _barcodeLabels[type] ?? type.name;

  List<Widget> _buildBarcodeControls(BarcodeDrawable barcode) {
    final valueController = TextEditingController(text: barcode.data);
    String currentValue = barcode.data;
    BarcodeType currentType = barcode.type;
    bool showValue = barcode.showValue;
    double currentFontSize = barcode.fontSize;
    Color currentForeground = barcode.foreground;
    Color currentBackground = barcode.background;
    bool currentBold = barcode.bold;
    bool currentItalic = barcode.italic;
    String currentFamily = barcode.fontFamily;
    TextAlign? currentAlign = barcode.textAlign;
    bool autoMaxWidth = barcode.maxTextWidth <= 0;
    double currentAngle = barcode.rotationAngle;

    double clampWidth(double value) => math.max(40.0, math.min(2000.0, value));
    double currentMaxWidth = clampWidth(autoMaxWidth ? barcode.size.width : barcode.maxTextWidth);

    void commitAll() {
      mutateSelected((d) {
        final cur = d as BarcodeDrawable;
        return cur.copyWith(
          data: currentValue,
          type: currentType,
          showValue: showValue,
          fontSize: currentFontSize,
          foreground: currentForeground,
          background: currentBackground,
          bold: currentBold,
          italic: currentItalic,
          fontFamily: currentFamily,
          textAlign: currentAlign,
          maxTextWidth: autoMaxWidth ? 0 : currentMaxWidth,
          rotation: currentAngle,
        );
      });
    }

    return [
      Row(
        children: [
          const Text('Angle'),
          IconButton(icon: const Icon(Icons.rotate_right), tooltip: 'Rotate 90°', onPressed: () { currentAngle = ((currentAngle + (math.pi / 2)) % (2 * math.pi)); commitAll(); }),
          Expanded(child: Slider(min: _angleMin, max: _angleMax, value: currentAngle.clamp(_angleMin, _angleMax), onChanged: (v){ currentAngle = v; commitAll(); })),
          SizedBox(width: 44, child: Text(_degLabel(currentAngle))),
        ],
      ),
      const SizedBox(height: 8),
      const Text('Barcode Value'),
      const SizedBox(height: 4),
      TextField(
        controller: valueController,
        minLines: 1, maxLines: 4,
        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
        onChanged: (v) { currentValue = v; commitAll(); },
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Text('Type'), const SizedBox(width: 8),
          DropdownButton<BarcodeType>(
            value: currentType,
            items: [
              for (final t in _barcodeTypes)
                DropdownMenuItem(value: t, child: Text(_barcodeLabel(t))),
            ],
            onChanged: (v) { if (v != null) { currentType = v; commitAll(); } },
          ),
        ],
      ),
      SwitchListTile(
        value: showValue, onChanged: (v) { showValue = v; commitAll(); },
        dense: true, contentPadding: EdgeInsets.zero, title: const Text('Show human-readable value'),
      ),
      Row(
        children: [
          const Text('Font Size'),
          Expanded(child: Slider(min: 8, max: 64, value: currentFontSize, onChanged: (v) { currentFontSize = v; commitAll(); })),
          SizedBox(width: 48, child: Text(currentFontSize.toStringAsFixed(0))),
        ],
      ),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: [
          FilterChip(label: const Text('Bold'), selected: currentBold, onSelected: (v){ currentBold = v; commitAll(); }),
          FilterChip(label: const Text('Italic'), selected: currentItalic, onSelected: (v){ currentItalic = v; commitAll(); }),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          const Text('Font'), const SizedBox(width: 8),
          DropdownButton<String>(
            value: currentFamily,
            items: const [
              DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
              DropdownMenuItem(value: 'NotoSans', child: Text('NotoSans')),
              DropdownMenuItem(value: 'Monospace', child: Text('Monospace')),
            ],
            onChanged: (v) { if (v != null) { currentFamily = v; commitAll(); } },
          ),
        ],
      ),
      Row(
        children: [
          const Text('Align'), const SizedBox(width: 8),
          DropdownButton<TextAlign?>(
            value: currentAlign,
            items: const [
              DropdownMenuItem(value: null, child: Text('Auto')),
              DropdownMenuItem(value: TextAlign.left, child: Text('Left')),
              DropdownMenuItem(value: TextAlign.center, child: Text('Center')),
              DropdownMenuItem(value: TextAlign.right, child: Text('Right')),
            ],
            onChanged: (v) { currentAlign = v; commitAll(); },
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildImageControls(ImageBoxDrawable img) {
    double currentAngle = img.rotationAngle;
    double currentStrokeWidth = img.strokeWidth;
    Color currentStrokeColor = img.strokeColor;
    double currentRadius = img.borderRadius.topLeft.x;

    void commitAll() {
      mutateSelected((d) {
        final cur = d as ImageBoxDrawable;
        return cur.copyWithExt(
          rotation: currentAngle,
          strokeWidth: currentStrokeWidth,
          strokeColor: currentStrokeColor,
          borderRadius: BorderRadius.all(Radius.circular(currentRadius)),
        );
      });
    }

    return [
      Row(
        children: [
          const Text('Angle'),
          IconButton(
            icon: const Icon(Icons.rotate_right),
            tooltip: 'Rotate 90°',
            onPressed: () { currentAngle = ((currentAngle + (math.pi / 2)) % (2 * math.pi)); commitAll(); },
          ),
          Expanded(
            child: Slider(
              min: _angleMin, max: _angleMax, value: currentAngle.clamp(_angleMin, _angleMax),
              onChanged: (v) { currentAngle = v; commitAll(); },
            ),
          ),
          SizedBox(width: 44, child: Text(_degLabel(currentAngle))),
        ],
      ),
      const SizedBox(height: 8),
      const Text('Stroke Color'),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: [
          for (final c in _swatchColors)
            ColorDot(color: c, selected: currentStrokeColor == c, onTap: () { currentStrokeColor = c; commitAll(); }),
        ],
      ),
      const SizedBox(height: 12),
      const Text('Stroke Width'),
      Slider(min: 0, max: 16, value: currentStrokeWidth, onChanged: (v) { currentStrokeWidth = v; commitAll(); }),
      const SizedBox(height: 12),
      const Text('Corner Radius'),
      Slider(min: 0, max: 40, value: currentRadius.clamp(0.0, 40.0), onChanged: (v) { currentRadius = v; commitAll(); }),
    ];
  }

  List<Widget> _buildLineLikeRotation(ObjectDrawable od) {
    double currentAngle = od.rotationAngle;
    void commitRotation() {
      mutateSelected((d) {
        if (d is LineDrawable) return d.copyWith(rotation: currentAngle);
        if (d is ArrowDrawable) return d.copyWith(rotation: currentAngle);
        return d;
      });
    }

    return [
      const SizedBox(height: 12),
      const Text('Rotation'),
      Row(
        children: [
          IconButton(icon: const Icon(Icons.rotate_right), tooltip: 'Rotate 90°', onPressed: () { currentAngle = ((currentAngle + (math.pi / 2)) % (2 * math.pi)); commitRotation(); }),
          Expanded(
            child: Slider(min: _angleMin, max: _angleMax, value: currentAngle.clamp(_angleMin, _angleMax), onChanged: (v) { currentAngle = v; commitRotation(); }),
          ),
          SizedBox(width: 44, child: Text(_degLabel(currentAngle))),
        ],
      ),
    ];
  }
}

Widget _kv(String k, String v) => Row(
      children: [
        Expanded(child: Text(k, style: const TextStyle(color: Colors.black54))),
        Text(v),
      ],
    );
