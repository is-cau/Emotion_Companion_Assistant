import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import '../app/config/speech_config.dart';
import 'storage_service.dart';

class SpeechService {
  static final SpeechService _instance = SpeechService._();
  factory SpeechService() => _instance;
  SpeechService._();

  final StorageService _storageService = StorageService();
  final FlutterTts _flutterTts = FlutterTts();

  // 当前 TTS 提供者：'system' 或 'api'
  String _provider = SpeechConfig.providerSystem;

  // 系统 TTS 状态
  bool _systemTtsReady = false;
  List<Map<String, String>> _systemVoices = [];
  String? _systemVoiceName;

  // API TTS 配置
  String _apiUrl = '';
  String _apiToken = '';
  String _apiVoiceType = '';

  // 通用 TTS 参数
  double _speed = SpeechConfig.ttsSpeed;
  double _volume = SpeechConfig.defaultVolume;
  double _pitch = SpeechConfig.defaultPitch;

  // 播放状态回调
  final Completer<void> _speakCompleter = Completer<void>()..complete();
  VoidCallback? _onComplete;

  /// 从本地存储加载用户自定义 TTS 配置
  Future<void> reloadTtsConfig() async {
    // 加载提供者
    final savedProvider = await _storageService.getTtsProvider();
    _provider = savedProvider;

    // 加载通用参数
    final userSpeed = await _storageService.getTtsSpeed();
    final userVolume = await _storageService.getTtsVolume();
    final userPitch = await _storageService.getTtsPitch();
    _speed = userSpeed ?? SpeechConfig.ttsSpeed;
    _volume = userVolume ?? SpeechConfig.defaultVolume;
    _pitch = userPitch ?? SpeechConfig.defaultPitch;

    // 加载 API TTS 配置
    final userApiUrl = await _storageService.getTtsBaseUrl();
    final userApiKey = await _storageService.getTtsApiKey();
    final userApiModel = await _storageService.getTtsModel();
    _apiUrl = (userApiUrl != null && userApiUrl.isNotEmpty) ? userApiUrl : '';
    _apiToken = (userApiKey != null && userApiKey.isNotEmpty) ? userApiKey : '';
    _apiVoiceType = (userApiModel != null && userApiModel.isNotEmpty) ? userApiModel : '';

    // 加载语音偏好
    final savedVoice = await _storageService.getTtsVoiceType();
    _systemVoiceName = savedVoice;

    // 初始化系统 TTS
    if (!_systemTtsReady) {
      await _initSystemTts();
    } else {
      await _applySystemTtsParams();
    }

    developer.log('【TTS配置】provider: $_provider, systemReady: $_systemTtsReady, apiConfigured: ${_apiUrl.isNotEmpty}');
  }

  /// 初始化系统 TTS 引擎
  Future<void> _initSystemTts() async {
    try {
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.awaitSynthCompletion(true);

      _flutterTts.setStartHandler(() {
        developer.log('【系统TTS】开始播放');
      });

      _flutterTts.setCompletionHandler(() {
        developer.log('【系统TTS】播放完成');
        _onComplete?.call();
      });

      _flutterTts.setErrorHandler((message) {
        developer.log('【系统TTS】错误: $message');
      });

      // 获取可用语音列表
      try {
        _systemVoices = (await _flutterTts.getVoices).cast<Map<String, String>>();
        developer.log('【系统TTS】可用语音: ${_systemVoices.length} 个');
      } catch (_) {
        _systemVoices = [];
      }

      // 设置语言（优先中文）
      await _flutterTts.setLanguage('zh-CN');
      final lang = await _flutterTts.getLanguages;
      developer.log('【系统TTS】语言: ${lang}');

      await _applySystemTtsParams();

      // 恢复保存的语音
      if (_systemVoiceName != null && _systemVoiceName!.isNotEmpty) {
        try {
          await _flutterTts.setVoice({'name': _systemVoiceName!});
        } catch (_) {}
      }

      _systemTtsReady = true;
    } catch (e) {
      developer.log('【系统TTS】初始化失败: $e');
      _systemTtsReady = false;
    }
  }

  Future<void> _applySystemTtsParams() async {
    try {
      await _flutterTts.setSpeechRate(_speed.clamp(0.5, 2.0));
      await _flutterTts.setVolume(_volume.clamp(0.1, 3.0));
      await _flutterTts.setPitch(_pitch.clamp(0.5, 2.0));
    } catch (e) {
      developer.log('【系统TTS】参数设置失败: $e');
    }
  }

  /// TTS 是否可用（系统 TTS 始终可用，API TTS 需要配置）
  bool isConfigured() {
    if (_provider == SpeechConfig.providerSystem) {
      return _systemTtsReady;
    }
    return _apiUrl.isNotEmpty && _apiToken.isNotEmpty;
  }

  /// 当前使用的提供者
  String get provider => _provider;

  /// 系统 TTS 可用语音列表
  List<Map<String, String>> get systemVoices => _systemVoices;

  /// 获取中文系统语音列表
  List<Map<String, String>> get chineseSystemVoices {
    return _systemVoices.where((v) {
      final locale = (v['locale'] ?? v['name'] ?? '').toLowerCase();
      return locale.contains('zh') || locale.contains('cn') || locale.contains('chinese');
    }).toList();
  }

  /// 当前语音名称（用于显示）
  String get currentVoiceName {
    if (_provider == SpeechConfig.providerSystem) {
      if (_systemVoiceName != null && _systemVoiceName!.isNotEmpty) {
        return _systemVoiceName!;
      }
      return '系统默认语音';
    }
    return SpeechConfig.voiceTypeLabels[_apiVoiceType] ?? _apiVoiceType;
  }

  // ==================== 公开 API ====================

  /// TTS 参数 getter
  String get apiUrl => _apiUrl;
  String get apiToken => _apiToken;
  String get apiVoiceType => _apiVoiceType;
  double get speed => _speed;
  double get volume => _volume;
  double get pitch => _pitch;

  /// 朗读文本（返回 true=成功, false=失败）
  Future<bool> speak(String text) async {
    if (_provider == SpeechConfig.providerSystem) {
      return _speakSystem(text);
    }
    return _speakApi(text);
  }

  /// 停止朗读
  Future<void> stop() async {
    if (_provider == SpeechConfig.providerSystem) {
      try {
        await _flutterTts.stop();
      } catch (_) {}
    }
  }

  /// 合成文本到音频文件（仅 API TTS 支持，系统 TTS 返回 null）
  Future<String?> synthesizeToFile(String text) async {
    if (_provider == SpeechConfig.providerApi) {
      return _synthesizeApi(text);
    }
    return null;
  }

  /// 设置播放完成回调
  void setOnComplete(VoidCallback? callback) {
    _onComplete = callback;
  }

  // ==================== 系统 TTS ====================

  Future<bool> _speakSystem(String text) async {
    if (!_systemTtsReady) {
      developer.log('【系统TTS】未就绪，尝试重新初始化');
      await _initSystemTts();
      if (!_systemTtsReady) return false;
    }

    try {
      await _flutterTts.stop();
      await _applySystemTtsParams();

      // 如果保存了语音偏好，应用它
      if (_systemVoiceName != null && _systemVoiceName!.isNotEmpty) {
        try {
          await _flutterTts.setVoice({'name': _systemVoiceName!});
        } catch (_) {}
      }

      await _flutterTts.speak(text);
      return true;
    } catch (e) {
      developer.log('【系统TTS】朗读失败: $e');
      // 降级：尝试使用 API TTS
      if (_apiUrl.isNotEmpty && _apiToken.isNotEmpty) {
        developer.log('【系统TTS】降级到 API TTS');
        return _speakApi(text);
      }
      return false;
    }
  }

  /// 切换系统语音
  Future<void> setSystemVoice(String voiceName) async {
    _systemVoiceName = voiceName;
    await _storageService.setTtsVoiceType(voiceName);
    try {
      await _flutterTts.setVoice({'name': voiceName});
    } catch (_) {}
  }

  // ==================== API TTS（豆包/火山方舟） ====================

  Future<bool> _speakApi(String text) async {
    final path = await _synthesizeApi(text);
    return path != null;
  }

  Future<String?> _synthesizeApi(String text) async {
    try {
      final chunks = _splitTextForTts(text);
      if (chunks.isEmpty) return null;

      if (chunks.length == 1) {
        return await _singleApiRequest(chunks[0]);
      }

      final allBytes = <int>[];
      for (int i = 0; i < chunks.length; i++) {
        final path = await _singleApiRequest(chunks[i]);
        if (path == null) {
          developer.log('TTS: 第 $i/${chunks.length} 段合成失败');
          return null;
        }
        final chunkBytes = await File(path).readAsBytes();
        allBytes.addAll(chunkBytes);
        try {
          File(path).deleteSync();
        } catch (_) {}
      }

      final f = File('${Directory.systemTemp.path}/tts_${DateTime.now().microsecondsSinceEpoch}.mp3');
      await f.writeAsBytes(allBytes);
      return f.path;
    } catch (e) {
      developer.log('TTS API 异常: $e');
      return null;
    }
  }

  Future<String?> _singleApiRequest(String text) async {
    final body = jsonEncode({
      'app': {
        'appid': SpeechConfig.appId,
        'token': _apiToken,
        'cluster': 'volcano_tts',
      },
      'user': {'uid': 'emotion_app'},
      'audio': {
        'voice_type': _apiVoiceType.isNotEmpty ? _apiVoiceType : SpeechConfig.defaultVoiceType,
        'encoding': 'mp3',
        'speed_ratio': _speed,
        'volume_ratio': _volume,
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
          Uri.parse(_apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer;$_apiToken',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data['code'] == 3000 && data['data'] != null) {
        final bytes = base64Decode(data['data']);
        final f = File('${Directory.systemTemp.path}/tts_${DateTime.now().microsecondsSinceEpoch}.mp3');
        await f.writeAsBytes(bytes);
        return f.path;
      }
      developer.log('TTS: code=${data['code']}, msg=${data['message']}');
    } else {
      developer.log('TTS: status=${resp.statusCode}');
    }
    return null;
  }

  /// 测试 API TTS 连接
  Future<(bool, String)> testApiConnection({
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

  // ==================== 文本分片 ====================

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

  Future<bool> isUsingTtsUserConfig() async {
    return _storageService.hasTtsUserConfig();
  }

  void dispose() {
    try {
      _flutterTts.stop();
    } catch (_) {}
  }
}
