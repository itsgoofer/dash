import 'package:flutter/material.dart';

import '../theme/dash_theme.dart';

/// Sci-fi panel: translucent fill, hairline border, four corner brackets and an
/// optional uppercase HUD title row. No backdrop blur — cheap enough to tile.
class HudFrame extends StatelessWidget {
  const HudFrame({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(DashSpace.x3),
  });

  final Widget child;
  final String? title;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _Brackets(DashColors.accent.withValues(alpha: 0.4)),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: DashColors.glassFill,
          borderRadius: DashRadius.br,
          border: Border.all(color: DashColors.glassBorder),
        ),
        child: title == null
            ? child
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Container(width: 3, height: 10, color: DashColors.accent.withValues(alpha: 0.7)),
                    const SizedBox(width: DashSpace.x2),
                    Text(title!, style: DashType.hudLabel),
                  ]),
                  const SizedBox(height: DashSpace.x3),
                  Expanded(child: child),
                ],
              ),
      ),
    );
  }
}

class _Brackets extends CustomPainter {
  _Brackets(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    const l = 10.0;
    final p = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(0, l)
      ..lineTo(0, 0)
      ..lineTo(l, 0)
      ..moveTo(s.width - l, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, l)
      ..moveTo(s.width, s.height - l)
      ..lineTo(s.width, s.height)
      ..lineTo(s.width - l, s.height)
      ..moveTo(l, s.height)
      ..lineTo(0, s.height)
      ..lineTo(0, s.height - l);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_Brackets old) => old.color != color;
}
