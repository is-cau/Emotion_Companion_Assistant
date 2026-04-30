# 抱抱情绪云

一款轻量化治愈系心理健康情绪陪伴 Flutter 应用。

**核心功能：** 情绪分析 · 匿名树洞倾诉 · AI 暖心安慰 · AI 梦境解读 · 语音朗读

## 功能特性

### 首页
- 根据时段自动切换暖心问候语
- 今日情绪状态总览（聚合当天所有日记的综合分析）
- 呼吸粒子动画倾诉按钮（HeartbeatBreathButton）
- 近期情绪波动柱状图（相对日期：今天/昨天/周X）
- 快捷入口（2×2 网格）：AI 暖心安慰、情绪分析、隐私中心、AI 梦境解读

### 情绪树洞
- 匿名文字倾诉，支持多行输入
- 提交后弹窗显示 AI 深度分析进度（支持取消后台运行）
- AI 深度情绪分析（大模型 7 维度评分 + 情绪解读 + 舒缓建议）
- 情绪日记列表（情绪标签、时间、查看报告、删除）
- 一键清空所有日记（浅红色醒目按钮）
- 白噪音开关（小雨 / 晚风 / 溪流），支持 3 秒淡入淡出平滑过渡
- 密码锁定保护（首次锁定需设置密码 → 专属密码提示）
- 二级安保：密保问题与答案（忘记密码时可通过密保找回并重置密码）

### AI 暖心安慰
- 流式对话（HTTP SSE，字词块模拟人类打字节奏）
- 打字光标闪烁特效（`▌`）
- 对话历史持久化，支持新建 / 切换 / 删除对话（侧边栏抽屉）
- AI 自动生成对话标题（≤10 字）
- 上次活跃对话自动恢复
- 情感陪伴师角色系统提示词
- 对话上下文记忆（恢复对话同步加载历史，最近 10 轮/20 条，单条超 800 字符截断）
- 大模型不可用时自动降级到本地预设话术
- 流式失败自动降级到普通模式
- Markdown 格式化渲染（加粗、标题、引用、分隔线、列表、代码块）
- AI 回复语音朗读（豆包 TTS，火山方舟语音合成 2.0，长文本自动分段朗读）
- 深呼吸引导 + 晚安语录快捷入口
- 右上角菜单支持切换大模型模式、音色、新建对话、配置语音合成

### AI 梦境解读
- 输入梦境片段，AI 从 5 个维度深度解析
- 维度：梦境主题与象征、情绪分析、心理学解读、生活关联、建议与引导
- AI 自动生成诗意梦境标题
- Markdown 格式化渲染分析结果
- 梦境解读历史记录持久化（支持查看、单条删除、一键清空全部）
- 解析中退出再进入自动恢复进度，不丢失记录
- 空状态引导提示
- 错误重试机制

### 情绪分析报告
- 7 维度情绪雷达图（悲伤 / 焦虑 / 愤怒 / 孤独 / 开心 / 平静 / 压抑）
- 各维度进度条 + AI 解读文案
- 舒缓建议卡片
- 近期情绪趋势图

### 隐私中心
- 树洞密码锁定（首次设置 → 专属密码提示；关闭需验证密码）
- 密码修改（无密码直接设置；有密码先验证旧密码再设新密码）
- 密保问题找回密码（二级安保）
- 夜间护眼模式（全局切换，即时生效，持久化存储，所有页面适配暗色主题）
- 一键清空所有记录
- 大模型自定义配置（支持 OpenAI 兼容 API + 测试连接）
- 语音合成自定义配置（API 地址、模型、音色、语速、音量 + 测试连接）
- 隐私政策说明

## 技术栈

| 层级 | 技术 |
|------|------|
| 框架 | Flutter 3.41 |
| 语言 | Dart（SDK ^3.11.5） |
| UI | Material 3 + 莫兰迪低饱和度配色 + 明暗双主题 |
| 状态管理 | GetX（主题切换） + GlobalKey（跨页同步） |
| HTTP | http ^1.6.0（OpenAI 兼容格式 API） |
| 本地存储 | SharedPreferences + MD5 密码加密 |
| 图表 | CustomPaint 情绪雷达图 |
| Markdown | flutter_markdown ^0.7.4（对话 + 梦境解读） |
| 音频 | audioplayers ^6.1.0（白噪音 + TTS 播放） |

| 字体 | google_fonts ^6.2.1 |
| SVG | flutter_svg ^2.0.10 |
| 工具 | intl ^0.19.0 · crypto ^3.0.6 |
| 情感分析 | 本地关键词权重 + 大模型深度分析 |
| 梦境分析 | 大模型多维度梦境解读 |

## 项目结构

```
lib/
├── main.dart                           # 入口 + 底部导航（GlobalKey 跨页同步）
├── app/
│   ├── config/
│   │   ├── llm_config.dart             # 大模型 API 配置
│   │   └── speech_config.dart          # 语音合成配置（TTS 可配置项默认值）
│   ├── routes/app_routes.dart          # 路由
│   ├── themes/
│   │   ├── app_colors.dart             # 莫兰迪配色定义（含暗色令牌）
│   │   └── app_theme.dart              # 明/暗双主题（完整 TextTheme + 组件主题）
│   └── app_controller.dart             # GetX 全局状态（主题切换）
├── pages/
│   ├── home/home_page.dart             # 首页（问候 + 情绪概览 + 快捷入口）
│   ├── treehole/treehole_page.dart     # 情绪树洞（倾诉 + AI 分析 + 日记 + 白噪音）
│   ├── comfort/comfort_page.dart       # AI 暖心安慰（流式对话 + 语音 + 音色切换）
│   ├── analysis/analysis_page.dart     # 情绪分析报告（雷达图 + 建议 + 趋势）
│   ├── dream/dream_page.dart           # AI 梦境解读（多维度分析 + 历史记录）
│   └── privacy/privacy_page.dart       # 隐私中心（密码/密保/暗色模式/清空数据）
├── widgets/
│   ├── emotion_radar.dart              # 情绪雷达图（CustomPaint）
│   ├── heartbeat_breath_button.dart    # 呼吸粒子动画按钮
│   ├── app_splash.dart                 # 启动闪屏动画
│   ├── llm_config_dialog.dart          # 大模型配置弹窗
│   └── speech_config_dialog.dart       # 语音合成配置弹窗
├── services/
│   ├── llm_service.dart                # 大模型 API（对话/流式/情绪分析/梦境解读/标题生成）
│   ├── emotion_service.dart            # 本地情感分析（关键词权重算法）
│   ├── ai_comfort_service.dart         # 本地预设安慰话术（降级备选）
│   ├── speech_service.dart             # 语音服务（豆包 TTS）
│   ├── storage_service.dart            # 本地存储（记录/对话/梦境/密码/密保/主题/LLM配置）
│   └── icon_service.dart               # Android 动态图标切换
└── models/
    └── emotion_models.dart             # EmotionRecord / DreamRecord / ChatMessage / Conversation
```

## 快速开始

### 1. 配置大模型 API

编辑 `lib/app/config/llm_config.dart`：

```dart
static const String baseUrl = 'https://api.openai.com/v1';
static const String apiKey = 'sk-xxxxxxxxxxxxxxxx';
static const String model = 'gpt-3.5-turbo';
```

支持所有 OpenAI 兼容格式的 API（DeepSeek / Qwen / GLM 等）。未配置时自动使用本地预设话术。也可在 APP 内「隐私中心 → 大模型配置」中自定义。同样支持语音合成的完整自定义配置（API 地址、模型、音色、语速、音量）及测试连接。

### 2. 配置语音服务（可选）

编辑 `lib/app/config/speech_config.dart`，填入火山方舟 API 凭证：

```dart
static const String arkApiKey = 'api-key-xxxxx';
static const String appId = 'your-app-id';
static const String accessToken = 'your-access-token';
static const String secretKey = 'your-secret-key';
```

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
