import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import '../models/emotion_models.dart';

class StorageService {
  static const String _recordsKey = 'emotion_records';
  static const String _lockKey = 'treehole_locked';
  static const String _pinKey = 'treehole_pin';
  static const String _recoveryQuestionKey = 'treehole_recovery_question';
  static const String _recoveryAnswerKey = 'treehole_recovery_answer';
  static const String _conversationsKey = 'conversations';
  static const String _activeConvKey = 'active_conversation_id';

  Future<List<EmotionRecord>> getAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_recordsKey) ?? [];
    return data.map((e) => EmotionRecord.fromJson(jsonDecode(e))).toList();
  }

  Future<void> saveRecord(EmotionRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await getAllRecords();
    // 按 id 去重：已存在则更新，否则新增
    final existingIndex = records.indexWhere((r) => r.id == record.id);
    if (existingIndex >= 0) {
      records[existingIndex] = record;
    } else {
      records.insert(0, record);
    }
    // 最多保留200条
    if (records.length > 200) records.removeRange(200, records.length);
    await prefs.setStringList(
      _recordsKey,
      records.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> deleteRecord(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await getAllRecords();
    records.removeWhere((r) => r.id == id);
    await prefs.setStringList(
      _recordsKey,
      records.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> clearAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recordsKey);
  }

  Future<bool> isLocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lockKey) ?? false;
  }

  Future<void> setLocked(bool locked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockKey, locked);
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final hashed = md5.convert(utf8.encode(pin)).toString();
    await prefs.setString(_pinKey, hashed);
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pinKey);
    if (stored == null) return true;
    final hashed = md5.convert(utf8.encode(pin)).toString();
    return hashed == stored;
  }

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pinKey);
  }

  // ===== 密码找回（二级安保） =====

  Future<void> setRecoveryQA(String question, String answer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recoveryQuestionKey, question);
    final hashed = md5.convert(utf8.encode(answer)).toString();
    await prefs.setString(_recoveryAnswerKey, hashed);
  }

  Future<String?> getRecoveryQuestion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_recoveryQuestionKey);
  }

  Future<bool> verifyRecoveryAnswer(String answer) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_recoveryAnswerKey);
    if (stored == null) return false;
    final hashed = md5.convert(utf8.encode(answer)).toString();
    return hashed == stored;
  }

  Future<bool> hasRecoveryQA() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_recoveryQuestionKey);
  }

  /// 清除密码及密保（用于找回密码后重置）
  Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
  }

  // ===== 夜间模式 =====

  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('dark_mode') ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
  }

  // ===== 对话管理 =====

  Future<List<Conversation>> getAllConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_conversationsKey) ?? [];
    final list = data
        .map((e) => Conversation.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<void> saveConversation(Conversation conv) async {
    final prefs = await SharedPreferences.getInstance();
    final conversations = await getAllConversations();
    final idx = conversations.indexWhere((c) => c.id == conv.id);
    if (idx >= 0) {
      conversations[idx] = conv;
    } else {
      conversations.insert(0, conv);
    }
    // 最多保留50个对话
    if (conversations.length > 50) conversations.removeRange(50, conversations.length);
    await prefs.setStringList(
      _conversationsKey,
      conversations.map((c) => jsonEncode(c.toJson())).toList(),
    );
  }

  Future<void> deleteConversation(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final conversations = await getAllConversations();
    conversations.removeWhere((c) => c.id == id);
    await prefs.setStringList(
      _conversationsKey,
      conversations.map((c) => jsonEncode(c.toJson())).toList(),
    );
  }

  Future<String?> getActiveConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeConvKey);
  }

  Future<void> setActiveConversationId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_activeConvKey);
    } else {
      await prefs.setString(_activeConvKey, id);
    }
  }
}
