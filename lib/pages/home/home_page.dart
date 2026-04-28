import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/themes/app_colors.dart';
import '../../services/emotion_service.dart';
import '../../services/storage_service.dart';
import '../../models/emotion_models.dart';
import '../../app/routes/app_routes.dart';
import '../../widgets/emotion_radar.dart';
import '../../widgets/heartbeat_breath_button.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
    _setGreeting();
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

  @override
  Widget build(BuildContext context) {
    final todayAggregated = _getTodayAggregated();
    final todayCount = _getTodayCount();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              // 顶部问候
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _greeting,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.hazeBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '我是你的情绪陪伴师',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 一键倾诉按钮（呼吸粒子效果）
              HeartbeatBreathButton(
                onTap: () => Get.toNamed(AppRoutes.treehole),
              ),
              const SizedBox(height: 40),

              // 今日情绪状态卡片
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '今日情绪状态',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            GestureDetector(
                              onTap: () {
                                if (todayAggregated != null) {
                                  Get.toNamed(AppRoutes.analysis, arguments: {'record': todayAggregated});
                                } else {
                                  Get.toNamed(AppRoutes.analysis);
                                }
                              },
                              child: Text(
                                '查看详情 →',
                                style: TextStyle(
                                  color: AppColors.hazeBlue,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildEmotionChip(todayAggregated?.dominantEmotion ?? '未知'),
                            const SizedBox(width: 12),
                            Text(
                              todayAggregated != null
                                  ? '今日 $todayCount 条 · 共 ${_records.length} 条'
                                  : '共 ${_records.length} 条情绪记录',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        if (todayAggregated != null) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 120,
                            child: EmotionRadarChart(
                              record: todayAggregated!,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 情绪波动卡片
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('近期情绪波动', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        _buildEmotionTimeline(),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 快捷功能
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickAction(
                        icon: Icons.shield_outlined,
                        label: '隐私中心',
                        color: AppColors.gentlePurple,
                        onTap: () => Get.toNamed(AppRoutes.privacy),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmotionChip(String emotion) {
    final colors = {
      '悲伤': AppColors.softPink,
      '焦虑': AppColors.softOrange,
      '愤怒': Colors.redAccent.shade100,
      '孤独': AppColors.gentlePurple,
      '开心': AppColors.calmGreen,
      '平静': AppColors.lightCyan,
      '压抑': AppColors.warmBeige,
      '未知': AppColors.textHint,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: (colors[emotion] ?? AppColors.hazeBlue).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        emotion,
        style: TextStyle(
          color: colors[emotion] ?? AppColors.hazeBlue,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildEmotionTimeline() {
    if (_records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            '还没有情绪记录，开始倾诉吧',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    final recent = _records.take(7).toList().reversed.toList();
    return SizedBox(
      height: 96,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: recent.map((r) {
          final colors = {
            '悲伤': AppColors.softPink,
            '焦虑': AppColors.softOrange,
            '愤怒': Colors.redAccent.shade100,
            '孤独': AppColors.gentlePurple,
            '开心': AppColors.calmGreen,
            '平静': AppColors.lightCyan,
            '压抑': AppColors.warmBeige,
          };
          // 正向指数：0~1，越高越积极
          final positive = (r.happiness + r.calmness) / 2;
          final barHeight = 16 + (positive * 36); // 16~52，安全范围
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 主导情绪小标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: (colors[r.dominantEmotion] ?? AppColors.hazeBlue).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  r.dominantEmotion,
                  style: TextStyle(
                    fontSize: 9,
                    color: colors[r.dominantEmotion] ?? AppColors.hazeBlue,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 10,
                height: barHeight,
                decoration: BoxDecoration(
                  color: (colors[r.dominantEmotion] ?? AppColors.hazeBlue).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTimelineDate(r.createdAt),
                style: TextStyle(fontSize: 10, color: AppColors.textHint),
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
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
