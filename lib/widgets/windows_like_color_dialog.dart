// UTF-8 인코딩, 한국어 주석
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Win32 색 대화상자와 유사한 커스텀 컬러 피커
/// - 다이얼로그 높이: 화면 높이의 90%
/// - 좌: 표준색 팔레트(프리셋)
/// - 우: HSV 선택 영역 + 밝기 슬라이더 + RGB/HSV/HEX 입력 + 미리보기
/// - 확인/취소 버튼 제공
Future<Color?> showWindowsLikeColorDialog(
  BuildContext context, {
  required Color initialColor,
  Color? originColor,
}) async {
  return showDialog<Color>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _WindowsLikeColorDialog(
      initialColor: initialColor,
      originColor: originColor ?? initialColor,
    ),
  );
}

class _WindowsLikeColorDialog extends StatefulWidget {
  final Color initialColor;
  final Color originColor;
  const _WindowsLikeColorDialog({
    required this.initialColor,
    required this.originColor,
  });

  @override
  State<_WindowsLikeColorDialog> createState() => _WindowsLikeColorDialogState();
}

class _WindowsLikeColorDialogState extends State<_WindowsLikeColorDialog> {
  // 내부 표현은 HSV로 보관 (value: 0..1)
  late double _h; // 0..360
  late double _s; // 0..1
  late double _v; // 0..1

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _h = hsv.hue;
    _s = hsv.saturation;
    _v = hsv.value;
  }

  Color get _currentColor =>
      HSVColor.fromAHSV(1.0, _h, _s.clamp(0.0, 1.0), _v.clamp(0.0, 1.0))
          .toColor();

  void _setFromRgb(int r, int g, int b) {
    final c = Color.fromARGB(255, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
    final hsv = HSVColor.fromColor(c);
    setState(() {
      _h = hsv.hue;
      _s = hsv.saturation;
      _v = hsv.value;
    });
  }

  void _setFromHex(String hex) {
    final v = _parseHex(hex);
    if (v != null) {
      _setFromRgb(v.red, v.green, v.blue);
    }
  }

  static Color? _parseHex(String input) {
    var s = input.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) {
      final intVal = int.tryParse(s, radix: 16);
      if (intVal == null) return null;
      return Color(0xFF000000 | intVal);
    } else if (s.length == 8) {
      final intVal = int.tryParse(s, radix: 16);
      if (intVal == null) return null;
      return Color(intVal);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final dialogH = screenH * 0.9;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: dialogH,
          maxWidth: 980,
          minWidth: 820,
          minHeight: 600,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Row(
                children: [
                  // 좌측: 표준색 팔레트
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _PresetPalette(
                        onPick: (c) {
                          final hsv = HSVColor.fromColor(c);
                          setState(() {
                            _h = hsv.hue;
                            _s = hsv.saturation;
                            _v = hsv.value;
                          });
                        },
                        selected: _currentColor,
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  // 우측: HSV 영역 + 슬라이더 + 입력 + 미리보기
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Expanded(
                            child: _HueSatPicker(
                              hue: _h,
                              sat: _s,
                              val: _v,
                              onChanged: (h, s) => setState(() {
                                _h = h;
                                _s = s;
                              }),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text('밝기'),
                              Expanded(
                                child: Slider(
                                  value: _v,
                                  onChanged: (v) => setState(() => _v = v),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _RgbHexInputs(
                            color: _currentColor,
                            onRgbChanged: _setFromRgb,
                            onHexChanged: _setFromHex,
                          ),
                          const SizedBox(height: 12),
                          _PreviewRow(
                            original: widget.originColor,
                            current: _currentColor,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(null),
                                child: const Text('취소'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => Navigator.of(context)
                                    .pop(_currentColor),
                                child: const Text('확인'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 표준 프리셋 컬러 팔레트(Win32 기본색 유사)
class _PresetPalette extends StatelessWidget {
  final void Function(Color) onPick;
  final Color selected;
  const _PresetPalette({required this.onPick, required this.selected});

  static const List<Color> _preset = [
    // 기본 48색 수준(행 × 열)
    Color(0xFF000000), Color(0xFF7F7F7F), Color(0xFFFFFFFF), Color(0xFFFF0000),
    Color(0xFFFF7F00), Color(0xFFFFFF00), Color(0xFF00FF00), Color(0xFF00FFFF),
    Color(0xFF0000FF), Color(0xFF8B00FF), Color(0xFFFF00FF), Color(0xFF964B00),
    Color(0xFF800000), Color(0xFF808000), Color(0xFF008000), Color(0xFF008080),
    Color(0xFF000080), Color(0xFF800080), Color(0xFF808080), Color(0xFFC0C0C0),
    Color(0xFF999999), Color(0xFFFF6666), Color(0xFFFFCC66), Color(0xFFFFFF66),
    Color(0xFF66FF66), Color(0xFF66FFFF), Color(0xFF6666FF), Color(0xFFCC66FF),
    Color(0xFFFF66FF), Color(0xFFCC9966), Color(0xFFCC0000), Color(0xFFCC6600),
    Color(0xFFCCCC00), Color(0xFF00CC00), Color(0xFF00CCCC), Color(0xFF0000CC),
    Color(0xFF9900CC), Color(0xFFCC00CC), Color(0xFF996633), Color(0xFF660000),
    Color(0xFF666600), Color(0xFF006600), Color(0xFF006666), Color(0xFF000066),
    Color(0xFF660099), Color(0xFF660066), Color(0xFF663300), Color(0xFF333333),
  ];

  @override
  Widget build(BuildContext context) {
    final cols = 8;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('표준 색'),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.6,
            ),
            itemCount: _preset.length,
            itemBuilder: (context, i) {
              final c = _preset[i];
              final sel = c.value == selected.value;
              return InkWell(
                onTap: () => onPick(c),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: sel ? Colors.blue : Colors.black26,
                      width: sel ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: c),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// HSV 선택 영역(좌: Hue x Sat) + 십자 포인터
class _HueSatPicker extends StatefulWidget {
  final double hue;
  final double sat;
  final double val;
  final void Function(double hue, double sat) onChanged;
  const _HueSatPicker({
    required this.hue,
    required this.sat,
    required this.val,
    required this.onChanged,
  });

  @override
  State<_HueSatPicker> createState() => _HueSatPickerState();
}

class _HueSatPickerState extends State<_HueSatPicker> {
  late double _h, _s;

  @override
  void initState() {
    super.initState();
    _h = widget.hue;
    _s = widget.sat;
  }

  @override
  void didUpdateWidget(covariant _HueSatPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _h = widget.hue;
    _s = widget.sat;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return GestureDetector(
          onPanDown: (d) => _handle(d.localPosition, c.biggest),
          onPanUpdate: (d) => _handle(d.localPosition, c.biggest),
          child: CustomPaint(
            size: c.biggest,
            painter: _HueSatPainter(hue: _h, val: widget.val),
            foregroundPainter: _CrosshairPainter(
              x: _s * c.maxWidth,
              y: (1 - (_h / 360.0)) * c.maxHeight,
            ),
          ),
        );
      },
    );
  }

  void _handle(Offset p, Size size) {
    final s = (p.dx / size.width).clamp(0.0, 1.0);
    final h = (360.0 * (1 - (p.dy / size.height))).clamp(0.0, 360.0);
    setState(() {
      _s = s;
      _h = h;
    });
    widget.onChanged(h, s);
  }
}

class _HueSatPainter extends CustomPainter {
  final double hue;
  final double val;
  const _HueSatPainter({required this.hue, required this.val});

  @override
  void paint(Canvas canvas, Size size) {
    // 수직: Hue(360->0), 수평: Saturation(0->1), Value 고정
    final image = _buildGradientImage(size, val);
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImage(image, Offset.zero, paint);
  }

  ui.Image _buildGradientImage(Size size, double v) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();
    final w = size.width;
    final h = size.height;

    // 배경: 흰색->색상 (S)
    final hueColor = HSVColor.fromAHSV(1.0, hue, 1.0, v).toColor();
    final satGrad = LinearGradient(
      colors: [Colors.white, hueColor],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    paint.shader = satGrad;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);

    // 상단: Hue 그라데이션(수직), 아래쪽은 v 유지
    final hueGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: List.generate(7, (i) {
        final hh = 360.0 - i * 60.0;
        return HSVColor.fromAHSV(1.0, hh, 1.0, v).toColor();
      }),
      stops: const [0, 1/6, 2/6, 3/6, 4/6, 5/6, 1],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    paint.shader = hueGrad;
    paint.blendMode = BlendMode.modulate;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);

    return recorder.endRecording().toImageSync(w.toInt(), h.toInt());
  }

  @override
  bool shouldRepaint(covariant _HueSatPainter oldDelegate) {
    return oldDelegate.hue != hue || oldDelegate.val != val;
  }
}

class _CrosshairPainter extends CustomPainter {
  final double x, y;
  const _CrosshairPainter({required this.x, required this.y});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(x, y), 6, p);
    canvas.drawLine(Offset(x - 10, y), Offset(x + 10, y), p);
    canvas.drawLine(Offset(x, y - 10), Offset(x, y + 10), p);
  }

  @override
  bool shouldRepaint(covariant _CrosshairPainter oldDelegate) {
    return oldDelegate.x != x || oldDelegate.y != y;
  }
}

class _RgbHexInputs extends StatelessWidget {
  final Color color;
  final void Function(int r, int g, int b) onRgbChanged;
  final void Function(String hex) onHexChanged;
  const _RgbHexInputs({
    required this.color,
    required this.onRgbChanged,
    required this.onHexChanged,
  });

  @override
  Widget build(BuildContext context) {
    final r = color.red;
    final g = color.green;
    final b = color.blue;

    final hex = '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              const Text('R'),
              const SizedBox(width: 4),
              _NumField(
                initial: r.toString(),
                onChanged: (v) => onRgbChanged(v ?? r, g, b),
              ),
              const SizedBox(width: 8),
              const Text('G'),
              const SizedBox(width: 4),
              _NumField(
                initial: g.toString(),
                onChanged: (v) => onRgbChanged(r, v ?? g, b),
              ),
              const SizedBox(width: 8),
              const Text('B'),
              const SizedBox(width: 4),
              _NumField(
                initial: b.toString(),
                onChanged: (v) => onRgbChanged(r, g, v ?? b),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              const Text('HEX'),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: hex,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: onHexChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final Color original;
  final Color current;
  const _PreviewRow({required this.original, required this.current});

  @override
  Widget build(BuildContext context) {
    Widget swatch(Color c) => Container(
      width: 48,
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        color: c,
      ),
    );

    return Row(
      children: [
        const Text('미리보기'),
        const SizedBox(width: 12),
        Column(
          children: [
            const Text('원본', style: TextStyle(fontSize: 12)),
            swatch(original),
          ],
        ),
        const SizedBox(width: 12),
        Column(
          children: [
            const Text('현재', style: TextStyle(fontSize: 12)),
            swatch(current),
          ],
        ),
      ],
    );
  }
}

class _NumField extends StatelessWidget {
  final String initial;
  final void Function(int? v) onChanged;
  const _NumField({required this.initial, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(text: initial);
    return SizedBox(
      width: 56,
      child: TextField(
        controller: ctrl,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
        ],
        onChanged: (s) {
          final v = int.tryParse(s);
          onChanged(v != null ? v.clamp(0, 255) : null);
        },
      ),
    );
  }
}