import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../app/themes/app_colors.dart';
import '../../app/config/llm_config.dart';
import '../../app/config/speech_config.dart';
import '../../services/emotion_service.dart';
import '../../services/llm_service.dart';
import '../../services/ai_comfort_service.dart';
import '../../services/speech_service.dart';
import '../../services/storage_service.dart';
import '../../models/emotion_models.dart';

class ComfortPage extends StatefulWidget {
  const ComfortPage({super.key});

  @override
  State<ComfortPage> createState() => _ComfortPageState();
}

class _ComfortPageState extends State<ComfortPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final EmotionService _emotionService = EmotionService();
  final LlmService _llmService = LlmService();
  final AiComfortService _fallbackService = AiComfortService();
  final StorageService _storageService = StorageService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<_ChatBubble> _messages = [];
  String _currentEmotion = '平静';
  bool _isLoading = false;
  bool _useLlm = true;
  bool _useStream = true;
  Timer? _typeTimer;
  Timer? _streamDisplayTimer;
  Timer? _cursorBlinkTimer;
  String _streamBuffer = '';
  int _streamDisplayPos = 0;
  bool _streamEnded = false;
  bool _cursorVisible = true;

  // 语音服务 (系统 ASR + 豆包 TTS)
  final SpeechService _speechService = SpeechService();
  final AudioPlayer _ttsPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _playingMessageIndex;
  String _ttsVoiceType = SpeechConfig.defaultVoiceType;

  // 对话管理
  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  bool _titleGenerated = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _loadVoicePreference();
  }

  Future<void> _loadVoicePreference() async {
    final voice = await _storageService.getTtsVoiceType();
    if (mounted) setState(() => _ttsVoiceType = voice);
  }

  Future<void> _loadConversations() async {
    _conversations = await _storageService.getAllConversations();
    final activeId = await _storageService.getActiveConversationId();
    if (activeId != null) {
      _currentConversation = _conversations.where((c) => c.id == activeId).firstOrNull;
      if (_currentConversation != null) {
        _restoreMessages();
        _titleGenerated = _currentConversation!.title != '新对话';
        if (mounted) setState(() {});
        return;
      }
    }
    // 没有活跃对话或找不到，取最近一个
    if (_conversations.isNotEmpty) {
      _currentConversation = _conversations.first;
      _restoreMessages();
      _titleGenerated = _currentConversation!.title != '新对话';
    } else {
      _addWelcomeMessage();
    }
    if (mounted) setState(() {});
  }

  void _restoreMessages() {
    _messages.clear();
    for (final msg in _currentConversation!.messages) {
      _messages.add(_ChatBubble(
        content: msg.content,
        isUser: msg.isUser,
        emotion: msg.emotion,
      ));
    }
    // 对话为空时显示欢迎语
    if (_messages.isEmpty) {
      _addWelcomeMessage();
    }
  }

  void _addWelcomeMessage() {
    _messages.add(_ChatBubble(
      content: '你好呀，我是你的暖心陪伴师。无论开心还是难过，我都在这里陪你。想说什么都可以告诉我。',
      isUser: false,
      emotion: '平静',
    ));
  }

  ChatMessage _bubbleToMessage(_ChatBubble bubble) {
    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      content: bubble.content,
      isUser: bubble.isUser,
      createdAt: DateTime.now(),
      emotion: bubble.emotion,
    );
  }

  Future<void> _saveCurrentConversation() async {
    final now = DateTime.now();
    if (_currentConversation == null) {
      _currentConversation = Conversation(
        id: now.microsecondsSinceEpoch.toString(),
        createdAt: now,
        updatedAt: now,
      );
      _conversations.insert(0, _currentConversation!);
    }
    _currentConversation!.updatedAt = now;
    // 过滤掉欢迎语（不保存到持久化）
    _currentConversation!.messages = _messages
        .where((b) => b.content != '你好呀，我是你的暖心陪伴师。无论开心还是难过，我都在这里陪你。想说什么都可以告诉我。')
        .map(_bubbleToMessage)
        .toList();
    await _storageService.saveConversation(_currentConversation!);
    await _storageService.setActiveConversationId(_currentConversation!.id);
  }

  Future<void> _maybeGenerateTitle() async {
    if (_titleGenerated) return;
    _titleGenerated = true;
    // 找到第一个用户消息和第一个AI回复
    final userMsgs = _messages.where((b) => b.isUser).toList();
    final aiMsgs = _messages.where((b) => !b.isUser && !b.isError && b.content.isNotEmpty && b.content != '你好呀，我是你的暖心陪伴师。无论开心还是难过，我都在这里陪你。想说什么都可以告诉我。').toList();
    if (userMsgs.isEmpty || aiMsgs.isEmpty) return;
    final title = await _llmService.generateTitle(userMsgs.first.content, aiMsgs.first.content);
    if (mounted && _currentConversation != null) {
      _currentConversation!.title = title;
      await _saveCurrentConversation();
      // 更新对话列表
      _conversations = await _storageService.getAllConversations();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _streamDisplayTimer?.cancel();
    _cursorBlinkTimer?.cancel();
    _ttsPlayer.dispose();
    _speechService.dispose();
    _saveCurrentConversation(); // fire-and-forget
    super.dispose();
  }

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    final record = _emotionService.analyze(text);
    setState(() {
      _currentEmotion = record.dominantEmotion;
      _messages.add(_ChatBubble(content: text, isUser: true, emotion: record.dominantEmotion));
      _isLoading = true;
      _messages.add(_ChatBubble(content: '', isUser: false, emotion: _currentEmotion, isStreaming: true));
    });

    _textController.clear();
    _scrollToBottom();

    if (_useLlm) {
      if (_useStream) {
        // ===== 流式模式：HTTP SSE 接收 + 字词块逐块显示，模拟人类打字 =====
        _streamBuffer = '';
        _streamDisplayPos = 0;
        _streamEnded = false;
        _cursorVisible = true;
        _streamDisplayTimer?.cancel();
        _cursorBlinkTimer?.cancel();

        // 光标闪烁定时器
        _cursorBlinkTimer = Timer.periodic(const Duration(milliseconds: 530), (_) {
          if (!mounted) { _cursorBlinkTimer?.cancel(); return; }
          setState(() => _cursorVisible = !_cursorVisible);
        });

        // 启动定时器，按字词块节奏显示已缓冲的文本
        _streamDisplayTimer = Timer.periodic(const Duration(milliseconds: 45), (_) {
          if (!mounted) { _streamDisplayTimer?.cancel(); return; }
          if (_streamDisplayPos < _streamBuffer.length) {
            final chunkSize = _nextChunkSize(_streamBuffer, _streamDisplayPos);
            _streamDisplayPos += chunkSize;
          }
          final cursor = _cursorVisible ? '▌' : '';
          setState(() {
            _messages.last.content = _streamBuffer.substring(0, _streamDisplayPos) + cursor;
            _messages.last.isStreaming = _streamBuffer.isEmpty;
          });
          if (_streamDisplayPos > 0) _scrollToBottom();
          if (_streamEnded && _streamDisplayPos >= _streamBuffer.length) {
            _streamDisplayTimer?.cancel();
            _cursorBlinkTimer?.cancel();
            setState(() {
              _messages.last.content = _streamBuffer;
              _messages.last.isStreaming = false;
            });
            _saveCurrentConversation().then((_) => _maybeGenerateTitle());
          }
        });

        try {
          final stream = _llmService.chatStream(text);
          await for (final delta in stream) {
            if (!mounted) break;
            _streamBuffer += delta;
          }
          _streamEnded = true;
          // 流式返回了空内容（API可能不支持流式），降级到非流式
          if (_streamBuffer.isEmpty && mounted) {
            _streamDisplayTimer?.cancel();
            _cursorBlinkTimer?.cancel();
            _messages.removeLast();
            _messages.add(_ChatBubble(content: '', isUser: false, emotion: _currentEmotion, isStreaming: true));
            final response = await _llmService.chat(text);
            if (mounted) {
              if (response.contains('失败') || response.contains('错误') || response.contains('异常') || response.contains('无法回复')) {
                _messages.removeLast();
                _messages.add(_ChatBubble(
                  content: '$response\n\n【已自动切换到本地模式回复】\n${_fallbackService.chat(text, _currentEmotion)}',
                  isUser: false, emotion: _currentEmotion, isError: true,
                ));
                _saveCurrentConversation();
              } else {
                _typewriterEffect(response);
              }
            }
          }
        } catch (e) {
          _streamDisplayTimer?.cancel();
          _cursorBlinkTimer?.cancel();
          // 流式失败，自动降级到非流式请求
          if (mounted) {
            _messages.removeLast();
            _messages.add(_ChatBubble(content: '', isUser: false, emotion: _currentEmotion, isStreaming: true));
            final response = await _llmService.chat(text);
            if (mounted) {
              if (response.contains('失败') || response.contains('错误') || response.contains('异常') || response.contains('无法回复')) {
                _messages.removeLast();
                _messages.add(_ChatBubble(
                  content: '$response\n\n【已自动切换到本地模式回复】\n${_fallbackService.chat(text, _currentEmotion)}',
                  isUser: false, emotion: _currentEmotion, isError: true,
                ));
                _saveCurrentConversation();
              } else {
                _typewriterEffect(response);
              }
            }
          }
        }
      } else {
        // ===== 非流式模式：先请求，再打字机逐字显示 =====
        final response = await _llmService.chat(text);
        if (mounted) {
          if (response.contains('失败') ||
              response.contains('错误') ||
              response.contains('异常') ||
              response.contains('无法回复')) {
            setState(() {
              _messages.removeLast();
              _messages.add(_ChatBubble(
                content: '$response\n\n【已自动切换到本地模式回复】\n${_fallbackService.chat(text, _currentEmotion)}',
                isUser: false,
                emotion: _currentEmotion,
                isError: true,
              ));
            });
            _saveCurrentConversation();
          } else {
            // 打字机效果逐字显示
            _typewriterEffect(response);
          }
        }
      }
    } else {
      // 本地预设话术模式：也做打字机效果
      await Future.delayed(const Duration(milliseconds: 300));
      final response = _fallbackService.chat(text, _currentEmotion);
      if (mounted) _typewriterEffect(response);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (_messages.isNotEmpty) _messages.last.isStreaming = false;
      });
    }
  }

  /// 计算下一块显示的字数，模拟人类逐词/逐句打字的节奏
  int _nextChunkSize(String text, int pos) {
    if (pos >= text.length) return 0;
    int size = 0;
    while (pos + size < text.length) {
      final char = text[pos + size];
      size++;
      // 遇到标点或换行，连标点一起显示后停止
      if ('，。！？；：、…\n'.contains(char)) break;
      // 普通字词每次显示1-2个字
      if (size >= 2) break;
    }
    return size;
  }

  /// 打字机效果：逐字显示文本
  void _typewriterEffect(String fullText) {
    int index = 0;
    _typeTimer?.cancel();

    _typeTimer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (index <= fullText.length) {
        setState(() {
          _messages.last.content = fullText.substring(0, index);
        });
        index++;
        _scrollToBottom();
      } else {
        timer.cancel();
        setState(() {
          _messages.last.isStreaming = false;
        });
        _saveCurrentConversation().then((_) => _maybeGenerateTitle());
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 30), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 切换录音状态
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      setState(() => _isRecording = false);
      final text = await _speechService.stopRecordingAndRecognize();
      if (text != null && text.isNotEmpty) {
        _textController.text = text;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('识别: $text'),
              backgroundColor: AppColors.calmGreen,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('语音识别失败，请重试'),
              backgroundColor: AppColors.softOrange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } else {
      final started = await _speechService.startRecording();
      if (started) {
        setState(() => _isRecording = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('无法启动录音，请检查麦克风权限'),
              backgroundColor: AppColors.softPink,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  /// 朗读AI消息 (豆包TTS, 截取前300字)
  Future<void> _speakMessage(int index, String text) async {
    if (_playingMessageIndex == '$index') {
      await _ttsPlayer.stop();
      setState(() => _playingMessageIndex = null);
      return;
    }

    await _ttsPlayer.stop();

    // 去除 Markdown 符号
    var plainText = text
        .replaceAll(RegExp(r'[#*>`~_\[\]|]'), '')
        .replaceAll(RegExp(r'\n{2,}'), '。')
        .replaceAll('\n', '。')
        .replaceAll('---', '。')
        .trim();

    if (plainText.isEmpty) return;

    // 截取前 300 字，避免太长导致生成慢
    if (plainText.length > 300) {
      plainText = plainText.substring(0, 300);
    }

    setState(() => _playingMessageIndex = '$index');

    final audioPath = await _speechService.textToSpeech(plainText, voiceType: _ttsVoiceType);
    if (audioPath != null && mounted) {
      await _ttsPlayer.play(DeviceFileSource(audioPath));
      _ttsPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playingMessageIndex = null);
      });
    } else {
      if (mounted) {
        setState(() => _playingMessageIndex = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('语音合成失败，请检查API配置'),
            backgroundColor: AppColors.softOrange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 22),
          onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          tooltip: '对话记录',
        ),
        title: Text(_currentConversation?.title ?? 'AI暖心安慰'),
        actions: [
          PopupMenuButton<String>(
            tooltip: '显示菜单',
            icon: Icon(_useLlm ? Icons.cloud_outlined : Icons.cloud_off_outlined, size: 22),
            onSelected: (value) {
              if (value == 'toggle_llm') {
                setState(() => _useLlm = !_useLlm);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_useLlm ? '已切换到大模型模式' : '已切换到本地预设模式'),
                    backgroundColor: AppColors.hazeBlue,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              } else if (value == 'toggle_stream') {
                setState(() => _useStream = !_useStream);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_useStream ? '已开启流式输出（API实时推送）' : '已关闭流式（打字机效果）'),
                    backgroundColor: AppColors.hazeBlue,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              } else if (value == 'clear') {
                _typeTimer?.cancel();
                _streamDisplayTimer?.cancel();
                _cursorBlinkTimer?.cancel();
                _newConversation();
              } else if (value == 'voice') {
                _showVoicePicker();
              } else if (value == 'config') {
                _showConfigInfo();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_llm',
                child: Row(
                  children: [
                    Icon(_useLlm ? Icons.cloud_off_outlined : Icons.cloud_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(_useLlm ? '切换到本地模式' : '切换到大模型模式'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_stream',
                child: Row(
                  children: [
                    Icon(_useStream ? Icons.stream : Icons.text_fields, size: 18),
                    const SizedBox(width: 8),
                    Text(_useStream ? '关闭流式（打字机）' : '开启流式（实时）'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'voice',
                child: Row(
                  children: [
                    Icon(
                      _ttsVoiceType == SpeechConfig.voiceTypeMale
                          ? Icons.man_outlined
                          : Icons.woman_outlined,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text('朗读音色: ${SpeechConfig.voiceTypeLabels[_ttsVoiceType] ?? '未知'}'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.add_comment_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('新建对话'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'config',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('查看配置'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.self_improvement, size: 22),
            onPressed: _showBreathGuide,
            tooltip: '深呼吸引导',
          ),
          IconButton(
            icon: const Icon(Icons.nightlight_outlined, size: 22),
            onPressed: _showGoodnight,
            tooltip: '晚安语录',
          ),
        ],
      ),
      body: Column(
        children: [
          // 状态标签
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (_currentEmotion != '平静' ? AppColors.softPink : AppColors.hazeBlue).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _currentEmotion != '平静' ? Icons.favorite_outline : Icons.cloud_outlined,
                  size: 14,
                  color: _currentEmotion != '平静' ? AppColors.softPink : AppColors.hazeBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  _currentEmotion != '平静'
                      ? '我感受到你现在有些$_currentEmotion'
                      : (_useLlm
                          ? '大模型模式${_useStream ? "·实时流式" : "·打字机"} · 随时倾诉'
                          : '本地模式·打字机 · 随时倾诉'),
                  style: TextStyle(
                    fontSize: 12,
                    color: _currentEmotion != '平静' ? AppColors.softPink : AppColors.hazeBlue,
                  ),
                ),
              ],
            ),
          ),

          // 对话列表
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessage(msg, index);
              },
            ),
          ),

          // 输入区域
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // 语音输入按钮
                  GestureDetector(
                    onTap: _toggleRecording,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording
                            ? AppColors.softPink.withValues(alpha: 0.15)
                            : AppColors.hazeBlue.withValues(alpha: 0.08),
                        border: Border.all(
                          color: _isRecording ? AppColors.softPink : AppColors.hazeBlue.withValues(alpha: 0.3),
                          width: _isRecording ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        _isRecording ? Icons.mic : Icons.mic_outlined,
                        color: _isRecording ? AppColors.softPink : AppColors.hazeBlue,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 100),
                      child: TextField(
                        controller: _textController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkBackground
                              : AppColors.milkWhite,
                          hintText: _isLoading
                              ? 'AI正在思考……'
                              : _isRecording
                                  ? '正在聆听……'
                                  : '说说你的心事……',
                          suffixIcon: IconButton(
                            icon: _isLoading
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.hazeBlue,
                                    ),
                                  )
                                : Icon(Icons.send_rounded, color: AppColors.hazeBlue, size: 20),
                            onPressed: _isLoading ? null : _sendMessage,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        width: 280,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('对话记录', style: Theme.of(context).textTheme.titleMedium),
                    GestureDetector(
                      onTap: _newConversation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.hazeBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 16, color: AppColors.hazeBlue),
                            const SizedBox(width: 4),
                            Text('新建', style: TextStyle(fontSize: 13, color: AppColors.hazeBlue)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _conversations.isEmpty
                    ? Center(
                        child: Text('暂无对话记录', style: Theme.of(context).textTheme.bodySmall),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _conversations.length,
                        itemBuilder: (context, index) {
                          final conv = _conversations[index];
                          final isActive = _currentConversation?.id == conv.id;
                          return ListTile(
                            selected: isActive,
                            selectedTileColor: AppColors.hazeBlue.withValues(alpha: 0.06),
                            title: Text(
                              conv.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              '${conv.messages.length} 条消息 · ${conv.updatedAt.month}月${conv.updatedAt.day}日',
                              style: TextStyle(fontSize: 11, color: AppColors.textHint),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.close, size: 16, color: AppColors.textHint.withValues(alpha: 0.5)),
                              onPressed: () => _deleteConversation(conv),
                            ),
                            onTap: () => _switchConversation(conv),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(_ChatBubble msg, int index) {
    if (msg.isUser) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16, left: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.hazeBlue.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(msg.content, style: Theme.of(context).textTheme.bodyMedium),
              ),
            ),
          ],
        ),
      );
    }

    // AI回复
    return Container(
      margin: const EdgeInsets.only(bottom: 16, right: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.hazeBlue, AppColors.softPink],
              ),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: msg.isError ? AppColors.softPink.withValues(alpha: 0.08) : Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.content.isEmpty)
                    Text('……', style: Theme.of(context).textTheme.bodyMedium)
                  else if (msg.isStreaming)
                    Text(
                      msg.content,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7),
                    )
                  else
                    MarkdownBody(
                      data: msg.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.7,
                          color: msg.isError ? AppColors.softPink : null,
                        ),
                        h1: Theme.of(context).textTheme.titleLarge,
                        h2: Theme.of(context).textTheme.titleMedium,
                        h3: Theme.of(context).textTheme.titleSmall,
                        strong: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        em: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                        code: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          backgroundColor: AppColors.hazeBlue.withValues(alpha: 0.1),
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: AppColors.hazeBlue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.divider, width: 0.5),
                        ),
                        blockquoteDecoration: BoxDecoration(
                          color: AppColors.hazeBlue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border(left: BorderSide(color: AppColors.hazeBlue, width: 3)),
                        ),
                        horizontalRuleDecoration: BoxDecoration(
                          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
                        ),
                        listBullet: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.7,
                        ),
                        tableHead: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        tableBody: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  // AI消息朗读按钮（非流式、非空）
                  if (!msg.isStreaming && msg.content.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _isLoading ? null : () => _speakMessage(index, msg.content),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _playingMessageIndex == '$index'
                                  ? AppColors.hazeBlue.withValues(alpha: 0.15)
                                  : AppColors.textHint.withValues(alpha: 0.08),
                            ),
                            child: Icon(
                              _playingMessageIndex == '$index'
                                  ? Icons.volume_up
                                  : Icons.volume_up_outlined,
                              size: 16,
                              color: _playingMessageIndex == '$index'
                                  ? AppColors.hazeBlue
                                  : AppColors.textHint,
                            ),
                          ),
                        ),
                        if (_playingMessageIndex == '$index') ...[
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.hazeBlue.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (msg.isStreaming) ...[
                    const SizedBox(height: 6),
                    _buildTypingIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.hazeBlue.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '正在思考中',
          style: TextStyle(fontSize: 11, color: AppColors.textHint),
        ),
      ],
    );
  }

  Future<void> _newConversation() async {
    // 保存当前对话（如果有内容）
    if (_currentConversation != null) {
      await _saveCurrentConversation();
    }
    _llmService.clearHistory();
    _currentConversation = null;
    _titleGenerated = false;
    _messages.clear();
    _addWelcomeMessage();
    await _storageService.setActiveConversationId(null);
    setState(() {});
  }

  Future<void> _switchConversation(Conversation conv) async {
    if (_currentConversation?.id == conv.id) {
      _scaffoldKey.currentState?.closeEndDrawer();
      return;
    }
    await _saveCurrentConversation();
    _llmService.clearHistory();
    _currentConversation = conv;
    _titleGenerated = conv.title != '新对话';
    _restoreMessages();
    await _storageService.setActiveConversationId(conv.id);
    _scaffoldKey.currentState?.closeEndDrawer();
    setState(() {});
  }

  Future<void> _deleteConversation(Conversation conv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除对话'),
        content: Text('确定要删除「${conv.title}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(color: AppColors.softPink)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _storageService.deleteConversation(conv.id);
    if (_currentConversation?.id == conv.id) {
      _currentConversation = null;
      _llmService.clearHistory();
      _messages.clear();
      _addWelcomeMessage();
      _titleGenerated = false;
    }
    _conversations = await _storageService.getAllConversations();
    if (_currentConversation == null && _conversations.isNotEmpty) {
      _currentConversation = _conversations.first;
      _restoreMessages();
      _titleGenerated = _currentConversation!.title != '新对话';
      await _storageService.setActiveConversationId(_currentConversation!.id);
    } else if (_currentConversation == null) {
      await _storageService.setActiveConversationId(null);
    }
    setState(() {});
  }

  void _showConfigInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('当前大模型配置'),
        content: SelectableText(
          'Base URL: ${LlmConfig.baseUrl}\n'
          'Model: ${LlmConfig.model}\n'
          'API Key: ${LlmConfig.apiKey.substring(0, LlmConfig.apiKey.length > 10 ? 10 : LlmConfig.apiKey.length)}****\n'
          'Temperature: ${LlmConfig.temperature}\n'
          'Max Tokens: ${LlmConfig.maxTokens}\n\n'
          '提示：如调用失败，请检查\n'
          '1. baseUrl 是否以 /v1 结尾\n'
          '2. model 名称是否正确（如 deepseek-chat）\n'
          '3. API Key 是否有效',
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showVoicePicker() {
    final voices = [
      SpeechConfig.voiceTypeFemale,
      SpeechConfig.voiceTypeFemale2,
      SpeechConfig.voiceTypeMale,
    ];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('选择朗读音色'),
        children: voices.map((v) {
          final isSelected = v == _ttsVoiceType;
          return RadioListTile<String>(
            value: v,
            groupValue: _ttsVoiceType,
            title: Text(
              SpeechConfig.voiceTypeLabels[v] ?? v,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.hazeBlue : null,
              ),
            ),
            activeColor: AppColors.hazeBlue,
            onChanged: (value) async {
              if (value != null && value != _ttsVoiceType) {
                await _storageService.setTtsVoiceType(value);
                setState(() => _ttsVoiceType = value);
                if (mounted) Navigator.pop(ctx);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  void _showBreathGuide() {
    int step = 0;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(Icons.self_improvement, color: AppColors.hazeBlue),
              const SizedBox(width: 8),
              const Text('深呼吸引导'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.hazeBlue.withValues(alpha: 0.1),
                ),
                child: Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.hazeBlue.withValues(alpha: 0.2),
                    ),
                    child: const Icon(Icons.air, color: AppColors.hazeBlue, size: 32),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _fallbackService.getBreathGuide(step),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
            TextButton(
              onPressed: () => setDialogState(() => step++),
              child: Text('下一步', style: TextStyle(color: AppColors.hazeBlue)),
            ),
          ],
        ),
      ),
    );
  }

  void _showGoodnight() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.nightlight, color: AppColors.gentlePurple),
            const SizedBox(width: 8),
            const Text('晚安'),
          ],
        ),
        content: Text(
          _fallbackService.getGoodnightWord(),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('晚安', style: TextStyle(color: AppColors.gentlePurple)),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble {
  String content;
  final bool isUser;
  final String emotion;
  bool isStreaming;
  bool isError;

  _ChatBubble({
    required this.content,
    required this.isUser,
    required this.emotion,
    this.isStreaming = false,
    this.isError = false,
  });
}
