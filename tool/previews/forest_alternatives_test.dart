import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growza/app_theme.dart';
import 'package:growza/plant_visual.dart';

enum _Option { photo, illustrated, plain }

const _names = ['أ · صورة خافتة', 'ب · غابة مرسومة', 'ج · دون الغابة'];
final _captureKey = GlobalKey();

class _Preview extends StatelessWidget {
  const _Preview(this.option);
  final _Option option;
  @override
  Widget build(BuildContext context) {
    final p = GrowzaPalette.of(context);
    final secondary = Color.alphaBlend(
      p.foreground.withValues(alpha: .86),
      p.background,
    );
    return Scaffold(
      body: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 26, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/branding/growza-icon.png',
                  width: 34,
                  height: 34,
                ),
                const SizedBox(width: 10),
                Text(
                  'Growza',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 23,
                    fontWeight: FontWeight.w600,
                    color: p.foreground,
                  ),
                ),
                const Spacer(),
                Icon(Icons.help_outline_rounded, color: secondary, size: 24),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'مستعد للمذاكرة؟',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: p.foreground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'خطوة صغيرة، كل يوم.',
              style: TextStyle(fontSize: 16, color: secondary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (option == _Option.photo) ...[
                    Opacity(
                      opacity: .12,
                      child: Image.asset(
                        'assets/images/study-forest-v1.png',
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: AlignmentDirectional.topCenter,
                          end: AlignmentDirectional.bottomCenter,
                          colors: [
                            p.background,
                            p.background.withValues(alpha: 0),
                            p.background,
                          ],
                          stops: const [0, .48, 1],
                        ),
                      ),
                    ),
                  ],
                  if (option == _Option.illustrated)
                    CustomPaint(painter: _FlatForest(p)),
                  const Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(38, 0, 38, 0),
                    child: StudyPlant(
                      units: 4,
                      flowers: .6,
                      centered: true,
                      animate: false,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'الأحياء · شجرة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: p.foreground,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'باقي 6 أيام · أنجزت 3 من 8 مواضيع',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: secondary),
            ),
            const SizedBox(height: 10),
            Semantics(
              label: 'تقدم المواضيع',
              child: Row(
                children: [
                  Text(
                    'المواضيع',
                    style: TextStyle(fontSize: 13, color: secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: 3 / 8,
                      minHeight: 4,
                      color: p.positiveText,
                      backgroundColor: p.subtle,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: p.action,
                foregroundColor: p.card,
              ),
              child: const Text(
                'ابدأ: الأحياء · الفصل الرابع',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'مواد أخرى',
                  style: TextStyle(fontSize: 15, color: secondary),
                ),
                const Spacer(),
                Text(
                  'عرض الكل',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: p.foreground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Mini('الرياضيات', 1.1, p),
                _Mini('الفيزياء', 2.1, p),
                _Mini('اللغة الإنجليزية', .1, p),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'المواد',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'الجدول',
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.name, this.units, this.palette);
  final String name;
  final double units;
  final GrowzaPalette palette;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 100,
    child: Column(
      children: [
        SizedBox(
          width: 48,
          height: 43,
          child: StudyPlant(
            units: units,
            flowers: 0,
            centered: true,
            animate: false,
          ),
        ),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: palette.foreground),
        ),
      ],
    ),
  );
}

class _FlatForest extends CustomPainter {
  const _FlatForest(this.p);
  final GrowzaPalette p;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()..isAntiAlias = true;
    Color tint(double amount) =>
        Color.lerp(p.background, p.positiveText, amount)!;
    final far = Path()
      ..moveTo(0, h * .4)
      ..cubicTo(w * .23, h * .08, w * .36, h * .4, w * .55, h * .37)
      ..cubicTo(w * .76, h * .15, w * .9, h * .3, w, h * .23)
      ..lineTo(w, h * .86)
      ..lineTo(0, h * .86)
      ..close();
    canvas.drawPath(far, paint..color = tint(.075));
    final near = Path()
      ..moveTo(0, h * .54)
      ..cubicTo(w * .25, h * .37, w * .4, h * .65, w * .63, h * .51)
      ..cubicTo(w * .85, h * .37, w * .92, h * .48, w, h * .46)
      ..lineTo(w, h * .87)
      ..lineTo(0, h * .87)
      ..close();
    canvas.drawPath(near, paint..color = tint(.13));
    // Silhouettes stay at the edges so the existing plant remains the focus.
    for (var i = 0; i < 11; i++) {
      final x = i < 6 ? -8.0 + i * 17 : w - 66 + (i - 6) * 17;
      final height = 42.0 + (i % 4) * 13;
      final bottom = h * .77 + math.sin(i * 2.0) * 7;
      paint.color = tint(.15 + (i % 3) * .035);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 1.4, bottom - height, 2.8, height),
          const Radius.circular(2),
        ),
        paint,
      );
      for (var branch = 0; branch < 3; branch++) {
        final top = bottom - height + branch * height * .20;
        final width = 13.0 + branch * 4;
        final tree = Path()
          ..moveTo(x, top)
          ..quadraticBezierTo(
            x - width * .4,
            top + height * .17,
            x - width,
            top + height * .34,
          )
          ..quadraticBezierTo(
            x,
            top + height * .39,
            x + width,
            top + height * .34,
          )
          ..quadraticBezierTo(x + width * .4, top + height * .17, x, top)
          ..close();
        canvas.drawPath(tree, paint);
      }
    }
    final ground = Path()
      ..moveTo(0, h * .79)
      ..quadraticBezierTo(w * .45, h * .72, w, h * .81)
      ..lineTo(w, h * .9)
      ..quadraticBezierTo(w * .45, h * .88, 0, h * .92)
      ..close();
    canvas.drawPath(ground, paint..color = tint(.09));
  }

  @override
  bool shouldRepaint(covariant _FlatForest old) => old.p != p;
}

Widget _app(_Option o) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: const Locale('ar', 'SA'),
  supportedLocales: const [Locale('ar', 'SA')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: buildGrowzaTheme(),
  home: _Preview(o),
);
Future<void> _save(WidgetTester t, String filename, {double ratio = 2}) async {
  await t.runAsync(() async {
    final b = t.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
    final im = await b.toImage(pixelRatio: ratio);
    final data = await im.toByteData(format: ui.ImageByteFormat.png);
    await File('output/previews/$filename')
        .writeAsBytes(data!.buffer.asUint8List());
    im.dispose();
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final font in [
      ('GrowzaArabic', 'assets/fonts/NotoNaskhArabic-Regular.ttf'),
      (
        'Roboto',
        'C:/src/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
      ),
      (
        'MaterialIcons',
        'C:/src/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      ),
    ]) {
      await (FontLoader(font.$1)..addFont(
            Future.value(ByteData.sublistView(File(font.$2).readAsBytesSync())),
          ))
          .load();
    }
  });
  testWidgets('Export matched forest alternatives and verify text contrast', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    Directory('output/previews').createSync(recursive: true);
    for (final o in _Option.values) {
      await t.pumpWidget(RepaintBoundary(key: _captureKey, child: _app(o)));
      await t.pumpAndSettle();
      await t.runAsync(() async {
        final ctx = t.element(find.byType(_Preview));
        await Future.wait([
          precacheImage(
            const AssetImage('assets/images/study-forest-v1.png'),
            ctx,
          ),
          precacheImage(
            const AssetImage('assets/branding/growza-icon.png'),
            ctx,
          ),
        ]);
      });
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await _save(t, 'Growza-Forest-${String.fromCharCode(65 + o.index)}.png');
    }
    // All actual text is placed on opaque cream. Check even the darkest
    // possible pixel beneath the faint photo, in case text is later overlaid.
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
    }

    final p = GrowzaPalette.light;
    final secondary = Color.alphaBlend(
      p.foreground.withValues(alpha: .86),
      p.background,
    );
    final darkestPhoto = Color.alphaBlend(
      Colors.black.withValues(alpha: .12),
      p.background,
    );
    expect(contrast(p.foreground, darkestPhoto), greaterThanOrEqualTo(4.5));
    expect(contrast(secondary, darkestPhoto), greaterThanOrEqualTo(4.5));
    expect(contrast(p.card, p.action), greaterThanOrEqualTo(4.5));
    await t.binding.setSurfaceSize(const Size(1230, 992));
    await t.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildGrowzaTheme(),
          locale: const Locale('ar', 'SA'),
          supportedLocales: const [Locale('ar', 'SA')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final o in _Option.values) ...[
                      if (o.index > 0) const SizedBox(width: 15),
                      SizedBox(
                        width: 390,
                        child: Column(
                          children: [
                            SizedBox(
                              height: 46,
                              child: Center(
                                child: Text(
                                  _names[o.index],
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: SizedBox(
                                width: 390,
                                height: 900,
                                child: _app(o),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await _save(t, 'Growza-Forest-Comparison.png', ratio: 1.5);
    debugPrint(
      'Preview-only exports complete; contrast: primary ${contrast(p.foreground, darkestPhoto).toStringAsFixed(2)}, secondary ${contrast(secondary, darkestPhoto).toStringAsFixed(2)}, action ${contrast(p.card, p.action).toStringAsFixed(2)}.',
    );
  });
}
