import 'package:flutter/material.dart';
import '../app/themes/app_colors.dart';
import '../app/config/speech_config.dart';
import '../services/speech_service.dart';
import '../services/storage_service.dart';

Future<void> showSpeechParamsDialog(BuildContext context) async {
  final speechService = SpeechService();
  final storageService = StorageService();

  final userSpeed = await storageService.getTtsSpeed();
  final userVolume = await storageService.getTtsVolume();

  double speed = userSpeed ?? SpeechConfig.ttsSpeed;
  double volume = userVolume ?? SpeechConfig.defaultVolume;

  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        title: const Row(
          children: [
            Icon(Icons.tune, size: 22),
            SizedBox(width: 8),
            Expanded(child: Text('语音参数', style: TextStyle(fontSize: 17))),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 语速
                Row(
                  children: [
                    const Text('语速', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text('${speed.toStringAsFixed(1)}x', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gentlePurple)),
                  ],
                ),
                Slider(
                  value: speed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  activeColor: AppColors.gentlePurple,
                  onChanged: (v) => setDialogState(() => speed = v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0.5x 慢速', style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.3))),
                    Text('2.0x 快速', style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.3))),
                  ],
                ),

                const SizedBox(height: 12),

                // 音量
                Row(
                  children: [
                    const Text('音量', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text('${volume.toStringAsFixed(1)}x', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gentlePurple)),
                  ],
                ),
                Slider(
                  value: volume,
                  min: 0.1,
                  max: 3.0,
                  divisions: 29,
                  activeColor: AppColors.gentlePurple,
                  onChanged: (v) => setDialogState(() => volume = v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0.1x 静音', style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.3))),
                    Text('3.0x 响亮', style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.3))),
                  ],
                ),

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        await storageService.setTtsSpeed(SpeechConfig.ttsSpeed);
                        await storageService.setTtsVolume(SpeechConfig.defaultVolume);
                        await speechService.reloadTtsConfig();
                        setDialogState(() {
                          speed = SpeechConfig.ttsSpeed;
                          volume = SpeechConfig.defaultVolume;
                        });
                      },
                      child: Text(
                        '恢复默认',
                        style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton(
                      onPressed: () async {
                        await storageService.setTtsSpeed(speed);
                        await storageService.setTtsVolume(volume);
                        await speechService.reloadTtsConfig();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.hazeBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text('保存', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
