import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/themes/app_colors.dart';
import '../../app/app_controller.dart';
import '../../services/storage_service.dart';

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
                      onChanged: (val) {
                        setState(() => _darkMode = val);
                        _appController.toggleDarkMode(val);
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
        if (mounted) _showTreasureDialog();
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
          content: TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              hintText: '请输入解锁密码',
              errorText: errorText,
            ),
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
      // 没有初始密码 → 直接设置
      final set = await _showCreatePinDialog(title: '设置树洞密码', hint: '请设置4-6位数字密码');
      if (set == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('密码设置成功'),
            backgroundColor: AppColors.calmGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _showTreasureDialog();
      }
    } else {
      // 有旧密码 → 先验证旧密码
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
          content: TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              hintText: '请输入旧密码',
              errorText: errorText,
            ),
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

  /// 创建/设置密码弹窗
  Future<bool?> _showCreatePinDialog({required String title, required String hint}) {
    final controller = TextEditingController();

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              if (controller.text.length >= 4) {
                await _storageService.setPin(controller.text);
                Navigator.pop(context, true);
              }
            },
            child: Text('确认', style: TextStyle(color: AppColors.hazeBlue)),
          ),
        ],
      ),
    );
  }

  /// "这是你的专属树洞密码，请好好保管" 弹窗
  void _showTreasureDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.favorite, color: AppColors.softPink, size: 24),
            const SizedBox(width: 8),
            const Text('密码已设置'),
          ],
        ),
        content: const Text('这是你的专属树洞密码，请好好保管'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('我知道了', style: TextStyle(color: AppColors.hazeBlue)),
          ),
        ],
      ),
    );
  }
}
