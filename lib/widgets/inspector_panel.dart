// ignore_for_file: unused_field

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barcode/barcode.dart';

import '../drawables/constrained_text_drawable.dart';
import '../drawables/barcode_drawable.dart';
import '../drawables/image_box_drawable.dart';
import '../drawables/table_drawable.dart';
import '../flutter_painter_v2/flutter_painter.dart';
import '../models/tool.dart' as tool;
import 'color_dot.dart';
import 'windows_like_color_dialog.dart';

// ==== Table 배경색 확장(안전장치) ====
// 구버전 TableDrawable에서도 컴파일되도록 보조 메서드 제공
extension TableDrawableBgExt on TableDrawable {
  Color? backgroundColorOf(int r, int c) {
    try {
      final key = "$r,$c";
      final m = cellStyles[key];
      if (m == null) return null;
      final v = m['bgColor'];
      if (v == null) return null;
      if (v is int) return Color(v);
      if (v is String) {
        var s = v.trim();
        if (s.startsWith('#')) s = s.substring(1);
        final n = int.tryParse(s, radix: 16);
        if (n == null) return null;
        if (s.length == 6) return Color(0xFF000000 | n);
        if (s.length == 8) return Color(n);
        return null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void setBackgroundForCells(Iterable<(int,int)> cells, Color? color) {
    final roots = <String, (int,int)>{};
    for (final cell in cells) {
      final root = resolveRoot(cell.$1, cell.$2);
      roots["${root.$1},${root.$2}"] = root;
    }
    final String? hex = (color == null || color.alpha == 0)
        ? null
        : "#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}";
    for (final root in roots.values) {
      final key = "${root.$1},${root.$2}";
      final style = Map<String, dynamic>.from(cellStyles[key] ?? const {});
      if (hex == null) {
        style.remove('bgColor');
      } else {
        style['bgColor'] = hex;
      }
      if (style.isEmpty) {
        cellStyles.remove(key);
      } else {
        cellStyles[key] = style;
      }
    }
  }
}


class ArrowKeySlider extends StatefulWidget {
  final double min;
  final double max;
  final double value;
  final ValueChanged<double> onChanged;
  final double? step;

  const ArrowKeySlider({
    Key? key,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    this.step,
  }) : super(key: key);

  @override
  State<ArrowKeySlider> createState() => _ArrowKeySliderState();
}

class _ArrowKeySliderState extends State<ArrowKeySlider> {
  final FocusNode _arrowKeySliderFocusNode = FocusNode();
  late final FocusNode _focusNode;
  late double _value;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      canRequestFocus: true,
      skipTraversal: false,
      debugLabel: 'ArrowKeySlider',
    );

    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(covariant ArrowKeySlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = widget.value;
    }
  }

  void _nudge(int dir) {
    final step = widget.step ?? (widget.max - widget.min) / 100.0;
    final nv = (_value + step * dir).clamp(widget.min, widget.max);
    setState(() {
      _value = nv;
    });
    widget.onChanged(nv);
  }

  @override
  @override
  void dispose() {
    _arrowKeySliderFocusNode.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _arrowKeySliderFocusNode,
      onKey: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _nudge(-1);
            return;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _nudge(1);
            return;
          }
        }
        return;
      },
      child: Slider(
        min: widget.min,
        max: widget.max,
        value: _value.clamp(widget.min, widget.max),
        onChanged: (v) {
          setState(() {
            _value = v;
          });
          widget.onChanged(v);
        },
      ),
    );
  }
}

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
  final tool.TxtAlign align;
  final double maxWidth;
}

class InspectorPanel extends StatelessWidget {
  final (int, int)? selectionFocusCell;
  final ({int topRow, int leftCol, int bottomRow, int rightCol})?
  cellSelectionRange;
  final double printerDpi;
  // === Quill 표 셀 스타일 섹션 연동 필드(한국어 주석) ===
  final bool showCellQuillSection;
  final bool quillBold;
  final bool quillItalic;
  final double quillFontSize;
  final tool.TxtAlign quillAlign;
  final void Function({
    bool? bold,
    bool? italic,
    double? fontSize,
    tool.TxtAlign? align,
  })?
  onQuillStyleChanged;
  final bool canMergeCells;
  final bool canUnmergeCells;
  final VoidCallback? onMergeCells;
  final VoidCallback? onUnmergeCells;

  const InspectorPanel({
    super.key,
    required this.selected,
    required this.strokeWidth,
    required this.onApplyStroke,
    required this.onReplaceDrawable,
    required this.angleSnap,
    required this.snapAngle,
    required this.textDefaults,
    required this.mutateSelected, // ★ 추가
    required this.printerDpi,
    this.selectionFocusCell,
    this.cellSelectionRange,
    this.showCellQuillSection = false,
    this.quillBold = false,
    this.quillItalic = false,
    this.quillFontSize = 12.0,
    this.quillAlign = tool.TxtAlign.left,
    this.onQuillStyleChanged,
    this.canMergeCells = false,
    this.canUnmergeCells = false,
    this.onMergeCells,
    this.onUnmergeCells,
  });

  final Drawable? selected;
  final double strokeWidth;
  final void Function({
    Color? newStrokeColor,
    double? newStrokeWidth,
    double? newCornerRadius,
  })
  onApplyStroke;
  final void Function(Drawable original, Drawable replacement)
  onReplaceDrawable;
  final bool angleSnap;
  final double Function(double) snapAngle;
  final TextDefaults textDefaults;

  /// 최신 선택 객체로 안전하게 변형/치환
  final void Function(Drawable Function(Drawable current))
  mutateSelected; // ★ 추가

  static const _swatchColors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
  ];

  // 연속 회전 지원을 위한 넓은 슬라이더 범위
  static const double _angleMin = -8 * math.pi;
  static const double _angleMax = 8 * math.pi;

  String _degLabel(double radians) {
    final deg = radians * 180 / math.pi;
    final norm = ((deg % 360) + 360) % 360; // 0..360
    return '${norm.toStringAsFixed(0)}°';
  }

  // 간단한 Key-Value 한 줄 표시 위젯
  Widget _kv(String k, String v) => Row(
    children: [
      Expanded(
        child: Text(k, style: const TextStyle(color: Colors.black54)),
      ),
      Text(v),
    ],
  );
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text(
            'Inspector',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          if (showCellQuillSection) ...[
            const SizedBox(height: 12),
            const Divider(),
            const Text(
              'Table Cell (Quill)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Style'),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Bold'),
                  selected: quillBold,
                  onSelected: (v) => onQuillStyleChanged?.call(bold: v),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Italic'),
                  selected: quillItalic,
                  onSelected: (v) => onQuillStyleChanged?.call(italic: v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Size'),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    min: 8,
                    max: 72,
                    divisions: 64,
                    value: quillFontSize,
                    onChanged: (v) => onQuillStyleChanged?.call(fontSize: v),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(quillFontSize.toStringAsFixed(0)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Align'),
                const SizedBox(width: 8),
                DropdownButton<tool.TxtAlign>(
                  value: quillAlign,
                  items: const [
                    DropdownMenuItem(
                      value: tool.TxtAlign.left,
                      child: Text('Left'),
                    ),
                    DropdownMenuItem(
                      value: tool.TxtAlign.center,
                      child: Text('Center'),
                    ),
                    DropdownMenuItem(
                      value: tool.TxtAlign.right,
                      child: Text('Right'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) onQuillStyleChanged?.call(align: v);
                  },
                ),
              ],
            ),
          ],
          if (canMergeCells || canUnmergeCells) ...[
            const SizedBox(height: 12),
            if (!showCellQuillSection) const Divider(),
            const Text(
              'Table Cells',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: canMergeCells ? onMergeCells : null,
                  child: const Text('Merge'),
                ),
                FilledButton.tonal(
                  onPressed: canUnmergeCells ? onUnmergeCells : null,
                  child: const Text('Unmerge'),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),
          if (selected == null)
            const Text('Nothing selected.\nUse Select tool and tap a shape.')
          else ...[
            _kv('Type', selected!.runtimeType.toString()),
            const SizedBox(height: 12),
            if (selected is RectangleDrawable)
              ..._buildRectControls(selected as RectangleDrawable),
            if (selected is OvalDrawable)
              ..._buildOvalControls(selected as OvalDrawable),
            if (selected is ConstrainedTextDrawable)
              ..._buildConstrainedTextControls(
                selected as ConstrainedTextDrawable,
              ),
            if (selected is TextDrawable)
              ..._buildPlainTextControls(selected as TextDrawable),
            if (selected is BarcodeDrawable)
              ..._buildBarcodeControls(selected as BarcodeDrawable),
            if (selected is TableDrawable && selectionFocusCell != null)
              ..._buildTableSizeControls(selected as TableDrawable),
            if (selected is TableDrawable && cellSelectionRange != null)
              ..._buildTableBackgroundControls(context, selected as TableDrawable),
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
      ArrowKeySlider(
        min: 1,
        max: 24,
        value: strokeWidth,
        onChanged: (v) => onApplyStroke(newStrokeWidth: v),
      ),
      const SizedBox(height: 12),
      const Text('Corner Radius'),
      ArrowKeySlider(
        min: 0,
        max: 40,
        value: r.borderRadius.topLeft.x.clamp(0.0, 40.0),
        onChanged: (v) => onApplyStroke(newCornerRadius: v),
      ),
    ];
  }

  List<Widget> _buildOvalControls(OvalDrawable o) {
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
      ArrowKeySlider(
        min: 1,
        max: 24,
        value: strokeWidth,
        onChanged: (v) => onApplyStroke(newStrokeWidth: v),
      ),
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
    tool.TxtAlign currentAlign = td.align;
    double currentMaxWidth = td.maxWidth;
    double currentAngle = td.rotationAngle;

    void commitAll() {
      this.mutateSelected((d) {
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
        controller: controller,
        minLines: 1,
        maxLines: 6,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onSubmitted: (_) => commitAll(),
        onChanged: (_) => commitAll(),
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
                commitAll();
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
                commitAll();
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
              commitAll();
            },
          ),
          FilterChip(
            label: const Text('Italic'),
            selected: currentItalic,
            onSelected: (v) {
              currentItalic = v;
              commitAll();
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
            items: [
              DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
              DropdownMenuItem(value: 'NotoSans', child: Text('NotoSans')),
              DropdownMenuItem(value: 'Monospace', child: Text('Monospace')),
            ],
            onChanged: (v) {
              if (v != null) {
                currentFamily = v;
                commitAll();
              }
            },
          ),
        ],
      ),
      Row(
        children: [
          const Text('Align'),
          const SizedBox(width: 8),
          DropdownButton<tool.TxtAlign>(
            value: currentAlign,
            items: [
              DropdownMenuItem(value: tool.TxtAlign.left, child: Text('Left')),
              DropdownMenuItem(
                value: tool.TxtAlign.center,
                child: Text('Center'),
              ),
              DropdownMenuItem(
                value: tool.TxtAlign.right,
                child: Text('Right'),
              ),
            ],
            onChanged: (v) {
              if (v != null) {
                currentAlign = v;
                commitAll();
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
                commitAll();
              },
            ),
          ),
          SizedBox(width: 56, child: Text(currentMaxWidth.toStringAsFixed(0))),
        ],
      ),

      Row(
        children: [
          const Text('Rotation'),
          IconButton(
            icon: const Icon(Icons.rotate_left),
            tooltip: 'Rotate -90°',
            onPressed: () {
              currentAngle = ((currentAngle - (math.pi / 2)) % (2 * math.pi));
              commitAll();
            },
          ),
          IconButton(
            icon: const Icon(Icons.rotate_right),
            tooltip: 'Rotate +90°',
            onPressed: () {
              currentAngle = ((currentAngle + (math.pi / 2)) % (2 * math.pi));
              commitAll();
            },
          ),
          Expanded(
            child: ArrowKeySlider(
              min: _angleMin,
              max: _angleMax,
              value: currentAngle.clamp(_angleMin, _angleMax),
              onChanged: (v) {
                currentAngle = v;
                commitAll();
              },
              step: (math.pi / 180),
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
    bool currentBold =
        (td.style.fontWeight ?? FontWeight.normal) == FontWeight.bold;
    bool currentItalic =
        (td.style.fontStyle ?? FontStyle.normal) == FontStyle.italic;
    String currentFamily = td.style.fontFamily ?? textDefaults.fontFamily;
    double currentAngle = td.rotationAngle;

    void commitAll() {
      this.mutateSelected((d) {
        final cur = d as TextDrawable;
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
          rotation: currentAngle,
        );
      });
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
        onSubmitted: (_) => commitAll(),
        onChanged: (_) => commitAll(),
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
                commitAll();
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
                commitAll();
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
              commitAll();
            },
          ),
          FilterChip(
            label: const Text('Italic'),
            selected: currentItalic,
            onSelected: (v) {
              currentItalic = v;
              commitAll();
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
            items: [
              DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
              DropdownMenuItem(value: 'NotoSans', child: Text('NotoSans')),
              DropdownMenuItem(value: 'Monospace', child: Text('Monospace')),
            ],
            onChanged: (v) {
              if (v != null) {
                currentFamily = v;
                commitAll();
              }
            },
          ),
        ],
      ),
      Row(
        children: [
          const Text('Angle'),
          IconButton(
            icon: const Icon(Icons.rotate_right),
            tooltip: 'Rotate 90°',
            onPressed: () {
              currentAngle = ((currentAngle + (math.pi / 2)) % (2 * math.pi));
              commitAll();
            },
          ),
          Expanded(
            child: Slider(
              min: _angleMin,
              max: _angleMax,
              value: currentAngle.clamp(_angleMin, _angleMax),
              onChanged: (v) {
                currentAngle = v;
                commitAll();
              },
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
  static String _barcodeLabel(BarcodeType type) =>
      _barcodeLabels[type] ?? type.name;

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
    double currentMaxWidth = clampWidth(
      autoMaxWidth ? barcode.size.width : barcode.maxTextWidth,
    );

    void commitAll() {
      this.mutateSelected((d) {
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
          IconButton(
            icon: const Icon(Icons.rotate_right),
            tooltip: 'Rotate 90°',
            onPressed: () {
              currentAngle = ((currentAngle + (math.pi / 2)) % (2 * math.pi));
              commitAll();
            },
          ),
          Expanded(
            child: Slider(
              min: _angleMin,
              max: _angleMax,
              value: currentAngle.clamp(_angleMin, _angleMax),
              onChanged: (v) {
                currentAngle = v;
                commitAll();
              },
            ),
          ),
          SizedBox(width: 44, child: Text(_degLabel(currentAngle))),
        ],
      ),
      const SizedBox(height: 8),
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
          commitAll();
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
              for (final t in _barcodeTypes)
                DropdownMenuItem(value: t, child: Text(_barcodeLabel(t))),
            ],
            onChanged: (v) {
              if (v != null) {
                currentType = v;
                commitAll();
              }
            },
          ),
        ],
      ),
      SwitchListTile(
        value: showValue,
        onChanged: (v) {
          showValue = v;
          commitAll();
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
                commitAll();
              },
            ),
          ),
          SizedBox(width: 48, child: Text(currentFontSize.toStringAsFixed(0))),
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
              commitAll();
            },
          ),
          FilterChip(
            label: const Text('Italic'),
            selected: currentItalic,
            onSelected: (v) {
              currentItalic = v;
              commitAll();
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
            items: [
              DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
              DropdownMenuItem(value: 'NotoSans', child: Text('NotoSans')),
              DropdownMenuItem(value: 'Monospace', child: Text('Monospace')),
            ],
            onChanged: (v) {
              if (v != null) {
                currentFamily = v;
                commitAll();
              }
            },
          ),
        ],
      ),
      Row(
        children: [
          const Text('Align'),
          const SizedBox(width: 8),
          DropdownButton<TextAlign?>(
            value: currentAlign,
            items: [
              DropdownMenuItem(value: null, child: Text('Auto')),
              DropdownMenuItem(value: TextAlign.left, child: Text('Left')),
              DropdownMenuItem(value: TextAlign.center, child: Text('Center')),
              DropdownMenuItem(value: TextAlign.right, child: Text('Right')),
            ],
            onChanged: (v) {
              currentAlign = v;
              commitAll();
            },
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
      this.mutateSelected((d) {
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
            onPressed: () {
              currentAngle = ((currentAngle + (math.pi / 2)) % (2 * math.pi));
              commitAll();
            },
          ),
          Expanded(
            child: Slider(
              min: _angleMin,
              max: _angleMax,
              value: currentAngle.clamp(_angleMin, _angleMax),
              onChanged: (v) {
                currentAngle = v;
                commitAll();
              },
            ),
          ),
          SizedBox(width: 44, child: Text(_degLabel(currentAngle))),
        ],
      ),
      const SizedBox(height: 8),
      const Text('Stroke Color'),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in _swatchColors)
            ColorDot(
              color: c,
              selected: currentStrokeColor == c,
              onTap: () {
                currentStrokeColor = c;
                commitAll();
              },
            ),
        ],
      ),
      const SizedBox(height: 12),
      const Text('Stroke Width'),
      ArrowKeySlider(
        min: 0,
        max: 16,
        value: currentStrokeWidth,
        onChanged: (v) {
          currentStrokeWidth = v;
          commitAll();
        },
      ),
      const SizedBox(height: 12),
      const Text('Corner Radius'),
      ArrowKeySlider(
        min: 0,
        max: 40,
        value: currentRadius.clamp(0.0, 40.0),
        onChanged: (v) {
          currentRadius = v;
          commitAll();
        },
      ),
    ];
  }

  List<Widget> _buildLineLikeRotation(ObjectDrawable od) {
    double currentAngle = od.rotationAngle;
    void commitRotation() {
      this.mutateSelected((d) {
        if (d is LineDrawable) return d.copyWith(rotation: currentAngle);
        if (d is ArrowDrawable) return d.copyWith(rotation: currentAngle);
        return d;
      });
    }

    return [
      const SizedBox(height: 12),

      const SizedBox(height: 12),
      const Text('Rotation'),
      Row(
        children: [
          IconButton(
            icon: const Icon(Icons.rotate_left),
            tooltip: 'Rotate -90°',
            onPressed: () {
              currentAngle = ((currentAngle - (math.pi / 2)) % (2 * math.pi));
              commitRotation();
            },
          ),
          Expanded(
            child: ArrowKeySlider(
              min: _angleMin,
              max: _angleMax,
              value: currentAngle.clamp(_angleMin, _angleMax),
              onChanged: (v) {
                currentAngle = v;
                commitRotation();
              },
              step: (math.pi / 180), // 1°
            ),
          ),
          IconButton(
            icon: const Icon(Icons.rotate_right),
            tooltip: 'Rotate +90°',
            onPressed: () {
              currentAngle = ((currentAngle + (math.pi / 2)) % (2 * math.pi));
              commitRotation();
            },
          ),
          SizedBox(width: 44, child: Text(_degLabel(currentAngle))),
        ],
      ),

      const SizedBox(height: 12),
      const Text('Stroke Color'),
      const SizedBox(height: 4),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in _swatchColors)
            ColorDot(
              color: c,
              onTap: () {
                this.mutateSelected((d) {
                  if (d is LineDrawable) {
                    return d.copyWith(paint: d.paint.copyWith(color: c));
                  }
                  if (d is ArrowDrawable) {
                    return d.copyWith(paint: d.paint.copyWith(color: c));
                  }
                  return d;
                });
              },
            ),
        ],
      ),
      const SizedBox(height: 12),
      const Text('Stroke Width'),
      ArrowKeySlider(
        min: 1,
        max: 24,
        value: (selected is LineDrawable
            ? (selected as LineDrawable).paint.strokeWidth
            : (selected as ArrowDrawable).paint.strokeWidth),
        onChanged: (v) {
          this.mutateSelected((d) {
            if (d is LineDrawable) {
              return d.copyWith(paint: d.paint.copyWith(strokeWidth: v));
            }
            if (d is ArrowDrawable) {
              return d.copyWith(paint: d.paint.copyWith(strokeWidth: v));
            }
            return d;
          });
        },
      ),
    ];
  }

  List<Widget> _buildTableSizeControls(TableDrawable table) {
    final int? selRow = selectionFocusCell?.$1;
    final int? selCol = selectionFocusCell?.$2;
    final double pxPerCm = printerDpi / 2.54;

    double _currentRowCm() {
      if (selRow == null) return 0.0;
      double sum = 0.0;
      for (final v in table.rowFractions) {
        if (v.isFinite && v > 0) sum += v;
      }
      final double h = (sum > 0)
          ? table.size.height *
                (table.rowFractions[selRow.clamp(0, table.rows - 1)] / sum)
          : (table.size.height / math.max(1, table.rows));
      return h / pxPerCm;
    }

    double _currentColCm() {
      if (selCol == null) return 0.0;
      double sum = 0.0;
      for (final v in table.columnFractions) {
        if (v.isFinite && v > 0) sum += v;
      }
      final double w = (sum > 0)
          ? table.size.width *
                (table.columnFractions[selCol.clamp(0, table.columns - 1)] /
                    sum)
          : (table.size.width / math.max(1, table.columns));
      return w / pxPerCm;
    }

    final rowCtrl = TextEditingController(
      text: selRow == null ? '' : _currentRowCm().toStringAsFixed(2),
    );
    final colCtrl = TextEditingController(
      text: selCol == null ? '' : _currentColCm().toStringAsFixed(2),
    );

    Widget _rowField() => Row(
      children: [
        SizedBox(
          width: 48,
          child: const Text('행 높이', style: TextStyle(fontSize: 12.0)),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: TextField(
            controller: rowCtrl,
            enabled: selRow != null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
            ],
            decoration: const InputDecoration(
              suffixText: 'cm',
              suffixStyle: TextStyle(fontSize: 12.0),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) {
              final v = double.tryParse(rowCtrl.text);
              if (v == null || v <= 0 || selRow == null) return;
              final double targetPx = v * pxPerCm;
              this.mutateSelected((d) {
                if (d is! TableDrawable) return d;
                final TableDrawable t = d;

                // Sample current per-row pixel heights using actual layout
                final List<double> rowPx = List<double>.generate(
                  math.max(1, t.rows),
                  (rr) => t.localCellRect(rr, 0, t.size).height,
                  growable: false,
                );

                final int r = selRow.clamp(0, t.rows - 1);
                final double h0 = t.size.height;
                rowPx[r] = targetPx;
                final double h1 = rowPx
                    .fold(0.0, (a, b) => a + b)
                    .clamp(1.0, double.infinity);

                // Convert back to fractions (others preserved exactly)
                final List<double> newRowFractions = rowPx
                    .map((h) => h / h1)
                    .toList();

                // Keep top-left anchored relative to canvas (account rotation)
                final double w0 = t.size.width;
                final double w1 = w0;
                final double dx = (w1 - w0) / 2.0;
                final double dy = (h1 - h0) / 2.0;
                final double ang = t.rotationAngle;
                final double cosA = math.cos(ang);
                final double sinA = math.sin(ang);
                final Offset delta = Offset(
                  dx * cosA - dy * sinA,
                  dx * sinA + dy * cosA,
                );

                return t.copyWith(
                  size: Size(w1, h1),
                  position: t.position + delta,
                  rowFractions: newRowFractions,
                );
              });
            },
          ),
        ),
      ],
    );

    Widget _colField() => Row(
      children: [
        SizedBox(
          width: 48,
          child: const Text('열 너비', style: TextStyle(fontSize: 12.0)),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: TextField(
            controller: colCtrl,
            enabled: selCol != null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
            ],
            decoration: const InputDecoration(
              suffixText: 'cm',
              suffixStyle: TextStyle(fontSize: 12.0),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) {
              final v = double.tryParse(colCtrl.text);
              if (v == null || v <= 0 || selCol == null) return;
              final double targetPx = v * pxPerCm;
              this.mutateSelected((d) {
                if (d is! TableDrawable) return d;
                final TableDrawable t = d;

                double sum = 0.0;
                for (final x in t.columnFractions) {
                  if (x.isFinite && x > 0) sum += x;
                }
                final List<double> colPx = (sum > 0)
                    ? t.columnFractions
                          .map((f) => t.size.width * (f / sum))
                          .toList()
                    : List<double>.filled(
                        math.max(1, t.columns),
                        t.size.width / math.max(1, t.columns),
                      );

                final int c = selCol.clamp(0, t.columns - 1);
                final double w0 = t.size.width;
                colPx[c] = targetPx;
                final double w1 = colPx
                    .fold(0.0, (a, b) => a + b)
                    .clamp(1.0, double.infinity);
                final List<double> newColFractions = colPx
                    .map((w) => w / w1)
                    .toList();

                // Keep top-left anchored, account rotation
                final double h0 = t.size.height;
                final double h1 = h0;
                final double dx = (w1 - w0) / 2.0;
                final double dy = (h1 - h0) / 2.0;
                final double ang = t.rotationAngle;
                final double cosA = math.cos(ang);
                final double sinA = math.sin(ang);
                final Offset delta = Offset(
                  dx * cosA - dy * sinA,
                  dx * sinA + dy * cosA,
                );

                return t.copyWith(
                  size: Size(w1, h1),
                  position: t.position + delta,
                  columnFractions: newColFractions,
                );
              });
            },
          ),
        ),
      ],
    );

    final selection = cellSelectionRange;
    final Set<(int, int)> rootCells = <(int, int)>{};
    if (selection != null) {
      for (int r = selection.topRow; r <= selection.bottomRow; r++) {
        for (int c = selection.leftCol; c <= selection.rightCol; c++) {
          rootCells.add(table.resolveRoot(r, c));
        }
      }
    } else if (selRow != null && selCol != null) {
      rootCells.add(table.resolveRoot(selRow, selCol));
    }
    final List<(int, int)> targetCells = rootCells.toList();

    (int, int, int, int) cellBounds(TableDrawable src, (int, int) cell) {
      final span = src.spanForRoot(cell.$1, cell.$2);
      final rowSpan = span?.rowSpan ?? 1;
      final colSpan = span?.colSpan ?? 1;
      final rowStart = cell.$1;
      final colStart = cell.$2;
      return (
        rowStart,
        rowStart + rowSpan - 1,
        colStart,
        colStart + colSpan - 1,
      );
    }

    bool touchesTop(TableDrawable src, (int, int) cell) {
      final range = selection;
      if (range == null) return true;
      final (rowStart, rowEnd, _, _) = cellBounds(src, cell);
      return rowStart <= range.topRow && rowEnd >= range.topRow;
    }

    bool touchesBottom(TableDrawable src, (int, int) cell) {
      final range = selection;
      if (range == null) return true;
      final (rowStart, rowEnd, _, _) = cellBounds(src, cell);
      return rowStart <= range.bottomRow && rowEnd >= range.bottomRow;
    }

    bool touchesLeft(TableDrawable src, (int, int) cell) {
      final range = selection;
      if (range == null) return true;
      final (_, _, colStart, colEnd) = cellBounds(src, cell);
      return colStart <= range.leftCol && colEnd >= range.leftCol;
    }

    bool touchesRight(TableDrawable src, (int, int) cell) {
      final range = selection;
      if (range == null) return true;
      final (_, _, colStart, colEnd) = cellBounds(src, cell);
      return colStart <= range.rightCol && colEnd >= range.rightCol;
    }

    // 실효 두께(렌더링 기준: 이웃 변과의 max)를 계산하여 범위 전체가 동일하면 값을, 아니면 null(혼합)을 반환
    double? uniformEffectiveThicknessForSide(
      String side, // 'top' | 'bottom' | 'left' | 'right'
      bool Function(TableDrawable, (int, int)) include,
    ) {
      double? value;
      var hasAny = false;
      for (final cell in targetCells) {
        if (!include(table, cell)) continue;
        hasAny = true;
        final (rowStart, rowEnd, colStart, colEnd) = cellBounds(table, cell);
        if (side == 'top') {
          // boundaryRow = rowStart
          for (int c = colStart; c <= colEnd; c++) {
            final selfT = table.borderOf(cell.$1, cell.$2).top;
            double neighborB = 0.0;
            final nr = rowStart - 1;
            if (nr >= 0) {
              final neigh = table.resolveRoot(nr, c);
              neighborB = table.borderOf(neigh.$1, neigh.$2).bottom;
            }
            final eff = math.max(selfT, neighborB);
            if (value == null) value = eff;
            else if ((value - eff).abs() > 1e-3) return null;
          }
        } else if (side == 'bottom') {
          // boundaryRow = rowEnd + 1
          for (int c = colStart; c <= colEnd; c++) {
            final selfB = table.borderOf(cell.$1, cell.$2).bottom;
            double neighborT = 0.0;
            final nr = rowEnd + 1;
            if (nr < table.rows) {
              final neigh = table.resolveRoot(nr, c);
              neighborT = table.borderOf(neigh.$1, neigh.$2).top;
            }
            final eff = math.max(selfB, neighborT);
            if (value == null) value = eff;
            else if ((value - eff).abs() > 1e-3) return null;
          }
        } else if (side == 'left') {
          // boundaryColumn = colStart
          for (int r = rowStart; r <= rowEnd; r++) {
            final selfL = table.borderOf(cell.$1, cell.$2).left;
            double neighborR = 0.0;
            final nc = colStart - 1;
            if (nc >= 0) {
              final neigh = table.resolveRoot(r, nc);
              neighborR = table.borderOf(neigh.$1, neigh.$2).right;
            }
            final eff = math.max(selfL, neighborR);
            if (value == null) value = eff;
            else if ((value - eff).abs() > 1e-3) return null;
          }
        } else if (side == 'right') {
          // boundaryColumn = colEnd + 1
          for (int r = rowStart; r <= rowEnd; r++) {
            final selfR = table.borderOf(cell.$1, cell.$2).right;
            double neighborL = 0.0;
            final nc = colEnd + 1;
            if (nc < table.columns) {
              final neigh = table.resolveRoot(r, nc);
              neighborL = table.borderOf(neigh.$1, neigh.$2).left;
            }
            final eff = math.max(selfR, neighborL);
            if (value == null) value = eff;
            else if ((value - eff).abs() > 1e-3) return null;
          }
        }
      }
      return hasAny ? value : null;
    }

    double snapThickness(double value) => (value * 10).roundToDouble() / 10.0;

    void applyBorders({
      double? top,
      double? bottom,
      double? left,
      double? right,
    }) {
      if (targetCells.isEmpty) return;
      final cells = List<(int, int)>.from(targetCells);
      this.mutateSelected((d) {
        if (d is! TableDrawable) return d;
        final next = d.copyWith();
        for (final cell in cells) {
          final bool applyTop = top != null && touchesTop(next, cell);
          final bool applyBottom = bottom != null && touchesBottom(next, cell);
          final bool applyLeft = left != null && touchesLeft(next, cell);
          final bool applyRight = right != null && touchesRight(next, cell);
          if (!(applyTop || applyBottom || applyLeft || applyRight)) continue;
          next.updateBorderThickness(
            cell.$1,
            cell.$2,
            top: applyTop ? top : null,
            bottom: applyBottom ? bottom : null,
            left: applyLeft ? left : null,
            right: applyRight ? right : null,
          );
        }
        return next;
      });
    }

  final double? uniformTop = uniformEffectiveThicknessForSide('top', touchesTop);
  final double? uniformBottom = uniformEffectiveThicknessForSide('bottom', touchesBottom);
  final double? uniformLeft = uniformEffectiveThicknessForSide('left', touchesLeft);
  final double? uniformRight = uniformEffectiveThicknessForSide('right', touchesRight);
    final topController = TextEditingController(
      text: uniformTop == null ? '' : uniformTop.toStringAsFixed(1),
    );
    final bottomController = TextEditingController(
      text: uniformBottom == null ? '' : uniformBottom.toStringAsFixed(1),
    );
    final leftController = TextEditingController(
      text: uniformLeft == null ? '' : uniformLeft.toStringAsFixed(1),
    );
    final rightController = TextEditingController(
      text: uniformRight == null ? '' : uniformRight.toStringAsFixed(1),
    );

    void submitBorder(
      TextEditingController controller,
      void Function(double value) apply,
    ) {
      final raw = double.tryParse(controller.text);
      if (raw == null) return;
      final sanitized = snapThickness(raw.clamp(0.0, 24.0));
      controller.text = sanitized.toStringAsFixed(1);
      apply(sanitized);
    }

    // 기존 borderField는 통합 UI로 대체되어 제거되었습니다.

    // ==== 안쪽 여백(cm) + 테두리 두께(px) + 선 종류(콤보) 통합 행 ====
    // 두 입력박스와 콤보박스 위에는 별도의 헤더 라벨을 추가
    Widget _borderHeaderRow() {
      const labelStyle = TextStyle(
        color: Colors.black54,
        fontWeight: FontWeight.w500,
        fontSize: 12.0,
      );
      return Row(
        children: [
          const SizedBox(width: 48), // side label 자리
          const SizedBox(width: 8),
          SizedBox(width: 72, child: Text('안쪽 여백', style: labelStyle)),
          const SizedBox(width: 8),
          SizedBox(width: 72, child: Text('테두리 두께', style: labelStyle)),
          const SizedBox(width: 8),
          Expanded(child: Text('선 종류', style: labelStyle)),
        ],
      );
    }

    Widget borderWithStyleRow({
      required String label,
      required TextEditingController padController,
      required void Function(double valuePx) applyPadding,
      required TextEditingController controller,
      required void Function(double value) applyThickness,
      required CellBorderStyle? uniformStyle,
      required void Function(CellBorderStyle style) applyStyle,
    }) {
      void submitThickness() => submitBorder(controller, applyThickness);
      void submitPad() {
        final raw = double.tryParse(padController.text);
        if (raw == null) return;
        final double valuePx = (pxPerCm > 0 ? raw * pxPerCm : raw)
            .clamp(0.0, 400.0);
        applyPadding(valuePx);
        final shown = (pxPerCm > 0 ? (valuePx / pxPerCm) : valuePx)
            .toStringAsFixed(2);
        padController.text = shown;
      }
      return Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.0),
            ),
          ),
          const SizedBox(width: 8),
          // 안쪽 여백(cm)
          SizedBox(
            width: 72,
            child: TextField(
              controller: padController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
              ],
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                suffixText: 'cm',
                suffixStyle: TextStyle(fontSize: 12.0),
              ),
              onSubmitted: (_) => submitPad(),
              onEditingComplete: submitPad,
            ),
          ),
          const SizedBox(width: 8),
          // 테두리 두께(px)
          SizedBox(
            width: 72,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
              ],
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                suffixText: 'px',
                suffixStyle: TextStyle(fontSize: 12.0),
              ),
              onSubmitted: (_) => submitThickness(),
              onEditingComplete: submitThickness,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<CellBorderStyle>(
              isExpanded: true,
              value: uniformStyle,
              hint: const Text('혼합', style: TextStyle(fontSize: 12.0)),
              items: const [
                DropdownMenuItem(
                  value: CellBorderStyle.solid,
                  child: Text('실선', style: TextStyle(fontSize: 12.0)),
                ),
                DropdownMenuItem(
                  value: CellBorderStyle.dashed,
                  child: Text('점선', style: TextStyle(fontSize: 12.0)),
                ),
              ],
              onChanged: (v) {
                if (v != null) applyStyle(v);
              },
            ),
          ),
        ],
      );
    }

    // 혼합/단일 '실제 표시 스타일' 판별 (인접 셀의 반대편 변도 고려)
    CellBorderStyle? uniformEffectiveStyleForSide(
      String side, // 'top' | 'bottom' | 'left' | 'right'
      bool Function(TableDrawable, (int, int)) include,
    ) {
      CellBorderStyle? value;
      var hasAny = false;
      for (final cell in targetCells) {
        if (!include(table, cell)) continue;
        hasAny = true;
        final (rowStart, rowEnd, colStart, colEnd) = cellBounds(table, cell);
        // 현재 루트 셀의 해당 변 스타일
        CellBorderStyle current = switch (side) {
          'top' => table.borderStyleOf(cell.$1, cell.$2).top,
          'bottom' => table.borderStyleOf(cell.$1, cell.$2).bottom,
          'left' => table.borderStyleOf(cell.$1, cell.$2).left,
          'right' => table.borderStyleOf(cell.$1, cell.$2).right,
          _ => CellBorderStyle.solid,
        };

        // 인접 셀의 반대편 변 스타일 고려 (하나라도 dashed면 dashed)
        if (side == 'top') {
          final nr = rowStart - 1;
          if (nr >= 0) {
            for (int c = colStart; c <= colEnd; c++) {
              final neigh = table.resolveRoot(nr, c);
              if (table.borderStyleOf(neigh.$1, neigh.$2).bottom == CellBorderStyle.dashed) {
                current = CellBorderStyle.dashed;
                break;
              }
            }
          }
        } else if (side == 'bottom') {
          final nr = rowEnd + 1;
          if (nr < table.rows) {
            for (int c = colStart; c <= colEnd; c++) {
              final neigh = table.resolveRoot(nr, c);
              if (table.borderStyleOf(neigh.$1, neigh.$2).top == CellBorderStyle.dashed) {
                current = CellBorderStyle.dashed;
                break;
              }
            }
          }
        } else if (side == 'left') {
          final nc = colStart - 1;
          if (nc >= 0) {
            for (int r = rowStart; r <= rowEnd; r++) {
              final neigh = table.resolveRoot(r, nc);
              if (table.borderStyleOf(neigh.$1, neigh.$2).right == CellBorderStyle.dashed) {
                current = CellBorderStyle.dashed;
                break;
              }
            }
          }
        } else if (side == 'right') {
          final nc = colEnd + 1;
          if (nc < table.columns) {
            for (int r = rowStart; r <= rowEnd; r++) {
              final neigh = table.resolveRoot(r, nc);
              if (table.borderStyleOf(neigh.$1, neigh.$2).left == CellBorderStyle.dashed) {
                current = CellBorderStyle.dashed;
                break;
              }
            }
          }
        }

        if (value == null) {
          value = current;
        } else if (value != current) {
          return null; // 혼합
        }
      }
      return hasAny ? value : null;
    }

    void applyBorderStyles({
      CellBorderStyle? top,
      CellBorderStyle? bottom,
      CellBorderStyle? left,
      CellBorderStyle? right,
    }) {
      if (targetCells.isEmpty) return;
      final cells = List<(int, int)>.from(targetCells);
      this.mutateSelected((d) {
        if (d is! TableDrawable) return d;
        final next = d.copyWith();
        for (final cell in cells) {
          final bool applyTop = top != null && touchesTop(next, cell);
          final bool applyBottom = bottom != null && touchesBottom(next, cell);
          final bool applyLeft = left != null && touchesLeft(next, cell);
          final bool applyRight = right != null && touchesRight(next, cell);
          if (!(applyTop || applyBottom || applyLeft || applyRight)) continue;
          next.updateBorderStyle(
            cell.$1,
            cell.$2,
            top: applyTop ? top : null,
            bottom: applyBottom ? bottom : null,
            left: applyLeft ? left : null,
            right: applyRight ? right : null,
          );
        }
        return next;
      });
    }

    // 기존 styleRow는 통합 UI로 대체되어 제거되었습니다.

    // 안쪽 여백(cm) 관련 헬퍼 및 컨트롤러를 먼저 준비
    double? uniformPaddingFor(double Function(CellPadding) pick) {
      double? value;
      for (final cell in targetCells) {
        final current = pick(table.paddingOf(cell.$1, cell.$2));
        if (value == null) {
          value = current;
        } else if ((value - current).abs() > 1e-3) {
          return null;
        }
      }
      return value;
    }

  double cmFromPx(double value) => pxPerCm > 0 ? value / pxPerCm : value;

    void applyPadding({
      double? top,
      double? bottom,
      double? left,
      double? right,
    }) {
      if (targetCells.isEmpty) return;
      final cells = List<(int, int)>.from(targetCells);
      this.mutateSelected((d) {
        if (d is! TableDrawable) return d;
        final next = d.copyWith();
        next.updatePaddingForCells(
          cells,
          top: top,
          bottom: bottom,
          left: left,
          right: right,
        );
        return next;
      });
    }

    final double? uniformPadTopPx = uniformPaddingFor((p) => p.top);
    final double? uniformPadBottomPx = uniformPaddingFor((p) => p.bottom);
    final double? uniformPadLeftPx = uniformPaddingFor((p) => p.left);
    final double? uniformPadRightPx = uniformPaddingFor((p) => p.right);
    final padTopController = TextEditingController(
      text: uniformPadTopPx == null
          ? ''
          : cmFromPx(uniformPadTopPx).toStringAsFixed(2),
    );
    final padBottomController = TextEditingController(
      text: uniformPadBottomPx == null
          ? ''
          : cmFromPx(uniformPadBottomPx).toStringAsFixed(2),
    );
    final padLeftController = TextEditingController(
      text: uniformPadLeftPx == null
          ? ''
          : cmFromPx(uniformPadLeftPx).toStringAsFixed(2),
    );
    final padRightController = TextEditingController(
      text: uniformPadRightPx == null
          ? ''
          : cmFromPx(uniformPadRightPx).toStringAsFixed(2),
    );

    final List<Widget> borderControls = targetCells.isEmpty
        ? const []
        : [
            const SizedBox(height: 12),
            const Divider(),
            const Text(
              '셀 테두리',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _borderHeaderRow(),
            const SizedBox(height: 6),
            borderWithStyleRow(
              label: '위',
              padController: padTopController,
              applyPadding: (v) => applyPadding(top: v),
              controller: topController,
              applyThickness: (v) => applyBorders(top: v),
              uniformStyle: uniformEffectiveStyleForSide('top', touchesTop),
              applyStyle: (st) => applyBorderStyles(top: st),
            ),
            const SizedBox(height: 8),
            borderWithStyleRow(
              label: '아래',
              padController: padBottomController,
              applyPadding: (v) => applyPadding(bottom: v),
              controller: bottomController,
              applyThickness: (v) => applyBorders(bottom: v),
              uniformStyle: uniformEffectiveStyleForSide('bottom', touchesBottom),
              applyStyle: (st) => applyBorderStyles(bottom: st),
            ),
            const SizedBox(height: 8),
            borderWithStyleRow(
              label: '왼쪽',
              padController: padLeftController,
              applyPadding: (v) => applyPadding(left: v),
              controller: leftController,
              applyThickness: (v) => applyBorders(left: v),
              uniformStyle: uniformEffectiveStyleForSide('left', touchesLeft),
              applyStyle: (st) => applyBorderStyles(left: st),
            ),
            const SizedBox(height: 8),
            borderWithStyleRow(
              label: '오른쪽',
              padController: padRightController,
              applyPadding: (v) => applyPadding(right: v),
              controller: rightController,
              applyThickness: (v) => applyBorders(right: v),
              uniformStyle: uniformEffectiveStyleForSide('right', touchesRight),
              applyStyle: (st) => applyBorderStyles(right: st),
            ),
          ];

    return [
      const SizedBox(height: 12),
      const Divider(),
      const Text(
        '표 크기 (선택된 셀 기준)',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      _rowField(),
      const SizedBox(height: 8),
      _colField(),
  ...borderControls,
    ];
  }


List<Widget> _buildTableBackgroundControls(BuildContext context, TableDrawable table) {
  final selection = cellSelectionRange;
  if (selection == null) return const [];
  // root 셀 추출
  final roots = <String, (int,int)>{};
  for (int r = selection.topRow; r <= selection.bottomRow; r++) {
    for (int c = selection.leftCol; c <= selection.rightCol; c++) {
      final root = table.resolveRoot(r, c);
      roots["${root.$1},${root.$2}"] = root;
    }
  }

  // 현재 색상(전부 동일하면 그 색, 아니면 null=혼합)
  Color? current;
  for (final rc in roots.values) {
    final bg = table.backgroundColorOf(rc.$1, rc.$2);
    if (current == null) {
      current = bg;
    } else {
      if ((bg?.value ?? -1) != (current.value)) {
        current = null;
        break;
      }
    }
  }

  String label;
  if (current == null) {
    label = '혼합';
  } else if (current.alpha == 0) {
    label = '투명';
  } else {
    final hex = current.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    label = '#$hex';
  }

  return [
    const Divider(),
    const Text('셀 바탕색'),
    const SizedBox(height: 6),
    Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: ColorDot(color: current ?? const Color(0x00000000)),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12.0)),
        const Spacer(),
        OutlinedButton(
          onPressed: () async {
            final picked = await showWindowsLikeColorDialog(
              context,
              initialColor: (current ?? Colors.black).withAlpha(255),
              originColor: current ?? Colors.black,
            );
            if (picked != null) {
              this.mutateSelected((d) {
                final t = d as TableDrawable;
                t.setBackgroundForCells(roots.values, picked);
                return t;
              });
            }
          },
          child: const Text('선택'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () {
            this.mutateSelected((d) {
              final t = d as TableDrawable;
              t.setBackgroundForCells(roots.values, null);
              return t;
            });
          },
          child: const Text('투명'),
        ),
      ],
    ),
  ];
}

}




