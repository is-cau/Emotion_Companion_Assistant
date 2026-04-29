import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import '../app/config/speech_config.dart';

class SpeechService {
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

      client = HttpClient();
      final wsRequest = await client.openUrl('GET', Uri.parse(_asrWsUrl));
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
            print('ASR WS recv binary: ${data.length} bytes');
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

      // 发送开始消息
      final startMsg = jsonEncode({
        'type': 'start',
        'audio': {
          'format': 'pcm',
          'rate': 16000,
          'bits': 16,
          'channel': 1,
          'language': 'zh-CN',
        },
      });
      ws.add(startMsg);
      print('ASR WS sent start: $startMsg');

      // 等待服务器确认 start (最多 2 秒)
      for (int i = 0; i < 20 && !startConfirmed && !resultCompleter.isCompleted; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (!startConfirmed) {
        print('ASR WS start not confirmed, server may have rejected');
      }

      // 分块发送音频数据
      const chunkSize = 3200;
      for (int i = 0; i < audioBytes.length && !resultCompleter.isCompleted; i += chunkSize) {
        final end = (i + chunkSize).clamp(0, audioBytes.length);
        ws.add(audioBytes.sublist(i, end));
        await Future.delayed(const Duration(milliseconds: 10));
      }
      print('ASR WS audio sent: ${audioBytes.length} bytes');

      // 发送结束消息
      final endMsg = jsonEncode({'type': 'end'});
      ws.add(endMsg);
      print('ASR WS sent end: $endMsg');

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

  // ==================== 豆包 TTS ====================
  static const _ttsUrl = 'https://openspeech.bytedance.com/api/v1/tts';

  Future<String?> textToSpeech(String text, {String? voiceType}) async {
    try {
      final body = jsonEncode({
        'app': {
          'appid': SpeechConfig.appId,
          'token': SpeechConfig.accessToken,
          'cluster': 'volcano_tts',
        },
        'user': {'uid': 'emotion_app'},
        'audio': {
          'voice_type': voiceType ?? SpeechConfig.defaultVoiceType,
          'encoding': 'mp3',
          'speed_ratio': SpeechConfig.ttsSpeed,
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
              'Authorization': 'Bearer;${SpeechConfig.accessToken}',
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
    } catch (e) {
      print('TTS exception: $e');
      return null;
    }
  }

  void dispose() {
    try { _recorder.dispose(); } catch (_) {}
  }
}
