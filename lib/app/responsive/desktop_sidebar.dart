import 'package:flutter/material.dart';
import '../themes/app_colors.dart';

class DesktopSidebar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;

  const DesktopSidebar({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
  });

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  static const double _width = 212.0;

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: '首页'),
    _NavItem(icon: Icons.edit_note_outlined, activeIcon: Icons.edit_note_rounded, label: '树洞'),
    _NavItem(icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome, label: '安慰'),
    _NavItem(icon: Icons.person_outlined, activeIcon: Icons.person, label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: _width,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildBranding(),
          const SizedBox(height: 32),
          ..._items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildNavItem(
              index: index,
              icon: item.icon,
              activeIcon: item.activeIcon,
              label: item.label,
              isDark: isDark,
            );
          }),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildBranding() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              isDark ? 'assets/images/app_icon_night.png' : 'assets/images/app_icon_day.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '抱抱情绪云',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.hazeBlue,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isDark,
  }) {
    final isActive = widget.currentIndex == index;
    final inactiveColor = isDark ? AppColors.darkTextHint : AppColors.textHint;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        onTap: () => widget.onTabChanged(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.hazeBlue.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? AppColors.hazeBlue : inactiveColor,
                size: 22,
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: isActive ? AppColors.hazeBlue : inactiveColor,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
