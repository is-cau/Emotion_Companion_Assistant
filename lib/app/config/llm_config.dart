/// 大模型 API 配置
/// 请通过应用内「API 配置」对话框填写你的 OpenAI 格式 API 信息
class LlmConfig {
  /// API 基础地址（如 https://api.openai.com/v1 或其他兼容地址）
  static const String baseUrl = '';

  /// API Key
  static const String apiKey = '';

  /// 模型名称（如 gpt-3.5-turbo、qwen-turbo 等）
  static const String model = '';

  /// 最大回复长度
  static const int maxTokens = 1024*2;

  /// 温度（0-1，越高越随机）
  static const double temperature = 0.7;
}
