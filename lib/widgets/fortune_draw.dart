import 'dart:math';
import 'package:flutter/material.dart';
import '../app/themes/app_colors.dart';

enum FortuneLevel { best, good, normal, poor, worst }

class FortuneData {
  final FortuneLevel level;
  final String label;
  final Color color;
  final String icon;
  final String blessing;

  const FortuneData({
    required this.level,
    required this.label,
    required this.color,
    required this.icon,
    required this.blessing,
  });
}

class FortuneDraw extends StatefulWidget {
  final String? savedDate;
  final FortuneLevel? savedLevel;
  final String? savedBlessing;
  final void Function(String date, FortuneLevel level, String blessing)
      onFortuneDrawn;

  const FortuneDraw({
    super.key,
    this.savedDate,
    this.savedLevel,
    this.savedBlessing,
    required this.onFortuneDrawn,
  });

  @override
  State<FortuneDraw> createState() => _FortuneDrawState();
}

class _FortuneDrawState extends State<FortuneDraw>
    with TickerProviderStateMixin {
  late AnimationController _drawController;
  late AnimationController _flipController;
  late Animation<double> _slideAnim;
  late Animation<double> _flipAnim;

  bool _hasDrawn = false;
  bool _isFlipped = false;
  bool _isDrawing = false;
  FortuneData? _fortune;

  static final _rng = Random();

  static const _labels = ['上上签', '上签', '中签', '下签', '下下签'];
  static const _colors = [
    AppColors.calmGreen,
    AppColors.lightCyan,
    AppColors.warmBeige,
    AppColors.softOrange,
    AppColors.softPink,
  ];
  static const _icons = ['🌟', '✨', '🍀', '🍂', '🌧'];
  static const _blessings = [
    ['万事如意\n心想事成', '春风得意\n马蹄疾', '福星高照\n好运连连'],
    ['拨云见日\n前途光明', '吉人天相\n自有福泽', '花开堪折\n直须折'],
    ['平平淡淡\n岁月静好', '心若安宁\n日日是好日', '不急不躁\n静待花开'],
    ['守得云开\n见月明', '船到桥头\n自然直', '塞翁失马\n焉知非福'],
    ['否极泰来\n转机将至', '柳暗花明\n又一村', '风雨过后\n方见彩虹'],
  ];

  static FortuneData _pick() {
    const weights = [5, 20, 50, 20, 5];
    final pool = <FortuneData>[];
    for (int i = 0; i < weights.length; i++) {
      for (int j = 0; j < weights[i]; j++) {
        pool.add(FortuneData(
          level: FortuneLevel.values[i],
          label: _labels[i],
          color: _colors[i],
          icon: _icons[i],
          blessing: _blessings[i][j % 3],
        ));
      }
    }
    return pool[_rng.nextInt(pool.length)];
  }

  @override
  void initState() {
    super.initState();

    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideAnim = CurvedAnimation(
      parent: _drawController,
      curve: Curves.easeOutBack,
    );

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _flipAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _drawController.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() => _isDrawing = false);
      }
    });

    _flipController.addStatusListener((s) {
      if (s == AnimationStatus.completed || s == AnimationStatus.dismissed) {
        setState(() => _isFlipped = _flipController.value > 0.5);
      }
    });

    _restore();
  }

  void _restore() {
    final today =
        '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    if (widget.savedDate == today &&
        widget.savedLevel != null &&
        widget.savedBlessing != null) {
      _fortune = FortuneData(
        level: widget.savedLevel!,
        label: _labels[widget.savedLevel!.index],
        color: _colors[widget.savedLevel!.index],
        icon: _icons[widget.savedLevel!.index],
        blessing: widget.savedBlessing!,
      );
      _hasDrawn = true;
      _drawController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _drawController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _draw() {
    if (_isDrawing) return;
    final f = _pick();
    final today =
        '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    widget.onFortuneDrawn(today, f.level, f.blessing);

    setState(() {
      _fortune = f;
      _hasDrawn = true;
      _isDrawing = true;
      _isFlipped = false;
    });
    _flipController.value = 0.0;
    _drawController.forward(from: 0);
  }

  void _toggleFlip() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardW = min(screenWidth - 120, 200.0);
    final cardH = cardW * 1.4;

    if (!_hasDrawn) {
      return _buildIdleView(cardW);
    }

    return GestureDetector(
      onTap: _hasDrawn && !_isDrawing ? _toggleFlip : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([_drawController, _flipController]),
        builder: (context, _) {
          final slideVal = _slideAnim.value;
          final angle = _flipAnim.value * pi;
          final halfPi = pi / 2;
          final frontOpacity =
              (angle < halfPi) ? (1.0 - angle / halfPi).clamp(0.0, 1.0) : 0.0;
          final backOpacity =
              (angle >= halfPi) ? ((angle - halfPi) / halfPi).clamp(0.0, 1.0) : 0.0;

          return Center(
            child: Opacity(
              opacity: slideVal.clamp(0.0, 1.0),
              child: SizedBox(
                width: cardW,
                height: cardH,
                child: Stack(
                  children: [
                    // Front face
                    Opacity(
                      opacity: frontOpacity,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle),
                        child: _buildFront(cardW, cardH),
                      ),
                    ),
                    // Back face — counter-rotated to be readable
                    Opacity(
                      opacity: backOpacity,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle - pi),
                        child: _buildBack(cardW, cardH),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIdleView(double cardW) {
    final tubeW = cardW * 0.6;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _draw,
          child: Container(
            width: tubeW,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.warmBeige.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
                bottom: Radius.circular(16),
              ),
              border: Border.all(
                color: AppColors.warmBeige.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 24,
                    child: Stack(
                      children: List.generate(5, (i) {
                        return Positioned(
                          left: 8.0 + i * (tubeW - 24) / 4,
                          top: Random(i).nextDouble() * 6,
                          child: Container(
                            width: 7,
                            height: 22 + Random(i + 5).nextDouble() * 4,
                            decoration: BoxDecoration(
                              color: _colors[i].withValues(alpha: 0.7),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                Positioned(
                  top: 5,
                  left: 4,
                  right: 4,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.warmBeige.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '👆 点击签筒抽取今日一签',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.hazeBlue,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  Widget _buildFront(double w, double h) {
    final f = _fortune!;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            f.color.withValues(alpha: 0.12),
            Theme.of(context).colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: f.color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: f.color.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(f.icon, style: const TextStyle(fontSize: 34)),
          const SizedBox(height: 10),
          Text(f.label,
              style: TextStyle(
                  color: f.color,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('点击翻转查看签文',
              style: TextStyle(color: AppColors.textHint, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildBack(double w, double h) {
    final f = _fortune!;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.surface,
            f.color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: f.color.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: f.color.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: Text(
                  f.blessing,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: f.color,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.9,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('点击翻转返回',
                style: TextStyle(color: AppColors.textHint, fontSize: 10)),
          ),
        ],
      ),
    );
  }
}
