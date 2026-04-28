import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../app/themes/app_colors.dart';
import '../../services/emotion_service.dart';
import '../../services/llm_service.dart';
import '../../services/storage_service.dart';
import '../../models/emotion_models.dart';
import '../../app/routes/app_routes.dart';

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

  @override
  void initState() {
    super.initState();
    _checkLock();
    _loadRecords();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  @override
  void dispose() {
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

    // 1. 先生成占位记录（"分析中..."），立即保存并刷新列表
    final pendingId = DateTime.now().microsecondsSinceEpoch.toString();
    final pendingRecord = EmotionRecord(
      id: pendingId,
      content: text,
      dominantEmotion: '分析中...',
      createdAt: DateTime.now(),
    );
    await _storageService.saveRecord(pendingRecord);
    _textController.clear();
    await _loadRecords(); // 立即刷新，显示"分析中..."状态

    // 2. 显示加载弹窗（带X关闭按钮，可取消但后台继续分析）
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
                child: Icon(Icons.close, size: 20, color: AppColors.textHint),
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

    // 3. 调用大模型深度分析（后台运行，即使用户关弹窗也不中断）
    final llmService = LlmService();
    final llmResult = await llmService.analyzeEmotion(text);

    // 4. 构建最终记录：AI成功用AI结果，失败用本地兜底
    final EmotionRecord finalRecord;
    if (llmResult != null) {
      finalRecord = EmotionRecord(
        id: pendingId,
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
      // AI失败，用本地关键词分析兜底
      final localRecord = _emotionService.analyze(text);
      finalRecord = EmotionRecord(
        id: pendingId,
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

    // 5. 用最终结果替换占位记录，刷新列表
    await _storageService.saveRecord(finalRecord);
    await _loadRecords();

    if (dialogCancelled) {
      // 用户已关弹窗 → 结果已静默更新到列表
    } else {
      // 弹窗仍在 → 关闭弹窗并跳转分析页
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        Get.toNamed(AppRoutes.analysis, arguments: {'recordId': finalRecord.id});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return _buildLockedView();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('情绪树洞'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline, size: 20),
            onPressed: _lockTreehole,
            tooltip: '锁定树洞',
          ),
        ],
      ),
      body: Column(
        children: [
          // 暖心提示
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.hazeBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.hazeBlue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '这里是你的私密空间，所有内容仅你可见，全程加密保护',
                    style: TextStyle(
                      color: AppColors.hazeBlue,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 输入区域
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              constraints: const BoxConstraints(minHeight: 160),
              child: TextField(
                controller: _textController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: '把心事写在这里吧，我静静听着……',
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      icon: Icon(Icons.send_rounded, color: AppColors.hazeBlue),
                      onPressed: _submitEmotion,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 白噪音开关
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Text('白噪音', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 12),
                _buildNoiseChip('小雨', Icons.water_drop_outlined, 'rain'),
                const SizedBox(width: 8),
                _buildNoiseChip('晚风', Icons.air, 'wind'),
                const SizedBox(width: 8),
                _buildNoiseChip('溪流', Icons.waves_outlined, 'stream'),
              ],
            ),
          ),

          const Divider(height: 32, indent: 20, endIndent: 20),

          // 情绪日记列表
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('情绪日记', style: Theme.of(context).textTheme.titleMedium),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${_records.length} 条记录', style: Theme.of(context).textTheme.bodySmall),
                    if (_records.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _deleteAllRecords,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.softPink.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_sweep_outlined, size: 15, color: AppColors.softPink),
                              const SizedBox(width: 2),
                              Text('清空', style: TextStyle(fontSize: 11, color: AppColors.softPink)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: _records.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_note, size: 48, color: AppColors.textHint),
                        const SizedBox(height: 12),
                        Text(
                          '还没有记录，开始写下你的心事吧',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final r = _records[index];
                      return _buildRecordCard(r);
                    },
                  ),
          ),
        ],
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: AppColors.textHint),
              const SizedBox(height: 20),
              Text('树洞已锁定', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('输入密码解锁', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: controller,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '请输入密码',
                    suffixIcon: IconButton(
                      icon: Icon(Icons.lock_open_outlined, color: AppColors.hazeBlue),
                      onPressed: tryUnlock,
                    ),
                  ),
                  onSubmitted: (_) => tryUnlock(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleNoise(String key) async {
    if (_currentNoise == key) {
      await _audioPlayer.stop();
      setState(() => _currentNoise = null);
    } else {
      await _audioPlayer.stop();
      final assetMap = {
        'rain': 'audio/rain.mp3',
        'wind': 'audio/night_wind.mp3',
        'stream': 'audio/stream.mp3',
      };
      await _audioPlayer.play(AssetSource(assetMap[key]!));
      setState(() => _currentNoise = key);
    }
  }

  Widget _buildNoiseChip(String label, IconData icon, String key) {
    final isActive = _currentNoise == key;
    return GestureDetector(
      onTap: () => _toggleNoise(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.hazeBlue.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.hazeBlue : AppColors.divider,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? AppColors.hazeBlue : AppColors.textHint),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? AppColors.hazeBlue : AppColors.textHint,
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
      '愤怒': Colors.redAccent.shade100,
      '孤独': AppColors.gentlePurple,
      '开心': AppColors.calmGreen,
      '平静': AppColors.lightCyan,
      '压抑': AppColors.warmBeige,
      '分析中...': AppColors.textHint,
    };

    final isPending = record.dominantEmotion == '分析中...';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (emotionColors[record.dominantEmotion] ?? AppColors.hazeBlue).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
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
                          color: AppColors.textHint,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      record.dominantEmotion,
                      style: TextStyle(
                        fontSize: 12,
                        color: emotionColors[record.dominantEmotion] ?? AppColors.hazeBlue,
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
                    style: TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
                  if (!isPending) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _deleteRecord(record.id),
                      child: Icon(Icons.close, size: 16, color: AppColors.textHint.withValues(alpha: 0.6)),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            record.content.length > 100 ? '${record.content.substring(0, 100)}……' : record.content,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (isPending) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.hazeBlue.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '正在AI深度分析中，请稍候……',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.hazeBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: AppColors.hazeBlue),
                    const SizedBox(width: 4),
                    Text(
                      '查看详细情绪报告',
                      style: TextStyle(fontSize: 12, color: AppColors.hazeBlue, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}月${dt.day}日 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

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

  Future<void> _lockTreehole() async {
    final hasPin = await _storageService.hasPin();
    if (!hasPin) {
      // 第一次锁定：需要先设置密码
      final set = await _showCreatePinDialog(title: '首次锁定树洞', hint: '请设置4-6位数字密码');
      if (set == true) {
        await _storageService.setLocked(true);
        setState(() => _isLocked = true);
        if (mounted) _showTreasureDialog();
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

  /// 创建密码弹窗（与隐私页共用逻辑）
  Future<bool?> _showCreatePinDialog({required String title, required String hint}) {
    final controller = TextEditingController();

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              if (controller.text.length >= 4) {
                await _storageService.setPin(controller.text);
                Navigator.pop(context, true);
              }
            },
            child: Text('确认', style: TextStyle(color: AppColors.hazeBlue)),
          ),
        ],
      ),
    );
  }

  /// "专属密码" 提示弹窗
  void _showTreasureDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.favorite, color: AppColors.softPink, size: 24),
            const SizedBox(width: 8),
            const Text('密码已设置'),
          ],
        ),
        content: const Text('这是你的专属树洞密码，请好好保管'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('我知道了', style: TextStyle(color: AppColors.hazeBlue)),
          ),
        ],
      ),
    );
  }
}
