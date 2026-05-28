import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../app/themes/app_colors.dart';
import '../../app/responsive/adaptive_content_wrapper.dart';
import '../../services/emotion_service.dart';
import '../../services/llm_service.dart';
import '../../services/storage_service.dart';
import '../../models/emotion_models.dart';
import '../../app/routes/app_routes.dart';
import '../../widgets/unified_config_dialog.dart';

class TreeholePage extends StatefulWidget {
  const TreeholePage({super.key});

  @override
  State<TreeholePage> createState() => TreeholePageState();
}

class TreeholePageState extends State<TreeholePage> {
  final TextEditingController _textController = TextEditingController();
  final EmotionService _emotionService = EmotionService();
  final StorageService _storageService = StorageService();
  List<EmotionRecord> _records = [];
  bool _isLocked = false;
  bool _showPinDialog = false;

  // 白噪音
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentNoise; // 'rain', 'wind', 'stream' 或 null
  Timer? _fadeTimer;
  double _currentVolume = 1.0;

  @override
  void initState() {
    super.initState();
    _checkLock();
    _loadRecords();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkLock() async {
    final locked = await _storageService.isLocked();
    setState(() => _isLocked = locked);
  }

  Future<void> _loadRecords() async {
    final records = await _storageService.getAllRecords();
    setState(() => _records = records);
  }

  /// 外部可调用的刷新方法，用于跨页面同步数据
  Future<void> refreshData() async {
    await _checkLock();
    await _loadRecords();
  }

  Future<void> _submitEmotion() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final llmService = LlmService();
    final useLlm = llmService.isConfigured();

    // 1. 生成记录
    final recordId = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();

    if (useLlm) {
      // LLM 模式：先创建占位记录，显示加载弹窗，后台分析
      final pendingRecord = EmotionRecord(
        id: recordId,
        content: text,
        dominantEmotion: '分析中...',
        createdAt: now,
      );
      await _storageService.saveRecord(pendingRecord);
      _textController.clear();
      await _loadRecords();

      // 显示加载弹窗
      bool dialogCancelled = false;
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('AI情绪分析', style: TextStyle(fontSize: 16)),
                GestureDetector(
                  onTap: () {
                    dialogCancelled = true;
                    Navigator.of(ctx).pop();
                  },
                  child: Icon(Icons.close, size: 20, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.3)),
                ),
              ],
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            content: const SizedBox(
              height: 100,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('正在生成详细情绪报告中……', style: TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ),
        );
      }

      final llmResult = await llmService.analyzeEmotion(text);

      // 构建最终记录：AI成功用AI结果，失败用本地兜底
      final EmotionRecord finalRecord;
      if (llmResult != null) {
        finalRecord = EmotionRecord(
          id: recordId,
          content: text,
          sadness: (llmResult['sadness'] ?? 0.0).toDouble(),
          anxiety: (llmResult['anxiety'] ?? 0.0).toDouble(),
          anger: (llmResult['anger'] ?? 0.0).toDouble(),
          loneliness: (llmResult['loneliness'] ?? 0.0).toDouble(),
          happiness: (llmResult['happiness'] ?? 0.0).toDouble(),
          calmness: (llmResult['calmness'] ?? 0.0).toDouble(),
          suppression: (llmResult['suppression'] ?? 0.0).toDouble(),
          dominantEmotion: llmResult['dominantEmotion'] ?? '平静',
          createdAt: pendingRecord.createdAt,
          interpretation: llmResult['interpretation'] ?? '',
          suggestions: (llmResult['suggestions'] as List<dynamic>?)?.cast<String>() ?? [],
        );
      } else {
        final localRecord = _emotionService.analyze(text);
        finalRecord = EmotionRecord(
          id: recordId,
          content: text,
          sadness: localRecord.sadness,
          anxiety: localRecord.anxiety,
          anger: localRecord.anger,
          loneliness: localRecord.loneliness,
          happiness: localRecord.happiness,
          calmness: localRecord.calmness,
          suppression: localRecord.suppression,
          dominantEmotion: localRecord.dominantEmotion,
          createdAt: pendingRecord.createdAt,
        );
      }

      // 用最终结果替换占位记录，刷新列表
      await _storageService.saveRecord(finalRecord);
      await _loadRecords();

      if (dialogCancelled) {
        // 用户已关弹窗 → 结果已静默更新到列表
      } else {
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          Get.toNamed(AppRoutes.analysis, arguments: {'recordId': finalRecord.id});
        }
      }
    } else {
      // 本地模式：直接分析，无需弹窗
      final localRecord = _emotionService.analyze(text);
      final finalRecord = EmotionRecord(
        id: recordId,
        content: text,
        sadness: localRecord.sadness,
        anxiety: localRecord.anxiety,
        anger: localRecord.anger,
        loneliness: localRecord.loneliness,
        happiness: localRecord.happiness,
        calmness: localRecord.calmness,
        suppression: localRecord.suppression,
        dominantEmotion: localRecord.dominantEmotion,
        createdAt: now,
      );
      await _storageService.saveRecord(finalRecord);
      _textController.clear();
      await _loadRecords();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('已使用本地分析，配置大模型 API 可获得 AI 深度分析'),
            backgroundColor: AppColors.hazeBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: '去配置',
              textColor: Colors.white,
              onPressed: () {
                showUnifiedConfigDialog(context).then((_) => _loadRecords());
              },
            ),
          ),
        );
      }
    }
  }

  // ============ BUILD ============

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return _buildLockedView();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? [AppColors.hazeBlue.withOpacity(0.12), AppColors.darkBackground]
        : [AppColors.hazeBlue.withOpacity(0.05), AppColors.background];

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
          child: AdaptiveContentWrapper(
            child: CustomScrollView(
            slivers: [
              _buildSliverHeader(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPrivacyBanner(),
                      const SizedBox(height: 12),
                      _buildInputArea(),
                      const SizedBox(height: 12),
                      _buildNoiseChipsSection(),
                      const SizedBox(height: 20),
                      _buildHistorySection(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  // ============ UI SECTIONS ============

  Widget _buildSliverHeader() {
    return SliverAppBar(
      pinned: true,
      title: Text(
        '情绪树洞',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.hazeBlue,
              fontWeight: FontWeight.w600,
            ),
      ),
      centerTitle: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.lock_outline, size: 20),
          onPressed: _lockTreehole,
          tooltip: '锁定树洞',
        ),
      ],
    );
  }

  Widget _buildPrivacyBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.hazeBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: const Border(
          left: BorderSide(color: AppColors.hazeBlue, width: 3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.hazeBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shield_outlined, size: 16, color: AppColors.hazeBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '这里是你的私密空间，所有内容仅你可见，全程加密保护',
              style: TextStyle(
                color: AppColors.hazeBlue,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.hazeBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.hazeBlue.withOpacity(0.12),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.park_outlined, size: 20, color: AppColors.hazeBlue),
              const SizedBox(width: 8),
              Text(
                '把心事写在这里',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.hazeBlue,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            maxLines: null,
            minLines: 2,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: '把心事写在这里吧，我静静听着……',
              hintStyle: Theme.of(context).textTheme.bodySmall,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.hazeBlue.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.hazeBlue.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.hazeBlue, width: 1.5),
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor.withOpacity(0.6),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _submitEmotion,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('投入树洞'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.hazeBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoiseChipsSection() {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.hazeBlue.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '白噪音',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.hazeBlue,
              ),
        ),
        const SizedBox(width: 12),
        _buildNoiseChip('小雨', Icons.water_drop_outlined, 'rain'),
        const SizedBox(width: 8),
        _buildNoiseChip('晚风', Icons.air, 'wind'),
        const SizedBox(width: 8),
        _buildNoiseChip('溪流', Icons.waves_outlined, 'stream'),
      ],
    );
  }

  Widget _buildHistorySection() {
    if (_records.isEmpty) {
      return _buildEmptyHistoryState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHistoryTitle(),
        const SizedBox(height: 12),
        ..._records.map((record) => _buildRecordCard(record)),
      ],
    );
  }

  Widget _buildHistoryTitle() {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.hazeBlue.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '情绪日记',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(width: 8),
        Text(
          '${_records.length}',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.hazeBlue.withOpacity(0.5),
          ),
        ),
        const Spacer(),
        if (_records.isNotEmpty)
          GestureDetector(
            onTap: _deleteAllRecords,
            child: Text(
              '清空全部',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.softPink.withOpacity(0.6),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyHistoryState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHistoryTitle(),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(Icons.park_outlined, size: 36, color: AppColors.hazeBlue.withOpacity(0.3)),
              const SizedBox(height: 12),
              Text(
                '还没有记录',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                '写下你的第一个心事，让树洞温柔接纳你的每一份情绪',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============ COMPONENT BUILDERS ============

  Widget _buildNoiseChip(String label, IconData icon, String key) {
    final isActive = _currentNoise == key;
    return GestureDetector(
      onTap: () => _toggleNoise(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.hazeBlue.withOpacity(0.12)
              : Theme.of(context).cardColor.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.hazeBlue.withOpacity(0.4) : AppColors.divider.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive
                  ? AppColors.hazeBlue
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive
                    ? AppColors.hazeBlue
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(EmotionRecord record) {
    final emotionColors = {
      '悲伤': AppColors.softPink,
      '焦虑': AppColors.softOrange,
      '愤怒': AppColors.angerRed,
      '孤独': AppColors.gentlePurple,
      '开心': AppColors.calmGreen,
      '平静': AppColors.lightCyan,
      '压抑': AppColors.warmBeige,
      '分析中...': AppColors.textHint,
    };

    final emotionColor = emotionColors[record.dominantEmotion] ?? AppColors.hazeBlue;
    final isPending = record.dominantEmotion == '分析中...';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.hazeBlue.withOpacity(0.08),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧情绪图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: emotionColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                isPending ? '⏳' : _emotionEmoji(record.dominantEmotion),
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 12),
            // 右侧内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: emotionColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPending) ...[
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: emotionColor.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              record.dominantEmotion,
                              style: TextStyle(
                                fontSize: 11,
                                color: emotionColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatDate(record.createdAt),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11),
                          ),
                          if (!isPending) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _deleteRecord(record.id),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.25),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    record.content.length > 100
                        ? '${record.content.substring(0, 100)}……'
                        : record.content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.hazeBlue.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '正在AI深度分析中，请稍候……',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ] else if (record.interpretation.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        Get.toNamed(AppRoutes.analysis, arguments: {'recordId': record.id});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.hazeBlue.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.hazeBlue.withOpacity(0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, size: 14, color: AppColors.hazeBlue),
                            const SizedBox(width: 6),
                            Text(
                              '查看详细情绪报告',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.hazeBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedView() {
    final controller = TextEditingController();

    void tryUnlock() async {
      final verified = await _storageService.verifyPin(controller.text);
      if (verified && mounted) {
        setState(() => _isLocked = false);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('密码错误'),
            backgroundColor: AppColors.softPink,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? [AppColors.hazeBlue.withOpacity(0.12), AppColors.darkBackground]
        : [AppColors.hazeBlue.withOpacity(0.05), AppColors.background];

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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.hazeBlue.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 40,
                    color: AppColors.hazeBlue.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '树洞已锁定',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '输入密码解锁，回到你的私密空间',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: controller,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '请输入密码',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.hazeBlue.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.hazeBlue.withOpacity(0.15)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.hazeBlue, width: 1.5),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.lock_open_outlined, color: AppColors.hazeBlue),
                        onPressed: tryUnlock,
                      ),
                    ),
                    onSubmitted: (_) => tryUnlock(),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _showForgotPasswordDialog(),
                  child: Text(
                    '忘记密码？',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.hazeBlue.withOpacity(0.7),
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.hazeBlue.withOpacity(0.35),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============ AUDIO ============

  double _easeInOut(double t) => t * t * (3 - 2 * t);

  void _fadeTo(AudioPlayer player, double target, Duration duration,
      {VoidCallback? onDone}) {
    _fadeTimer?.cancel();
    final steps = (duration.inMilliseconds / 50).round();
    final startVolume = _currentVolume;
    final delta = target - startVolume;
    int step = 0;
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      step++;
      if (step >= steps) {
        _currentVolume = target;
        player.setVolume(target);
        timer.cancel();
        _fadeTimer = null;
        onDone?.call();
      } else {
        final progress = _easeInOut(step / steps);
        _currentVolume = startVolume + delta * progress;
        player.setVolume(_currentVolume);
      }
    });
  }

  void _toggleNoise(String key) async {
    _fadeTimer?.cancel();

    if (_currentNoise == key) {
      setState(() => _currentNoise = null);
      _fadeTo(_audioPlayer, 0.0, const Duration(seconds: 3), onDone: () {
        _audioPlayer.stop();
        _currentVolume = 1.0;
      });
    } else {
      await _audioPlayer.stop();
      final assetMap = {
        'rain': 'audio/rain.mp3',
        'wind': 'audio/night_wind.mp3',
        'stream': 'audio/stream.mp3',
      };
      _currentVolume = 0.0;
      _audioPlayer.setVolume(0.0);
      await _audioPlayer.play(AssetSource(assetMap[key]!));
      setState(() => _currentNoise = key);
      _fadeTo(_audioPlayer, 1.0, const Duration(seconds: 3));
    }
  }

  // ============ HELPERS ============

  String _emotionEmoji(String emotion) {
    const emojis = {
      '悲伤': '😢',
      '焦虑': '😰',
      '愤怒': '😠',
      '孤独': '🥺',
      '开心': '😊',
      '平静': '😌',
      '压抑': '😔',
    };
    return emojis[emotion] ?? '😌';
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}月${dt.day}日 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ============ RECORD MANAGEMENT ============

  Future<void> _deleteRecord(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除日记'),
        content: const Text('确定要删除这条情绪日记吗？删除后无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除', style: TextStyle(color: AppColors.softPink)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _storageService.deleteRecord(id);
      await _loadRecords();
    }
  }

  Future<void> _deleteAllRecords() async {
    if (_records.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('清空所有日记'),
        content: const Text('确定要删除全部情绪日记吗？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('全部删除', style: TextStyle(color: AppColors.softPink)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _storageService.clearAllRecords();
      await _loadRecords();
    }
  }

  // ============ LOCK / PIN ============

  Future<void> _lockTreehole() async {
    final hasPin = await _storageService.hasPin();
    if (!hasPin) {
      final set = await _showCreatePinDialog(title: '首次锁定树洞', hint: '请设置4-6位数字密码');
      if (set == true) {
        await _storageService.setLocked(true);
        setState(() => _isLocked = true);
        if (mounted) {
          await _showRecoveryQASetupDialog();
        }
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('锁定树洞'),
          content: const Text('锁定后需要输入密码才能访问，是否确认？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('确认锁定', style: TextStyle(color: AppColors.hazeBlue)),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await _storageService.setLocked(true);
        setState(() => _isLocked = true);
      }
    }
  }

  /// 创建密码弹窗（两步验证：输入 → 确认）
  Future<bool?> _showCreatePinDialog({required String title, required String hint}) {
    final controller = TextEditingController();
    String? errorText;

    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('请输入4-6位数字密码', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: hint,
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                final pin = controller.text;
                if (pin.length < 4) {
                  setDialogState(() => errorText = '密码至少4位');
                  return;
                }
                // 弹出确认密码弹窗
                final confirmed = await _showConfirmPinDialog(pin);
                if (confirmed == true) {
                  await _storageService.setPin(pin);
                  Navigator.pop(context, true);
                } else if (confirmed == false) {
                  setDialogState(() => errorText = '两次输入不一致，请重新输入');
                  controller.clear();
                }
              },
              child: Text('下一步', style: TextStyle(color: AppColors.hazeBlue)),
            ),
          ],
        ),
      ),
    );
  }

  /// 确认密码弹窗（二次输入）
  Future<bool?> _showConfirmPinDialog(String firstPin) {
    final controller = TextEditingController();

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('确认密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('请再次输入密码以确认', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: '请再次输入密码'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () {
              if (controller.text == firstPin) {
                Navigator.pop(context, true);
              } else {
                Navigator.pop(context, false);
              }
            },
            child: Text('确认', style: TextStyle(color: AppColors.hazeBlue)),
          ),
        ],
      ),
    );
  }

  /// 二级安保：设置密保问题与答案（强制设置）
  Future<void> _showRecoveryQASetupDialog() async {
    final questionController = TextEditingController();
    final answerController = TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.security, color: AppColors.softOrange, size: 24),
            const SizedBox(width: 8),
            const Text('二级安保设置'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '设置密保问题，忘记密码时可通过回答此问题找回',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: questionController,
              decoration: const InputDecoration(
                hintText: '请输入密保问题（如：我的小名是什么？）',
                labelText: '密保问题',
              ),
              maxLength: 50,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: answerController,
              decoration: const InputDecoration(
                hintText: '请输入答案',
                labelText: '密保答案',
              ),
              maxLength: 30,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final q = questionController.text.trim();
              final a = answerController.text.trim();
              if (q.isEmpty || a.isEmpty) return;
              await _storageService.setRecoveryQA(q, a);
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('密保已设置，忘记密码时可通过密保找回'),
                    backgroundColor: AppColors.calmGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Text('确认设置', style: TextStyle(color: AppColors.hazeBlue)),
          ),
        ],
      ),
    );
  }

  /// 忘记密码 → 密保验证 → 重置密码
  Future<void> _showForgotPasswordDialog() async {
    final hasQA = await _storageService.hasRecoveryQA();
    if (!hasQA) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('无法找回'),
            content: const Text('尚未设置密保问题，无法通过此方式找回密码。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('知道了', style: TextStyle(color: AppColors.hazeBlue)),
              ),
            ],
          ),
        );
      }
      return;
    }

    final question = await _storageService.getRecoveryQuestion();
    final answerController = TextEditingController();
    String? errorText;

    if (!mounted) return;
    final verified = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.help_outline, color: AppColors.softOrange, size: 24),
              const SizedBox(width: 8),
              const Text('找回密码'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('请回答以下密保问题：', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softOrange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  question ?? '',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: answerController,
                decoration: InputDecoration(
                  hintText: '请输入答案',
                  errorText: errorText,
                ),
                maxLength: 30,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                final ok = await _storageService.verifyRecoveryAnswer(answerController.text.trim());
                if (ok) {
                  Navigator.pop(context, true);
                } else {
                  setDialogState(() => errorText = '答案错误，请重试');
                }
              },
              child: Text('验证', style: TextStyle(color: AppColors.hazeBlue)),
            ),
          ],
        ),
      ),
    );

    if (verified == true && mounted) {
      // 密保验证通过 → 重置密码
      await _storageService.clearPin();
      final set = await _showCreatePinDialog(title: '重置密码', hint: '请设置新的4-6位数字密码');
      if (set == true && mounted) {
        // 重新设置密保
        _showRecoveryQASetupDialog();
        // 解锁
        setState(() => _isLocked = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('密码已重置，树洞已解锁'),
            backgroundColor: AppColors.calmGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
