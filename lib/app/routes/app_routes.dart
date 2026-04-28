import 'package:get/get.dart';
import '../../pages/home/home_page.dart';
import '../../pages/treehole/treehole_page.dart';
import '../../pages/comfort/comfort_page.dart';
import '../../pages/privacy/privacy_page.dart';
import '../../pages/analysis/analysis_page.dart';

class AppRoutes {
  static const String home = '/';
  static const String treehole = '/treehole';
  static const String comfort = '/comfort';
  static const String privacy = '/privacy';
  static const String analysis = '/analysis';

  static final routes = [
    GetPage(name: home, page: () => const HomePage()),
    GetPage(name: treehole, page: () => const TreeholePage()),
    GetPage(name: comfort, page: () => const ComfortPage()),
    GetPage(name: privacy, page: () => const PrivacyPage()),
    GetPage(name: analysis, page: () => const AnalysisPage()),
  ];
}
