import 'package:flutter/material.dart';

class ColorDot extends StatelessWidget {
  const ColorDot({
    super.key,
    required this.color,
    this.selected = false,
    this.showChecker = false,
    this.onTap,
  });

  final Color color;
  final bool selected;
  final bool showChecker;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final displayColor = color.a == 0 && !showChecker ? null : color;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: displayColor,
          border: Border.all(color: selected ? Colors.black : Colors.black26),
          borderRadius: BorderRadius.circular(20),
        ),
        child: color.a == 0 && showChecker
            ? const _CheckerPainterWidget()
            : null,
      ),
    );
  }
}

class _CheckerPainterWidget extends StatelessWidget {
  const _CheckerPainterWidget();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CheckerPainter());
  }
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 4;
    final p1 = Paint()..color = const Color(0xFFE0E0E0);
    final p2 = Paint()..color = const Color(0xFFFFFFFF);
    for (int y = 0; y < 4; y++) {
      for (int x = 0; x < 4; x++) {
        final r = Rect.fromLTWH(x * s, y * s, s, s);
        canvas.drawRect(r, ((x + y) % 2 == 0) ? p1 : p2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
