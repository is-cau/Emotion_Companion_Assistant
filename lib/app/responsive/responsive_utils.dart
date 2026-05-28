import 'package:flutter/material.dart';

class ResponsiveUtils {
  ResponsiveUtils._();

  static const double tabletBreakpoint = 900.0;
  static const double desktopMaxContentWidth = 1200.0;
  static const double sidebarWidth = 212.0;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < tabletBreakpoint;
}
