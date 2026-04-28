import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/themes/app_colors.dart';
import '../../services/storage_service.dart';
import '../../models/emotion_models.dart';
import '../../widgets/emotion_radar.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  final StorageService _storageService = StorageService();
  List<EmotionRecord> _records = [];
  EmotionRecord? _targetRecord;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final records = await _storageService.getAllRecords();
    if (mounted) {
      setState(() {
        _records = records;
        // 从路由参数获取指定记录：优先使用传入的完整记录对象，其次是recordId，最后取最新记录
        final args = Get.arguments as Map<String, dynamic>?;
        final passedRecord = args?['record'] as EmotionRecord?;
        if (passedRecord != null) {
          _targetRecord = passedRecord;
        } else {
          final recordId = args?['recordId'] as String?;
          if (recordId != null) {
            _targetRecord = records.where((r) => r.id == recordId).firstOrNull ?? records.firstOrNull;
          } else {
            _targetRecord = records.firstOrNull;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final latestRecord = _targetRecord;

    return Scaffold(
      appBar: AppBar(title: const Text('情绪分析报告')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            if (latestRecord == null)
              _buildEmptyState()
            else ...[
              // 情绪雷达图卡片
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('情绪雷达图', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 200,
                          child: EmotionRadarChart(record: latestRecord),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 情绪维度详细数据
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('情绪维度', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        _buildEmotionBar('悲伤', latestRecord.sadness, AppColors.softPink),
                        _buildEmotionBar('焦虑', latestRecord.anxiety, AppColors.softOrange),
                        _buildEmotionBar('愤怒', latestRecord.anger, Colors.redAccent.shade100),
                        _buildEmotionBar('孤独', latestRecord.loneliness, AppColors.gentlePurple),
                        _buildEmotionBar('开心', latestRecord.happiness, AppColors.calmGreen),
                        _buildEmotionBar('平静', latestRecord.calmness, AppColors.lightCyan),
                        _buildEmotionBar('压抑', latestRecord.suppression, AppColors.warmBeige),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 情绪解读
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome, color: AppColors.hazeBlue, size: 18),
                            const SizedBox(width: 8),
                            Text('情绪解读', style: Theme.of(context).textTheme.titleMedium),
                            if (_targetRecord?.interpretation.isNotEmpty == true) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.hazeBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'AI深度分析',
                                  style: TextStyle(fontSize: 10, color: AppColors.hazeBlue),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _getEmotionInterpretation(latestRecord!),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 情绪舒缓建议
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.spa_outlined, color: AppColors.calmGreen, size: 18),
                            const SizedBox(width: 8),
                            Text('舒缓建议', style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._getComfortSuggestions(latestRecord).map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ', style: TextStyle(color: AppColors.calmGreen, fontWeight: FontWeight.bold)),
                              Expanded(child: Text(s, style: Theme.of(context).textTheme.bodyMedium)),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 情绪历史趋势
              if (_records.length >= 2)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('近期情绪趋势', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 16),
                          _buildTrendChart(),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 80),
          Icon(Icons.analytics_outlined, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text('还没有情绪数据', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textHint)),
          const SizedBox(height: 8),
          Text('去树洞写下你的心事，我会为你分析', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildEmotionBar(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: value.clamp(0.05, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _getEmotionInterpretation(EmotionRecord record) {
    // 优先使用记录中存储的大模型解读
    if (record.interpretation.isNotEmpty) return record.interpretation;

    final interpretations = <String>[];

    if (record.sadness > 0.5) interpretations.add('你当前有些悲伤的情绪，这可能来源于近期的失落或不舍。');
    if (record.anxiety > 0.5) interpretations.add('焦虑感比较明显，可能是因为对未来有些不确定或担心。');
    if (record.anger > 0.5) interpretations.add('你感到有些愤怒，这通常意味着你的边界或底线被触碰了。');
    if (record.loneliness > 0.5) interpretations.add('孤独感较强，你可能需要更多温暖的连接和陪伴。');
    if (record.suppression > 0.5) interpretations.add('压抑感明显，你可能长期承受了一些没有释放的压力。');
    if (record.happiness > 0.5) interpretations.add('你目前的状态不错，开心和愉悦的情绪占据主导。');
    if (record.calmness > 0.5) interpretations.add('你处于相对平静的状态，这是很好的内心平衡。');

    if (interpretations.isEmpty) {
      interpretations.add('你的情绪状态整体比较平稳，没有明显的波动。保持这份内心的安宁。');
    }

    return interpretations.join('\n\n');
  }

  List<String> _getComfortSuggestions(EmotionRecord record) {
    // 优先使用记录中存储的大模型建议
    if (record.suggestions.isNotEmpty) return record.suggestions;

    final suggestions = <String>[];

    if (record.sadness > 0.3) suggestions.addAll(['允许自己哭泣，眼泪是最好的自我疗愈', '听一首温暖的音乐，让旋律陪你度过']);
    if (record.anxiety > 0.3) suggestions.addAll(['试试4-7-8深呼吸法，慢慢平复心跳', '把担心的事情写下来，逐一分析是否可控']);
    if (record.anger > 0.3) suggestions.addAll(['出去走走，让身体释放紧张能量', '对着枕头大声说出你的不满，然后放下']);
    if (record.loneliness > 0.3) suggestions.addAll(['给自己一个温暖的拥抱，你值得被爱', '回忆一个让你感到温暖的时刻']);
    if (record.suppression > 0.3) suggestions.addAll(['找一个安全的地方释放情绪，不需要压抑', '允许自己不完美，你已经在尽力了']);
    if (record.happiness > 0.3) suggestions.add('记录下让你开心的事情，不开心时翻看');
    if (record.calmness > 0.3) suggestions.add('保持这份平静，享受当下的安宁');

    if (suggestions.isEmpty) suggestions.add('好好休息，照顾好自己');
    return suggestions;
  }

  Widget _buildTrendChart() {
    final recent = _records.take(7).toList().reversed.toList();
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: recent.map((r) {
          final emotionColors = {
            '悲伤': AppColors.softPink,
            '焦虑': AppColors.softOrange,
            '愤怒': Colors.redAccent.shade100,
            '孤独': AppColors.gentlePurple,
            '开心': AppColors.calmGreen,
            '平静': AppColors.lightCyan,
            '压抑': AppColors.warmBeige,
          };
          // 正向指数：0~1，越高情绪越积极
          final positive = (r.happiness + r.calmness) / 2;
          final barHeight = 24 + (positive * 72); // 24~96，安全范围
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 主导情绪标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (emotionColors[r.dominantEmotion] ?? AppColors.hazeBlue).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  r.dominantEmotion,
                  style: TextStyle(
                    fontSize: 10,
                    color: emotionColors[r.dominantEmotion] ?? AppColors.hazeBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 22,
                height: barHeight,
                decoration: BoxDecoration(
                  color: (emotionColors[r.dominantEmotion] ?? AppColors.hazeBlue).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${r.createdAt.month}/${r.createdAt.day}',
                style: TextStyle(fontSize: 10, color: AppColors.textHint),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
