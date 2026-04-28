import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../app/config/speech_config.dart';

class SpeechService {
  /// 文字转语音 (TTS)
  /// 返回临时音频文件路径，失败返回 null
  Future<String?> textToSpeech(String text) async {
    try {
      final body = jsonEncode({
        'app': {
          'appid': SpeechConfig.appId,
          'token': SpeechConfig.accessToken,
          'cluster': 'volcano_tts',
        },
        'user': {
          'uid': 'emotion_companion_user',
        },
        'audio': {
          'voice_type': SpeechConfig.ttsVoiceType,
          'encoding': 'mp3',
          'speed_ratio': SpeechConfig.ttsSpeed,
          'volume_ratio': SpeechConfig.ttsVolume,
          'pitch_ratio': SpeechConfig.ttsPitch,
        },
        'request': {
          'reqid': _generateReqId(),
          'text': text,
          'text_type': 'plain',
          'operation': 'query',
        },
      });

      final response = await http.post(
        Uri.parse(SpeechConfig.ttsBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer;${SpeechConfig.accessToken}',
        },
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 3000 && data['data'] != null) {
          // 响应可能直接包含 base64 编码的音频
          final audioBase64 = data['data'];
          final audioBytes = base64Decode(audioBase64);
          final tempFile = File(
            '${Directory.systemTemp.path}/tts_${DateTime.now().microsecondsSinceEpoch}.mp3',
          );
          await tempFile.writeAsBytes(audioBytes);
          return tempFile.path;
        } else {
          // 某些TTS接口返回二进制的，直接保存
          final tempFile = File(
            '${Directory.systemTemp.path}/tts_${DateTime.now().microsecondsSinceEpoch}.mp3',
          );
          await tempFile.writeAsBytes(response.bodyBytes);
          // 检查是否真的保存了音频
          if (await tempFile.length() > 100) {
            return tempFile.path;
          }
          return null;
        }
      } else {
        // 检查是否是直接返回二进制音频
        if (response.bodyBytes.length > 100) {
          final tempFile = File(
            '${Directory.systemTemp.path}/tts_${DateTime.now().microsecondsSinceEpoch}.mp3',
          );
          await tempFile.writeAsBytes(response.bodyBytes);
          return tempFile.path;
        }
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// 语音识别 (ASR) - 一次性识别
  /// [audioPath] 音频文件路径 (WAV, 16kHz, mono)
  /// 返回识别文本，失败返回 null
  Future<String?> speechToText(String audioPath) async {
    try {
      final file = File(audioPath);
      if (!await file.exists()) return null;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(SpeechConfig.asrBaseUrl),
      );

      request.headers['Authorization'] = 'Bearer;${SpeechConfig.accessToken}';
      request.fields['appid'] = SpeechConfig.appId;
      request.fields['request_id'] = _generateReqId();
      request.fields['format'] = 'wav';
      request.fields['rate'] = '16000';
      request.fields['bits'] = '16';
      request.fields['channel'] = '1';
      request.fields['language'] = 'zh-CN';

      request.files.add(
        await http.MultipartFile.fromPath('audio', audioPath),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 1000 && data['result'] != null) {
          return data['result'].toString();
        }
        // 其他可能的响应格式
        if (data['text'] != null) {
          return data['text'].toString();
        }
        return null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String _generateReqId() {
    return '${DateTime.now().microsecondsSinceEpoch}_${DateTime.now().millisecond}';
  }
}
