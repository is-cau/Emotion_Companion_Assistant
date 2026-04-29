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

  Future<void> toggleDarkMode(bool value) async {
    isDarkMode.value = value;
    await _storage.setDarkMode(value);
    IconService.setIcon(value);
  }
}
