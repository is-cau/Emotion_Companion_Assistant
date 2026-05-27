import 'dart:math';
import 'package:flutter/material.dart';
import '../app/themes/app_colors.dart';

class HeartbeatBreathButton extends StatefulWidget {
  final VoidCallback onTap;

  const HeartbeatBreathButton({super.key, required this.onTap});

  @override
  State<HeartbeatBreathButton> createState() => _HeartbeatBreathButtonState();
}

class _HeartbeatBreathButtonState extends State<HeartbeatBreathButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = 180.0;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          // 呼吸脉冲：正弦波，3-4秒一个周期
          final breathe = 1.0 + sin(t * 2 * pi) * 0.06;

          return SizedBox(
            width: size + 40,
            height: size + 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 粒子层
                CustomPaint(
                  size: Size(size + 40, size + 40),
                  painter: _BreathParticlesPainter(
                    progress: t,
                    breatheScale: breathe,
                  ),
                ),
                // 主按钮
                Transform.scale(
                  scale: breathe,
                  child: child,
                ),
              ],
            ),
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.hazeBlue.withValues(alpha: 0.8),
                AppColors.softPink.withValues(alpha: 0.6),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.hazeBlue.withValues(alpha: 0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite, color: AppColors.morandiRed, size: 36),
              const SizedBox(height: 8),
              Text(
                '开始情绪倾诉',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double orbitRadius;
  final double speed;
  final double size;
  final double baseOpacity;
  final double driftPhase;

  _Particle({
    required this.angle,
    required this.orbitRadius,
    required this.speed,
    required this.size,
    required this.baseOpacity,
    required this.driftPhase,
  });
}

class _BreathParticlesPainter extends CustomPainter {
  final double progress;
  final double breatheScale;

  _BreathParticlesPainter({
    required this.progress,
    required this.breatheScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rng = Random(42); // 固定种子保持粒子分布稳定
    final particles = List.generate(10, (i) {
      return _Particle(
        angle: (i / 10) * 2 * pi + (rng.nextDouble() - 0.5) * 0.3,
        orbitRadius: 80.0 + rng.nextDouble() * 20,
        speed: 0.15 + rng.nextDouble() * 0.25,
        size: 3.0 + rng.nextDouble() * 4.0,
        baseOpacity: 0.3 + rng.nextDouble() * 0.4,
        driftPhase: rng.nextDouble() * 2 * pi,
      );
    });

    for (final p in particles) {
      // 粒子绕行角度随时间和速度变化
      final currentAngle = p.angle + progress * 2 * pi * p.speed;
      // 呼吸漂移：粒子随呼吸节奏向外扩散再收回
      final drift = sin(progress * 2 * pi + p.driftPhase) * 12;
      final radius = p.orbitRadius + drift;
      // 呼吸时粒子变大、更亮
      final breatheBoost = (breatheScale - 1.0) * 8; // 呼吸时增强
      final opacity = p.baseOpacity + breatheBoost * 0.3;

      final x = center.dx + cos(currentAngle) * radius;
      final y = center.dy + sin(currentAngle) * radius;

      // 光点主体
      final paint = Paint()
        ..color = AppColors.hazeBlue.withValues(alpha: opacity.clamp(0.1, 0.7))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(x, y), p.size + breatheBoost, paint);

      // 光点核心（更亮的小点）
      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: (opacity * 0.8).clamp(0.05, 0.5));
      canvas.drawCircle(Offset(x, y), (p.size + breatheBoost) * 0.4, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BreathParticlesPainter oldDelegate) => true;
}
