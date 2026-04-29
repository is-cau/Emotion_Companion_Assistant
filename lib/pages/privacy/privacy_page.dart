import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/themes/app_colors.dart';
import '../../app/app_controller.dart';
import '../../services/storage_service.dart';
import '../../widgets/llm_config_dialog.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => PrivacyPageState();
}

class PrivacyPageState extends State<PrivacyPage> {
  final StorageService _storageService = StorageService();
  final AppController _appController = Get.find<AppController>();
  bool _isLocked = false;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final locked = await _storageService.isLocked();
    setState(() {
      _isLocked = locked;
      _darkMode = _appController.isDarkMode.value;
    });
  }

  /// 外部可调用的刷新方法，用于跨页面同步
  Future<void> refreshData() async {
    await _loadState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隐私中心')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            // 安全状态卡片
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.calmGreen.withOpacity(0.15),
                        ),
                        child: Icon(Icons.verified_user_outlined, color: AppColors.calmGreen, size: 32),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '你的隐私已被保护',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.calmGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '所有数据仅存储在本机，全程加密保护',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 隐私功能列表
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                child: Column(
                  children: [
                    _buildSwitchTile(
                      icon: Icons.lock_outline,
                      title: '树洞锁定',
                      subtitle: '锁定后需要密码才能访问树洞',
                      value: _isLocked,
                      onChanged: (val) async {
                        if (val) {
                          await _handleEnableLock();
                        } else {
                          final unlocked = await _handleDisableLock();
                          if (unlocked) {
                            await _storageService.setLocked(false);
                            setState(() => _isLocked = false);
                          }
                        }
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildSwitchTile(
                      icon: Icons.dark_mode_outlined,
                      title: '夜间护眼模式',
                      subtitle: '降低屏幕亮度，保护眼睛',
                      value: _darkMode,
                      onChanged: (val) async {
                        // 先只切换主题，不切换桌面图标
                        setState(() => _darkMode = val);
                        _appController.toggleDarkMode(val);

                        final ok = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text('温馨提示'),
                            content: const Text('桌面图标已更换，点击确定退出应用后生效。'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text('确定', style: TextStyle(color: AppColors.hazeBlue)),
                              ),
                            ],
                          ),
                        );

                        if (ok == true) {
                          _appController.switchIconAndExit(val);
                        } else {
                          // 用户取消，恢复主题
                          setState(() => _darkMode = !val);
                          _appController.toggleDarkMode(!val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 危险操作区
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                child: Column(
                  children: [
                    _buildActionTile(
                      icon: Icons.delete_outline,
                      title: '一键清空所有记录',
                      subtitle: '删除所有情绪日记，不可恢复',
                      color: Colors.redAccent.shade100,
                      onTap: _confirmClearAll,
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildActionTile(
                      icon: Icons.lock_reset_outlined,
                      title: '修改树洞密码',
                      subtitle: '设置新的访问密码',
                      color: AppColors.softOrange,
                      onTap: _showSetPinDialog,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 大模型配置
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                child: _buildActionTile(
                  icon: Icons.api,
                  title: '大模型配置',
                  subtitle: '自定义API地址、Key和模型',
                  color: AppColors.hazeBlue,
                  onTap: () => showLlmConfigDialog(context),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 隐私政策说明
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.hazeBlue, size: 18),
                          const SizedBox(width: 8),
                          Text('隐私政策', style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildPolicyItem('零用户敏感信息采集'),
                      _buildPolicyItem('无需实名认证、无需读取通讯录'),
                      _buildPolicyItem('无需读取相册、无需位置权限'),
                      _buildPolicyItem('所有倾诉内容本地加密存储'),
                      _buildPolicyItem('自动定时清理冗余数据'),
                      _buildPolicyItem('无后台数据售卖、无第三方信息共享'),
                      _buildPolicyItem('符合个人隐私保护法律法规'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.hazeBlue, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.hazeBlue,
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(title, style: TextStyle(fontSize: 15, color: color)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: Icon(Icons.chevron_right, color: AppColors.textHint, size: 18),
      onTap: onTap,
    );
  }

  Widget _buildPolicyItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.calmGreen, size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }

  /// 开启锁定时，如果没有密码则先要求设置
  Future<void> _handleEnableLock() async {
    final hasPin = await _storageService.hasPin();
    if (!hasPin) {
      final set = await _showCreatePinDialog(title: '首次锁定树洞', hint: '请设置4-6位数字密码');
      if (set == true) {
        await _storageService.setLocked(true);
        setState(() => _isLocked = true);
        if (mounted) {
          await _showRecoveryQASetupDialog();
        }
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('锁定树洞'),
          content: const Text('锁定后需要输入密码才能访问，是否确认？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('确认锁定', style: TextStyle(color: AppColors.hazeBlue)),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await _storageService.setLocked(true);
        setState(() => _isLocked = true);
      }
    }
  }

  /// 关闭锁定时，需要验证密码
  Future<bool> _handleDisableLock() async {
    final controller = TextEditingController();
    String? errorText;

    final verified = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('解锁树洞'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: '请输入解锁密码',
                  errorText: errorText,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // 先关闭当前弹窗
                    _showForgotPasswordDialogForDisable();
                  },
                  child: Text(
                    '忘记密码？',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.hazeBlue.withValues(alpha: 0.7),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                final ok = await _storageService.verifyPin(controller.text);
                if (ok) {
                  Navigator.pop(context, true);
                } else {
                  setDialogState(() => errorText = '密码错误');
                }
              },
              child: Text('解锁', style: TextStyle(color: AppColors.hazeBlue)),
            ),
          ],
        ),
      ),
    );
    return verified ?? false;
  }

  /// 忘记密码流程（用于关闭锁定时）
  Future<void> _showForgotPasswordDialogForDisable() async {
    final hasQA = await _storageService.hasRecoveryQA();
    if (!hasQA) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('无法找回'),
            content: const Text('尚未设置密保问题，无法通过此方式找回密码。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('知道了', style: TextStyle(color: AppColors.hazeBlue)),
              ),
            ],
          ),
        );
      }
      return;
    }

    final question = await _storageService.getRecoveryQuestion();
    final answerController = TextEditingController();
    String? errorText;

    if (!mounted) return;
    final verified = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.help_outline, color: AppColors.softOrange, size: 24),
              const SizedBox(width: 8),
              const Text('找回密码'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('请回答以下密保问题：', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  question ?? '',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: answerController,
                decoration: InputDecoration(
                  hintText: '请输入答案',
                  errorText: errorText,
                ),
                maxLength: 30,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                final ok = await _storageService.verifyRecoveryAnswer(answerController.text.trim());
                if (ok) {
                  Navigator.pop(context, true);
                } else {
                  setDialogState(() => errorText = '答案错误，请重试');
                }
              },
              child: Text('验证', style: TextStyle(color: AppColors.hazeBlue)),
            ),
          ],
        ),
      ),
    );

    if (verified == true && mounted) {
      await _storageService.clearPin();
      final set = await _showCreatePinDialog(title: '重置密码', hint: '请设置新的4-6位数字密码');
      if (set == true && mounted) {
        _showRecoveryQASetupDialog();
        await _storageService.setLocked(false);
        setState(() => _isLocked = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('密码已重置，锁定已解除'),
            backgroundColor: AppColors.calmGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('确认清空'),
        content: const Text('此操作将删除所有情绪记录，且不可恢复。确定要继续吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              await _storageService.clearAllRecords();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('已清空所有记录'),
                  backgroundColor: AppColors.calmGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: Text('确认清空', style: TextStyle(color: Colors.redAccent.shade100)),
          ),
        ],
      ),
    );
  }

  /// 修改密码入口：先判断是否有旧密码
  void _showSetPinDialog() async {
    final hasPin = await _storageService.hasPin();
    if (!hasPin) {
      final set = await _showCreatePinDialog(title: '设置树洞密码', hint: '请设置4-6位数字密码');
      if (set == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('密码设置成功'),
            backgroundColor: AppColors.calmGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        await _showRecoveryQASetupDialog();
      }
    } else {
      final verified = await _showVerifyOldPinDialog();
      if (verified == true) {
        final set = await _showCreatePinDialog(title: '修改树洞密码', hint: '请输入新的4-6位数字密码');
        if (set == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('密码修改成功'),
              backgroundColor: AppColors.calmGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          // 修改密码后强制更新密保
          if (mounted) await _showRecoveryQASetupDialog();
        }
      }
    }
  }

  /// 验证旧密码弹窗
  Future<bool?> _showVerifyOldPinDialog() {
    final controller = TextEditingController();
    String? errorText;

    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('验证旧密码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: '请输入旧密码',
                  errorText: errorText,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // 关闭当前弹窗
                    _showForgotPasswordDialogForChangePin();
                  },
                  child: Text(
                    '忘记密码？',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.hazeBlue.withValues(alpha: 0.7),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                final verified = await _storageService.verifyPin(controller.text);
                if (verified) {
                  Navigator.pop(context, true);
                } else {
                  setDialogState(() => errorText = '密码错误');
                }
              },
              child: Text('确认', style: TextStyle(color: AppColors.hazeBlue)),
            ),
          ],
        ),
      ),
    );
  }

  /// 忘记密码流程（用于修改密码时）
  Future<void> _showForgotPasswordDialogForChangePin() async {
    final hasQA = await _storageService.hasRecoveryQA();
    if (!hasQA) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('无法找回'),
            content: const Text('尚未设置密保问题，无法通过此方式找回密码。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('知道了', style: TextStyle(color: AppColors.hazeBlue)),
              ),
            ],
          ),
        );
      }
      return;
    }

    final question = await _storageService.getRecoveryQuestion();
    final answerController = TextEditingController();
    String? errorText;

    if (!mounted) return;
    final verified = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.help_outline, color: AppColors.softOrange, size: 24),
              const SizedBox(width: 8),
              const Text('找回密码'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('请回答以下密保问题：', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  question ?? '',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: answerController,
                decoration: InputDecoration(
                  hintText: '请输入答案',
                  errorText: errorText,
                ),
                maxLength: 30,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                final ok = await _storageService.verifyRecoveryAnswer(answerController.text.trim());
                if (ok) {
                  Navigator.pop(context, true);
                } else {
                  setDialogState(() => errorText = '答案错误，请重试');
                }
              },
              child: Text('验证', style: TextStyle(color: AppColors.hazeBlue)),
            ),
          ],
        ),
      ),
    );

    if (verified == true && mounted) {
      await _storageService.clearPin();
      final set = await _showCreatePinDialog(title: '重置密码', hint: '请设置新的4-6位数字密码');
      if (set == true && mounted) {
        _showRecoveryQASetupDialog();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('密码已重置'),
            backgroundColor: AppColors.calmGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 创建密码弹窗（两步验证：输入 → 确认）
  Future<bool?> _showCreatePinDialog({required String title, required String hint}) {
    final controller = TextEditingController();
    String? errorText;

    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('请输入4-6位数字密码', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: hint,
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                final pin = controller.text;
                if (pin.length < 4) {
                  setDialogState(() => errorText = '密码至少4位');
                  return;
                }
                final confirmed = await _showConfirmPinDialog(pin);
                if (confirmed == true) {
                  await _storageService.setPin(pin);
                  Navigator.pop(context, true);
                } else if (confirmed == false) {
                  setDialogState(() => errorText = '两次输入不一致，请重新输入');
                  controller.clear();
                }
              },
              child: Text('下一步', style: TextStyle(color: AppColors.hazeBlue)),
            ),
          ],
        ),
      ),
    );
  }

  /// 确认密码弹窗（二次输入）
  Future<bool?> _showConfirmPinDialog(String firstPin) {
    final controller = TextEditingController();

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('确认密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('请再次输入密码以确认', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: '请再次输入密码'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () {
              if (controller.text == firstPin) {
                Navigator.pop(context, true);
              } else {
                Navigator.pop(context, false);
              }
            },
            child: Text('确认', style: TextStyle(color: AppColors.hazeBlue)),
          ),
        ],
      ),
    );
  }

  /// 二级安保：设置密保问题与答案（强制设置）
  Future<void> _showRecoveryQASetupDialog() async {
    final questionController = TextEditingController();
    final answerController = TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.security, color: AppColors.softOrange, size: 24),
            const SizedBox(width: 8),
            const Text('二级安保设置'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '设置密保问题，忘记密码时可通过回答此问题找回',
              style: TextStyle(fontSize: 13, color: AppColors.textHint),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: questionController,
              decoration: const InputDecoration(
                hintText: '请输入密保问题（如：我的小名是什么？）',
                labelText: '密保问题',
              ),
              maxLength: 50,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: answerController,
              decoration: const InputDecoration(
                hintText: '请输入答案',
                labelText: '密保答案',
              ),
              maxLength: 30,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final q = questionController.text.trim();
              final a = answerController.text.trim();
              if (q.isEmpty || a.isEmpty) return;
              await _storageService.setRecoveryQA(q, a);
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('密保已设置，忘记密码时可通过密保找回'),
                    backgroundColor: AppColors.calmGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Text('确认设置', style: TextStyle(color: AppColors.hazeBlue)),
          ),
        ],
      ),
    );
  }
}
