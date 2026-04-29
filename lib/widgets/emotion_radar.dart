import 'package:flutter/material.dart';
import 'dart:math';
import '../app/themes/app_colors.dart';
import '../models/emotion_models.dart';

class EmotionRadarChart extends StatelessWidget {
  final EmotionRecord record;
  final Color textColor;

  const EmotionRadarChart({super.key, required this.record, this.textColor = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 120),
      painter: _RadarPainter(record, textColor: textColor),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final EmotionRecord record;
  final Color textColor;

  _RadarPainter(this.record, {this.textColor = AppColors.textSecondary});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 10;

    final dimensions = [
      ('悲伤', record.sadness, AppColors.softPink),
      ('焦虑', record.anxiety, AppColors.softOrange),
      ('愤怒', record.anger, AppColors.angerRed),
      ('孤独', record.loneliness, AppColors.gentlePurple),
      ('开心', record.happiness, AppColors.calmGreen),
      ('平静', record.calmness, AppColors.lightCyan),
      ('压抑', record.suppression, AppColors.warmBeige),
    ];

    final n = dimensions.length;
    final angleStep = 2 * pi / n;

    // 绘制网格
    final gridPaint = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (var i = 1; i <= 3; i++) {
      final path = Path();
      for (var j = 0; j < n; j++) {
        final angle = angleStep * j - pi / 2;
        final r = radius * i / 3;
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);
        if (j == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // 绘制数据区域
    final dataPath = Path();
    final dataPaint = Paint()
      ..color = AppColors.hazeBlue.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = AppColors.hazeBlue.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 0; i < n; i++) {
      final angle = angleStep * i - pi / 2;
      final r = radius * dimensions[i].$2;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) dataPath.moveTo(x, y);
      else dataPath.lineTo(x, y);
    }
    dataPath.close();
    canvas.drawPath(dataPath, dataPaint);
    canvas.drawPath(dataPath, borderPaint);

    // 绘制数据点和标签
    for (var i = 0; i < n; i++) {
      final angle = angleStep * i - pi / 2;
      final r = radius * dimensions[i].$2;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);

      canvas.drawCircle(Offset(x, y), 3, Paint()..color = dimensions[i].$3);

      // 标签
      final labelR = radius + 16;
      final lx = center.dx + labelR * cos(angle);
      final ly = center.dy + labelR * sin(angle);
      final textPainter = TextPainter(
        text: TextSpan(
          text: dimensions[i].$1,
          style: TextStyle(
            color: textColor,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(lx - textPainter.width / 2, ly - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
