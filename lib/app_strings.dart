import 'package:flutter/material.dart';

import 'app_translations.dart';

/// Interpolation values are inserted verbatim: subject/topic names are never
/// translated or changed in storage.
String tr(
  BuildContext context,
  String source, [
  List<Object?> values = const [],
]) {
  final english = Localizations.maybeLocaleOf(context)?.languageCode == 'en';
  final template = english ? englishCopy[source] ?? source : source;
  return template.replaceAllMapped(RegExp(r'\{(\d+)\}'), (match) {
    final i = int.parse(match[1]!);
    return i < values.length ? '${values[i] ?? ''}' : match[0]!;
  });
}

String translatedMessage(BuildContext context, String source) {
  if (Localizations.maybeLocaleOf(context)?.languageCode != 'en') return source;
  final direct = englishCopy[source];
  if (direct != null) return direct;
  // Service messages retain their original storage language and are localized
  // only at presentation. Dynamic UI text uses explicit interpolation above.
  return source;
}
