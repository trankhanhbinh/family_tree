import 'package:flutter/material.dart';

import 'package:familytree/core/ui/portrait_frame.dart';

const Color kPortraitBackground = Color(0xFFE8E8E8);
const Color kPortraitFigure = Color(0xFF8C8C8C);

final Path _shoulders = Path()
  ..moveTo(6, 80)
  ..cubicTo(6, 58, 19, 50, 30, 50)
  ..cubicTo(41, 50, 54, 58, 54, 80)
  ..close();

final Paint _figurePaint = Paint()..color = kPortraitFigure;

void paintPortraitFigure(Canvas canvas, Rect box) {
  canvas.save();
  canvas.clipRect(box);
  canvas.translate(box.left, box.top);
  canvas.scale(box.width / 60, box.height / 80);
  canvas.drawCircle(const Offset(30, 31), 13, _figurePaint);
  canvas.drawPath(_shoulders, _figurePaint);
  canvas.restore();
}

class _FigurePainter extends CustomPainter {
  const _FigurePainter();

  @override
  void paint(Canvas canvas, Size size) {
    paintPortraitFigure(canvas, Offset.zero & size);
  }

  @override
  bool shouldRepaint(_FigurePainter oldDelegate) => false;
}

class DefaultPortrait extends StatelessWidget {
  const DefaultPortrait({super.key, required this.width, required this.accent});

  final double width;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * PortraitFrame.heightRatio,
      decoration: BoxDecoration(
        color: kPortraitBackground,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1),
      ),
      child: const CustomPaint(painter: _FigurePainter()),
    );
  }
}
