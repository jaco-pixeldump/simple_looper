import 'package:flutter/material.dart';

class VUPainter extends CustomPainter {
  Color lineColor;
  double width;

  double level = 0;

  VUPainter({this.lineColor, this.level});

  @override
  void paint(Canvas canvas, Size size) {

    Paint line = new Paint()
      ..color = lineColor
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    double offsetX = (100 + level) * 2;

    canvas.drawLine(new Offset(0, 0), new Offset(offsetX, 0), line);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
