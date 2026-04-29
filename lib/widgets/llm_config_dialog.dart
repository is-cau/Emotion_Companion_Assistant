import 'package:flutter/material.dart';
import '../app/themes/app_colors.dart';
import '../services/llm_service.dart';
import '../services/storage_service.dart';

/// 用户自定义大模型配置弹窗，可在任意页面调用
Future<void> showLlmConfigDialog(BuildContext context) async {
  final llmService = LlmService();
  final storageService = StorageService();

  // 只加载用户自定义配置，不加载默认值
  final userUrl = await storageService.getLlmBaseUrl();
  final userKey = await storageService.getLlmApiKey();
  final userModel = await storageService.getLlmModel();
  final hasUserConfig = userUrl != null && userUrl.isNotEmpty
      && userKey != null && userKey.isNotEmpty;

  // 文本字段仅显示用户已保存的值，未设置则为空
  final urlController = TextEditingController(text: userUrl ?? '');
  final keyController = TextEditingController(text: userKey ?? '');
  final modelController = TextEditingController(text: userModel ?? '');
  bool obscureKey = true;
  bool isTesting = false;
  // 已有保存过的自定义配置，视为已测试通过
  // 全新配置或修改后必须测试通过才能保存
  bool testPassed = hasUserConfig;
  // 是否有用户自定义配置（响应式，随恢复默认而变化）
  bool hasConfig = hasUserConfig;

  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.api, color: AppColors.hazeBlue, size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text('大模型配置', style: TextStyle(fontSize: 17))),
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
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '填写你自己的大模型API信息，留空则使用默认配置。\n支持 OpenAI 兼容接口（DeepSeek、Qwen 等）。',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint, height: 1.5),
                ),
                const SizedBox(height: 16),

                // API 地址
                Text('API 地址', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextField(
                  controller: urlController,
                  enabled: !isTesting,
                  onChanged: (_) => setDialogState(() => testPassed = false),
                  decoration: InputDecoration(
                    hintText: '例如: https://api.openai.com/v1',
                    hintStyle: TextStyle(fontSize: 13, color: AppColors.textHint.withValues(alpha: 0.6)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 14),

                // API Key
                Text('API Key', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextField(
                  controller: keyController,
                  obscureText: obscureKey,
                  enabled: !isTesting,
                  onChanged: (_) => setDialogState(() => testPassed = false),
                  decoration: InputDecoration(
                    hintText: '请输入你的 API Key',
                    hintStyle: TextStyle(fontSize: 13, color: AppColors.textHint.withValues(alpha: 0.6)),
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

                // 模型名称
                Text('模型名称', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextField(
                  controller: modelController,
                  enabled: !isTesting,
                  onChanged: (_) => setDialogState(() => testPassed = false),
                  decoration: InputDecoration(
                    hintText: '例如: deepseek-chat, gpt-4o',
                    hintStyle: TextStyle(fontSize: 13, color: AppColors.textHint.withValues(alpha: 0.6)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),

                // 未测试通过提示
                if (!testPassed) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: AppColors.softOrange),
                      const SizedBox(width: 6),
                      Text(
                        '修改配置后需重新测试连接通过才能保存',
                        style: TextStyle(fontSize: 12, color: AppColors.softOrange),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          // 恢复默认（始终可见，无自定义配置时禁用）
          TextButton(
            onPressed: (isTesting || !hasConfig) ? null : () async {
              await storageService.clearLlmConfig();
              await llmService.reloadConfig();
              setDialogState(() {
                urlController.clear();
                keyController.clear();
                modelController.clear();
                hasConfig = false;
                testPassed = true;
              });
              if (ctx.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('已恢复默认配置'),
                    backgroundColor: AppColors.hazeBlue,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Text(
              '恢复默认',
              style: TextStyle(
                fontSize: 13,
                color: (isTesting || !hasConfig) ? AppColors.textHint.withValues(alpha: 0.4) : AppColors.textHint,
              ),
            ),
          ),
          TextButton(
            onPressed: isTesting ? null : () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
          ),
          // 测试连接
          TextButton(
            onPressed: isTesting ? null : () async {
              final url = urlController.text.trim();
              final key = keyController.text.trim();
              final model = modelController.text.trim();

              if (url.isEmpty || key.isEmpty || model.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('请先填写 API 地址、Key 和模型名称'),
                    backgroundColor: AppColors.softOrange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
                return;
              }

              setDialogState(() => isTesting = true);

              // 显示测试中弹窗
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
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.hazeBlue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text('正在测试连接中...', style: TextStyle(fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final (success, message) = await llmService.testConnection(
                baseUrl: url,
                apiKey: key,
                model: model,
              );

              setDialogState(() {
                isTesting = false;
                if (success) testPassed = true;
              });

              // 关闭测试中弹窗
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }

              // 显示测试结果
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
                          style: TextStyle(
                            fontSize: 17,
                            color: success ? AppColors.calmGreen : AppColors.softPink,
                          ),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isTesting ? Icons.hourglass_top : Icons.wifi_find,
                  size: 16,
                  color: isTesting ? AppColors.textHint : AppColors.calmGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  '测试连接',
                  style: TextStyle(
                    fontSize: 13,
                    color: isTesting ? AppColors.textHint : AppColors.calmGreen,
                  ),
                ),
              ],
            ),
          ),
          // 保存（全空直接恢复默认，有内容需测试通过）
          TextButton(
            onPressed: (isTesting) ? null : () async {
              final url = urlController.text.trim();
              final key = keyController.text.trim();
              final model = modelController.text.trim();
              final allEmpty = url.isEmpty && key.isEmpty && model.isEmpty;

              // 全部留空 = 恢复默认，无需测试
              if (!allEmpty && !testPassed) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('请先测试连接通过后再保存'),
                    backgroundColor: AppColors.softOrange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
                return;
              }

              await storageService.setLlmBaseUrl(url);
              await storageService.setLlmApiKey(key);
              await storageService.setLlmModel(model);
              await llmService.reloadConfig();

              if (ctx.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(allEmpty ? '已恢复默认配置' : '已切换至用户自定义配置'),
                    backgroundColor: AppColors.calmGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            child: Text(
              '保存',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isTesting ? AppColors.textHint : AppColors.hazeBlue,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
