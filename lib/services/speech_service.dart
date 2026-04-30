import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
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

  // ==================== 豆包 ASR (WebSocket 流式识别) ====================
  static const _asrWsUrl = 'https://openspeech.bytedance.com/api/v3/sauc/bigmodel';
  static const _resourceId = 'volc.bigasr.sauc.duration';

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _lastFilePath;

  bool get isRecording => _isRecording;

  Future<bool> startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) return false;

      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        sampleRate: 16000,
        bitRate: 256000,
      );
      final path =
          '${Directory.systemTemp.path}/asr_${DateTime.now().microsecondsSinceEpoch}.pcm';
      await _recorder.start(config, path: path);
      _lastFilePath = path;
      _isRecording = true;
      print('ASR recording started: $path');
      return true;
    } catch (e) {
      print('ASR startRecording error: $e');
      return false;
    }
  }

  Future<String?> stopRecordingAndRecognize() async {
    try {
      final path = await _recorder.stop();
      _isRecording = false;
      if (path == null || !File(path).existsSync()) {
        print('ASR: no audio file recorded');
        return null;
      }
      final fileSize = File(path).lengthSync();
      print('ASR recording stopped: $path ($fileSize bytes)');

      final text = await _sendToAsrWs(path);
      try { File(path).deleteSync(); } catch (_) {}
      return text;
    } catch (e) {
      _isRecording = false;
      print('ASR stopRecording error: $e');
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      await _recorder.stop();
      _isRecording = false;
    } catch (_) {}
  }

  Future<String?> _sendToAsrWs(String audioPath) async {
    HttpClient? client;
    WebSocket? ws;
    try {
      final audioBytes = await File(audioPath).readAsBytes();
      final requestId = _generateUuid();

      // 生成 WebSocket 握手密钥
      final wsKeyBytes = List<int>.generate(16, (_) => Random().nextInt(256));
      final wsKey = base64Encode(wsKeyBytes);

      client = HttpClient();
      final wsRequest = await client.openUrl('GET', Uri.parse(_asrWsUrl));
      // WebSocket 升级头
      wsRequest.headers.add('Connection', 'Upgrade');
      wsRequest.headers.add('Upgrade', 'websocket');
      wsRequest.headers.add('Sec-WebSocket-Key', wsKey);
      wsRequest.headers.add('Sec-WebSocket-Version', '13');
      // 豆包 ASR 鉴权头
      wsRequest.headers.add('X-Api-App-Key', SpeechConfig.appId);
      wsRequest.headers.add('X-Api-Access-Key', SpeechConfig.accessToken);
      wsRequest.headers.add('X-Api-Resource-Id', _resourceId);
      wsRequest.headers.add('X-Api-Request-Id', requestId);

      final wsResponse = await wsRequest.close();
      print('ASR WS upgrade status: ${wsResponse.statusCode} ${wsResponse.reasonPhrase}');
      if (wsResponse.statusCode != 101) {
        final body = await wsResponse.transform(utf8.decoder).join();
        print('ASR WS upgrade failed, body: $body');
        client.close();
        return null;
      }

      final socket = await wsResponse.detachSocket();
      ws = WebSocket.fromUpgradedSocket(socket, serverSide: false);

      final resultCompleter = Completer<String?>();
      final textBuffer = StringBuffer();
      bool startConfirmed = false;

      ws.listen(
        (data) {
          print('ASR WS recv type=${data.runtimeType}');
          if (data is String) {
            try {
              final msg = jsonDecode(data);
              print('ASR WS message: $msg');
              final code = msg['code'];
              if (code != null && code != 0 && code != 1000) {
                print('ASR WS error code=$code message=${msg['message']}');
                if (!resultCompleter.isCompleted) resultCompleter.complete(null);
                return;
              }
              if (msg['type'] == 'start_result') {
                startConfirmed = true;
                print('ASR WS start confirmed');
              }
              if (msg['payload_msg'] != null) {
                final payload = msg['payload_msg'];
                final text = payload['text'] ?? payload['result'] ?? '';
                if (text is String && text.isNotEmpty) {
                  textBuffer.write(text);
                }
              }
              if (msg['type'] == 'final' || msg['type'] == 'end') {
                if (!resultCompleter.isCompleted) {
                  resultCompleter.complete(textBuffer.toString());
                }
              }
            } catch (e) {
              print('ASR WS parse error: $e raw=$data');
            }
          } else if (data is List<int>) {
            final hex = data.take(64).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
            print('ASR WS recv binary: ${data.length} bytes, hex=[$hex]');
          }
        },
        onError: (e) {
          print('ASR WS stream error: $e');
          if (!resultCompleter.isCompleted) resultCompleter.complete(null);
        },
        onDone: () {
          print('ASR WS closed, text=${textBuffer.toString()}');
          if (!resultCompleter.isCompleted) {
            final text = textBuffer.toString();
            resultCompleter.complete(text.isNotEmpty ? text : null);
          }
        },
        cancelOnError: false,
      );

      // 发送开始消息 (二进制协议格式)
      final startJson = jsonEncode({
        'type': 'start',
        'audio': {
          'format': 'pcm',
          'rate': 16000,
          'bits': 16,
          'channel': 1,
          'language': 'zh-CN',
        },
      });
      final startBytes = utf8.encode(startJson);
      ws.add(_buildBinaryFrame(0x01, 0x10, startBytes));
      print('ASR WS sent start: $startJson');

      // 等待服务器确认 start (最多 2 秒)
      for (int i = 0; i < 20 && !startConfirmed && !resultCompleter.isCompleted; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (!startConfirmed) {
        print('ASR WS start not confirmed, server may have rejected');
      }

      // 分块发送音频数据 (二进制帧)
      const chunkSize = 3200;
      for (int i = 0; i < audioBytes.length && !resultCompleter.isCompleted; i += chunkSize) {
        final end = (i + chunkSize).clamp(0, audioBytes.length);
        ws.add(_buildBinaryFrame(0x02, 0x00, audioBytes.sublist(i, end)));
        await Future.delayed(const Duration(milliseconds: 10));
      }
      print('ASR WS audio sent: ${audioBytes.length} bytes');

      // 发送结束消息 (二进制帧)
      final endJson = jsonEncode({'type': 'end'});
      final endBytes = utf8.encode(endJson);
      ws.add(_buildBinaryFrame(0x04, 0x10, endBytes));
      print('ASR WS sent end: $endJson');

      final result =
          await resultCompleter.future.timeout(const Duration(seconds: 15));
      await ws.close();
      client.close();
      return result;
    } catch (e) {
      print('ASR WS exception: $e');
      try { await ws?.close(); } catch (_) {}
      try { client?.close(); } catch (_) {}
      return null;
    }
  }

  String _generateUuid() {
    final r = Random();
    return '${_hex8(r)}-${_hex4(r)}-${_hex4(r)}-${_hex4(r)}-${_hex12(r)}';
  }

  String _hex8(Random r) =>
      r.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
  String _hex4(Random r) =>
      r.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
  String _hex12(Random r) =>
      '${r.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0')}${r.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}';

  /// SAUC WebSocket 二进制帧: [version(1), msg_type(1), flags(1), reserved(1), payload_len(4 big-endian), payload...]
  Uint8List _buildBinaryFrame(int msgType, int flags, List<int> payload) {
    final buf = ByteData(8 + payload.length);
    buf.setUint8(0, 0x01); // version
    buf.setUint8(1, msgType);
    buf.setUint8(2, flags);
    buf.setUint8(3, 0x00); // reserved
    buf.setUint32(4, payload.length, Endian.big);
    buf.buffer.asUint8List().setRange(8, 8 + payload.length, payload);
    return buf.buffer.asUint8List();
  }

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

  void dispose() {
    try { _recorder.dispose(); } catch (_) {}
  }
}
