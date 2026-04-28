import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../models/emotion_models.dart';

class EmotionService {
  // 本地情感分析 - 基于关键词权重
  // 后续可替换为 huggingface 中文预训练模型
  static final Map<String, Map<String, double>> _emotionKeywords = {
    '悲伤': {'sadness': 0.8, 'loneliness': 0.3},
    '难过': {'sadness': 0.7, 'loneliness': 0.4},
    '哭': {'sadness': 0.8, 'suppression': 0.2},
    '伤心': {'sadness': 0.8},
    '心痛': {'sadness': 0.7, 'suppression': 0.3},
    '想哭': {'sadness': 0.7, 'suppression': 0.2},
    '焦虑': {'anxiety': 0.8, 'suppression': 0.3},
    '担心': {'anxiety': 0.7},
    '紧张': {'anxiety': 0.6},
    '害怕': {'anxiety': 0.7, 'loneliness': 0.2},
    '不安': {'anxiety': 0.6, 'suppression': 0.2},
    '烦躁': {'anxiety': 0.5, 'anger': 0.3},
    '愤怒': {'anger': 0.8},
    '生气': {'anger': 0.7},
    '烦': {'anger': 0.5, 'anxiety': 0.3},
    '讨厌': {'anger': 0.6},
    '受够了': {'anger': 0.7, 'suppression': 0.3},
    '孤独': {'loneliness': 0.8, 'sadness': 0.3},
    '寂寞': {'loneliness': 0.7, 'sadness': 0.2},
    '一个人': {'loneliness': 0.6, 'sadness': 0.2},
    '没人': {'loneliness': 0.7},
    '压抑': {'suppression': 0.8, 'anxiety': 0.2},
    '委屈': {'suppression': 0.7, 'sadness': 0.3},
    '内耗': {'suppression': 0.6, 'anxiety': 0.4},
    '崩溃': {'suppression': 0.7, 'sadness': 0.3},
    '撑不住': {'suppression': 0.7, 'sadness': 0.3},
    '累': {'suppression': 0.5, 'anxiety': 0.2},
    '开心': {'happiness': 0.8},
    '高兴': {'happiness': 0.7},
    '幸福': {'happiness': 0.8, 'calmness': 0.2},
    '快乐': {'happiness': 0.7},
    '平静': {'calmness': 0.8},
    '放松': {'calmness': 0.7, 'happiness': 0.2},
    '安心': {'calmness': 0.7},
    '舒服': {'calmness': 0.6, 'happiness': 0.3},
    '失眠': {'anxiety': 0.5, 'suppression': 0.4, 'sadness': 0.2},
    '睡不着': {'anxiety': 0.4, 'suppression': 0.3},
    '压力大': {'anxiety': 0.6, 'suppression': 0.4},
    '工作': {'anxiety': 0.3, 'suppression': 0.2},
    'emo': {'sadness': 0.5, 'suppression': 0.3, 'loneliness': 0.2},
    '失恋': {'sadness': 0.7, 'loneliness': 0.4, 'suppression': 0.2},
    '分手': {'sadness': 0.6, 'loneliness': 0.3, 'anger': 0.2},
  };

  EmotionRecord analyze(String content) {
    final scores = <String, double>{
      'sadness': 0.0,
      'anxiety': 0.0,
      'anger': 0.0,
      'loneliness': 0.0,
      'happiness': 0.0,
      'calmness': 0.0,
      'suppression': 0.0,
    };

    for (final entry in _emotionKeywords.entries) {
      if (content.contains(entry.key)) {
        for (final score in entry.value.entries) {
          scores[score.key] = scores[score.key]! + score.value;
        }
      }
    }

    // 归一化到0-1
    final maxScore = scores.values.reduce(max);
    if (maxScore > 0) {
      for (final key in scores.keys) {
        scores[key] = (scores[key]! / maxScore).clamp(0.0, 1.0);
      }
    } else {
      // 默认平静
      scores['calmness'] = 0.6;
      scores['happiness'] = 0.2;
    }

    final dominantEmotion = _getDominantEmotion(scores);
    final id = md5.convert(utf8.encode('${content}${DateTime.now().millisecondsSinceEpoch}')).toString();

    return EmotionRecord(
      id: id,
      content: content,
      sadness: scores['sadness']!,
      anxiety: scores['anxiety']!,
      anger: scores['anger']!,
      loneliness: scores['loneliness']!,
      happiness: scores['happiness']!,
      calmness: scores['calmness']!,
      suppression: scores['suppression']!,
      dominantEmotion: dominantEmotion,
      createdAt: DateTime.now(),
    );
  }

  String _getDominantEmotion(Map<String, double> scores) {
    const emotionLabels = {
      'sadness': '悲伤',
      'anxiety': '焦虑',
      'anger': '愤怒',
      'loneliness': '孤独',
      'happiness': '开心',
      'calmness': '平静',
      'suppression': '压抑',
    };

    String maxKey = 'calmness';
    double maxVal = 0;
    for (final entry in scores.entries) {
      if (entry.value > maxVal) {
        maxVal = entry.value;
        maxKey = entry.key;
      }
    }
    return emotionLabels[maxKey] ?? '平静';
  }
}
