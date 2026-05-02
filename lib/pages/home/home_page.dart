import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/themes/app_colors.dart';
import '../../services/emotion_service.dart';
import '../../services/storage_service.dart';
import '../../models/emotion_models.dart';
import '../../app/routes/app_routes.dart';
import '../../widgets/emotion_radar.dart';
import '../../widgets/heartbeat_breath_button.dart';
import '../../widgets/fortune_draw.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onNavigateToComfort;
  const HomePage({super.key, this.onNavigateToComfort});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final EmotionService _emotionService = EmotionService();
  final StorageService _storageService = StorageService();
  List<EmotionRecord> _records = [];
  String _greeting = '';
  String? _fortuneDate;
  FortuneLevel? _fortuneLevel;
  String? _fortuneBlessing;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setGreeting();
    _loadFortuneState();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) {
      _greeting = '夜深了，记得早点休息';
    } else if (hour < 9) {
      _greeting = '早安，新的一天温柔以待';
    } else if (hour < 12) {
      _greeting = '上午好，今天也要照顾好自己';
    } else if (hour < 14) {
      _greeting = '午安，记得好好吃饭';
    } else if (hour < 18) {
      _greeting = '下午好，累了就歇一歇';
    } else if (hour < 22) {
      _greeting = '晚上好，今天辛苦了';
    } else {
      _greeting = '夜深了，把烦恼留给明天';
    }
  }

  Future<void> _loadFortuneState() async {
    final date = await _storageService.getFortuneDate();
    final today = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    if (date == today) {
      final levelIdx = await _storageService.getFortuneLevel();
      final blessing = await _storageService.getFortuneBlessing();
      if (levelIdx != null && blessing != null && mounted) {
        setState(() {
          _fortuneDate = date;
          _fortuneLevel = FortuneLevel.values[levelIdx];
          _fortuneBlessing = blessing;
        });
      }
    }
  }

  Future<void> _saveFortune(
      String date, FortuneLevel level, String blessing) async {
    await _storageService.setFortuneDate(date);
    await _storageService.setFortuneLevel(level.index);
    await _storageService.setFortuneBlessing(blessing);
    setState(() {
      _fortuneDate = date;
      _fortuneLevel = level;
      _fortuneBlessing = blessing;
    });
  }

  Future<void> _loadData() async {
    final records = await _storageService.getAllRecords();
    setState(() => _records = records);
  }

  /// 外部可调用的刷新方法，用于跨页面同步数据
  Future<void> refreshData() async {
    await _loadData();
  }

  String _formatTimelineDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recordDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(recordDay).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[dt.weekday - 1];
    }
    return '${dt.month}月${dt.day}日';
  }

  /// 聚合今日所有情绪日记，返回综合分析记录和记录条数
  EmotionRecord? _getTodayAggregated() {
    final todayRecords = _records.where((r) =>
      r.createdAt.year == DateTime.now().year &&
      r.createdAt.month == DateTime.now().month &&
      r.createdAt.day == DateTime.now().day &&
      r.dominantEmotion != '分析中...'  // 过滤占位记录
    ).toList();

    if (todayRecords.isEmpty) return null;

    final n = todayRecords.length;
    double avg(List<double> values) => values.reduce((a, b) => a + b) / n;

    final sadness = avg(todayRecords.map((r) => r.sadness).toList());
    final anxiety = avg(todayRecords.map((r) => r.anxiety).toList());
    final anger = avg(todayRecords.map((r) => r.anger).toList());
    final loneliness = avg(todayRecords.map((r) => r.loneliness).toList());
    final happiness = avg(todayRecords.map((r) => r.happiness).toList());
    final calmness = avg(todayRecords.map((r) => r.calmness).toList());
    final suppression = avg(todayRecords.map((r) => r.suppression).toList());

    final scores = <String, double>{
      '悲伤': sadness, '焦虑': anxiety, '愤怒': anger, '孤独': loneliness,
      '开心': happiness, '平静': calmness, '压抑': suppression,
    };
    final dominant = scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return EmotionRecord(
      id: 'today_aggregated',
      content: '今日情绪综合分析（$n条记录）',
      sadness: sadness,
      anxiety: anxiety,
      anger: anger,
      loneliness: loneliness,
      happiness: happiness,
      calmness: calmness,
      suppression: suppression,
      dominantEmotion: dominant,
      createdAt: todayRecords.first.createdAt,
    );
  }

  int _getTodayCount() {
    return _records.where((r) =>
      r.createdAt.year == DateTime.now().year &&
      r.createdAt.month == DateTime.now().month &&
      r.createdAt.day == DateTime.now().day &&
      r.dominantEmotion != '分析中...'
    ).length;
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final months = [
      '1月', '2月', '3月', '4月', '5月', '6月',
      '7月', '8月', '9月', '10月', '11月', '12月',
    ];
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${months[dt.month - 1]}${dt.day}日 ${weekdays[dt.weekday - 1]}';
  }

  // ============= UI Builders =============

  Widget _buildSectionHeader(String title, Color accentColor, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildIconContainer(IconData icon, Color color, {double size = 18, double containerSize = 38}) {
    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: size, color: color),
    );
  }

  // ============= Main Build =============

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayAggregated = _getTodayAggregated();
    final todayCount = _getTodayCount();
    final now = DateTime.now();

    final gradientColors = isDark
        ? [AppColors.hazeBlue.withValues(alpha: 0.12), AppColors.darkBackground]
        : [AppColors.hazeBlue.withValues(alpha: 0.05), AppColors.background];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ===== SliverAppBar =====
              SliverAppBar(
                pinned: true,
                title: Text(
                  '情绪陪伴',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.hazeBlue,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                centerTitle: false,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
              ),

              // ===== All Content =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // ===== Greeting Header =====
                      _buildGreetingHeader(now),

                      const SizedBox(height: 28),

                      // ===== Heartbeat Breath Button =====
                      _buildHeartbeatSection(),

                      const SizedBox(height: 32),

                      // ===== Fortune Section =====
                      _buildFortuneSection(),

                      const SizedBox(height: 16),

                      // ===== Today's Emotion Card =====
                      _buildTodayEmotionCard(todayAggregated, todayCount),

                      const SizedBox(height: 16),

                      // ===== Emotion Timeline Card =====
                      _buildTimelineCard(),

                      const SizedBox(height: 16),

                      // ===== Quick Actions =====
                      _buildQuickActionsSection(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============= Greeting Header =============

  Widget _buildGreetingHeader(DateTime now) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.hazeBlue.withValues(alpha: 0.08),
            AppColors.hazeBlue.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.hazeBlue.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppColors.hazeBlue,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '我是你的情绪陪伴师',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.hazeBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.cloud_outlined,
                  size: 22,
                  color: AppColors.hazeBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.hazeBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: AppColors.hazeBlue.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(now),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.hazeBlue.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============= Heartbeat Section =============

  Widget _buildHeartbeatSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.hazeBlue.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.hazeBlue.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            '轻轻点击，开始倾诉...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textHint,
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 16),
          HeartbeatBreathButton(
            onTap: () => Get.toNamed(AppRoutes.treehole),
          ),
          const SizedBox(height: 16),
          Text(
            '你的每一次倾诉，都会被温柔聆听',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
        ],
      ),
    );
  }

  // ============= Fortune Section =============

  Widget _buildFortuneSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.warmBeige.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('今日一签', AppColors.warmBeige),
          const SizedBox(height: 8),
          FortuneDraw(
            savedDate: _fortuneDate,
            savedLevel: _fortuneLevel,
            savedBlessing: _fortuneBlessing,
            onFortuneDrawn: _saveFortune,
          ),
        ],
      ),
    );
  }

  // ============= Today's Emotion Card =============

  Widget _buildTodayEmotionCard(EmotionRecord? todayAggregated, int todayCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.hazeBlue.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            '今日情绪状态',
            AppColors.hazeBlue,
            trailing: GestureDetector(
              onTap: () {
                if (todayAggregated != null) {
                  Get.toNamed(AppRoutes.analysis, arguments: {'record': todayAggregated});
                } else {
                  Get.toNamed(AppRoutes.analysis);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.hazeBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '查看详情 →',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.hazeBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          if (todayAggregated == null) ...[
            const SizedBox(height: 8),
            _buildEmptyState(
              icon: Icons.sentiment_neutral_outlined,
              iconColor: AppColors.hazeBlue,
              title: '还没有情绪记录',
              subtitle: '开始倾诉，让情绪被温柔看见',
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _buildIconContainer(
                  Icons.auto_awesome,
                  _emotionColor(todayAggregated.dominantEmotion),
                ),
                const SizedBox(width: 12),
                _buildEmotionChip(todayAggregated.dominantEmotion),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '今日 $todayCount 条 · 共 ${_records.length} 条',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: EmotionRadarChart(
                record: todayAggregated,
                textColor: Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _emotionColor(String emotion) {
    const colors = {
      '悲伤': AppColors.softPink,
      '焦虑': AppColors.softOrange,
      '愤怒': AppColors.angerRed,
      '孤独': AppColors.gentlePurple,
      '开心': AppColors.calmGreen,
      '平静': AppColors.lightCyan,
      '压抑': AppColors.warmBeige,
    };
    return colors[emotion] ?? AppColors.hazeBlue;
  }

  // ============= Emotion Timeline Card =============

  Widget _buildTimelineCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.hazeBlue.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('近期情绪波动', AppColors.hazeBlue),
          const SizedBox(height: 8),
          if (_records.isEmpty)
            _buildEmptyState(
              icon: Icons.show_chart_rounded,
              iconColor: AppColors.hazeBlue,
              title: '还没有情绪记录',
              subtitle: '开始倾诉，记录你的情绪旅程',
            )
          else
            _buildEmotionTimeline(),
        ],
      ),
    );
  }

  // ============= Quick Actions =============

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _buildSectionHeader('功能', AppColors.hazeBlue),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _buildQuickAction(
                icon: Icons.auto_awesome,
                label: 'AI暖心安慰',
                color: AppColors.softPink,
                onTap: () {
                  if (widget.onNavigateToComfort != null) {
                    widget.onNavigateToComfort!();
                  } else {
                    Get.toNamed(AppRoutes.comfort);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickAction(
                icon: Icons.analytics_outlined,
                label: '情绪分析',
                color: AppColors.lightCyan,
                onTap: () => Get.toNamed(AppRoutes.analysis),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickAction(
                icon: Icons.shield_outlined,
                label: '隐私中心',
                color: AppColors.gentlePurple,
                onTap: () => Get.toNamed(AppRoutes.privacy),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickAction(
                icon: Icons.nightlight_round,
                label: 'AI梦境解读',
                color: AppColors.dreamyLavender,
                onTap: () => Get.toNamed(AppRoutes.dream),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============= Reusable Widget Builders =============

  Widget _buildEmptyState({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: iconColor.withValues(alpha: 0.45)),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionChip(String emotion) {
    final colors = {
      '悲伤': AppColors.softPink,
      '焦虑': AppColors.softOrange,
      '愤怒': AppColors.angerRed,
      '孤独': AppColors.gentlePurple,
      '开心': AppColors.calmGreen,
      '平静': AppColors.lightCyan,
      '压抑': AppColors.warmBeige,
      '未知': AppColors.textHint,
    };
    final color = colors[emotion] ?? AppColors.hazeBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        emotion,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildEmotionTimeline() {
    final recent = _records.take(7).toList().reversed.toList();
    return SizedBox(
      height: 110,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: recent.map((r) {
          final emotionColor = _emotionColor(r.dominantEmotion);
          final positive = (r.happiness + r.calmness) / 2;
          final barHeight = 20 + (positive * 42);

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dominant emotion label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: emotionColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  r.dominantEmotion,
                  style: TextStyle(
                    fontSize: 9,
                    color: emotionColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Bar with gradient
              Container(
                width: 14,
                height: barHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      emotionColor.withValues(alpha: 0.7),
                      emotionColor.withValues(alpha: 0.25),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              const SizedBox(height: 6),
              // Date label
              Text(
                _formatTimelineDate(r.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            // 底层：彩色柔光投影，营造"浮起"感
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            // 中层：中性灰投影，增加厚度
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // 图标容器 — 彩色半透明底
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            // 标签 — 用主文字色，确保可读性
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
