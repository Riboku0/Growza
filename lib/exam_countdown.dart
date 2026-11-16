import 'app_strings.dart';

import 'package:flutter/material.dart';

String examCountdownLabel(DateTime exam, DateTime now) {
  final local = exam.toLocal();
  final today = now.toLocal();
  final allDay = local == DateTime(local.year, local.month, local.day);
  final cutoff = allDay
      ? DateTime(local.year, local.month, local.day + 1)
      : local;
  if (!cutoff.isAfter(now)) return 'مضى الاختبار';
  final days = DateTime.utc(
    local.year,
    local.month,
    local.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  if (days == 0) return 'الاختبار اليوم';
  if (days == 1) return 'الاختبار غداً';
  return 'الأيام المتبقية: $days';
}

String localizedCountdown(BuildContext context, DateTime exam, DateTime now) {
  final label = examCountdownLabel(exam, now);
  final days = DateUtils.dateOnly(exam)
      .difference(DateUtils.dateOnly(now))
      .inDays;
  return label.startsWith('الأيام المتبقية:')
      ? tr(context, 'الأيام المتبقية: {0}', [days])
      : tr(context, label);
}
