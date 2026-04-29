import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app/themes/app_theme.dart';
import 'app/themes/app_colors.dart';
import 'app/routes/app_routes.dart';
import 'app/app_controller.dart';
import 'pages/home/home_page.dart';
import 'pages/treehole/treehole_page.dart';
import 'pages/comfort/comfort_page.dart';
import 'pages/privacy/privacy_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(AppController());
  runApp(const EmotionCompanionApp());
}

class EmotionCompanionApp extends StatelessWidget {
  const EmotionCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    return Obx(() => GetMaterialApp(
          title: '抱抱情绪云',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: controller.isDarkMode.value ? ThemeMode.dark : ThemeMode.light,
          home: const MainNavigation(),
          getPages: AppRoutes.routes,
        ));
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final GlobalKey<HomePageState> _homeKey = GlobalKey<HomePageState>();
  final GlobalKey<TreeholePageState> _treeholeKey = GlobalKey<TreeholePageState>();
  final GlobalKey<PrivacyPageState> _privacyKey = GlobalKey<PrivacyPageState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(key: _homeKey, onNavigateToComfort: () => _onTabChanged(2)),
      TreeholePage(key: _treeholeKey),
      const ComfortPage(),
      PrivacyPage(key: _privacyKey),
    ];
  }

  void _onTabChanged(int index) {
    setState(() => _currentIndex = index);
    // 切换页面时刷新数据，确保多端同步
    if (index == 0) {
      _homeKey.currentState?.refreshData();
    } else if (index == 1) {
      _treeholeKey.currentState?.refreshData();
    } else if (index == 3) {
      _privacyKey.currentState?.refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, '首页'),
                _buildNavItem(1, Icons.edit_note_outlined, Icons.edit_note_rounded, '树洞'),
                _buildNavItem(2, Icons.auto_awesome_outlined, Icons.auto_awesome, '安慰'),
                _buildNavItem(3, Icons.person_outlined, Icons.person, '我的'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabChanged(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.hazeBlue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.hazeBlue : AppColors.textHint,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? AppColors.hazeBlue : AppColors.textHint,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
