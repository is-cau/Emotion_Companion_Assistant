import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import '../app/config/speech_config.dart';

class SpeechService {
  // ==================== 豆包 ASR (云端语音识别) ====================
  static const _asrUrl = 'https://openspeech.bytedance.com/api/v1/asr';

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _lastFilePath;

  bool get isRecording => _isRecording;

  Future<bool> startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) return false;

      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        numChannels: 1,
        sampleRate: 16000,
        bitRate: 256000,
      );
      final path =
          '${Directory.systemTemp.path}/asr_${DateTime.now().microsecondsSinceEpoch}.wav';
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
      print('ASR recording stopped: $path (${File(path).lengthSync()} bytes)');

      final text = await _sendToAsr(path);
      // 删除临时文件
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

  Future<String?> _sendToAsr(String audioPath) async {
    try {
      // 使用火山方舟 Seed API (兼容 OpenAI 格式)
      const url = 'https://ark.cn-beijing.volces.com/api/v3/audio/transcriptions';

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer ${SpeechConfig.arkApiKey}';
      request.fields['model'] = SpeechConfig.asrModel;
      request.fields['language'] = 'zh';
      request.files.add(await http.MultipartFile.fromPath('file', audioPath));

      final streamedResp = await request.send().timeout(const Duration(seconds: 30));
      final resp = await http.Response.fromStream(streamedResp);

      print('ASR response: status=${resp.statusCode}, body=${resp.body}');
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final text = data['text'] as String?;
        if (text != null && text.isNotEmpty) {
          return text;
        }
      }
      return null;
    } catch (e) {
      print('ASR _sendToAsr error: $e');
      return null;
    }
  }

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
