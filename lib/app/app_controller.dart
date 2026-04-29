import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../services/storage_service.dart';
import '../services/icon_service.dart';

class AppController extends GetxController {
  final StorageService _storage = StorageService();
  var isDarkMode = false.obs;

  final Completer<void> _readyCompleter = Completer<void>();
  Future<void> get ready => _readyCompleter.future;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    await _loadDarkMode();
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
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
