import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'app_preferences.dart';
import 'app_strings.dart';
import 'settings_sheet.dart';
import 'growza_guide.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key, this.backLabel, this.onBack});
  final String? backLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    key: const ValueKey('app-header'),
    constraints: BoxConstraints(minHeight: 48),
    child: Row(
      children: [
        Expanded(
          child: backLabel != null
              ? Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: onBack,
                    icon: BackButtonIcon(),
                    label: Text(backLabel!),
                  ),
                )
              : Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.asset(
                        'assets/branding/growza-icon.png',
                        width: 35,
                        height: 35,
                        excludeFromSemantics: true,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Growza',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          color: growzaColor(context, ink),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        if (GrowzaPreferences.maybeOf(context) != null)
          IconButton(
            key: const ValueKey('header-settings'),
            tooltip: tr(context, 'الإعدادات'),
            onPressed: () => showGrowzaSettings(context),
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        IconButton(
          tooltip: tr(context, 'كيف يعمل Growza'),
          onPressed: () => showGrowzaGuide(context),
          icon: Icon(
            Icons.help_outline_rounded,
            color: growzaColor(context, muted),
            size: 21,
          ),
        ),
      ],
    ),
  );
}
