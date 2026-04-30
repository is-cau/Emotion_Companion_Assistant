import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import '../app/config/speech_config.dart';
import 'storage_service.dart';

class SpeechService {
  static final SpeechService _instance = SpeechService._();
  factory SpeechService() => _instance;
  SpeechService._();

  final StorageService _storageService = StorageService();

  // TTS 配置：从存储加载，未设置则使用 SpeechConfig 默认值
  String _ttsUrl = 'https://openspeech.bytedance.com/api/v1/tts';
  String _ttsToken = SpeechConfig.accessToken;
  String _ttsModel = SpeechConfig.defaultVoiceType;
  double _ttsSpeed = SpeechConfig.ttsSpeed;
  double _ttsVolume = SpeechConfig.defaultVolume;

  /// 从本地存储加载用户自定义 TTS 配置
  Future<void> reloadTtsConfig() async {
    final userUrl = await _storageService.getTtsBaseUrl();
    final userKey = await _storageService.getTtsApiKey();
    final userModel = await _storageService.getTtsModel();
    final userSpeed = await _storageService.getTtsSpeed();
    final userVolume = await _storageService.getTtsVolume();

    _ttsUrl = (userUrl != null && userUrl.isNotEmpty) ? userUrl : 'https://openspeech.bytedance.com/api/v1/tts';
    _ttsToken = (userKey != null && userKey.isNotEmpty) ? userKey : SpeechConfig.accessToken;
    _ttsModel = (userModel != null && userModel.isNotEmpty) ? userModel : SpeechConfig.defaultVoiceType;
    _ttsSpeed = userSpeed ?? SpeechConfig.ttsSpeed;
    _ttsVolume = userVolume ?? SpeechConfig.defaultVolume;

    developer.log('【TTS配置】URL: $_ttsUrl, model: $_ttsModel, speed: $_ttsSpeed, volume: $_ttsVolume, token: ${_ttsToken.length > 6 ? '${_ttsToken.substring(0, 6)}****' : '****'}');
  }

  Future<bool> isUsingTtsUserConfig() async {
    return _storageService.hasTtsUserConfig();
  }

  String get ttsUrl => _ttsUrl;
  String get ttsToken => _ttsToken;
  String get ttsModel => _ttsModel;
  double get ttsSpeed => _ttsSpeed;
  double get ttsVolume => _ttsVolume;

  // ==================== 豆包 TTS ====================

  static List<String> _splitTextForTts(String text) {
    final utf8Bytes = utf8.encode(text);
    if (utf8Bytes.length <= SpeechConfig.ttsMaxTextBytes) {
      return [text];
    }

    final chunks = <String>[];
    final sentences = text.split(RegExp(r'(?<=[。！？\n])'));
    StringBuffer currentChunk = StringBuffer();
    int currentBytes = 0;

    for (final sentence in sentences) {
      final sentenceBytes = utf8.encode(sentence);

      if (currentBytes + sentenceBytes.length > SpeechConfig.ttsMaxTextBytes &&
          currentBytes > 0) {
        chunks.add(currentChunk.toString());
        currentChunk = StringBuffer();
        currentBytes = 0;
      }

      if (sentenceBytes.length > SpeechConfig.ttsMaxTextBytes) {
        if (currentBytes > 0) {
          chunks.add(currentChunk.toString());
          currentChunk = StringBuffer();
          currentBytes = 0;
        }
        int pos = 0;
        while (pos < sentence.length) {
          int end = pos;
          int bytes = 0;
          while (end < sentence.length) {
            final charBytes = utf8.encode(sentence[end]).length;
            if (bytes + charBytes > SpeechConfig.ttsMaxTextBytes) break;
            bytes += charBytes;
            end++;
          }
          if (end == pos) end = pos + 1;
          chunks.add(sentence.substring(pos, end));
          pos = end;
        }
      } else {
        currentChunk.write(sentence);
        currentBytes += sentenceBytes.length;
      }
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.toString());
    }

    return chunks;
  }

  Future<String?> _singleTtsRequest(String text, {String? voiceType}) async {
    final body = jsonEncode({
      'app': {
        'appid': SpeechConfig.appId,
        'token': _ttsToken,
        'cluster': 'volcano_tts',
      },
      'user': {'uid': 'emotion_app'},
      'audio': {
        'voice_type': voiceType ?? _ttsModel,
        'encoding': 'mp3',
        'speed_ratio': _ttsSpeed,
        'volume_ratio': _ttsVolume,
      },
      'request': {
        'reqid': DateTime.now().microsecondsSinceEpoch.toString(),
        'text': text,
        'text_type': 'plain',
        'operation': 'query',
      },
    });

    final resp = await http
        .post(
          Uri.parse(_ttsUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer;$_ttsToken',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data['code'] == 3000 && data['data'] != null) {
        final bytes = base64Decode(data['data']);
        final f = File(
            '${Directory.systemTemp.path}/tts_${DateTime.now().microsecondsSinceEpoch}.mp3');
        await f.writeAsBytes(bytes);
        return f.path;
      }
      print('TTS: code=${data['code']}, msg=${data['message']}');
    } else {
      print('TTS: status=${resp.statusCode}');
    }
    return null;
  }

  Future<String?> textToSpeech(String text, {String? voiceType}) async {
    try {
      final chunks = _splitTextForTts(text);
      if (chunks.isEmpty) return null;

      if (chunks.length == 1) {
        return await _singleTtsRequest(chunks[0], voiceType: voiceType);
      }

      final allBytes = <int>[];
      for (int i = 0; i < chunks.length; i++) {
        final path = await _singleTtsRequest(chunks[i], voiceType: voiceType);
        if (path == null) {
          print('TTS: failed to synthesize chunk $i/${chunks.length}');
          return null;
        }
        final chunkBytes = await File(path).readAsBytes();
        allBytes.addAll(chunkBytes);
        try {
          File(path).deleteSync();
        } catch (_) {}
      }

      final f = File(
          '${Directory.systemTemp.path}/tts_${DateTime.now().microsecondsSinceEpoch}.mp3');
      await f.writeAsBytes(allBytes);
      return f.path;
    } catch (e) {
      print('TTS exception: $e');
      return null;
    }
  }

  /// 测试 TTS 连接：用指定配置合成简短音频
  Future<(bool, String)> testTtsConnection({
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    try {
      final body = jsonEncode({
        'app': {
          'appid': SpeechConfig.appId,
          'token': apiKey,
          'cluster': 'volcano_tts',
        },
        'user': {'uid': 'emotion_app'},
        'audio': {
          'voice_type': model,
          'encoding': 'mp3',
          'speed_ratio': 1.0,
        },
        'request': {
          'reqid': DateTime.now().microsecondsSinceEpoch.toString(),
          'text': '测试连接',
          'text_type': 'plain',
          'operation': 'query',
        },
      });

      final resp = await http
          .post(
            Uri.parse(baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer;$apiKey',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['code'] == 3000 && data['data'] != null) {
          return (true, '连接成功，TTS服务响应正常');
        }
        return (false, 'TTS服务返回异常 (code: ${data['code']}, message: ${data['message']})');
      } else {
        return (false, '连接失败 (状态码: ${resp.statusCode})\n${resp.body}');
      }
    } on SocketException catch (e) {
      return (false, '网络连接失败，请检查 API 地址\n$e');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return (false, '连接超时，请检查网络或 API 地址');
      }
      return (false, '连接测试异常: $e');
    }
  }

  void dispose() {}
}
