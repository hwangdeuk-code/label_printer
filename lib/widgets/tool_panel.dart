import 'package:flutter/material.dart';

import '../models/tool.dart';
import 'color_dot.dart';

class ToolPanel extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('Tools', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _toolChip(Tool.select, 'Select', Icons.near_me),
              _toolChip(Tool.pen, 'Pen', Icons.draw),
              _toolChip(Tool.eraser, 'Eraser', Icons.auto_fix_off),
              _toolChip(Tool.rect, 'Rect', Icons.crop_square),
              _toolChip(Tool.oval, 'Oval', Icons.circle),
              _toolChip(Tool.line, 'Line', Icons.show_chart),
              _toolChip(Tool.arrow, 'Arrow', Icons.arrow_right_alt),
              _toolChip(Tool.text, 'Text', Icons.title),
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
            title: const Text('Lock Ratio (Rect/Oval -> Square/Circle)'),
            dense: true,
          ),
          SwitchListTile(
            value: angleSnap,
            onChanged: onAngleSnapChanged,
            title: const Text('Angle Snap (0 deg / 45 deg / 90 deg)'),
            dense: true,
          ),
          SwitchListTile(
            value: endpointDragRotates,
            onChanged: onEndpointDragRotatesChanged,
            title: const Text('Endpoint drag rotates (Line/Arrow)'),
            dense: true,
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
    Colors.red.withOpacity(0.2),
    Colors.blue.withOpacity(0.2),
    Colors.green.withOpacity(0.2),
    Colors.orange.withOpacity(0.2),
  ];
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
