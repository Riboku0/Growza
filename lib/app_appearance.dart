import 'package:flutter/material.dart';

class GrowzaAppearance extends InheritedWidget {
  const GrowzaAppearance({
    super.key,
    required this.isDark,
    required this.onToggle,
    required super.child,
  });
  final bool isDark;
  final VoidCallback onToggle;
  static GrowzaAppearance? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GrowzaAppearance>();
  @override
  bool updateShouldNotify(GrowzaAppearance oldWidget) =>
      oldWidget.isDark != isDark;
}
