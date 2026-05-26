/// TTS 语音配置
/// 支持两种模式：系统默认 TTS（无需配置）和自定义 API TTS
class SpeechConfig {
  // ========== TTS 提供者模式 ==========

  /// 使用系统默认 TTS 引擎
  static const String providerSystem = 'system';

  /// 使用自定义 API TTS（火山方舟/豆包等）
  static const String providerApi = 'api';

  /// TTS 提供者显示名映射
  static const Map<String, String> providerLabels = {
    'system': '系统默认',
    'api': '自定义 API',
  };

  // ========== 火山方舟 API 配置（仅 provider=api 时使用） ==========

  /// 火山方舟 API Key (Ark 平台鉴权)
  static const String arkApiKey = '';

  /// 豆包语音 App ID
  static const String appId = '';

  /// 豆包语音 Access Token (AK)
  static const String accessToken = '';

  /// 豆包语音 Secret Key (SK) - 用于签名鉴权
  static const String secretKey = '';

  /// TTS 模型 (豆包语音合成2.0)
  static const String ttsModel = 'doubao-tts-2.0';

  /// API TTS 音色常量 (豆包语音合成2.0)
  static const String voiceTypeFemale = 'zh_female_vv_uranus_bigtts'; // vivi 2.0 (清新女声)
  static const String voiceTypeMale = 'zh_male_m191_uranus_bigtts';   // 云舟 (沉稳男声)

  /// 音色显示名映射
  static const Map<String, String> voiceTypeLabels = {
    'zh_female_vv_uranus_bigtts': 'vivi 2.0 (清新女声)',
    'zh_male_m191_uranus_bigtts': '云舟 (沉稳男声)',
  };

  /// 默认音色
  static const String defaultVoiceType = voiceTypeFemale;

  // ========== 通用 TTS 参数 ==========

  /// TTS 语速 (0.5-2.0)
  static const double ttsSpeed = 1.2;

  /// TTS 音量 (0.1-3.0，1.0 为原音量)
  static const double defaultVolume = 1.0;

  /// TTS 音调 (0.5-2.0，1.0 为默认)
  static const double defaultPitch = 1.0;

  /// TTS 单次请求最大文本字节数 (火山方舟 API 限制约 1024 字节)
  static const int ttsMaxTextBytes = 1000;
}
