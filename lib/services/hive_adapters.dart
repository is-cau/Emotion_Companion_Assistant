import 'package:hive_ce/hive.dart';
import '../models/emotion_models.dart';

class EmotionRecordAdapter extends TypeAdapter<EmotionRecord> {
  @override
  final int typeId = 0;

  @override
  EmotionRecord read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      final key = reader.readByte();
      fields[key] = reader.read();
    }
    return EmotionRecord(
      id: fields[0] as String,
      content: fields[1] as String,
      sadness: (fields[2] as num?)?.toDouble() ?? 0,
      anxiety: (fields[3] as num?)?.toDouble() ?? 0,
      anger: (fields[4] as num?)?.toDouble() ?? 0,
      loneliness: (fields[5] as num?)?.toDouble() ?? 0,
      happiness: (fields[6] as num?)?.toDouble() ?? 0,
      calmness: (fields[7] as num?)?.toDouble() ?? 0,
      suppression: (fields[8] as num?)?.toDouble() ?? 0,
      dominantEmotion: fields[9] as String? ?? '平静',
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[10] as int),
      interpretation: fields[11] as String? ?? '',
      suggestions: (fields[12] as List?)?.cast<String>() ?? [],
    );
  }

  @override
  void write(BinaryWriter writer, EmotionRecord obj) {
    writer.writeByte(13);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.content);
    writer.writeByte(2);
    writer.write(obj.sadness);
    writer.writeByte(3);
    writer.write(obj.anxiety);
    writer.writeByte(4);
    writer.write(obj.anger);
    writer.writeByte(5);
    writer.write(obj.loneliness);
    writer.writeByte(6);
    writer.write(obj.happiness);
    writer.writeByte(7);
    writer.write(obj.calmness);
    writer.writeByte(8);
    writer.write(obj.suppression);
    writer.writeByte(9);
    writer.write(obj.dominantEmotion);
    writer.writeByte(10);
    writer.write(obj.createdAt.millisecondsSinceEpoch);
    writer.writeByte(11);
    writer.write(obj.interpretation);
    writer.writeByte(12);
    writer.write(obj.suggestions);
  }
}

class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 1;

  @override
  ChatMessage read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      final key = reader.readByte();
      fields[key] = reader.read();
    }
    return ChatMessage(
      id: fields[0] as String,
      content: fields[1] as String,
      isUser: fields[2] as bool,
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[3] as int),
      emotion: fields[4] as String? ?? '平静',
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer.writeByte(5);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.content);
    writer.writeByte(2);
    writer.write(obj.isUser);
    writer.writeByte(3);
    writer.write(obj.createdAt.millisecondsSinceEpoch);
    writer.writeByte(4);
    writer.write(obj.emotion);
  }
}

class ConversationAdapter extends TypeAdapter<Conversation> {
  @override
  final int typeId = 2;

  @override
  Conversation read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      final key = reader.readByte();
      fields[key] = reader.read();
    }
    return Conversation(
      id: fields[0] as String,
      title: fields[1] as String? ?? '新对话',
      messages: (fields[2] as List?)?.cast<ChatMessage>() ?? [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[3] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(fields[4] as int),
    );
  }

  @override
  void write(BinaryWriter writer, Conversation obj) {
    writer.writeByte(5);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.title);
    writer.writeByte(2);
    writer.write(obj.messages);
    writer.writeByte(3);
    writer.write(obj.createdAt.millisecondsSinceEpoch);
    writer.writeByte(4);
    writer.write(obj.updatedAt.millisecondsSinceEpoch);
  }
}

class DreamRecordAdapter extends TypeAdapter<DreamRecord> {
  @override
  final int typeId = 3;

  @override
  DreamRecord read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      final key = reader.readByte();
      fields[key] = reader.read();
    }
    return DreamRecord(
      id: fields[0] as String,
      dreamText: fields[1] as String,
      analysis: fields[2] as String,
      title: fields[3] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(fields[4] as int),
    );
  }

  @override
  void write(BinaryWriter writer, DreamRecord obj) {
    writer.writeByte(5);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.dreamText);
    writer.writeByte(2);
    writer.write(obj.analysis);
    writer.writeByte(3);
    writer.write(obj.title);
    writer.writeByte(4);
    writer.write(obj.createdAt.millisecondsSinceEpoch);
  }
}
