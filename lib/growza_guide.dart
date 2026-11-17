import 'app_strings.dart';

import 'package:flutter/material.dart';

void showGrowzaGuide(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: EdgeInsetsDirectional.fromSTEB(24, 4, 24, 24),
            children: [
              Text('Growza', style: Theme.of(context).textTheme.headlineMedium),
              SizedBox(height: 6),
              Text(tr(context, "نمِّ تقدمك، موضوعاً تلو الآخر.")),
              SizedBox(height: 24),
              for (final step in [
                (
                  tr(context, "1. أضف مادة"),
                  tr(
                    context,
                    "اختر موعد الاختبار وأدخل موضوعاً أو عدة مواضيع. الدقائق تقديرك للجهد المطلوب، ويمكنك تعديلها لاحقاً.",
                  ),
                ),
                (
                  tr(context, "2. خصّص وقتاً للمذاكرة"),
                  tr(
                    context,
                    "ابدأ آخر مادة من الرئيسية بنقرة، أو اختر مادة أخرى. يساعدك الجدول و«تغيّر وقتك؟» على تنظيم الوقت المتاح.",
                  ),
                ),
                (
                  tr(context, "3. أكّد تقدمك"),
                  tr(
                    context,
                    "التركيز ينمّي ساق نبتة المادة. في النهاية، حدّد المواضيع التي أنهيتها لتتفتح الأزهار. يبقى وقتك مسجلاً ولو لم تنهِ موضوعاً، ويمكن إعادة فتح المواضيع من المواد.",
                  ),
                ),
                (
                  tr(context, "4. تابع مواعيدك"),
                  tr(
                    context,
                    "تظهر اختبارات المواد في الجدول تلقائياً. فعّل تنبيهات الدراسة من تنبيهات الاختبار. روابط التقويم تجلب تسليمات الجامعة ومحاضراتها.",
                  ),
                ),
                (
                  tr(context, "5. أكمل من حيث توقفت"),
                  tr(
                    context,
                    "تُحفظ بياناتك ومؤقتك على هذا الجهاز. يستمر المؤقت الجاري عند إغلاق التطبيق، ويبقى المؤقت المتوقف متوقفاً.",
                  ),
                ),
                (
                  tr(context, "حول مراجع PDF"),
                  tr(
                    context,
                    "اختر PDF أثناء إضافة المادة أو الموضوع. يُقرأ الفهرس مباشرة على جهازك، ثم وافق على التحليل وراجع المواضيع قبل حفظها.",
                  ),
                ),
              ]) ...[
                Text(step.$1, style: Theme.of(context).textTheme.titleMedium),
                SizedBox(height: 6),
                Text(step.$2),
                SizedBox(height: 20),
              ],
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr(context, "فهمت")),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
