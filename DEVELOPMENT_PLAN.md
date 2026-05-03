# 情感分析小助手 - 开发计划

## 项目概述
一款轻量化治愈系心理健康情绪陪伴APP，主打：情感分析、匿名树洞倾诉、AI暖心安慰

---

## 第一阶段：技术选型与项目架构

### 1.1 技术栈
| 层级 | 技术选择 | 说明 |
|------|----------|------|
| 跨端框架 | **Flutter 3.41** | 全平台适配（Android/iOS/Windows/macOS/Linux/Web） |
| 前端UI | Flutter Widget + Material3 | 莫兰迪配色，圆角卡片 |
| 本地存储 | SharedPreferences + MD5 加密 | 轻量级，本地加密存储 |
| 状态管理 | GetX（主题） + GlobalKey（跨页同步） | 轻量，简洁 |
| HTTP请求 | http ^1.6.0 | OpenAI格式API调用 |
| **情感分析** | **本地关键词权重 + 大模型深度分析** | 双重保障 |
| **AI对话** | **OpenAI格式API（HTTP SSE流式输出）** | 兼容所有OpenAI格式的大模型服务 |
| 语音识别 | 可选暂不加 | 后续按需添加 |

### 1.2 项目目录结构
```
emotion_companion/
├── lib/
│   ├── main.dart                    # 主入口 + 底部导航（IndexedStack + GlobalKey同步）
│   ├── app/
│   │   ├── config/
│   │   │   └── llm_config.dart      # 大模型API配置（base-url/key/model）
│   │   ├── routes/
│   │   │   └── app_routes.dart      # 路由配置
│   │   ├── themes/
│   │   │   ├── app_colors.dart      # 莫兰迪配色定义（含暗色）
│   │   │   └── app_theme.dart       # 明/暗双主题（含input/elevatedButton/等全组件）
│   │   └── app_controller.dart      # GetX全局状态（暗色模式响应式切换）
│   ├── pages/
│   │   ├── home/
│   │   │   └── home_page.dart       # 首页（问候+情绪总览+波动图+快捷入口）
│   │   ├── treehole/
│   │   │   └── treehole_page.dart   # 情绪树洞（输入+白噪音+日记+密码锁定）
│   │   ├── comfort/
│   │   │   └── comfort_page.dart    # AI安慰（流式对话+对话历史+AI标题生成）
│   │   ├── analysis/
│   │   │   └── analysis_page.dart   # 情绪分析报告（雷达图+解读+建议）
│   │   └── privacy/
│   │       └── privacy_page.dart    # 隐私中心（锁定/密码/暗色模式/清空）
│   ├── widgets/
│   │   ├── emotion_radar.dart       # 情绪雷达图组件
│   │   ├── heartbeat_breath_button.dart # 呼吸粒子动画按钮
│   │   ├── fortune_draw.dart        # 每日抽签组件（3D翻转+全正向签文）
│   │   └── fortune_calendar.dart    # 签到日历组件
│   ├── services/
│   │   ├── llm_service.dart         # 大模型API（流式SSE/普通/情绪分析/标题生成）
│   │   ├── emotion_service.dart     # 本地情感分析（关键词权重算法）
│   │   ├── ai_comfort_service.dart  # 本地预设安慰话术（降级备选）
│   │   └── storage_service.dart     # 本地存储（记录/对话/密码/暗色模式）
│   └── models/
│       └── emotion_models.dart      # EmotionRecord / ChatMessage / Conversation
├── assets/
├── pubspec.yaml
└── test/
```

---

## 第二阶段：UI界面开发（已完成）

### 2.1 全局主题配置
- ✅ 莫兰迪低饱和度配色（雾霾蓝、柔粉、浅青、奶白、暖米、柔紫）
- ✅ 圆角卡片样式（borderRadius: 16-24）
- ✅ 护眼夜间模式（完整暗色主题，所有组件适配，GetX响应式切换）
- ✅ Material3 设计规范

### 2.2 首页 (Home Page)
- ✅ 顶部暖心问候标语（根据时段自动切换，居中显示）
- ✅ 今日情绪状态卡片（聚合当天所有日记的7维度平均分，无记录显示"未知"）
- ✅ 每日一签功能（全正向签等：上上上签/上上签/上签，3D翻转动画+寄语，每日固定）
- ✅ 签到日历（月历标记已抽签日期，今日高亮，独立弹窗可返回抽签界面）
- ✅ 情绪波动柱状图 + 趋势折线（带箭头方向指示）
- ✅ 快捷功能入口（AI暖心安慰→切换到安慰Tab，保持同一对话实例）

### 2.3 情绪树洞页面 (Treehole Page)
- ✅ 匿名多行文本输入框
- ✅ 隐私加密图标提示
- ✅ AI深度情绪分析弹窗（可取消X按钮，后台继续运行）
- ✅ 情绪日记列表（情绪标签+时间+查看详细报告+删除）
- ✅ 一键清空所有日记（浅红色醒目胶囊按钮）
- ✅ 白噪音开关（雨声/晚风/森林）
- ✅ 树洞密码锁定（首次锁定→设置密码→专属密码提示弹窗）
- ✅ 锁定页面密码验证（错误提示SnackBar，不解锁）
- ✅ 与隐私页锁定状态双向同步（切Tab时自动refreshData）
- [ ] 语音输入按钮（后续添加）

### 2.4 AI暖心安慰页面 (Comfort Page)
- ✅ HTTP SSE 流式输出（字词块智能分块，模拟人类打字节奏）
- ✅ 打字光标闪烁特效（`▌`，530ms间隔）
- ✅ 流式失败自动降级链：SSE → 普通模式 → 本地话术
- ✅ 对话历史持久化（最多50个对话，SharedPreferences存储）
- ✅ 新建/切换/删除对话（endDrawer侧边栏 + 顶部菜单）
- ✅ AI自动生成对话标题（≤10字，首次交换后LLM生成）
- ✅ 情感陪伴师角色系统提示词（温柔共情+8条行为准则）
- ✅ 对话上下文记忆（最近20轮）
- ✅ 深呼吸引导弹窗 + 晚安语录弹窗

### 2.5 情绪分析报告页面
- ✅ 情绪雷达图（7维度：悲伤/焦虑/愤怒/孤独/开心/平静/压抑）
- ✅ 情绪维度进度条
- ✅ AI情绪解读文案
- ✅ 舒缓建议卡片

### 2.6 隐私中心 (Privacy Page)
- ✅ 安全状态展示
- ✅ 树洞锁定开关（首次开启→设置密码→专属密码提示；关闭→验证密码）
- ✅ 夜间护眼模式开关（全局响应式切换，持久化存储）
- ✅ 一键清空所有记录
- ✅ 修改树洞密码（无旧密码直接设置→专属提示；有旧密码先验证→再设新密码）
- ✅ 隐私政策说明（7条合规声明）

---

## 第三阶段：核心功能实现

### 3.1 情感分析功能
- ✅ 本地关键词权重算法（40+情绪关键词，即时兜底）
- ✅ 大模型深度分析（7维度评分+解读+建议，结构化JSON返回）
- ✅ 主导情绪识别
- ✅ 情绪雷达图渲染
- ✅ 情绪日记自动保存（upsert去重）
- ✅ 今日情绪聚合（多日记加权平均）
- [ ] 接入huggingface中文预训练模型（升级备选）

### 3.2 AI对话功能
- ✅ OpenAI格式API调用（`/chat/completions`）
- ✅ HTTP SSE 流式输出（`http.Client().send()` + `stream: true`）
- ✅ 字词块分段显示（45ms定时器 + 标点感知分块）
- ✅ 流式失败自动降级到普通模式
- ✅ 系统提示词（情感陪伴师角色定义）
- ✅ 对话上下文记忆（最近20轮）
- ✅ 对话历史系统（新建/切换/删除，AI自动生成标题）
- ✅ 本地预设话术降级（大模型不可用时自动切换）
- ✅ 错误处理（网络/格式/认证异常，详细错误信息）

### 3.3 大模型API配置
- ✅ 配置文件 `lib/app/config/llm_config.dart`
- ✅ 支持任意OpenAI兼容格式API
- ✅ 可配置项：baseUrl / apiKey / model / maxTokens / temperature

**配置示例：**
```dart
// lib/app/config/llm_config.dart
static const String baseUrl = 'https://api.openai.com/v1';  // 或其他兼容地址
static const String apiKey = 'sk-xxxxxxxxxxxxxxxx';
static const String model = 'gpt-3.5-turbo';               // 或 qwen-turbo / deepseek-chat 等
```

### 3.4 本地存储
- ✅ SharedPreferences本地存储
- ✅ MD5密码加密
- ✅ 情绪日记CRUD（upsert去重，最多200条）
- ✅ 对话管理（最多50个对话）
- ✅ 暗色模式持久化

### 3.5 跨页面数据同步
- ✅ GlobalKey 模式（HomePageState / TreeholePageState / PrivacyPageState）
- ✅ 切Tab时自动刷新（refreshData）
- ✅ 首页 ↔ 树洞页：情绪记录双向同步
- ✅ 树洞页 ↔ 隐私页：锁定状态双向同步
- ✅ 首页 ↔ 安慰页：同一对话实例（onNavigateToComfort回调）

### 3.6 语音识别功能（后续添加）
- [ ] 实时语音转文字
- [ ] 长时间录音支持

---

## 启动与运行指南

### 前置条件
- Flutter SDK 已安装
- 已执行 `flutter pub get` 安装依赖
- 已在 `lib/app/config/llm_config.dart` 配置大模型API（可选，未配置时使用本地模式）

### 运行
```bash
# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Chrome
flutter run -d chrome

# Android
flutter run -d android

# 查看所有可用设备
flutter devices
```

### 运行时快捷键
| 按键 | 功能 |
|------|------|
| `r` | 热重载（代码改动即时生效） |
| `R` | 热重启（完全重启，清空状态） |
| `q` | 退出APP |
| `h` | 列出所有可用命令 |

### 打包发布
```bash
# Windows
flutter build windows

# macOS
flutter build macos

# Android APK
flutter build apk --release

# Android App Bundle（上架Google Play）
flutter build appbundle --release

# iOS（仅macOS，需Xcode）
flutter build ios --release

# Web
flutter build web
```

---

## 第四阶段：待完成

### 4.1 功能增强
- [x] 每日一签 + 签到日历（全正向签文、3D翻转动画、日历标记）
- [x] 情绪趋势折线图（柱状图顶部连线 + 方向箭头）
- [ ] 语音识别输入
- [ ] 接入huggingface中文预训练模型
- [ ] 白噪音实际音频播放

### 4.2 性能优化
- [ ] 启动速度优化
- [ ] 内存占用优化

### 4.3 测试
- [ ] 大模型对话体验测试
- [ ] 隐私功能测试（锁定/清空/密码）
- [ ] 流式输出稳定性测试

---

## 开发优先级排序

```
第1优先：项目搭建 + 主题配置 + 页面框架 ✅
第2优先：首页UI + 导航结构 ✅
第3优先：情绪树洞UI + 文字输入 ✅
第4优先：AI安慰UI + 大模型对话 ✅
第5优先：情感分析算法 ✅
第6优先：大模型API接入（流式SSE） ✅
第7优先：数据存储加密 + 对话历史 ✅
第8优先：跨页面同步 + 暗色模式完善 ✅
第9优先：语音识别集成（待定）
第10优先：完整测试 + 打包
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
