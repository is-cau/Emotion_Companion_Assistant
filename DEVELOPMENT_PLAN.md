# 情感分析小助手 - 开发步骤计划

## 项目概述
一款轻量化治愈系心理健康情绪陪伴APP，主打：情感分析、匿名树洞倾诉、AI暖心安慰

---

## 第一阶段：技术选型与项目架构

### 1.1 技术栈确定
| 层级 | 技术选择 | 说明 |
|------|----------|------|
| 跨端框架 | **Flutter 3.41.7** | 全平台适配（Android/iOS/Windows/macOS/Linux/Web） |
| 前端UI | Flutter Widget + Material3 | 莫兰迪配色，圆角卡片 |
| 本地存储 | SharedPreferences + 加密（MD5） | 轻量级，本地加密存储 |
| 状态管理 | GetX | 轻量，简洁 |
| HTTP请求 | http ^1.6.0 | OpenAI格式API调用 |
| **情感分析** | **本地关键词权重分析** | 免费，无需API，后续可接入huggingface中文预训练模型 |
| **AI对话** | **OpenAI格式API（流式输出）** | 兼容所有OpenAI格式的大模型服务 |
| 语音识别 | 可选暂不加 | 后续按需添加 SenseVoice/Whisper |

**模型方案：**
- 情感分析（当前）：本地关键词权重算法，识别20+细分情绪维度
- 情感分析（升级）：`IDEA-CCNL/Erlangshen-Roberta-110M-Sentiment` 或 `uer/roberta-base-finetuned-jd-binary-chinese`
- AI对话：OpenAI兼容格式API，支持任意大模型（GPT/Qwen/DeepSeek/GLM等）

### 1.2 项目目录结构
```
emotion_companion/
├── lib/
│   ├── main.dart                    # 主入口 + 底部导航
│   ├── app/
│   │   ├── config/
│   │   │   └── llm_config.dart      # 大模型API配置（base-url/key/model）
│   │   ├── routes/
│   │   │   └── app_routes.dart      # 路由配置
│   │   └── themes/
│   │       ├── app_colors.dart      # 莫兰迪配色定义
│   │       └── app_theme.dart       # 明/暗主题配置
│   ├── pages/
│   │   ├── home/
│   │   │   └── home_page.dart       # 首页（问候+倾诉按钮+情绪卡片）
│   │   ├── treehole/
│   │   │   └── treehole_page.dart   # 情绪树洞（匿名输入+白噪音+日记）
│   │   ├── comfort/
│   │   │   └── comfort_page.dart    # AI暖心安慰（大模型对话+流式输出）
│   │   ├── analysis/
│   │   │   └── analysis_page.dart   # 情绪分析（雷达图+维度+建议）
│   │   └── privacy/
│   │       └── privacy_page.dart    # 隐私中心（锁定+清空+政策）
│   ├── widgets/
│   │   └── emotion_radar.dart       # 情绪雷达图组件
│   ├── services/
│   │   ├── llm_service.dart         # 大模型API调用（OpenAI格式，流式+普通）
│   │   ├── emotion_service.dart     # 本地情感分析（关键词权重算法）
│   │   ├── ai_comfort_service.dart  # 本地预设安慰话术（降级备选）
│   │   └── storage_service.dart     # 本地加密存储
│   └── models/
│       └── emotion_models.dart      # 数据模型
├── assets/
│   ├── images/
│   ├── audio/
│   └── icons/
├── pubspec.yaml
└── test/
```

---

## 第二阶段：UI界面开发（已完成）

### 2.1 全局主题配置
- [x] 莫兰迪低饱和度配色（雾霾蓝、柔粉、浅青、奶白、暖米、柔紫）
- [x] 圆角卡片样式（borderRadius: 16-24）
- [x] 护眼夜间模式（darkTheme已配置）
- [x] Material3 设计规范

### 2.2 首页 (Home Page)
- [x] 顶部暖心问候标语（根据时段自动切换）
- [x] 一键「开始情绪倾诉」大按钮（渐变圆形+爱心图标）
- [x] 今日情绪状态卡片
- [x] 情绪波动柱状图
- [x] 底部导航栏（首页/树洞/AI安慰/我的）
- [x] 快捷功能入口（AI安慰/情绪分析/隐私中心）

### 2.3 情绪树洞页面 (Treehole Page)
- [x] 匿名输入框（文字，支持多行）
- [x] 隐私加密图标提示
- [x] 白噪音开关（雨声/晚风/森林）
- [x] 情绪日记列表
- [x] 树洞锁定功能（密码保护）
- [ ] 语音输入按钮（后续添加）

### 2.4 AI暖心安慰页面 (Comfort Page)
- [x] AI头像+渐变气泡
- [x] 对话气泡列表（用户/AI双向）
- [x] 输入框+发送按钮
- [x] 情绪匹配标签
- [x] 深呼吸引导弹窗
- [x] 晚安语录弹窗
- [x] 流式输出（逐字显示AI回复）
- [x] 大模型/本地模式切换
- [x] 大模型失败自动降级到本地话术
- [x] 清空对话功能
- [x] 输入中loading状态

### 2.5 情感分析报告页面
- [x] 情绪雷达图（7维度：悲伤/焦虑/愤怒/孤独/开心/平静/压抑）
- [x] 情绪维度进度条（百分比展示）
- [x] 情绪解读文案
- [x] 舒缓建议卡片
- [x] 近期情绪趋势图

### 2.6 我的隐私中心 (Privacy Page)
- [x] 安全状态展示
- [x] 树洞锁定开关
- [x] 夜间护眼模式开关
- [x] 一键清空所有记录
- [x] 修改树洞密码
- [x] 隐私政策说明（7条合规声明）

---

## 第三阶段：核心功能实现

### 3.1 情感分析功能
- [x] 本地关键词权重算法（40+情绪关键词）
- [x] 7维度情绪评分（悲伤/焦虑/愤怒/孤独/开心/平静/压抑）
- [x] 主导情绪识别
- [x] 情绪雷达图渲染
- [x] 情绪日记自动保存
- [ ] 接入huggingface中文预训练模型（升级）

### 3.2 AI对话功能
- [x] OpenAI格式API调用（`/chat/completions`）
- [x] 流式输出（SSE，逐字显示）
- [x] 普通模式（非流式备选）
- [x] 系统提示词（情感陪伴师角色定义）
- [x] 对话上下文记忆（最近20轮）
- [x] 本地预设话术降级（大模型不可用时自动切换）
- [x] 错误处理（网络/格式/认证异常）
- [x] 大模型/本地模式手动切换

### 3.3 大模型API配置
- [x] 配置文件 `lib/app/config/llm_config.dart`
- [x] 支持任意OpenAI兼容格式API
- [x] 可配置项：baseUrl / apiKey / model / maxTokens / temperature

**配置示例：**
```dart
// lib/app/config/llm_config.dart
static const String baseUrl = 'https://api.openai.com/v1';  // 或其他兼容地址
static const String apiKey = 'sk-xxxxxxxxxxxxxxxx';
static const String model = 'gpt-3.5-turbo';               // 或 qwen-turbo / deepseek-chat 等
```

### 3.4 本地存储加密
- [x] SharedPreferences本地存储
- [x] MD5密码加密
- [x] 情绪日记CRUD
- [x] 最多保留200条记录

### 3.5 语音识别功能（后续添加）
- [ ] 实时语音转文字
- [ ] 长时间录音支持

---

## 启动与运行指南

### 前置条件
- Flutter SDK 已克隆到项目目录 `flutter/`
- 已执行 `flutter pub get` 安装依赖
- 已在 `lib/app/config/llm_config.dart` 配置大模型API（可选，未配置时使用本地模式）

### Windows 系统启动

```powershell
# 1. 进入项目目录
cd D:\PythonCode\情感分析小助手\emotion_companion

# 2. 启动 Windows 桌面版
D:\PythonCode\情感分析小助手\flutter\bin\flutter.bat run -d windows

# 3. 首次构建较慢（约1-2分钟），后续启动秒开
```

**Windows 运行时快捷键：**
| 按键 | 功能 |
|------|------|
| `r` | 热重载（代码改动后按r即时生效，保留状态） |
| `R` | 热重启（完全重启APP，清空状态） |
| `q` | 退出APP |
| `d` | 分离（APP继续运行，终端可退出） |
| `h` | 列出所有可用命令 |

**Windows 关闭方式：**
- 方式1：终端按 `q` 退出
- 方式2：直接关闭APP窗口
- 方式3：终端按 `Ctrl+C` 强制终止

### macOS 系统启动

```bash
# 1. 进入项目目录
cd /path/to/emotion_companion

# 2. 确保 Flutter 在 PATH 中（如未添加）
export PATH="$PATH:/path/to/flutter/bin"

# 3. 启动 macOS 桌面版
flutter run -d macos

# 4. 首次构建较慢（需Xcode），后续启动秒开
```

**macOS 前置要求：**
- 已安装 Xcode（App Store 下载）
- 已安装 CocoaPods：`sudo gem install cocoapods`
- 首次运行需授权：系统偏好设置 → 安全性与隐私 → 允许运行

**macOS 运行时快捷键：**
| 按键 | 功能 |
|------|------|
| `r` | 热重载 |
| `R` | 热重启 |
| `q` | 退出APP |
| `d` | 分离 |
| `h` | 列出所有可用命令 |

**macOS 关闭方式：**
- 方式1：终端按 `q` 退出
- 方式2：`Cmd+Q` 关闭APP窗口
- 方式3：终端按 `Ctrl+C` 强制终止

### 其他平台启动

```bash
# Chrome 浏览器版
flutter run -d chrome

# Android 真机/模拟器（需连接设备或启动模拟器）
flutter run -d android

# iOS 模拟器（仅macOS，需Xcode）
flutter run -d ios

# Linux 桌面版
flutter run -d linux

# 查看所有可用设备
flutter devices
```

### 打包发布

```bash
# Windows 打包（生成 exe）
flutter build windows
# 产物位置：build/windows/x64/runner/Release/

# macOS 打包（生成 app）
flutter build macos
# 产物位置：build/macos/Build/Products/Release/

# Android APK 打包
flutter build apk --release
# 产物位置：build/app/outputs/flutter-apk/app-release.apk

# Android App Bundle（上架Google Play）
flutter build appbundle --release

# iOS IPA 打包（仅macOS）
flutter build ios --release
```

---

## 第四阶段：上线准备

### 4.1 功能测试
- [x] 文本情感分析测试（本地关键词模式）
- [ ] 大模型对话体验测试
- [ ] 隐私功能测试（锁定/清空/密码）
- [ ] 流式输出稳定性测试

### 4.2 性能优化
- [ ] 启动速度优化
- [ ] 内存占用优化
- [ ] 电池消耗优化

### 4.3 各平台打包
- [ ] 安卓APK打包
- [ ] iOS IPA打包（需Mac）
- [ ] Windows exe打包
- [ ] macOS app打包

---

## 开发优先级排序

```
第1优先：项目搭建 + 主题配置 + 页面框架 ✅
第2优先：首页UI + 导航结构 ✅
第3优先：情绪树洞UI + 文字输入 ✅
第4优先：AI安慰UI + 大模型对话 ✅
第5优先：情感分析算法 ✅
第6优先：大模型API接入（OpenAI格式，流式输出） ✅
第7优先：数据存储加密 ✅
第8优先：语音识别集成（待定）
第9优先：完整测试 + 打包
```

---

## 推荐开发工具

| 用途 | 工具 |
|------|------|
| 代码编辑 | VS Code + Flutter插件 |
| UI设计 | Figma |
| API调试 | Postman |
| 版本管理 | Git |
| 图标素材 | IconFont / Flaticon |
| 白噪音素材 | freesound.org |
