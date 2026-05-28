import 'package:flutter/material.dart';
import 'responsive_utils.dart';

class AdaptiveContentWrapper extends StatelessWidget {
  final Widget child;

  const AdaptiveContentWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (ResponsiveUtils.isMobile(context)) {
      return child;
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: ResponsiveUtils.desktopMaxContentWidth,
        ),
        child: child,
      ),
    );
  }
}
