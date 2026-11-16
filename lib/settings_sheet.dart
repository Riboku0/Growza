import 'account_service.dart';
import 'privacy_screen.dart';
import 'workspace_actions.dart';

import 'package:flutter/material.dart';

import 'app_preferences.dart';
import 'study_ui.dart';
import 'auth_screen.dart';

Future<void> showGrowzaSettings(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const SafeArea(top: false, child: _SettingsSheet()),
    );

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();
  @override
  Widget build(BuildContext context) {
    final preferences = GrowzaPreferences.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .84,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(context, 'الإعدادات'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: tr(context, 'إغلاق'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(22, 0, 22, 24),
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      tr(context, 'حسابك'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: GrowzaPalette.of(context).subtle,
                        foregroundColor: GrowzaPalette.of(context).action,
                        child: const Icon(Icons.person_outline_rounded),
                      ),
                      title: Text(
                        AccountScope.maybeOf(context)?.session?.email ??
                            tr(context, 'ذاكر الآن، والحساب اختياري'),
                      ),
                      subtitle: Text(
                        tr(
                          context,
                          AccountScope.maybeOf(context)?.session != null &&
                                  AccountScope.maybeOf(context)?.isLocal == true
                              ? 'حساب محلي · موادك محفوظة على هذا الجهاز.'
                              : 'موادك محفوظة على هذا الجهاز.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (AccountScope.maybeOf(context)?.session == null)
                      OutlinedButton.icon(
                        key: const ValueKey('settings-account'),
                        icon: const Icon(Icons.login_rounded),
                        label: Text(tr(context, 'تسجيل الدخول أو إنشاء حساب')),
                        onPressed: () {
                          final navigator = Navigator.of(context);
                          navigator.pop();
                          navigator.push(
                            GrowzaRoute(builder: (_) => const AuthScreen()),
                          );
                        },
                      ),
                    const SizedBox(height: 20),
                    Text(
                      tr(context, 'المظهر'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _Options(
                      children: [
                        _Choice(
                          key: const ValueKey('appearance-system'),
                          icon: Icons.phone_android_rounded,
                          label: tr(context, 'تلقائي'),
                          selected: preferences.themeMode == ThemeMode.system,
                          onTap: () => preferences.onTheme(null),
                        ),
                        _Choice(
                          key: const ValueKey('appearance-light'),
                          icon: Icons.light_mode_outlined,
                          label: tr(context, 'فاتح'),
                          selected: preferences.themeMode == ThemeMode.light,
                          onTap: () => preferences.onTheme(false),
                        ),
                        _Choice(
                          key: const ValueKey('appearance-dark'),
                          icon: Icons.dark_mode_outlined,
                          label: tr(context, 'داكن'),
                          selected: preferences.themeMode == ThemeMode.dark,
                          onTap: () => preferences.onTheme(true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      tr(context, 'اللغة'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _Options(
                      children: [
                        _Choice(
                          key: const ValueKey('language-system'),
                          icon: Icons.phone_android_rounded,
                          label: tr(context, 'لغة الهاتف'),
                          selected: preferences.languageCode == null,
                          onTap: () => preferences.onLanguage(null),
                        ),
                        _Choice(
                          key: const ValueKey('language-ar'),
                          icon: Icons.translate_rounded,
                          label: 'العربية',
                          selected: preferences.languageCode == 'ar',
                          onTap: () => preferences.onLanguage('ar'),
                        ),
                        _Choice(
                          key: const ValueKey('language-en'),
                          icon: Icons.translate_rounded,
                          label: 'English',
                          selected: preferences.languageCode == 'en',
                          onTap: () => preferences.onLanguage('en'),
                        ),
                      ],
                    ),
                    if (AccountScope.maybeOf(context)?.session != null)
                      TextButton.icon(
                        key: const ValueKey('settings-sign-out'),
                        onPressed: () async {
                          final accounts = AccountScope.maybeOf(context)!;
                          try {
                            await accounts.signOut();
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    tr(context, accountMessage('unavailable')),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.logout),
                        label: Text(tr(context, 'تسجيل الخروج')),
                      ),
                    TextButton(
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        navigator.push(
                          GrowzaRoute(builder: (_) => const PrivacyScreen()),
                        );
                      },
                      child: Text(tr(context, 'الخصوصية والحساب')),
                    ),
                    const SizedBox(height: 24),
                    if (WorkspaceActions.maybeOf(context) case final actions?)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.backup_outlined),
                        title: Text(tr(context, 'النسخ الاحتياطي')),
                        trailing: Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.chevron_left_rounded
                              : Icons.chevron_right_rounded,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          actions.onBackup();
                        },
                      ),
                    Text(
                      tr(context, 'تُحفظ اختياراتك تلقائياً.'),
                      style: TextStyle(
                        color: GrowzaPalette.of(context).secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Options extends StatelessWidget {
  const _Options({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (i, child) in children.indexed) ...[
        if (i != 0) const SizedBox(width: 8),
        Expanded(child: child),
      ],
    ],
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = GrowzaPalette.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? p.subtle : p.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 92),
            padding: const EdgeInsetsDirectional.fromSTEB(6, 16, 6, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? p.action : p.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: selected ? p.action : p.secondaryText),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(height: 5),
                  Icon(Icons.check_rounded, size: 16, color: p.action),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
