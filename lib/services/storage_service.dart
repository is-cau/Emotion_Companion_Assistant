import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:crypto/crypto.dart';
import '../models/emotion_models.dart';
import '../app/config/speech_config.dart';

class StorageService {
  static const String _settingsBox = 'settings';
  static const String _recordsBox = 'emotion_records';
  static const String _conversationsBox = 'conversations';
  static const String _dreamRecordsBox = 'dream_records';

  static const String _lockKey = 'treehole_locked';
  static const String _pinKey = 'treehole_pin';
  static const String _recoveryQuestionKey = 'treehole_recovery_question';
  static const String _recoveryAnswerKey = 'treehole_recovery_answer';
  static const String _activeConvKey = 'active_conversation_id';
  static const String _ttsVoiceTypeKey = 'tts_voice_type';
  static const String _llmBaseUrlKey = 'llm_base_url';
  static const String _llmApiKeyKey = 'llm_api_key';
  static const String _llmModelKey = 'llm_model';
  static const String _ttsBaseUrlKey = 'tts_base_url';
  static const String _ttsApiKeyKey = 'tts_api_key';
  static const String _ttsModelKey = 'tts_model';
  static const String _ttsSpeedKey = 'tts_speed';
  static const String _ttsVolumeKey = 'tts_volume';
  static const String _pendingDreamTextKey = 'pending_dream_text';
  static const String _pendingDreamIdKey = 'pending_dream_id';
  static const String _darkModeKey = 'dark_mode';
  static const String _fortuneDateKey = 'fortune_date';
  static const String _fortuneLevelKey = 'fortune_level';
  static const String _fortuneBlessingKey = 'fortune_blessing';

  Box _settings() => Hive.box(_settingsBox);
  Box<EmotionRecord> _records() => Hive.box<EmotionRecord>(_recordsBox);
  Box<Conversation> _conversations() => Hive.box<Conversation>(_conversationsBox);
  Box<DreamRecord> _dreams() => Hive.box<DreamRecord>(_dreamRecordsBox);

  static Future<void> init() async {
    await Hive.openBox(_settingsBox);
    await Hive.openBox<EmotionRecord>(_recordsBox);
    await Hive.openBox<Conversation>(_conversationsBox);
    await Hive.openBox<DreamRecord>(_dreamRecordsBox);
  }

  // ===== 情绪记录 =====

  Future<List<EmotionRecord>> getAllRecords() async {
    final list = _records().values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> saveRecord(EmotionRecord record) async {
    await _records().put(record.id, record);
  }

  Future<void> deleteRecord(String id) async {
    await _records().delete(id);
  }

  Future<void> clearAllRecords() async {
    await _records().clear();
  }

  // ===== 树洞锁定 =====

  Future<bool> isLocked() async => _settings().get(_lockKey, defaultValue: false);

  Future<void> setLocked(bool locked) async => _settings().put(_lockKey, locked);

  Future<void> setPin(String pin) async {
    final hashed = md5.convert(utf8.encode(pin)).toString();
    await _settings().put(_pinKey, hashed);
  }

  Future<bool> verifyPin(String pin) async {
    final stored = _settings().get(_pinKey);
    if (stored == null) return true;
    final hashed = md5.convert(utf8.encode(pin)).toString();
    return hashed == stored;
  }

  Future<bool> hasPin() async => _settings().containsKey(_pinKey);

  Future<void> clearPin() async => _settings().delete(_pinKey);

  // ===== 密保 =====

  Future<void> setRecoveryQA(String question, String answer) async {
    await _settings().put(_recoveryQuestionKey, question);
    final hashed = md5.convert(utf8.encode(answer)).toString();
    await _settings().put(_recoveryAnswerKey, hashed);
  }

  Future<String?> getRecoveryQuestion() async => _settings().get(_recoveryQuestionKey);

  Future<bool> verifyRecoveryAnswer(String answer) async {
    final stored = _settings().get(_recoveryAnswerKey);
    if (stored == null) return false;
    final hashed = md5.convert(utf8.encode(answer)).toString();
    return hashed == stored;
  }

  Future<bool> hasRecoveryQA() async => _settings().containsKey(_recoveryQuestionKey);

  // ===== 夜间模式 =====

  Future<bool> getDarkMode() async => _settings().get(_darkModeKey, defaultValue: false);

  Future<void> setDarkMode(bool value) async => _settings().put(_darkModeKey, value);

  // ===== 对话管理 =====

  Future<List<Conversation>> getAllConversations() async {
    final list = _conversations().values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<void> saveConversation(Conversation conv) async {
    await _conversations().put(conv.id, conv);
  }

  Future<void> deleteConversation(String id) async {
    await _conversations().delete(id);
  }

  Future<String?> getActiveConversationId() async => _settings().get(_activeConvKey);

  Future<void> setActiveConversationId(String? id) async {
    if (id == null) {
      await _settings().delete(_activeConvKey);
    } else {
      await _settings().put(_activeConvKey, id);
    }
  }

  // ===== TTS 音色 =====

  Future<String> getTtsVoiceType() async =>
      _settings().get(_ttsVoiceTypeKey, defaultValue: SpeechConfig.defaultVoiceType);

  Future<void> setTtsVoiceType(String voiceType) async =>
      _settings().put(_ttsVoiceTypeKey, voiceType);

  // ===== TTS 语速/音量 =====

  Future<double?> getTtsSpeed() async => _settings().get(_ttsSpeedKey);

  Future<void> setTtsSpeed(double? speed) async {
    if (speed == null) {
      await _settings().delete(_ttsSpeedKey);
    } else {
      await _settings().put(_ttsSpeedKey, speed);
    }
  }

  Future<double?> getTtsVolume() async => _settings().get(_ttsVolumeKey);

  Future<void> setTtsVolume(double? volume) async {
    if (volume == null) {
      await _settings().delete(_ttsVolumeKey);
    } else {
      await _settings().put(_ttsVolumeKey, volume);
    }
  }

  // ===== 大模型配置 =====

  Future<String?> getLlmBaseUrl() async => _settings().get(_llmBaseUrlKey);
  Future<void> setLlmBaseUrl(String? url) async {
    if (url == null || url.isEmpty) {
      await _settings().delete(_llmBaseUrlKey);
    } else {
      await _settings().put(_llmBaseUrlKey, url);
    }
  }
  Future<String?> getLlmApiKey() async => _settings().get(_llmApiKeyKey);
  Future<void> setLlmApiKey(String? key) async {
    if (key == null || key.isEmpty) {
      await _settings().delete(_llmApiKeyKey);
    } else {
      await _settings().put(_llmApiKeyKey, key);
    }
  }
  Future<String?> getLlmModel() async => _settings().get(_llmModelKey);
  Future<void> setLlmModel(String? model) async {
    if (model == null || model.isEmpty) {
      await _settings().delete(_llmModelKey);
    } else {
      await _settings().put(_llmModelKey, model);
    }
  }

  Future<bool> hasLlmUserConfig() async {
    final url = await getLlmBaseUrl();
    final key = await getLlmApiKey();
    return url != null && url.isNotEmpty && key != null && key.isNotEmpty;
  }

  Future<void> clearLlmConfig() async {
    await _settings().delete(_llmBaseUrlKey);
    await _settings().delete(_llmApiKeyKey);
    await _settings().delete(_llmModelKey);
  }

  // ===== 梦境记录 =====

  Future<List<DreamRecord>> getAllDreamRecords() async {
    final list = _dreams().values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> saveDreamRecord(DreamRecord record) async {
    await _dreams().put(record.id, record);
  }

  Future<void> deleteDreamRecord(String id) async {
    await _dreams().delete(id);
  }

  Future<void> clearAllDreamRecords() async {
    await _dreams().clear();
  }

  // ===== 进行中的梦境解析 =====

  Future<String?> getPendingDreamText() async => _settings().get(_pendingDreamTextKey);
  Future<String?> getPendingDreamId() async => _settings().get(_pendingDreamIdKey);

  Future<void> setPendingDream(String id, String text) async {
    await _settings().put(_pendingDreamIdKey, id);
    await _settings().put(_pendingDreamTextKey, text);
  }

  Future<void> clearPendingDream() async {
    await _settings().delete(_pendingDreamIdKey);
    await _settings().delete(_pendingDreamTextKey);
  }

  // ===== TTS 配置 =====

  Future<String?> getTtsBaseUrl() async => _settings().get(_ttsBaseUrlKey);
  Future<void> setTtsBaseUrl(String? url) async {
    if (url == null || url.isEmpty) {
      await _settings().delete(_ttsBaseUrlKey);
    } else {
      await _settings().put(_ttsBaseUrlKey, url);
    }
  }
  Future<String?> getTtsApiKey() async => _settings().get(_ttsApiKeyKey);
  Future<void> setTtsApiKey(String? key) async {
    if (key == null || key.isEmpty) {
      await _settings().delete(_ttsApiKeyKey);
    } else {
      await _settings().put(_ttsApiKeyKey, key);
    }
  }
  Future<String?> getTtsModel() async => _settings().get(_ttsModelKey);
  Future<void> setTtsModel(String? model) async {
    if (model == null || model.isEmpty) {
      await _settings().delete(_ttsModelKey);
    } else {
      await _settings().put(_ttsModelKey, model);
    }
  }

  Future<bool> hasTtsUserConfig() async {
    final url = await getTtsBaseUrl();
    final key = await getTtsApiKey();
    return url != null && url.isNotEmpty && key != null && key.isNotEmpty;
  }

  Future<void> clearTtsConfig() async {
    await _settings().delete(_ttsBaseUrlKey);
    await _settings().delete(_ttsApiKeyKey);
    await _settings().delete(_ttsModelKey);
    await _settings().delete(_ttsSpeedKey);
    await _settings().delete(_ttsVolumeKey);
  }

  // ===== 抽签 =====

  Future<String?> getFortuneDate() async => _settings().get(_fortuneDateKey);
  Future<void> setFortuneDate(String date) async => _settings().put(_fortuneDateKey, date);
  Future<int?> getFortuneLevel() async => _settings().get(_fortuneLevelKey);
  Future<void> setFortuneLevel(int level) async => _settings().put(_fortuneLevelKey, level);
  Future<String?> getFortuneBlessing() async => _settings().get(_fortuneBlessingKey);
  Future<void> setFortuneBlessing(String blessing) async => _settings().put(_fortuneBlessingKey, blessing);
  Future<void> clearFortune() async {
    await _settings().delete(_fortuneDateKey);
    await _settings().delete(_fortuneLevelKey);
    await _settings().delete(_fortuneBlessingKey);
  }
}
