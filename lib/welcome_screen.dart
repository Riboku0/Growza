import 'package:flutter/material.dart';

import 'study_ui.dart';
import 'growth_rules.dart';
import 'plant_visual.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onSignIn,
    required this.onCreate,
    required this.onGuest,
  });
  final VoidCallback onSignIn, onCreate, onGuest;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ScreenList(
        children: [
          const AppHeader(),
          const SizedBox(height: 12),
          const SizedBox(
            height: 180,
            child: PlantView(
              stage: PlantStage.sprout,
              state: PlantVisualState.breathing,
            ),
          ),
          PageHeading(
            tr(context, 'أهلاً بك في Growza'),
            tr(context, 'خطوة صغيرة للمذاكرة، ونمو تراه كل يوم.'),
          ),
          Text(
            tr(
              context,
              'ابدأ بحسابك أو تابع دون حساب. موادك محفوظة على هذا الجهاز.',
            ),
            style: TextStyle(color: GrowzaPalette.of(context).secondaryText),
          ),
          StudyButton(
            tr(context, 'تسجيل الدخول'),
            onSignIn,
            key: const ValueKey('welcome-sign-in'),
          ),
          OutlinedButton(
            onPressed: onCreate,
            key: const ValueKey('welcome-create'),
            child: Text(tr(context, 'إنشاء حساب')),
          ),
          TextButton(
            onPressed: onGuest,
            key: const ValueKey('welcome-guest'),
            child: Text(tr(context, 'متابعة دون حساب')),
          ),
        ],
      ),
    ),
  );
}
