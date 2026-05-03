import 'dart:math';
import 'package:flutter/material.dart';
import '../app/themes/app_colors.dart';

enum FortuneLevel { great, best, good }

class FortuneData {
  final FortuneLevel level;
  final String label;
  final Color color;
  final String icon;
  final String blessing;
  const FortuneData(this.level, this.label, this.color, this.icon, this.blessing);
}

class FortuneDraw extends StatefulWidget {
  final String? savedDate;
  final FortuneLevel? savedLevel;
  final String? savedBlessing;
  final void Function(String date, FortuneLevel level, String blessing) onFortuneDrawn;
  const FortuneDraw({super.key, this.savedDate, this.savedLevel, this.savedBlessing, required this.onFortuneDrawn});
  @override
  State<FortuneDraw> createState() => _FortuneDrawState();
}

class _FortuneDrawState extends State<FortuneDraw> with TickerProviderStateMixin {
  late AnimationController _revealCtrl;
  late AnimationController _flipCtrl;

  bool _hasDrawn = false;
  bool _isRevealing = false;
  bool _isFlipped = false;
  FortuneData? _fortune;

  static final _rng = Random();

  static const _labels = ['上上上签', '上上签', '上签'];
  static const _colors = [AppColors.calmGreen, AppColors.lightCyan, AppColors.warmBeige];
  static const _icons = ['🌟', '✨', '🍀'];

  static const _blessings = [
    // 上上上签 (12条)
    [
      '心之所向\n皆能如愿', '诸事顺遂\n好运连连', '福星高照\n心想事成',
      '春风得意\n前程似锦', '万事胜意\n未来可期', '吉星拱照\n喜乐安康',
      '天随人愿\n花开富贵', '鸿运当头\n步步高升', '岁月静好\n温暖如初',
      '阳光万里\n一路繁花', '所念皆星河\n所爱如月色', '幸甚至哉\n日日是好日',
    ],
    // 上上签 (12条)
    [
      '拨云见日\n前途光明', '吉人天相\n自有福泽', '花开堪折\n直须折',
      '心若向阳\n无畏悲伤', '步履不停\n自有答案', '山高水长\n来日可期',
      '温柔以待\n岁月回赠', '心有山海\n静待花开', '且听风吟\n且看云起',
      '不念过往\n不畏将来', '热爱可抵\n岁月漫长', '但行好事\n莫问前程',
    ],
    // 上签 (12条)
    [
      '心若安宁\n日日是好日', '不急不躁\n静待花开', '平平淡淡\n岁月温柔',
      '今天也是\n被爱的一天', '你值得\n世间所有美好', '慢慢来\n一切都会好',
      '保持热爱\n奔赴山海', '做自己的光\n温暖而明亮', '简单一点\n快乐就来了',
      '放下焦虑\n拥抱当下', '生活明朗\n万物可爱', '好好爱自己\n世界也会爱你',
    ],
  ];

  static FortuneData _pick() {
    const weights = [10, 30, 60];
    final pool = <FortuneData>[];
    for (int i = 0; i < weights.length; i++) {
      final blessings = _blessings[i];
      for (int j = 0; j < weights[i]; j++) {
        pool.add(FortuneData(
          FortuneLevel.values[i], _labels[i], _colors[i], _icons[i],
          blessings[j % blessings.length],
        ));
      }
    }
    return pool[_rng.nextInt(pool.length)];
  }

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _flipCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _restore();
    _revealCtrl.addListener(_onTick);
    _flipCtrl.addListener(_onTick);
    _revealCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() { _isRevealing = false; _hasDrawn = true; });
      }
    });
    _flipCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed || s == AnimationStatus.dismissed) {
        setState(() => _isFlipped = _flipCtrl.value > 0.5);
      }
    });
  }

  void _onTick() => setState(() {});

  void _restore() {
    final today = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    if (widget.savedDate == today && widget.savedLevel != null && widget.savedBlessing != null) {
      _fortune = FortuneData(
        widget.savedLevel!,
        _labels[widget.savedLevel!.index],
        _colors[widget.savedLevel!.index],
        _icons[widget.savedLevel!.index],
        widget.savedBlessing!,
      );
      _hasDrawn = true;
      _revealCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _revealCtrl.removeListener(_onTick);
    _flipCtrl.removeListener(_onTick);
    _revealCtrl.dispose();
    _flipCtrl.dispose();
    super.dispose();
  }

  void _tapCard() {
    if (_isRevealing) return;
    if (!_hasDrawn) {
      final f = _pick();
      final today = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
      widget.onFortuneDrawn(today, f.level, f.blessing);
      setState(() { _fortune = f; _isRevealing = true; _isFlipped = false; });
      _revealCtrl.forward(from: 0);
    } else {
      _toggleFlip();
    }
  }

  void _toggleFlip() {
    if (_isFlipped) { _flipCtrl.reverse(); } else { _flipCtrl.forward(); }
  }

  double _easeOutCubic(double t) => 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);
  double _easeInOut(double t) => t < 0.5 ? 4.0 * t * t * t : 1.0 - (-2.0 * t + 2.0) * (-2.0 * t + 2.0) * (-2.0 * t + 2.0) / 2.0;

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final cardW = min(sw - 80, 200.0);
    final cardH = cardW * 1.4;
    final surface = Theme.of(context).colorScheme.surface;

    final revealT = _easeOutCubic(_revealCtrl.value);
    final flipT = _easeInOut(_flipCtrl.value);
    final restored = _hasDrawn && !_isRevealing;

    final textOpacity = restored ? 0.0 : (1.0 - revealT).clamp(0.0, 1.0);
    final fortuneOpacity = restored ? 1.0 : revealT.clamp(0.0, 1.0);
    final fortuneFloat = restored ? 0.0 : (1.0 - revealT) * 28;

    final angle = flipT * pi;
    final halfPi = pi / 2;
    final frontOpacity = (angle < halfPi) ? (1.0 - angle / halfPi).clamp(0.0, 1.0) : 0.0;
    final backOpacity = (angle >= halfPi) ? ((angle - halfPi) / halfPi).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: _tapCard,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: cardW,
        height: cardH,
        child: Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.warmBeige.withValues(alpha: 0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.warmBeige.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: textOpacity,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('✨', style: TextStyle(fontSize: 30)),
                        const SizedBox(height: 14),
                        Text('请点击查看今日运势', textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.hazeBlue, fontSize: 15, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
              if (_fortune != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: fortuneOpacity,
                    child: Transform.translate(
                      offset: Offset(0, fortuneFloat),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: frontOpacity,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle),
                              child: _buildFront(),
                            ),
                          ),
                          Opacity(
                            opacity: backOpacity,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle - pi),
                              child: _buildBack(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (restored)
                Positioned(
                  bottom: 12, left: 0, right: 0,
                  child: Text(
                    _isFlipped ? '点击翻转返回' : '点击翻转查看签文',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textHint, fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFront() {
    final f = _fortune!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(f.icon, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text(f.label, style: TextStyle(color: f.color, fontSize: 22, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildBack() {
    final f = _fortune!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Center(
        child: Text(f.blessing, textAlign: TextAlign.center,
          style: TextStyle(color: f.color, fontSize: 17, fontWeight: FontWeight.w600, height: 1.8, letterSpacing: 2)),
      ),
    );
  }
}
