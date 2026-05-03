import 'package:flutter/material.dart';
import '../app/themes/app_colors.dart';
import '../services/llm_service.dart';
import '../services/speech_service.dart';
import '../services/storage_service.dart';

Future<void> showUnifiedConfigDialog(BuildContext context) async {
  final llmService = LlmService();
  final speechService = SpeechService();
  final storageService = StorageService();

  // LLM prefills
  final userLlmUrl = await storageService.getLlmBaseUrl();
  final userLlmKey = await storageService.getLlmApiKey();
  final userLlmModel = await storageService.getLlmModel();
  final hasLlmConfig = userLlmUrl != null && userLlmUrl.isNotEmpty
      && userLlmKey != null && userLlmKey.isNotEmpty;

  // TTS prefills
  final userTtsUrl = await storageService.getTtsBaseUrl();
  final userTtsKey = await storageService.getTtsApiKey();
  final userTtsModel = await storageService.getTtsModel();
  final hasTtsConfig = userTtsUrl != null && userTtsUrl.isNotEmpty
      && userTtsKey != null && userTtsKey.isNotEmpty;

  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => _UnifiedConfigDialog(
      llmService: llmService,
      speechService: speechService,
      storageService: storageService,
      initialLlmUrl: userLlmUrl ?? '',
      initialLlmKey: userLlmKey ?? '',
      initialLlmModel: userLlmModel ?? '',
      hasLlmConfig: hasLlmConfig,
      initialTtsUrl: userTtsUrl ?? '',
      initialTtsKey: userTtsKey ?? '',
      initialTtsModel: userTtsModel ?? '',
      hasTtsConfig: hasTtsConfig,
    ),
  );
}

class _UnifiedConfigDialog extends StatefulWidget {
  final LlmService llmService;
  final SpeechService speechService;
  final StorageService storageService;
  final String initialLlmUrl;
  final String initialLlmKey;
  final String initialLlmModel;
  final bool hasLlmConfig;
  final String initialTtsUrl;
  final String initialTtsKey;
  final String initialTtsModel;
  final bool hasTtsConfig;

  const _UnifiedConfigDialog({
    required this.llmService,
    required this.speechService,
    required this.storageService,
    required this.initialLlmUrl,
    required this.initialLlmKey,
    required this.initialLlmModel,
    required this.hasLlmConfig,
    required this.initialTtsUrl,
    required this.initialTtsKey,
    required this.initialTtsModel,
    required this.hasTtsConfig,
  });

  @override
  State<_UnifiedConfigDialog> createState() => _UnifiedConfigDialogState();
}

class _UnifiedConfigDialogState extends State<_UnifiedConfigDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // LLM state
  late final TextEditingController _llmUrlCtrl;
  late final TextEditingController _llmKeyCtrl;
  late final TextEditingController _llmModelCtrl;
  bool _llmObscureKey = true;
  bool _llmTesting = false;
  bool _llmTestPassed = false;
  String? _llmError;

  // TTS state
  late final TextEditingController _ttsUrlCtrl;
  late final TextEditingController _ttsKeyCtrl;
  late final TextEditingController _ttsModelCtrl;
  bool _ttsObscureKey = true;
  bool _ttsTesting = false;
  bool _ttsTestPassed = false;
  String? _ttsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _llmUrlCtrl = TextEditingController(text: widget.initialLlmUrl);
    _llmKeyCtrl = TextEditingController(text: widget.initialLlmKey);
    _llmModelCtrl = TextEditingController(text: widget.initialLlmModel);
    _llmTestPassed = widget.hasLlmConfig;

    _ttsUrlCtrl = TextEditingController(text: widget.initialTtsUrl);
    _ttsKeyCtrl = TextEditingController(text: widget.initialTtsKey);
    _ttsModelCtrl = TextEditingController(text: widget.initialTtsModel);
    _ttsTestPassed = widget.hasTtsConfig;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _llmUrlCtrl.dispose();
    _llmKeyCtrl.dispose();
    _llmModelCtrl.dispose();
    _ttsUrlCtrl.dispose();
    _ttsKeyCtrl.dispose();
    _ttsModelCtrl.dispose();
    super.dispose();
  }

  bool get _llmAllEmpty =>
      _llmUrlCtrl.text.trim().isEmpty &&
      _llmKeyCtrl.text.trim().isEmpty &&
      _llmModelCtrl.text.trim().isEmpty;

  bool get _ttsAllEmpty =>
      _ttsUrlCtrl.text.trim().isEmpty &&
      _ttsKeyCtrl.text.trim().isEmpty &&
      _ttsModelCtrl.text.trim().isEmpty;

  bool get _canSaveLlm => _llmAllEmpty || _llmTestPassed;
  bool get _canSaveTts => _ttsAllEmpty || _ttsTestPassed;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.hazeBlue, AppColors.gentlePurple],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('API 配置', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      Text(
                        '大模型 & 语音合成',
                        style: TextStyle(fontSize: 11, color: AppColors.textHint.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Tab bar
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.textHint.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerHeight: 0,
                labelColor: AppColors.hazeBlue,
                unselectedLabelColor: AppColors.textHint.withValues(alpha: 0.5),
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                padding: const EdgeInsets.all(3),
                tabs: const [
                  Tab(text: '大模型'),
                  Tab(text: '语音合成'),
                ],
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 420,
        height: 440,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildLlmTab(),
            _buildTtsTab(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LLM Tab
  // ============================================================
  Widget _buildLlmTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('API 地址'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _llmUrlCtrl,
            hintText: 'https://api.openai.com/v1',
            enabled: !_llmTesting,
            onChanged: (_) => _resetLlmTest(),
          ),
          const SizedBox(height: 14),
          _buildFieldLabel('API Key'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _llmKeyCtrl,
            hintText: '请输入你的 API Key',
            obscureText: _llmObscureKey,
            enabled: !_llmTesting,
            onChanged: (_) => _resetLlmTest(),
            suffixIcon: IconButton(
              icon: Icon(
                _llmObscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: AppColors.textHint,
              ),
              onPressed: _llmTesting ? null : () => setState(() => _llmObscureKey = !_llmObscureKey),
            ),
          ),
          const SizedBox(height: 14),
          _buildFieldLabel('模型名称'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _llmModelCtrl,
            hintText: 'deepseek-chat / gpt-4o',
            enabled: !_llmTesting,
            onChanged: (_) => _resetLlmTest(),
          ),

          if (_llmError != null) ...[
            const SizedBox(height: 12),
            _buildErrorBanner(_llmError!),
          ] else if (widget.hasLlmConfig && !_llmTestPassed) ...[
            const SizedBox(height: 12),
            _buildHintBanner(),
          ],

          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _buildActionRow(
            isTesting: _llmTesting,
            testPassed: _llmTestPassed,
            hasConfig: widget.hasLlmConfig,
            canSave: _canSaveLlm,
            testColor: AppColors.calmGreen,
            saveColor: AppColors.hazeBlue,
            onTest: _testLlm,
            onSave: _saveLlm,
            onReset: _resetLlmToDefault,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TTS Tab
  // ============================================================
  Widget _buildTtsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('API 地址'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _ttsUrlCtrl,
            hintText: 'https://openspeech.bytedance.com/api/v1/tts',
            enabled: !_ttsTesting,
            onChanged: (_) => _resetTtsTest(),
          ),
          const SizedBox(height: 14),
          _buildFieldLabel('API Key / Token'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _ttsKeyCtrl,
            hintText: '请输入你的 Access Token',
            obscureText: _ttsObscureKey,
            enabled: !_ttsTesting,
            onChanged: (_) => _resetTtsTest(),
            suffixIcon: IconButton(
              icon: Icon(
                _ttsObscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: AppColors.textHint,
              ),
              onPressed: _ttsTesting ? null : () => setState(() => _ttsObscureKey = !_ttsObscureKey),
            ),
          ),
          const SizedBox(height: 14),
          _buildFieldLabel('音色名称'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _ttsModelCtrl,
            hintText: 'zh_female_vv_uranus_bigtts',
            enabled: !_ttsTesting,
            onChanged: (_) => _resetTtsTest(),
          ),

          if (_ttsError != null) ...[
            const SizedBox(height: 12),
            _buildErrorBanner(_ttsError!),
          ] else if (widget.hasTtsConfig && !_ttsTestPassed) ...[
            const SizedBox(height: 12),
            _buildHintBanner(),
          ],

          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _buildActionRow(
            isTesting: _ttsTesting,
            testPassed: _ttsTestPassed,
            hasConfig: widget.hasTtsConfig,
            canSave: _canSaveTts,
            testColor: AppColors.calmGreen,
            saveColor: AppColors.gentlePurple,
            onTest: _testTts,
            onSave: _saveTts,
            onReset: _resetTtsToDefault,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Shared Widgets
  // ============================================================

  Widget _buildFieldLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    bool enabled = true,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(fontSize: 13, color: AppColors.textHint.withValues(alpha: 0.5)),
        isDense: true,
        filled: true,
        fillColor: enabled ? null : AppColors.textLight.withValues(alpha: 0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.hazeBlue.withValues(alpha: 0.4), width: 1.2),
        ),
        suffixIcon: suffixIcon,
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.softPink.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.softPink.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.softPink),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12, color: AppColors.softPink))),
        ],
      ),
    );
  }

  Widget _buildHintBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.softOrange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.softOrange.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '修改配置后需重新测试连接通过才能保存',
              style: TextStyle(fontSize: 12, color: AppColors.softOrange.withValues(alpha: 0.8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required bool isTesting,
    required bool testPassed,
    required bool hasConfig,
    required bool canSave,
    required Color testColor,
    required Color saveColor,
    required VoidCallback onTest,
    required VoidCallback onSave,
    required VoidCallback onReset,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isTesting ? null : onTest,
                icon: Icon(
                  isTesting ? Icons.hourglass_top : Icons.wifi_find,
                  size: 16,
                  color: isTesting ? Theme.of(context).disabledColor : testColor,
                ),
                label: Text(
                  '测试连接',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isTesting ? Theme.of(context).disabledColor : testColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: testColor.withValues(alpha: isTesting ? 0.15 : 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: (isTesting || !canSave) ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: saveColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('保存', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: (isTesting || !hasConfig) ? null : onReset,
              child: const Text('恢复默认', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: isTesting ? null : () => Navigator.pop(context),
              child: const Text('关闭', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // LLM Actions
  // ============================================================

  void _resetLlmTest() => setState(() { _llmTestPassed = false; _llmError = null; });

  void _testLlm() async {
    final url = _llmUrlCtrl.text.trim();
    final key = _llmKeyCtrl.text.trim();
    final model = _llmModelCtrl.text.trim();

    if (url.isEmpty || key.isEmpty || model.isEmpty) {
      setState(() => _llmError = '请先填写 API 地址、Key 和模型名称');
      return;
    }

    setState(() { _llmTesting = true; _llmError = null; });

    _showTestingOverlay();

    final (success, message) = await widget.llmService.testConnection(
      baseUrl: url, apiKey: key, model: model,
    );

    setState(() {
      _llmTesting = false;
      if (success) { _llmTestPassed = true; _llmError = null; }
    });

    if (context.mounted) Navigator.of(context).pop();
    if (context.mounted) _showTestResult(success, message);
  }

  void _saveLlm() async {
    await widget.storageService.setLlmBaseUrl(_llmUrlCtrl.text.trim());
    await widget.storageService.setLlmApiKey(_llmKeyCtrl.text.trim());
    await widget.storageService.setLlmModel(_llmModelCtrl.text.trim());
    await widget.llmService.reloadConfig();
  }

  void _resetLlmToDefault() async {
    await widget.storageService.clearLlmConfig();
    await widget.llmService.reloadConfig();
    setState(() {
      _llmUrlCtrl.clear();
      _llmKeyCtrl.clear();
      _llmModelCtrl.clear();
      _llmTestPassed = true;
      _llmError = null;
    });
  }

  // ============================================================
  // TTS Actions
  // ============================================================

  void _resetTtsTest() => setState(() { _ttsTestPassed = false; _ttsError = null; });

  void _testTts() async {
    final url = _ttsUrlCtrl.text.trim();
    final key = _ttsKeyCtrl.text.trim();
    final model = _ttsModelCtrl.text.trim();

    if (url.isEmpty || key.isEmpty || model.isEmpty) {
      setState(() => _ttsError = '请先填写 API 地址、Key 和音色名称');
      return;
    }

    setState(() { _ttsTesting = true; _ttsError = null; });

    _showTestingOverlay();

    final (success, message) = await widget.speechService.testTtsConnection(
      baseUrl: url, apiKey: key, model: model,
    );

    setState(() {
      _ttsTesting = false;
      if (success) { _ttsTestPassed = true; _ttsError = null; }
    });

    if (context.mounted) Navigator.of(context).pop();
    if (context.mounted) _showTestResult(success, message);
  }

  void _saveTts() async {
    await widget.storageService.setTtsBaseUrl(_ttsUrlCtrl.text.trim());
    await widget.storageService.setTtsApiKey(_ttsKeyCtrl.text.trim());
    await widget.storageService.setTtsModel(_ttsModelCtrl.text.trim());
    await widget.speechService.reloadTtsConfig();
  }

  void _resetTtsToDefault() async {
    await widget.storageService.clearTtsConfig();
    await widget.speechService.reloadTtsConfig();
    setState(() {
      _ttsUrlCtrl.clear();
      _ttsKeyCtrl.clear();
      _ttsModelCtrl.clear();
      _ttsTestPassed = true;
      _ttsError = null;
    });
  }

  // ============================================================
  // Helpers
  // ============================================================

  void _showTestingOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.hazeBlue),
              ),
              const SizedBox(width: 16),
              const Text('正在测试连接...', style: TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  void _showTestResult(bool success, String message) {
    showDialog(
      context: context,
      builder: (resultCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (success ? AppColors.calmGreen : AppColors.softPink).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: success ? AppColors.calmGreen : AppColors.softPink,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              success ? '测试通过' : '测试失败',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: success ? AppColors.calmGreen : AppColors.softPink,
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(resultCtx),
            child: Text(
              '关闭',
              style: TextStyle(color: success ? AppColors.calmGreen : AppColors.softPink),
            ),
          ),
        ],
      ),
    );
  }
}
