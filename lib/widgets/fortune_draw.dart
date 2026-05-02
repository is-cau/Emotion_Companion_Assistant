import 'dart:math';
import 'package:flutter/material.dart';
import '../app/themes/app_colors.dart';

enum FortuneLevel { best, good, normal, poor, worst }

enum FortuneState { idle, drawing, showingFront, showingBack }

class FortuneData {
  final FortuneLevel level;
  final String label;
  final Color color;
  final String blessing;

  const FortuneData({
    required this.level,
    required this.label,
    required this.color,
    required this.blessing,
  });
}

class FortuneDraw extends StatefulWidget {
  final String? savedDate;
  final FortuneLevel? savedLevel;
  final String? savedBlessing;
  final void Function(String date, FortuneLevel level, String blessing) onFortuneDrawn;

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
  late Animation<double> _stickSlide;
  late Animation<double> _flipAngle;

  FortuneState _state = FortuneState.idle;
  FortuneData? _currentFortune;

  static final _rng = Random();
  static List<FortuneData>? _cachedFortunes;

  static const _levelLabels = ['上上签', '上签', '中签', '下签', '下下签'];
  static const _levelColors = [
    AppColors.calmGreen,
    AppColors.lightCyan,
    AppColors.warmBeige,
    AppColors.softOrange,
    AppColors.softPink,
  ];
  static const _levelIcons = ['🌟', '✨', '🍀', '🍂', '🌧'];

  static const _blessings = [
    ['万事如意\n心想事成', '春风得意\n马蹄疾', '福星高照\n好运连连'],
    ['拨云见日\n前途光明', '吉人天相\n自有福泽', '花开堪折\n直须折'],
    ['平平淡淡\n岁月静好', '心若安宁\n日日是好日', '不急不躁\n静待花开'],
    ['守得云开\n见月明', '船到桥头\n自然直', '塞翁失马\n焉知非福'],
    ['否极泰来\n转机将至', '柳暗花明\n又一村', '风雨过后\n方见彩虹'],
  ];

  static List<FortuneData> _buildFortunes() {
    if (_cachedFortunes != null) return _cachedFortunes!;
    const weights = [5, 20, 50, 20, 5];
    final list = <FortuneData>[];
    for (int i = 0; i < weights.length; i++) {
      for (int j = 0; j < weights[i]; j++) {
        list.add(FortuneData(
          level: FortuneLevel.values[i],
          label: _levelLabels[i],
          color: _levelColors[i],
          blessing: _blessings[i][j % 3],
        ));
      }
    }
    _cachedFortunes = list;
    return list;
  }

  FortuneData _pickFortune() {
    final fortunes = _buildFortunes();
    return fortunes[_rng.nextInt(fortunes.length)];
  }

  @override
  void initState() {
    super.initState();

    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _stickSlide = CurvedAnimation(
      parent: _drawController,
      curve: Curves.easeOutBack,
    );

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAngle = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _drawController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _state = FortuneState.showingFront);
      }
    });

    _flipController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _state = FortuneState.showingBack);
      } else if (status == AnimationStatus.dismissed) {
        setState(() => _state = FortuneState.showingFront);
      }
    });

    _loadSavedState();
  }

  void _loadSavedState() {
    if (widget.savedDate != null) {
      final today = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
      if (widget.savedDate == today &&
          widget.savedLevel != null &&
          widget.savedBlessing != null) {
        _currentFortune = FortuneData(
          level: widget.savedLevel!,
          label: _levelLabels[widget.savedLevel!.index],
          color: _levelColors[widget.savedLevel!.index],
          blessing: widget.savedBlessing!,
        );
        _state = FortuneState.showingFront;
      }
    }
  }

  @override
  void dispose() {
    _drawController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _handleTap() {
    switch (_state) {
      case FortuneState.idle:
        _onDraw();
        break;
      case FortuneState.showingFront:
        _flipController.forward();
        break;
      case FortuneState.showingBack:
        _flipController.reverse();
        break;
      case FortuneState.drawing:
        break;
    }
  }

  void _onDraw() {
    final fortune = _pickFortune();
    _currentFortune = fortune;
    final today = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    widget.onFortuneDrawn(today, fortune.level, fortune.blessing);

    setState(() => _state = FortuneState.drawing);
    _drawController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = min(screenWidth - 80, 240.0);
    final cardHeight = cardWidth * 1.8;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: cardHeight + 120,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Tube (签筒) at top
            if (_state == FortuneState.idle || _state == FortuneState.drawing)
              _buildTube(cardWidth, isDark),

            // Stick card that slides up and flips
            if (_state != FortuneState.idle)
              AnimatedBuilder(
                animation: Listenable.merge([_drawController, _flipController]),
                builder: (context, child) {
                  final slideOffset = _stickSlide.value;
                  final flipProgress = _flipAngle.value;

                  return Positioned(
                    top: 50 + (1 - slideOffset) * 120,
                    left: (screenWidth - cardWidth) / 2 - 20,
                    child: Opacity(
                      opacity: slideOffset.clamp(0.0, 1.0),
                      child: _buildFlippableStick(cardWidth, cardHeight, flipProgress, isDark),
                    ),
                  );
                },
              ),

            // Idle prompt
            if (_state == FortuneState.idle)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildIdlePrompt(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTube(double cardWidth, bool isDark) {
    final tubeWidth = cardWidth * 0.6;
    final stickColors = _levelColors;

    return Container(
      width: tubeWidth,
      height: 90,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.warmBeige.withValues(alpha: 0.3),
            AppColors.warmBeige.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(10),
          bottom: Radius.circular(16),
        ),
        border: Border.all(
          color: AppColors.warmBeige.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Sticks peeking out from tube
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 32,
              child: Stack(
                children: List.generate(5, (i) {
                  final leftOffset = 8.0 + i * (tubeWidth - 20) / 4;
                  return Positioned(
                    left: leftOffset,
                    top: _rng.nextDouble() * 10,
                    child: Container(
                      width: 8,
                      height: 28 + _rng.nextDouble() * 4,
                      decoration: BoxDecoration(
                        color: stickColors[i].withValues(alpha: 0.7),
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
          // Tube rim
          Positioned(
            top: 6,
            left: 4,
            right: 4,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.warmBeige.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlippableStick(
      double width, double height, double flipProgress, bool isDark) {
    if (_currentFortune == null) return const SizedBox.shrink();

    final angle = flipProgress * pi;
    final halfPi = pi / 2;
    final frontOpacity =
        (angle < halfPi) ? (1.0 - (angle / halfPi)).clamp(0.0, 1.0) : 0.0;
    final backOpacity =
        (angle >= halfPi) ? ((angle - halfPi) / halfPi).clamp(0.0, 1.0) : 0.0;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          // Front face: fortune level
          Opacity(
            opacity: frontOpacity,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              child: _buildFrontFace(width, height, _currentFortune!, isDark),
            ),
          ),
          // Back face: blessing text (counter-rotated to be readable)
          Opacity(
            opacity: backOpacity,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle - pi),
              child: _buildBackFace(width, height, _currentFortune!, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrontFace(
      double width, double height, FortuneData data, bool isDark) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            data.color.withValues(alpha: 0.15),
            isDark ? Theme.of(context).cardColor : Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: data.color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _levelIcons[data.level.index],
            style: const TextStyle(fontSize: 44),
          ),
          const SizedBox(height: 16),
          Text(
            data.label,
            style: TextStyle(
              color: data.color,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '点击翻转查看签文',
            style: TextStyle(
              color: AppColors.textHint,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackFace(
      double width, double height, FortuneData data, bool isDark) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isDark ? Theme.of(context).cardColor : Colors.white,
            data.color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: data.color.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Vertical blessing text: characters separated by newlines
          Expanded(
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                child: Text(
                  data.blessing,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: data.color,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 2.0,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '点击翻转返回',
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdlePrompt() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '点击签筒',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.hazeBlue,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '抽取今日一签',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textHint,
              ),
        ),
      ],
    );
  }
}
