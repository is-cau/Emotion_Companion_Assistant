import 'package:flutter/material.dart';
import '../app/themes/app_colors.dart';

class AppSplash extends StatefulWidget {
  final VoidCallback onFinished;

  const AppSplash({super.key, required this.onFinished});

  @override
  State<AppSplash> createState() => _AppSplashState();
}

class _AppSplashState extends State<AppSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scale;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    _scale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );

    _float = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) widget.onFinished();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF5F0EB),
                Color(0xFFF0E8E0),
                Color(0xFFEEE5DA),
              ],
            ),
          ),
          child: Stack(
            children: [
              _buildFloatingCircles(),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated icon
                    Transform.scale(
                      scale: _scale.value,
                      child: Opacity(
                        opacity: _fadeIn.value,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha:0.9),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.hazeBlue.withValues(alpha:0.2),
                                blurRadius: 30,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '☁️',
                              style: TextStyle(fontSize: 48),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // App name
                    Opacity(
                      opacity: _fadeIn.value,
                      child: Transform.translate(
                        offset: Offset(0, 4 * (1 - _float.value)),
                        child: const Text(
                          '抱抱情绪云',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: _fadeIn.value * 0.7,
                      child: Text(
                        '用温暖抱抱你的每一种情绪',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Loading dots
                    Opacity(
                      opacity: _fadeIn.value * 0.6,
                      child: _LoadingDots(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingCircles() {
    return Positioned.fill(
      child: Opacity(
        opacity: _fadeIn.value * 0.4,
        child: const _FloatingDecorations(),
      ),
    );
  }
}

class _FloatingDecorations extends StatelessWidget {
  const _FloatingDecorations();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: const Alignment(-0.7, -0.6),
          child: _DecoCircle(color: AppColors.softPink, size: 60, delay: 0.0),
        ),
        Align(
          alignment: const Alignment(0.75, -0.4),
          child: _DecoCircle(color: AppColors.lightCyan, size: 80, delay: 0.3),
        ),
        Align(
          alignment: const Alignment(-0.6, 0.2),
          child: _DecoCircle(color: AppColors.gentlePurple, size: 50, delay: 0.6),
        ),
        Align(
          alignment: const Alignment(0.65, 0.1),
          child: _DecoCircle(color: AppColors.calmGreen, size: 70, delay: 0.9),
        ),
        Align(
          alignment: const Alignment(-0.3, 0.5),
          child: _DecoCircle(color: AppColors.softOrange, size: 40, delay: 1.2),
        ),
      ],
    );
  }
}

class _DecoCircle extends StatefulWidget {
  final Color color;
  final double size;
  final double delay;

  const _DecoCircle({
    required this.color,
    required this.size,
    required this.delay,
  });

  @override
  State<_DecoCircle> createState() => _DecoCircleState();
}

class _DecoCircleState extends State<_DecoCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).round()), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -8 * _ctrl.value),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha:0.15),
            ),
          ),
        );
      },
    );
  }
}

class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = ((_ctrl.value - delay + 1.0) % 1.0);
            final opacity = 0.3 + 0.5 * (1 - (t - 0.5).abs() * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.hazeBlue.withValues(alpha:opacity),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
