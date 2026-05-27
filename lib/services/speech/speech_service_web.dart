import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' show VoidCallback;
import 'package:http/http.dart' as http;
import '../../app/config/speech_config.dart';
import '../storage_service.dart';

// ============================================================
// Web Speech API JS interop (Wasm-compatible)
// ============================================================

@JS('window.speechSynthesis')
external SpeechSynthesisJS get _speechSynthesis;

@JS('SpeechSynthesisUtterance')
external SpeechSynthesisUtteranceJS _createUtterance(String text);

extension type SpeechSynthesisJS(JSObject _) implements JSObject {
  external bool get speaking;
  external bool get paused;
  external void cancel();
  external void speak(SpeechSynthesisUtteranceJS utterance);
  external JSArray<SpeechSynthesisVoiceJS> getVoices();
  external set onvoiceschanged(JSFunction callback);
}

extension type SpeechSynthesisUtteranceJS(JSObject _) implements JSObject {
  external set text(String value);
  external set lang(String value);
  external set rate(double value);
  external set pitch(double value);
  external set volume(double value);
  external set voice(SpeechSynthesisVoiceJS voice);
  external set onend(JSFunction callback);
  external set onerror(JSFunction callback);
}

extension type SpeechSynthesisVoiceJS(JSObject _) implements JSObject {
  external String get name;
  external String get lang;
  external bool get default_;
}

// ============================================================
// SpeechService — Web implementation
// ============================================================

class SpeechService {
  static final SpeechService _instance = SpeechService._();
  factory SpeechService() => _instance;
  SpeechService._();

  final StorageService _storageService = StorageService();

  String _provider = SpeechConfig.providerSystem;

  bool _systemTtsReady = false;
  List<Map<String, String>> _systemVoices = [];
  String? _systemVoiceName;

  String _apiUrl = '';
  String _apiToken = '';
  String _apiVoiceType = '';

  double _speed = SpeechConfig.ttsSpeed;
  double _volume = SpeechConfig.defaultVolume;
  double _pitch = SpeechConfig.defaultPitch;

  VoidCallback? _onComplete;
  bool _voicesLoaded = false;

  Future<void> reloadTtsConfig() async {
    final savedProvider = await _storageService.getTtsProvider();
    _provider = savedProvider;

    final userSpeed = await _storageService.getTtsSpeed();
    final userVolume = await _storageService.getTtsVolume();
    final userPitch = await _storageService.getTtsPitch();
    _speed = userSpeed ?? SpeechConfig.ttsSpeed;
    _volume = userVolume ?? SpeechConfig.defaultVolume;
    _pitch = userPitch ?? SpeechConfig.defaultPitch;

    final userApiUrl = await _storageService.getTtsBaseUrl();
    final userApiKey = await _storageService.getTtsApiKey();
    final userApiModel = await _storageService.getTtsModel();
    _apiUrl = (userApiUrl != null && userApiUrl.isNotEmpty) ? userApiUrl : '';
    _apiToken = (userApiKey != null && userApiKey.isNotEmpty) ? userApiKey : '';
    _apiVoiceType = (userApiModel != null && userApiModel.isNotEmpty) ? userApiModel : '';

    final savedVoice = await _storageService.getTtsVoiceType();
    _systemVoiceName = savedVoice;

    if (_systemTtsReady) {
      await _applySystemTtsParams();
    }

    developer.log('【TTS-Web配置】provider: $_provider, ready: $_systemTtsReady, apiConfigured: ${_apiUrl.isNotEmpty}');
  }

  Future<void> ensureReady() async {
    if (_systemTtsReady) return;
    if (_provider != SpeechConfig.providerSystem) return;
    await _initSystemTts();
  }

  Future<void> _initSystemTts() async {
    developer.log('【Web-TTS】开始初始化...');

    _systemTtsReady = true;
    await _fetchVoices();

    developer.log('【Web-TTS】就绪，${_systemVoices.length} 个语音');
  }

  Future<void> _fetchVoices() async {
    try {
      final raw = _speechSynthesis.getVoices().toDart;
      if (raw.isNotEmpty) {
        _parseVoices(raw);
        _voicesLoaded = true;
        developer.log('【Web-TTS】同步加载 ${_systemVoices.length} 个语音');
      }
    } catch (e) {
      developer.log('【Web-TTS】getVoices 异常: $e');
    }

    // Chrome loads voices asynchronously; listen for voiceschanged event
    if (!_voicesLoaded) {
      final completer = Completer<void>();
      _speechSynthesis.onvoiceschanged = (() {
        try {
          _parseVoices(_speechSynthesis.getVoices().toDart);
          _voicesLoaded = true;
          developer.log('【Web-TTS】异步加载 ${_systemVoices.length} 个语音');
        } catch (_) {}
        if (!completer.isCompleted) completer.complete();
      }).toJS;

      // Timeout after 2 seconds
      await Future.any([completer.future, Future.delayed(const Duration(seconds: 2))]);
      if (!_voicesLoaded) {
        developer.log('【Web-TTS】语音加载超时');
      }
    }
  }

  void _parseVoices(List<JSAny?> raw) {
    final parsed = <Map<String, String>>[];
    for (final item in raw) {
      if (item is SpeechSynthesisVoiceJS) {
        final name = item.name;
        final locale = item.lang;
        if (name.isNotEmpty) {
          parsed.add({'name': name, 'locale': locale});
          developer.log('【Web-TTS】语音: $name ($locale)');
        }
      }
    }
    _systemVoices = parsed;
  }

  Future<void> refreshVoices() async {
    _voicesLoaded = false;
    await _fetchVoices();
  }

  Future<void> _applySystemTtsParams() async {
    // Web Speech API parameters are applied per-utterance, no-op here
  }

  bool isConfigured() {
    if (_provider == SpeechConfig.providerSystem) {
      return _systemTtsReady;
    }
    return _apiUrl.isNotEmpty && _apiToken.isNotEmpty;
  }

  String get provider => _provider;
  List<Map<String, String>> get systemVoices => _systemVoices;

  List<Map<String, String>> get chineseSystemVoices {
    return _systemVoices.where((v) {
      final locale = (v['locale'] ?? v['name'] ?? '').toLowerCase();
      return locale.contains('zh') || locale.contains('cn') || locale.contains('chinese');
    }).toList();
  }

  String get currentVoiceName {
    if (_provider == SpeechConfig.providerSystem) {
      if (_systemVoiceName != null && _systemVoiceName!.isNotEmpty) {
        return _systemVoiceName!;
      }
      return '系统默认语音';
    }
    return SpeechConfig.voiceTypeLabels[_apiVoiceType] ?? _apiVoiceType;
  }

  String get apiUrl => _apiUrl;
  String get apiToken => _apiToken;
  String get apiVoiceType => _apiVoiceType;
  double get speed => _speed;
  double get volume => _volume;
  double get pitch => _pitch;

  /// System TTS: speak via Web Speech API
  Future<bool> speak(String text) async {
    if (_provider == SpeechConfig.providerSystem) {
      return _speakSystem(text);
    }
    // API TTS: just synthesize, caller will use synthesizeToBytes for playback
    final bytes = await synthesizeToBytes(text);
    return bytes != null;
  }

  /// Stop speaking
  Future<void> stop() async {
    if (_provider == SpeechConfig.providerSystem) {
      try {
        _speechSynthesis.cancel();
      } catch (_) {}
    }
  }

  /// Synthesize text to audio bytes (API TTS only)
  Future<Uint8List?> synthesizeToBytes(String text) async {
    if (_provider == SpeechConfig.providerApi) {
      return _synthesizeApi(text);
    }
    return null;
  }

  void setOnComplete(VoidCallback? callback) {
    _onComplete = callback;
  }

  // ==================== System TTS via Web Speech API ====================

  Future<bool> _speakSystem(String text) async {
    if (!_systemTtsReady) {
      developer.log('【Web-TTS】未就绪，尝试初始化');
      await _initSystemTts();
    }

    try {
      _speechSynthesis.cancel();

      final utterance = _createUtterance(text);
      utterance.lang = 'zh-CN';
      utterance.rate = _speed.clamp(0.1, 10.0);
      utterance.pitch = _pitch.clamp(0.0, 2.0);
      utterance.volume = _volume.clamp(0.0, 1.0);

      // Apply saved voice preference
      if (_systemVoiceName != null && _systemVoiceName!.isNotEmpty) {
        try {
          final voices = _speechSynthesis.getVoices().toDart;
          for (final v in voices) {
            if (v is SpeechSynthesisVoiceJS && v.name == _systemVoiceName) {
              utterance.voice = v;
              break;
            }
          }
        } catch (_) {}
      }

      final completer = Completer<void>();
      utterance.onend = (() {
        developer.log('【Web-TTS】播放完成');
        _onComplete?.call();
        if (!completer.isCompleted) completer.complete();
      }).toJS;
      utterance.onerror = ((JSObject event) {
        developer.log('【Web-TTS】播放错误: $event');
        if (!completer.isCompleted) completer.complete();
      }).toJS;

      _speechSynthesis.speak(utterance);
      return true;
    } catch (e) {
      developer.log('【Web-TTS】朗读失败: $e');
      if (_apiUrl.isNotEmpty && _apiToken.isNotEmpty) {
        developer.log('【Web-TTS】降级到 API TTS');
        final bytes = await synthesizeToBytes(text);
        return bytes != null;
      }
      return false;
    }
  }

  Future<void> setSystemVoice(String voiceName) async {
    _systemVoiceName = voiceName;
    await _storageService.setTtsVoiceType(voiceName);
  }

  // ==================== API TTS ====================

  Future<Uint8List?> _synthesizeApi(String text) async {
    try {
      final chunks = _splitTextForTts(text);
      if (chunks.isEmpty) return null;

      if (chunks.length == 1) {
        return await _singleApiRequest(chunks[0]);
      }

      final allBytes = <int>[];
      for (int i = 0; i < chunks.length; i++) {
        final chunkBytes = await _singleApiRequest(chunks[i]);
        if (chunkBytes == null) {
          developer.log('TTS: 第 $i/${chunks.length} 段合成失败');
          return null;
        }
        allBytes.addAll(chunkBytes);
      }

      return Uint8List.fromList(allBytes);
    } catch (e) {
      developer.log('TTS API 异常: $e');
      return null;
    }
  }

  Future<Uint8List?> _singleApiRequest(String text) async {
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
        return base64Decode(data['data']);
      }
      developer.log('TTS: code=${data['code']}, msg=${data['message']}');
    } else {
      developer.log('TTS: status=${resp.statusCode}');
    }
    return null;
  }

  /// Test API TTS connection
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
    } on Exception catch (e) {
      return (false, '网络连接失败，请检查 API 地址\n$e');
    }
  }

  // ==================== Text chunking ====================

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
      _speechSynthesis.cancel();
    } catch (_) {}
  }
}
