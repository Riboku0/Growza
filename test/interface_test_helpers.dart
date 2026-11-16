import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> chooseAppearance(WidgetTester t, String mode) async {
  final scroll = find.byWidgetPredicate(
    (w) =>
        w is Scrollable &&
        (w.axisDirection == AxisDirection.down ||
            w.axisDirection == AxisDirection.up),
  );
  if (scroll.evaluate().isNotEmpty) {
    t.state<ScrollableState>(scroll.first).position.jumpTo(0);
    await t.pumpAndSettle();
  }
  await t.tap(find.byKey(const ValueKey('header-settings')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(ValueKey('appearance-$mode')));
  await t.pumpAndSettle();
  await t.tap(find.byTooltip('إغلاق').last);
  await t.pumpAndSettle();
}

Future<void> confirmEnd(WidgetTester t) async {
  await t.pumpAndSettle();
  await t.tap(find.widgetWithText(FilledButton, 'إنهاء الجلسة'));
  await t.pumpAndSettle();
}
