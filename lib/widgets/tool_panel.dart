import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';

import '../models/tool.dart';
import 'color_dot.dart';

class ToolPanel extends StatelessWidget {
  final double scalePercent;
  final ValueChanged<double> onScalePercentChanged;
  const ToolPanel({
    super.key,
    required this.currentTool,
    required this.onToolSelected,
    required this.strokeColor,
    required this.onStrokeColorChanged,
    required this.strokeWidth,
    required this.onStrokeWidthChanged,
    required this.fillColor,
    required this.onFillColorChanged,
    required this.lockRatio,
    required this.onLockRatioChanged,
    required this.angleSnap,
    required this.onAngleSnapChanged,
    required this.endpointDragRotates,
    required this.onEndpointDragRotatesChanged,
    required this.textFontSize,
    required this.onTextFontSizeChanged,
    required this.textBold,
    required this.onTextBoldChanged,
    required this.textItalic,
    required this.onTextItalicChanged,
    required this.textFontFamily,
    required this.onTextFontFamilyChanged,
    required this.defaultTextAlign,
    required this.onDefaultTextAlignChanged,
    required this.defaultTextMaxWidth,
    required this.onDefaultTextMaxWidthChanged,
    required this.barcodeData,
    required this.onBarcodeDataChanged,
    required this.barcodeType,
    required this.onBarcodeTypeChanged,
    required this.barcodeShowValue,
    required this.onBarcodeShowValueChanged,
    required this.barcodeFontSize,
    required this.onBarcodeFontSizeChanged,
    required this.barcodeForeground,
    required this.onBarcodeForegroundChanged,
    required this.barcodeBackground,
    required this.onBarcodeBackgroundChanged,
    required this.scalePercent,
    required this.onScalePercentChanged,
  });

  final Tool currentTool;
  final ValueChanged<Tool> onToolSelected;
  final Color strokeColor;
  final ValueChanged<Color> onStrokeColorChanged;
  final double strokeWidth;
  final ValueChanged<double> onStrokeWidthChanged;
  final Color fillColor;
  final ValueChanged<Color> onFillColorChanged;
  final bool lockRatio;
  final ValueChanged<bool> onLockRatioChanged;
  final bool angleSnap;
  final ValueChanged<bool> onAngleSnapChanged;
  final bool endpointDragRotates;
  final ValueChanged<bool> onEndpointDragRotatesChanged;
  final double textFontSize;
  final ValueChanged<double> onTextFontSizeChanged;
  final bool textBold;
  final ValueChanged<bool> onTextBoldChanged;
  final bool textItalic;
  final ValueChanged<bool> onTextItalicChanged;
  final String textFontFamily;
  final ValueChanged<String> onTextFontFamilyChanged;
  final TxtAlign defaultTextAlign;
  final ValueChanged<TxtAlign> onDefaultTextAlignChanged;
  final double defaultTextMaxWidth;
  final ValueChanged<double> onDefaultTextMaxWidthChanged;
  final String barcodeData;
  final ValueChanged<String> onBarcodeDataChanged;
  final BarcodeType barcodeType;
  final ValueChanged<BarcodeType> onBarcodeTypeChanged;
  final bool barcodeShowValue;
  final ValueChanged<bool> onBarcodeShowValueChanged;
  final double barcodeFontSize;
  final ValueChanged<double> onBarcodeFontSizeChanged;
  final Color barcodeForeground;
  final ValueChanged<Color> onBarcodeForegroundChanged;
  final Color barcodeBackground;
  final ValueChanged<Color> onBarcodeBackgroundChanged;

  @override
  Widget build(BuildContext context) {
    final scaleSlider = Row(
      children: [
        const Text('Scale'),
        Expanded(
          child: Slider(
            min: 10,
            max: 400,
            divisions: 39,
            value: scalePercent,
            label: '${scalePercent.toInt()}%',
            onChanged: onScalePercentChanged,
          ),
        ),
        SizedBox(width: 40, child: Text('${scalePercent.toInt()}%')),
      ],
    );
    return SizedBox(
      width: 320,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          scaleSlider,
          const SizedBox(height: 12),
          const Text('Tools', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _toolChip(Tool.select, 'Select', Icons.near_me),
              _toolChip(Tool.pen, 'Pen', Icons.draw),
              _toolChip(Tool.eraser, 'Eraser', Icons.auto_fix_off),
              _toolChip(Tool.rect, 'Rect', Icons.square),
              _toolChip(Tool.oval, 'Oval', Icons.circle),
              _toolChip(Tool.line, 'Line', Icons.show_chart),
              _toolChip(Tool.arrow, 'Arrow', Icons.arrow_right_alt),
              _toolChip(Tool.text, 'Text', Icons.title),
              _toolChip(Tool.barcode, 'Barcode', Icons.qr_code_2),
              _toolChip(Tool.image, 'Image', Icons.image),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Draw Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Stroke'),
              const SizedBox(width: 8),
              for (final c in _strokeChoices)
                ColorDot(
                  color: c,
                  selected: strokeColor == c,
                  onTap: () => onStrokeColorChanged(c),
                ),
            ],
          ),
          Row(
            children: [
              const Text('Width'),
              Expanded(
                child: Slider(
                  min: 1,
                  max: 24,
                  value: strokeWidth,
                  onChanged: onStrokeWidthChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Fill'),
              const SizedBox(width: 8),
              ColorDot(
                color: Colors.transparent,
                selected: fillColor.opacity == 0,
                showChecker: true,
                onTap: () => onFillColorChanged(Colors.transparent),
              ),
              for (final c in _fillChoices)
                ColorDot(
                  color: c,
                  selected: fillColor == c,
                  onTap: () => onFillColorChanged(c),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Snap / Behavior', style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(
            value: lockRatio,
            onChanged: onLockRatioChanged,
            title: const Text('Lock ratio (Rect/Oval/Barcode)'),
            dense: true,
          ),
          SwitchListTile(
            value: angleSnap,
            onChanged: onAngleSnapChanged,
            title: const Text('Angle snap (0 / 45 / 90 deg)'),
            dense: true,
          ),
          SwitchListTile(
            value: endpointDragRotates,
            onChanged: onEndpointDragRotatesChanged,
            title: const Text('Endpoint drag rotates (Line/Arrow)'),
            dense: true,
          ),
          const SizedBox(height: 16),
          const Text('Barcode Defaults', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: barcodeData,
            decoration: const InputDecoration(
              labelText: 'Value',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: onBarcodeDataChanged,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Type'),
              const SizedBox(width: 8),
              DropdownButton<BarcodeType>(
                value: barcodeType,
                items: [
                  for (final type in _barcodeTypes)
                    DropdownMenuItem(
                      value: type,
                      child: Text(_barcodeLabel(type)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onBarcodeTypeChanged(value);
                },
              ),
            ],
          ),
          SwitchListTile(
            value: barcodeShowValue,
            onChanged: onBarcodeShowValueChanged,
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
                  value: barcodeFontSize,
                  onChanged: onBarcodeFontSizeChanged,
                ),
              ),
              SizedBox(width: 40, child: Text(barcodeFontSize.toStringAsFixed(0))),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Foreground'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _strokeChoices)
                ColorDot(
                  color: c,
                  selected: barcodeForeground == c,
                  onTap: () => onBarcodeForegroundChanged(c),
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
                  selected: barcodeBackground.value == c.value,
                  showChecker: c.alpha < 0xFF,
                  onTap: () => onBarcodeBackgroundChanged(c),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Text Defaults', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              const Text('Size'),
              Expanded(
                child: Slider(
                  min: 8,
                  max: 96,
                  value: textFontSize,
                  onChanged: onTextFontSizeChanged,
                ),
              ),
              SizedBox(width: 40, child: Text(textFontSize.toStringAsFixed(0))),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Bold'),
                selected: textBold,
                onSelected: onTextBoldChanged,
              ),
              FilterChip(
                label: const Text('Italic'),
                selected: textItalic,
                onSelected: onTextItalicChanged,
              ),
            ],
          ),
          Row(
            children: [
              const Text('Font'),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: textFontFamily,
                items: const [
                  DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
                  DropdownMenuItem(value: 'NotoSans', child: Text('NotoSans')),
                  DropdownMenuItem(value: 'Monospace', child: Text('Monospace')),
                ],
                onChanged: (v) {
                  if (v != null) onTextFontFamilyChanged(v);
                },
              ),
            ],
          ),
          Row(
            children: [
              const Text('Default Align'),
              const SizedBox(width: 8),
              DropdownButton<TxtAlign>(
                value: defaultTextAlign,
                items: const [
                  DropdownMenuItem(value: TxtAlign.left, child: Text('Left')),
                  DropdownMenuItem(value: TxtAlign.center, child: Text('Center')),
                  DropdownMenuItem(value: TxtAlign.right, child: Text('Right')),
                ],
                onChanged: (v) {
                  if (v != null) onDefaultTextAlignChanged(v);
                },
              ),
            ],
          ),
          Row(
            children: [
              const Text('Default MaxW'),
              Expanded(
                child: Slider(
                  min: 40,
                  max: 800,
                  value: defaultTextMaxWidth,
                  onChanged: onDefaultTextMaxWidthChanged,
                ),
              ),
              SizedBox(width: 56, child: Text(defaultTextMaxWidth.toStringAsFixed(0))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolChip(Tool tool, String label, IconData icon) => _ToolChip(
        currentTool: currentTool,
        tool: tool,
        label: label,
        icon: icon,
        onSelected: onToolSelected,
      );

  static const _strokeChoices = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
  ];

  static final _fillChoices = [
    Colors.black12,
    Colors.redAccent.withOpacity(0.2),
    Colors.blueAccent.withOpacity(0.2),
    Colors.greenAccent.withOpacity(0.2),
    Colors.orangeAccent.withOpacity(0.2),
  ];

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

  static String _barcodeLabel(BarcodeType type) => _barcodeLabels[type] ?? type.name;
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.currentTool,
    required this.tool,
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  final Tool currentTool;
  final Tool tool;
  final String label;
  final IconData icon;
  final ValueChanged<Tool> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = currentTool == tool;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)],
      ),
      selected: selected,
      onSelected: (_) => onSelected(tool),
    );
  }
}
