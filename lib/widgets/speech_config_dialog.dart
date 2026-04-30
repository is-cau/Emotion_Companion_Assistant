import 'package:flutter/material.dart';
import '../app/themes/app_colors.dart';
import '../app/config/speech_config.dart';
import '../services/speech_service.dart';
import '../services/storage_service.dart';

Future<void> showSpeechConfigDialog(BuildContext context) async {
  final speechService = SpeechService();
  final storageService = StorageService();

  final userUrl = await storageService.getTtsBaseUrl();
  final userKey = await storageService.getTtsApiKey();
  final userModel = await storageService.getTtsModel();
  final userSpeed = await storageService.getTtsSpeed();
  final userVolume = await storageService.getTtsVolume();
  final hasUserConfig = userUrl != null && userUrl.isNotEmpty
      && userKey != null && userKey.isNotEmpty;

  final urlController = TextEditingController(text: userUrl ?? '');
  final keyController = TextEditingController(text: userKey ?? '');
  final modelController = TextEditingController(text: userModel ?? '');
  bool obscureKey = true;
  bool isTesting = false;
  bool testPassed = hasUserConfig;
  bool hasConfig = hasUserConfig;
  String? inlineError;
  double speed = userSpeed ?? SpeechConfig.ttsSpeed;
  double volume = userVolume ?? SpeechConfig.defaultVolume;

  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        title: Row(
          children: [
            Icon(Icons.record_voice_over, color: AppColors.gentlePurple, size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text('语音合成配置', style: TextStyle(fontSize: 17))),
            if (hasConfig)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.calmGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('自定义', style: TextStyle(fontSize: 11, color: AppColors.calmGreen)),
              ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '填写你自己的TTS API信息，留空则使用默认配置。',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 16),

                Text('API 地址', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextField(
                  controller: urlController,
                  enabled: !isTesting,
                  onChanged: (_) => setDialogState(() { testPassed = false; inlineError = null; }),
                  decoration: InputDecoration(
                    hintText: '例如: https://openspeech.bytedance.com/api/v1/tts',
                    hintStyle: Theme.of(ctx).inputDecorationTheme.hintStyle?.copyWith(fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 14),

                Text('API Key / Token', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextField(
                  controller: keyController,
                  obscureText: obscureKey,
                  enabled: !isTesting,
                  onChanged: (_) => setDialogState(() { testPassed = false; inlineError = null; }),
                  decoration: InputDecoration(
                    hintText: '请输入你的 Access Token',
                    hintStyle: Theme.of(ctx).inputDecorationTheme.hintStyle?.copyWith(fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    suffixIcon: IconButton(
                      icon: Icon(obscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                      onPressed: isTesting ? null : () => setDialogState(() => obscureKey = !obscureKey),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 14),

                Text('音色名称', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextField(
                  controller: modelController,
                  enabled: !isTesting,
                  onChanged: (_) => setDialogState(() { testPassed = false; inlineError = null; }),
                  decoration: InputDecoration(
                    hintText: '例如: zh_female_vv_uranus_bigtts',
                    hintStyle: Theme.of(ctx).inputDecorationTheme.hintStyle?.copyWith(fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),

                // 语速
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text('语速', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text(speed.toStringAsFixed(1), style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5))),
                  ],
                ),
                Slider(
                  value: speed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  activeColor: AppColors.gentlePurple,
                  onChanged: isTesting ? null : (v) => setDialogState(() { speed = v; testPassed = false; inlineError = null; }),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0.5x 慢速', style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.3))),
                    Text('2.0x 快速', style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.3))),
                  ],
                ),

                // 音量
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('音量', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text(volume.toStringAsFixed(1), style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5))),
                  ],
                ),
                Slider(
                  value: volume,
                  min: 0.1,
                  max: 3.0,
                  divisions: 29,
                  activeColor: AppColors.gentlePurple,
                  onChanged: isTesting ? null : (v) => setDialogState(() { volume = v; testPassed = false; inlineError = null; }),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0.1x 静音', style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.3))),
                    Text('3.0x 响亮', style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.3))),
                  ],
                ),

                if (inlineError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.softPink.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(inlineError!, style: TextStyle(fontSize: 12, color: AppColors.softPink)),
                  ),
                ] else if (!testPassed) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: AppColors.softOrange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '修改配置后需重新测试连接通过才能保存',
                          style: TextStyle(fontSize: 12, color: AppColors.softOrange),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.divider),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isTesting ? null : () async {
                          final url = urlController.text.trim();
                          final key = keyController.text.trim();
                          final model = modelController.text.trim();

                          if (url.isEmpty || key.isEmpty || model.isEmpty) {
                            setDialogState(() => inlineError = '请先填写 API 地址、Key 和音色名称');
                            return;
                          }

                          setDialogState(() { isTesting = true; inlineError = null; });

                          if (ctx.mounted) {
                            showDialog(
                              context: ctx,
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
                                      const Text('正在测试连接中...', style: TextStyle(fontSize: 15)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          final (success, message) = await speechService.testTtsConnection(
                            baseUrl: url, apiKey: key, model: model,
                          );

                          setDialogState(() {
                            isTesting = false;
                            if (success) { testPassed = true; inlineError = null; }
                          });

                          if (ctx.mounted) Navigator.of(ctx).pop();

                          if (ctx.mounted) {
                            await showDialog(
                              context: ctx,
                              builder: (resultCtx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Row(
                                  children: [
                                    Icon(
                                      success ? Icons.check_circle_outline : Icons.error_outline,
                                      color: success ? AppColors.calmGreen : AppColors.softPink,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      success ? '测试通过' : '测试失败',
                                      style: TextStyle(fontSize: 17, color: success ? AppColors.calmGreen : AppColors.softPink),
                                    ),
                                  ],
                                ),
                                content: Text(message, style: const TextStyle(fontSize: 14, height: 1.5)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(resultCtx),
                                    child: const Text('关闭'),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          isTesting ? Icons.hourglass_top : Icons.wifi_find,
                          size: 16,
                          color: isTesting ? Theme.of(ctx).colorScheme.onSurface.withOpacity(0.3) : AppColors.calmGreen,
                        ),
                        label: Text(
                          '测试连接',
                          style: TextStyle(fontSize: 13, color: isTesting ? Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5) : AppColors.calmGreen),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.calmGreen.withValues(alpha: isTesting ? 0.2 : 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isTesting ? null : () async {
                          final url = urlController.text.trim();
                          final key = keyController.text.trim();
                          final model = modelController.text.trim();
                          final allEmpty = url.isEmpty && key.isEmpty && model.isEmpty;

                          if (!allEmpty && !testPassed) {
                            setDialogState(() => inlineError = '请先测试连接通过后再保存');
                            return;
                          }

                          await storageService.setTtsBaseUrl(url);
                          await storageService.setTtsApiKey(key);
                          await storageService.setTtsModel(model);
                          await storageService.setTtsSpeed(speed);
                          await storageService.setTtsVolume(volume);
                          await speechService.reloadTtsConfig();
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.hazeBlue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.hazeBlue.withValues(alpha: 0.3),
                          disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: Text('保存', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: (isTesting || !hasConfig) ? null : () async {
                        await storageService.clearTtsConfig();
                        await speechService.reloadTtsConfig();
                        setDialogState(() {
                          urlController.clear();
                          keyController.clear();
                          modelController.clear();
                          hasConfig = false;
                          testPassed = true;
                          inlineError = null;
                          speed = SpeechConfig.ttsSpeed;
                          volume = SpeechConfig.defaultVolume;
                        });
                      },
                      child: Text(
                        '恢复默认',
                        style: TextStyle(
                          fontSize: 12,
                          color: (isTesting || !hasConfig) ? Theme.of(ctx).colorScheme.onSurface.withOpacity(0.15) : Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: isTesting ? null : () => Navigator.pop(ctx),
                      child: Text('取消', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
