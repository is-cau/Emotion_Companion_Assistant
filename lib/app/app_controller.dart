import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../services/storage_service.dart';
import '../services/icon_service.dart';

class AppController extends GetxController {
  final StorageService _storage = StorageService();
  var isDarkMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadDarkMode();
  }

  Future<void> _loadDarkMode() async {
    isDarkMode.value = await _storage.getDarkMode();
  }

  /// 仅切换主题与持久化，不触发图标切换
  Future<void> toggleDarkMode(bool value) async {
    isDarkMode.value = value;
    await _storage.setDarkMode(value);
  }

  /// 切换桌面图标并退出应用
  Future<void> switchIconAndExit(bool isNight) async {
    await IconService.setIcon(isNight);
    SystemNavigator.pop();
  }
}
