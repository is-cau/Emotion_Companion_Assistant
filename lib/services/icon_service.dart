import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class IconService {
  static const _channel = MethodChannel('com.emotioncompanion/icon');

  static Future<void> setIcon(bool isNight) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('setIcon', {'isNight': isNight});
    } catch (e) {
      // 非 Android 平台忽略
    }
  }
}
