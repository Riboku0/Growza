import 'package:flutter/material.dart';

class GrowzaPreferences extends InheritedWidget {
  const GrowzaPreferences({
    super.key,
    required this.languageCode,
    required this.themeMode,
    required this.onLanguage,
    required this.onTheme,
    required super.child,
  });
  final String? languageCode;
  final ThemeMode themeMode;
  final ValueChanged<String?> onLanguage;
  final ValueChanged<bool?> onTheme;
  static GrowzaPreferences of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GrowzaPreferences>()!;
  static GrowzaPreferences? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GrowzaPreferences>();
  @override
  bool updateShouldNotify(GrowzaPreferences oldWidget) =>
      languageCode != oldWidget.languageCode ||
      themeMode != oldWidget.themeMode;
}
