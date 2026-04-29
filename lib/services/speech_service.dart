import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../app/config/speech_config.dart';

class SpeechService {
  // ==================== 系统 ASR ====================
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _sttAvailable = false;

  SpeechService() {
    _stt.initialize().then((v) => _sttAvailable = v).catchError((_) => _sttAvailable = false);
  }

  bool get sttAvailable => _sttAvailable;
  bool get isListening => _stt.isListening;

  Future<bool> startListening(void Function(String text) onResult) async {
    if (!_sttAvailable) return false;
    try {
      return await _stt.listen(
        onResult: (result) {
          if (result.finalResult) onResult(result.recognizedWords);
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'zh_CN',
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> stopListening() async {
    try { await _stt.stop(); } catch (_) {}
  }

  // ==================== 豆包 TTS ====================
  static const _ttsUrl = 'https://openspeech.bytedance.com/api/v1/tts';

  Future<String?> textToSpeech(String text) async {
    try {
      final body = jsonEncode({
        'app': {
          'appid': SpeechConfig.appId,
          'token': SpeechConfig.accessToken,
          'cluster': 'volcano_tts',
        },
        'user': {'uid': 'emotion_app'},
        'audio': {
          'voice_type': SpeechConfig.ttsVoiceType,
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

      final resp = await http.post(
        Uri.parse(_ttsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer;${SpeechConfig.accessToken}',
        },
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['code'] == 3000 && data['data'] != null) {
          final bytes = base64Decode(data['data']);
          final f = File('${Directory.systemTemp.path}/tts_${DateTime.now().microsecondsSinceEpoch}.mp3');
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
    try { _stt.cancel(); } catch (_) {}
  }
}
