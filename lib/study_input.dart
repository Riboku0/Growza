import 'package:flutter/services.dart';

String normalizeStudyDigits(String input) => String.fromCharCodes(
  input.runes.map((c) {
    if (c >= 0x0660 && c <= 0x0669) return c - 0x0660 + 0x30;
    if (c >= 0x06f0 && c <= 0x06f9) return c - 0x06f0 + 0x30;
    return c;
  }),
);
final studyDigitsFormatter = TextInputFormatter.withFunction(
  (oldValue, newValue) =>
      FilteringTextInputFormatter.digitsOnly.formatEditUpdate(
        oldValue,
        newValue.copyWith(text: normalizeStudyDigits(newValue.text)),
      ),
);
