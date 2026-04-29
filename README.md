# 抱抱情绪云

一款轻量化治愈系心理健康情绪陪伴 Flutter 应用。

**核心功能：** 情绪分析 · 匿名树洞倾诉 · AI 暖心安慰 · 语音对话

## 功能特性

### 首页
- 根据时段自动切换暖心问候语
- 今日情绪状态总览（聚合当天所有日记的综合分析）
- 呼吸粒子动画倾诉按钮（HeartbeatBreathButton）
- 近期情绪波动柱状图（相对日期：今天/昨天/周X）
- 快捷入口：AI 暖心安慰、情绪分析、隐私中心

### 情绪树洞
- 匿名文字倾诉，支持多行输入
- 提交后弹窗显示 AI 深度分析进度（支持取消后台运行）
- AI 深度情绪分析（大模型 7 维度评分 + 情绪解读 + 舒缓建议）
- 情绪日记列表（情绪标签、时间、查看报告、删除）
- 一键清空所有日记（浅红色醒目按钮）
- 白噪音开关（小雨 / 晚风 / 溪流）
- 密码锁定保护（首次锁定需设置密码 → 专属密码提示）
- 二级安保：密保问题与答案（忘记密码时可通过密保找回并重置密码）

### AI 暖心安慰
- 流式对话（HTTP SSE，字词块模拟人类打字节奏）
- 打字光标闪烁特效（`▌`）
- 对话历史持久化，支持新建 / 切换 / 删除对话（侧边栏抽屉）
- AI 自动生成对话标题（≤10 字）
- 上次活跃对话自动恢复
- 情感陪伴师角色系统提示词
- 对话上下文记忆（最近 20 轮）
- 大模型不可用时自动降级到本地预设话术
- 流式失败自动降级到普通模式
- Markdown 格式化渲染（加粗、标题、引用、分隔线、列表、代码块）
- 语音输入（系统 ASR，中文识别）
- AI 回复语音朗读（豆包 TTS，火山方舟语音合成 2.0）
- 深呼吸引导 + 晚安语录快捷入口

### 情绪分析报告
- 7 维度情绪雷达图（悲伤 / 焦虑 / 愤怒 / 孤独 / 开心 / 平静 / 压抑）
- 各维度进度条 + AI 解读文案
- 舒缓建议卡片
- 近期情绪趋势图

### 隐私中心
- 树洞密码锁定（首次设置 → 专属密码提示；关闭需验证密码）
- 密码修改（无密码直接设置；有密码先验证旧密码再设新密码）
- 密保问题找回密码（二级安保）
- 夜间护眼模式（全局切换，即时生效，持久化存储）
- 一键清空所有记录
- 隐私政策说明

## 技术栈

| 层级 | 技术 |
|------|------|
| 框架 | Flutter 3.41 |
| 语言 | Dart（SDK ^3.11.5） |
| UI | Material 3 + 莫兰迪低饱和度配色 |
| 状态管理 | GetX（主题切换） + GlobalKey（跨页同步） |
| HTTP | http ^1.6.0（OpenAI 兼容格式 API） |
| 本地存储 | SharedPreferences + MD5 密码加密 |
| 图表 | fl_chart ^0.69.0（雷达图） |
| Markdown | flutter_markdown ^0.7.4 |
| 音频 | audioplayers ^6.1.0（白噪音 + TTS 播放） |
| 语音识别 | speech_to_text ^7.3.0（系统 ASR） |
| 字体 | google_fonts ^6.2.1 |
| SVG | flutter_svg ^2.0.10 |
| 工具 | intl ^0.19.0 · crypto ^3.0.6 |
| 情感分析 | 本地关键词权重 + 大模型深度分析 |

## 项目结构

```
lib/
├── main.dart                           # 入口 + 底部导航（GlobalKey 跨页同步）
├── app/
│   ├── config/
│   │   ├── llm_config.dart             # 大模型 API 配置
│   │   └── speech_config.dart          # 豆包语音配置（TTS + ASR）
│   ├── routes/app_routes.dart          # 路由
│   ├── themes/
│   │   ├── app_colors.dart             # 莫兰迪配色定义
│   │   └── app_theme.dart              # 明/暗双主题
│   └── app_controller.dart             # GetX 全局状态（主题切换）
├── pages/
│   ├── home/home_page.dart             # 首页
│   ├── treehole/treehole_page.dart     # 情绪树洞
│   ├── comfort/comfort_page.dart       # AI 暖心安慰
│   ├── analysis/analysis_page.dart     # 情绪分析报告
│   └── privacy/privacy_page.dart       # 隐私中心
├── widgets/
│   ├── emotion_radar.dart              # 情绪雷达图
│   └── heartbeat_breath_button.dart    # 呼吸粒子动画按钮
├── services/
│   ├── llm_service.dart                # 大模型 API（流式/普通/情绪分析/标题生成）
│   ├── emotion_service.dart            # 本地情感分析（关键词权重算法）
│   ├── ai_comfort_service.dart         # 本地预设安慰话术（降级备选）
│   ├── speech_service.dart             # 语音服务（系统 ASR + 豆包 TTS）
│   ├── storage_service.dart            # 本地存储（记录/对话/密码/密保/主题）
│   └── icon_service.dart               # Android 动态图标切换
└── models/
    └── emotion_models.dart             # EmotionRecord / ChatMessage / Conversation
```

## 快速开始

### 1. 配置大模型 API

编辑 `lib/app/config/llm_config.dart`：

```dart
static const String baseUrl = 'https://api.openai.com/v1';
static const String apiKey = 'sk-xxxxxxxxxxxxxxxx';
static const String model = 'gpt-3.5-turbo';
```

支持所有 OpenAI 兼容格式的 API（DeepSeek / Qwen / GLM 等）。未配置时自动使用本地预设话术。

### 2. 配置语音服务（可选）

编辑 `lib/app/config/speech_config.dart`，填入火山方舟 API 凭证：

```dart
static const String arkApiKey = 'api-key-xxxxx';
static const String appId = 'your-app-id';
static const String accessToken = 'your-access-token';
static const String secretKey = 'your-secret-key';
```

- **语音输入**：使用系统内置 ASR（`speech_to_text` 插件），无需额外配置
- **语音合成**：使用豆包语音合成 2.0（火山方舟 TTS），支持多种音色

### 3. 准备资源文件

在项目根目录下放置以下资源：

```
assets/
├── images/          # 图片资源
├── audio/           # 白噪音音频
│   ├── rain.mp3         # 小雨
│   ├── night_wind.mp3   # 晚风
│   └── stream.mp3       # 溪流
└── icons/           # 应用图标
```

### 4. 运行

```bash
# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Chrome
flutter run -d chrome

# Android
flutter run -d android
```

### 5. 打包

```bash
# Windows
flutter build windows

# macOS
flutter build macos

# Android
flutter build apk --release
```

## 许可证

MIT
