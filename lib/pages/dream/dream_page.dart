import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import '../../app/themes/app_colors.dart';
import '../../models/emotion_models.dart';
import '../../services/llm_service.dart';
import '../../services/storage_service.dart';

class DreamPage extends StatefulWidget {
  const DreamPage({super.key});

  @override
  State<DreamPage> createState() => _DreamPageState();
}

class _DreamPageState extends State<DreamPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final LlmService _llmService = LlmService();
  final StorageService _storageService = StorageService();

  bool _isLoading = false;
  String? _resultMarkdown;
  String? _resultTitle;
  String? _errorMessage;
  String _dreamText = '';
  List<DreamRecord> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final records = await _storageService.getAllDreamRecords();
    setState(() => _history = records);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitDream() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
      _dreamText = text;
      _resultMarkdown = null;
      _resultTitle = null;
      _errorMessage = null;
    });
    _textController.clear();

    final result = await _llmService.analyzeDream(text);

    if (result != null && mounted) {
      final title = result['title'] ?? '梦境解读';
      final analysis = result['analysis'] ?? '';
      if (analysis.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '梦境分析暂时遇到问题，请检查网络或API配置后重试';
        });
        return;
      }

      // 保存到历史
      final record = DreamRecord(
        id: md5.convert(utf8.encode('$text${DateTime.now().millisecondsSinceEpoch}')).toString(),
        dreamText: text,
        analysis: analysis,
        title: title,
        createdAt: DateTime.now(),
      );
      await _storageService.saveDreamRecord(record);
      await _loadHistory();

      setState(() {
        _isLoading = false;
        _resultMarkdown = analysis;
        _resultTitle = title;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = '梦境分析暂时遇到问题，请检查网络或API配置后重试';
      });
    }

    _scrollToResult();
  }

  void _scrollToResult() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearInput() {
    setState(() {
      _resultMarkdown = null;
      _resultTitle = null;
      _errorMessage = null;
      _dreamText = '';
      _textController.clear();
    });
  }

  void _viewHistoryItem(DreamRecord record) {
    setState(() {
      _resultMarkdown = record.analysis;
      _resultTitle = record.title;
      _dreamText = record.dreamText;
      _errorMessage = null;
    });
  }

  Future<void> _deleteHistoryItem(String id) async {
    final wasViewing = _history.any((r) => r.id == id && r.analysis == _resultMarkdown);
    await _storageService.deleteDreamRecord(id);
    await _loadHistory();
    if (wasViewing && mounted) {
      _clearInput();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? [AppColors.dreamyLavender.withOpacity(0.15), AppColors.darkBackground]
        : [AppColors.dreamyLavender.withOpacity(0.06), AppColors.background];

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
            controller: _scrollController,
            slivers: [
              _buildSliverHeader(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInputArea(),
                      const SizedBox(height: 12),
                      if (_isLoading) _buildLoadingState(),
                      if (_errorMessage != null && !_isLoading) _buildErrorCard(),
                      if (_resultMarkdown != null && !_isLoading) _buildResultCard(),
                      const SizedBox(height: 24),
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
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      pinned: true,
      title: const Text('AI梦境解读'),
      centerTitle: false,
      backgroundColor: AppColors.dreamyLavender.withOpacity(0.06),
      elevation: 0,
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.dreamyLavender.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.dreamyLavender.withOpacity(0.15),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.nightlight_round, size: 20, color: AppColors.dreamyLavender),
              const SizedBox(width: 8),
              Text(
                '把梦说给我听',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.dreamyLavender,
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
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: '描述你的梦境……\n比如：我梦到自己在飞，天空是紫色的，还有一只会说话的猫……',
              hintStyle: Theme.of(context).textTheme.bodySmall,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.dreamyLavender.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.dreamyLavender.withOpacity(0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.dreamyLavender, width: 1.5),
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor.withOpacity(0.6),
              contentPadding: const EdgeInsets.all(14),
            ),
            onSubmitted: (_) => _submitDream(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _submitDream,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('开始解读'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.dreamyLavender,
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

  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.dreamyLavender.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.dreamyLavender.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '正在深入解读你的梦境……',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '梦是心灵的信使，让我们耐心聆听它的密语',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.softOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_outlined, size: 28, color: AppColors.softOrange),
            ),
            const SizedBox(height: 12),
            Text(
              '梦境分析暂时遇到问题',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                setState(() => _errorMessage = null);
                _textController.text = _dreamText;
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.dreamyLavender,
                side: const BorderSide(color: AppColors.dreamyLavender),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('重新输入'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.dreamyLavender.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppColors.dreamyLavender, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _resultTitle ?? '梦境解读',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.dreamyLavender,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                GestureDetector(
                  onTap: _clearInput,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.dreamyLavender.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_comment_rounded, size: 16, color: AppColors.dreamyLavender),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 用户梦境引用
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.dreamyLavender.withOpacity(0.08),
                    AppColors.dreamyLavender.withOpacity(0.02),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                  left: BorderSide(color: AppColors.dreamyLavender, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.format_quote_rounded, size: 14, color: AppColors.dreamyLavender.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Text(
                        '你的梦境',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.dreamyLavender.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _dreamText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          height: 1.7,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Markdown 分析内容
            MarkdownBody(
              data: _resultMarkdown!,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                h1: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.dreamyLavender,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                h2: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.dreamyLavender,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.85,
                    ),
                strong: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                em: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                listBullet: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7),
                listBulletPadding: const EdgeInsets.only(left: 4, right: 12, top: 4),
                blockquoteDecoration: BoxDecoration(
                  color: AppColors.dreamyLavender.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    left: BorderSide(color: AppColors.dreamyLavender, width: 3),
                  ),
                ),
                blockquotePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                horizontalRuleDecoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.dreamyLavender.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                codeblockDecoration: BoxDecoration(
                  color: AppColors.dreamyLavender.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // 底部波浪装饰
            const SizedBox(height: 20),
            Center(
              child: Text(
                '~ ~ ~',
                style: TextStyle(
                  color: AppColors.dreamyLavender.withOpacity(0.25),
                  fontSize: 16,
                  letterSpacing: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_history.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHistoryTitle(),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.nightlight_outlined, size: 36, color: AppColors.dreamyLavender.withOpacity(0.3)),
                const SizedBox(height: 12),
                Text(
                  '还没有解读过梦境',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '写下你的第一个梦，让潜意识的密语被温柔聆听',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHistoryTitle(),
        const SizedBox(height: 12),
        ..._history.map((record) => _buildHistoryCard(record)),
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
            color: AppColors.dreamyLavender.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '历史记录',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(width: 8),
        Text(
          '${_history.length}',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.dreamyLavender.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(DreamRecord record) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _viewHistoryItem(record),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.dreamyLavender.withOpacity(0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.dreamyLavender.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.nightlight_round, size: 18, color: AppColors.dreamyLavender),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      record.dreamText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDate(record.createdAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                        ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _deleteHistoryItem(record.id),
                    child: Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
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
}
