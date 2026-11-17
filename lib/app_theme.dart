import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'motion.dart';

const ink = Color(0xff303c34);
const accent = Color(0xff354b3d);
const canvas = Color(0xfff7f6f2);
const surface = Color(0xfffdfcf8);
const accentSoft = Color(0xffe6e9de);
const outline = Color(0xffe1e4da);
const muted = Color(0xff616d5d);
const amberLight = Color(0xfff5ecdf);
const amberInk = Color(0xff8a613d);
const greenLight = Color(0xffe7edde);
const greenInk = Color(0xff536b49);

const growzaSystemBars = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  systemNavigationBarColor: canvas,
  systemNavigationBarIconBrightness: Brightness.dark,
);

class GrowzaPalette {
  const GrowzaPalette({
    required this.foreground,
    required this.action,
    required this.background,
    required this.card,
    required this.subtle,
    required this.border,
    required this.secondaryText,
    required this.warningBg,
    required this.warningText,
    required this.positiveBg,
    required this.positiveText,
  });
  final Color foreground,
      action,
      background,
      card,
      subtle,
      border,
      secondaryText;
  final Color warningBg, warningText, positiveBg, positiveText;
  static const light = GrowzaPalette(
    foreground: ink,
    action: accent,
    background: canvas,
    card: surface,
    subtle: accentSoft,
    border: outline,
    secondaryText: muted,
    warningBg: amberLight,
    warningText: amberInk,
    positiveBg: greenLight,
    positiveText: greenInk,
  );
  static const dark = GrowzaPalette(
    foreground: Color(0xffe6e9df),
    action: Color(0xffa8c49f),
    background: Color(0xff151e19),
    card: Color(0xff202c24),
    subtle: Color(0xff304233),
    border: Color(0xff3e4e42),
    secondaryText: Color(0xffadb6a6),
    warningBg: Color(0xff3b3022),
    warningText: Color(0xffe5c297),
    positiveBg: Color(0xff293c2c),
    positiveText: Color(0xffb3cda3),
  );
  static GrowzaPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

Color growzaColor(BuildContext context, Color lightColor) {
  final p = GrowzaPalette.of(context);
  return <Color, Color>{
        ink: p.foreground,
        accent: p.action,
        canvas: p.background,
        surface: p.card,
        accentSoft: p.subtle,
        outline: p.border,
        muted: p.secondaryText,
        amberLight: p.warningBg,
        amberInk: p.warningText,
        greenLight: p.positiveBg,
        greenInk: p.positiveText,
      }[lightColor] ??
      lightColor;
}

SystemUiOverlayStyle growzaSystemBarsFor(Brightness brightness) =>
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarColor: brightness == Brightness.dark
          ? GrowzaPalette.dark.background
          : canvas,
      systemNavigationBarIconBrightness: brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
    );

ThemeData buildGrowzaTheme({Brightness brightness = Brightness.light}) {
  final palette = brightness == Brightness.dark
      ? GrowzaPalette.dark
      : GrowzaPalette.light;
  final ink = palette.foreground,
      accent = palette.action,
      canvas = palette.background,
      surface = palette.card,
      accentSoft = palette.subtle,
      outline = palette.border,
      muted = palette.secondaryText,
      greenInk = palette.positiveText;

  final base = brightness == Brightness.dark
      ? ThemeData.dark(useMaterial3: true)
      : ThemeData.light(useMaterial3: true);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(15));
  return ThemeData(
    useMaterial3: true,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: GrowzaPageTransitions(),
        TargetPlatform.windows: GrowzaPageTransitions(),
        TargetPlatform.linux: GrowzaPageTransitions(),
      },
    ),
    fontFamily: 'GrowzaArabic',
    fontFamilyFallback: ['Roboto'],
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      primary: accent,
      onPrimary: surface,
      secondary: greenInk,
      secondaryContainer: accentSoft,
      onSecondaryContainer: ink,
      surface: surface,
      onSurface: ink,
      outline: outline,
      error: brightness == Brightness.dark
          ? Color(0xffffb4a6)
          : Color(0xffa04435),
    ),
    scaffoldBackgroundColor: canvas,
    visualDensity: VisualDensity.standard,
    textTheme: base.textTheme
        .apply(
          fontFamily: 'GrowzaArabic',
          fontFamilyFallback: ['Roboto'],
          bodyColor: ink,
          displayColor: ink,
        )
        .copyWith(
          headlineLarge: TextStyle(
            fontFamily: 'GrowzaArabic',
            fontFamilyFallback: ['Roboto'],
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            color: ink,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'GrowzaArabic',
            fontFamilyFallback: ['Roboto'],
            fontSize: 27,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            color: ink,
          ),
          titleLarge: TextStyle(
            fontFamily: 'GrowzaArabic',
            fontFamilyFallback: ['Roboto'],
            fontSize: 21,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            color: ink,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'GrowzaArabic',
            fontFamilyFallback: ['Roboto'],
            fontSize: 15,
            height: 1.5,
            color: ink,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'GrowzaArabic',
            fontFamilyFallback: ['Roboto'],
            fontSize: 14,
            height: 1.45,
            color: ink,
          ),
          bodySmall: TextStyle(
            fontFamily: 'GrowzaArabic',
            fontFamilyFallback: ['Roboto'],
            fontSize: 12,
            height: 1.45,
            color: muted,
          ),
          labelLarge: TextStyle(
            fontFamily: 'GrowzaArabic',
            fontFamilyFallback: ['Roboto'],
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      systemOverlayStyle: growzaSystemBarsFor(brightness),
      titleTextStyle: TextStyle(
        fontFamily: 'GrowzaArabic',
        fontFamilyFallback: ['Roboto'],
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: ink,
        letterSpacing: 0,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      backgroundColor: canvas,
      indicatorColor: accentSoft,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'GrowzaArabic',
          fontFamilyFallback: ['Roboto'],
          fontSize: 11.5,
          color: states.contains(WidgetState.selected) ? ink : muted,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected) ? ink : muted,
        ),
      ),
    ),
    iconTheme: IconThemeData(color: ink, size: 22),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: ink,
        minimumSize: Size(44, 44),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: surface,
        elevation: 0,
        minimumSize: Size(0, 50),
        shape: shape,
        textStyle: TextStyle(
          fontFamily: 'GrowzaArabic',
          fontFamilyFallback: ['Roboto'],
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: BorderSide(color: outline),
        minimumSize: Size(0, 48),
        shape: shape,
        textStyle: TextStyle(
          fontFamily: 'GrowzaArabic',
          fontFamilyFallback: ['Roboto'],
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        minimumSize: Size(44, 44),
        padding: EdgeInsets.symmetric(horizontal: 10),
        textStyle: TextStyle(
          fontFamily: 'GrowzaArabic',
          fontFamilyFallback: ['Roboto'],
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: brightness == Brightness.dark
              ? Color(0xffffb4a6)
              : Color(0xffa04435),
        ),
      ),
      labelStyle: TextStyle(
        fontFamily: 'GrowzaArabic',
        fontFamilyFallback: ['Roboto'],
        fontSize: 14,
        color: muted,
      ),
      helperStyle: TextStyle(
        fontFamily: 'GrowzaArabic',
        fontFamilyFallback: ['Roboto'],
        fontSize: 12,
        color: muted,
      ),
      prefixIconColor: muted,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Color(0x44303c34),
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      headerForegroundColor: ink,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: surface,
      hourMinuteColor: accentSoft,
      dialBackgroundColor: accentSoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: accentSoft,
      side: BorderSide(color: outline),
      shape: StadiumBorder(),
      labelStyle: TextStyle(
        fontFamily: 'GrowzaArabic',
        fontFamilyFallback: ['Roboto'],
        fontSize: 12,
        color: ink,
      ),
    ),
    dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 24),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor: accentSoft,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionColor: accent.withValues(alpha: 0.18),
      selectionHandleColor: accent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      contentTextStyle: TextStyle(
        fontFamily: 'GrowzaArabic',
        fontFamilyFallback: ['Roboto'],
        color: surface,
        fontSize: 13,
      ),
    ),
  );
}

abstract final class GrowzaLayout {
  static const heroPlantHeight = 280.0;
  static const seedHeight = 220.0;
  static const thumbnail = 56.0;
  static const buttonRadius = 16.0;
  static const panelRadius = 20.0;
  static const sectionGap = 20.0;
}

/// Drawing colors live with the app palette, including the quiet forest layers.
class PlantPalette {
  const PlantPalette({
    required this.background,
    required this.trunk,
    required this.trunkLight,
    required this.stem,
    required this.leafDark,
    required this.leafMid,
    required this.leafLight,
    required this.vein,
    required this.soil,
    required this.soilDark,
    required this.seed,
    required this.seedLight,
    required this.petal,
    required this.pollen,
    required this.highlight,
    required this.halo,
    required this.text,
    required this.secondary,
  });
  final Color background,
      trunk,
      trunkLight,
      stem,
      leafDark,
      leafMid,
      leafLight,
      vein;
  final Color soil,
      soilDark,
      seed,
      seedLight,
      petal,
      pollen,
      highlight,
      halo,
      text,
      secondary;
  static PlantPalette of(BuildContext context) =>
      forBrightness(Theme.of(context).brightness);
  static PlantPalette forBrightness(Brightness b) {
    final p = b == Brightness.dark ? GrowzaPalette.dark : GrowzaPalette.light;
    final dark = b == Brightness.dark;
    return PlantPalette(
      background: p.background,
      trunk: dark ? const Color(0xffa28a65) : const Color(0xff806d50),
      trunkLight: dark ? const Color(0xffc6ae82) : const Color(0xffb7a17d),
      stem: dark ? const Color(0xff9cb887) : const Color(0xff547348),
      leafDark: dark ? const Color(0xff6c8d58) : const Color(0xff45663e),
      leafMid: dark ? const Color(0xff90ac74) : const Color(0xff527c56),
      leafLight: dark ? const Color(0xffb1c58f) : const Color(0xff87a879),
      vein: dark ? const Color(0xffcad7ad) : const Color(0xffc3d1a8),
      soil: dark ? const Color(0xff2b3d2c) : const Color(0xffe3e9d8),
      soilDark: dark ? const Color(0xff40543a) : const Color(0xffbccba9),
      seed: dark ? const Color(0xffc5a174) : const Color(0xff96734f),
      seedLight: dark ? const Color(0xffe1c89c) : const Color(0xffcfb58c),
      petal: dark ? const Color(0xfff2d8a5) : const Color(0xfff6e6cd),
      pollen: const Color(0xffebcc80),
      highlight: const Color(0xfffaedc8),
      halo: dark ? const Color(0xffa58747) : const Color(0xffe5ce9c),
      text: p.foreground,
      secondary: p.secondaryText,
    );
  }

  Color forest(double amount) => Color.lerp(background, leafMid, amount)!;
}
