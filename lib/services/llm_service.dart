import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import '../app/config/llm_config.dart';

class LlmService {
  static final LlmService _instance = LlmService._();
  factory LlmService() => _instance;
  LlmService._();

  final String _baseUrl = LlmConfig.baseUrl;
  final String _apiKey = LlmConfig.apiKey;
  final String _model = LlmConfig.model;

  final List<Map<String, String>> _history = [];

  /// 系统提示词：定义AI角色为情感陪伴师
  static const String _systemPrompt = '''你是一位温柔、共情、专业的情绪陪伴师。你的职责是：
1. 用温暖轻柔的语气陪伴用户，绝不生硬机械回复
2. 根据用户的情绪状态智能匹配安慰话术：难过时温柔共情安抚、焦虑时理性疏导解压、愤怒时耐心情绪平复、孤独时暖心陪伴聊天
3. 支持深夜emo专属陪伴、压力大专属疏导、失恋暖心安慰、学业职场压力开导
4. 需要时提供正念深呼吸引导、情绪冥想放松话术、睡前暖心晚安治愈语录
5. 不评判、不指责、只温柔陪伴
6. 回复简洁温暖，不要过长，2-4句话为佳
7. 如果用户提到想睡、晚安等，给予温暖的晚安祝福
8. 如果用户要求呼吸引导或放松，引导做深呼吸练习
9. 可使用Markdown格式让回复更美观：加粗关键词、用小标题分层、短引用表达共情、分隔线区分段落、列表展示建议''';

  /// 发送消息并获取AI回复（非流式，更稳定）
  Future<String> chat(String userMessage) async {
    _history.add({'role': 'user', 'content': userMessage});

    final messages = [
      {'role': 'system', 'content': _systemPrompt},
      ..._history.length > 20 ? _history.sublist(_history.length - 20) : _history,
    ];

    developer.log('【LLM请求】URL: $_baseUrl/chat/completions');
    developer.log('【LLM请求】模型: $_model');
    developer.log('【LLM请求】消息数: ${messages.length}');

    try {
      final uri = Uri.parse('$_baseUrl/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'max_tokens': LlmConfig.maxTokens,
          'temperature': LlmConfig.temperature,
        }),
      ).timeout(const Duration(seconds: 60));

      developer.log('【LLM响应】状态码: ${response.statusCode}');
      developer.log('【LLM响应】内容: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices']?[0]?['message']?['content'] as String?;
        if (reply != null && reply.isNotEmpty) {
          _history.add({'role': 'assistant', 'content': reply});
          return reply.trim();
        } else {
          return '抱歉，AI返回了空内容。响应结构：${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}';
        }
      } else {
        // 详细错误信息
        String errorDetail;
        try {
          final errorJson = jsonDecode(response.body);
          errorDetail = errorJson['error']?['message'] ?? errorJson['message'] ?? response.body;
        } catch (_) {
          errorDetail = response.body;
        }
        return 'API调用失败（状态码: ${response.statusCode}）\n错误信息: $errorDetail';
      }
    } on SocketException catch (e) {
      developer.log('【LLM错误】网络异常: $e');
      return '网络连接失败: $e。请检查网络或API地址是否正确。';
    } on HttpException catch (e) {
      developer.log('【LLM错误】HTTP异常: $e');
      return 'HTTP请求异常: $e。请检查 baseUrl 配置。';
    } on FormatException catch (e) {
      developer.log('【LLM错误】格式异常: $e');
      return '响应解析失败: $e。请确认API为OpenAI兼容格式。';
    } catch (e) {
      developer.log('【LLM错误】未知异常: $e');
      return '发生未知错误: $e';
    }
  }

  /// 流式输出（SSE）
  Stream<String> chatStream(String userMessage) async* {
    _history.add({'role': 'user', 'content': userMessage});

    final messages = [
      {'role': 'system', 'content': _systemPrompt},
      ..._history.length > 20 ? _history.sublist(_history.length - 20) : _history,
    ];

    developer.log('【LLM流式】URL: $_baseUrl/chat/completions');

    try {
      final uri = Uri.parse('$_baseUrl/chat/completions');
      final client = http.Client();
      final request = http.Request('POST', uri);
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      });
      request.body = jsonEncode({
        'model': _model,
        'messages': messages,
        'max_tokens': LlmConfig.maxTokens,
        'temperature': LlmConfig.temperature,
        'stream': true,
      });

      final response = await client.send(request).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        developer.log('【LLM流式错误】状态码: ${response.statusCode}, 内容: $body');
        yield 'API调用失败（状态码: ${response.statusCode}）\n响应内容: $body';
        return;
      }

      final buffer = StringBuffer();
      String fullReply = '';

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer.write(chunk);
        final text = buffer.toString();
        final lines = text.split('\n');
        buffer.clear();

        // 保留最后一行（可能不完整）
        if (lines.isNotEmpty) buffer.write(lines.last);

        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isEmpty || line == 'data: [DONE]') continue;
          if (line.startsWith('data: ')) {
            try {
              final jsonStr = line.substring(6);
              final json = jsonDecode(jsonStr);

              // DeepSeek/OpenAI 兼容解析
              final choices = json['choices'];
              if (choices == null || choices.isEmpty) continue;

              final delta = choices[0]['delta'];
              if (delta == null) continue;

              final content = delta['content'];
              if (content == null || content.isEmpty) continue;

              fullReply += content;
              yield content;
            } catch (e) {
              developer.log('【LLM流式】解析单行失败: $e, 行内容: $line');
            }
          }
        }
      }

      // 处理buffer中剩余的内容
      final remaining = buffer.toString().trim();
      if (remaining.startsWith('data: ') && remaining != 'data: [DONE]') {
        try {
          final json = jsonDecode(remaining.substring(6));
          final content = json['choices']?[0]?['delta']?['content'];
          if (content != null && content.isNotEmpty) {
            fullReply += content;
            yield content;
          }
        } catch (_) {}
      }

      if (fullReply.isNotEmpty) {
        _history.add({'role': 'assistant', 'content': fullReply});
      }
    } catch (e) {
      developer.log('【LLM流式错误】异常: $e');
      yield '发生错误: $e';
    }
  }

  /// 情绪分析：调用大模型做结构化7维度分析
  /// 返回 {"sadness":0.0, "anxiety":0.0, ... , "dominantEmotion":"...", "interpretation":"...", "suggestions":["..."]}
  Future<Map<String, dynamic>?> analyzeEmotion(String text) async {
    const String analyzePrompt = '''你是一位专业的心理学情绪分析师。请对用户的倾诉内容进行深度情绪分析。

要求：
1. 从以下7个维度给出0.0-1.0的评分（0=完全没有，1=极度强烈）：
   - sadness（悲伤）
   - anxiety（焦虑）
   - anger（愤怒）
   - loneliness（孤独）
   - happiness（开心/幸福）
   - calmness（平静/放松）
   - suppression（压抑/内耗）
2. 判断主导情绪 dominantEmotion，从以下选择一项：悲伤、焦虑、愤怒、孤独、开心、平静、压抑
3. 给出专业的情绪解读 interpretation（2-4句话，温柔共情的语气）
4. 给出3-5条具体的舒缓建议 suggestions（数组格式，每条一句话）

必须严格返回以下JSON格式，不要包含任何其他文字：
{
  "sadness": 0.0,
  "anxiety": 0.0,
  "anger": 0.0,
  "loneliness": 0.0,
  "happiness": 0.0,
  "calmness": 0.0,
  "suppression": 0.0,
  "dominantEmotion": "",
  "interpretation": "",
  "suggestions": [""]
}''';

    try {
      final uri = Uri.parse('$_baseUrl/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': analyzePrompt},
            {'role': 'user', 'content': '请分析以下倾诉内容：\n$text'},
          ],
          'max_tokens': 2048,
          'temperature': 0.3,
        }),
      ).timeout(const Duration(seconds: 60));

      developer.log('【情绪分析】状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices']?[0]?['message']?['content'] as String?;
        if (reply == null || reply.isEmpty) return null;

        // 提取 JSON 部分
        String jsonStr = reply.trim();
        // 有些模型会包裹在 ```json ... ``` 中
        if (jsonStr.contains('```json')) {
          jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
        } else if (jsonStr.contains('```')) {
          jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
        }

        final result = jsonDecode(jsonStr) as Map<String, dynamic>;
        developer.log('【情绪分析】结果: $result');
        return result;
      } else {
        developer.log('【情绪分析】失败: ${response.body}');
        return null;
      }
    } catch (e) {
      developer.log('【情绪分析】异常: $e');
      return null;
    }
  }

  /// 根据对话内容生成简短标题（10字以内）
  Future<String> generateTitle(String userMessage, String aiReply) async {
    const prompt = '根据以下对话内容，生成一个10字以内的简短标题，直接返回标题文字，不要引号、标点或额外说明。';

    try {
      final uri = Uri.parse('$_baseUrl/chat/completions');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': prompt},
            {'role': 'user', 'content': '用户：$userMessage\nAI：${aiReply.length > 200 ? aiReply.substring(0, 200) : aiReply}'},
          ],
          'max_tokens': 32,
          'temperature': 0.5,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final title = data['choices']?[0]?['message']?['content'] as String?;
        if (title != null && title.trim().isNotEmpty) {
          return title.trim().length > 15 ? title.trim().substring(0, 15) : title.trim();
        }
      }
    } catch (_) {}
    // 降级：截取用户消息前15字作为标题
    return userMessage.length > 15 ? '${userMessage.substring(0, 15)}…' : userMessage;
  }

  /// 清空对话历史
  void clearHistory() {
    _history.clear();
  }
}
