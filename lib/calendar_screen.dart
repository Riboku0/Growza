import 'package:flutter/material.dart';

import 'calendar_data.dart';
import 'calendar_service.dart';
import 'study_data.dart';
import 'study_ui.dart';
import 'form_guard.dart';

class ExternalCalendarsScreen extends StatefulWidget {
  const ExternalCalendarsScreen({
    super.key,
    required this.service,
    required this.now,
  });
  final CalendarService service;
  final DateTime Function() now;
  @override
  State<ExternalCalendarsScreen> createState() =>
      _ExternalCalendarsScreenState();
}

class _ExternalCalendarsScreenState extends State<ExternalCalendarsScreen> {
  int _filter = 0;
  Future<void> _import() => Navigator.push<void>(
    context,
    GrowzaRoute(
      builder: (context) =>
          CalendarImportScreen(service: widget.service, now: widget.now),
    ),
  );

  Future<void> _remove(CalendarSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, "إزالة التقويم؟")),
        content: Text(
          tr(context, "إزالة {0} وتنبيهاته المستوردة؟", [source.name]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, "إلغاء")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, "إزالة")),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.service.remove(source.id);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) {
      final service = widget.service;
      final now = widget.now();
      final items = service.items
          .where(
            (item) => switch (_filter) {
              1 => !item.completedAt(now) && item.isPast(now),
              2 => item.completedAt(now),
              _ => !item.completedAt(now) && !item.isPast(now),
            },
          )
          .toList();
      return Scaffold(
        appBar: AppBar(title: Text(tr(context, "التنبيهات والتقاويم"))),
        body: SafeArea(
          child: ScreenList(
            children: [
              PageHeading(
                tr(context, "كل مواعيد دراستك معاً"),
                tr(context, "أدر تنبيهات الاختبارات واربط تقويم دراستك."),
                eyebrow: tr(context, "الاختبارات والتقاويم"),
              ),
              if (!service.supported)
                Panel(
                  child: Text(
                    tr(context, "روابط التقويم متاحة في تطبيقَي Android وiOS."),
                  ),
                )
              else if (service.loading)
                Center(child: CircularProgressIndicator())
              else ...[
                StudyButton(
                  tr(context, "إضافة رابط تقويم"),
                  service.busy ? null : _import,
                ),
                if (service.error case final error?) ...[
                  Panel(
                    color: growzaColor(context, amberLight),
                    child: Text(translatedMessage(context, error)),
                  ),
                  TextButton(
                    onPressed: service.retry,
                    child: Text(tr(context, "إعادة المحاولة")),
                  ),
                ],
                if (service.backgroundError case final warning?)
                  Panel(
                    color: growzaColor(context, amberLight),
                    child: Text(warning),
                  ),
                if (service.engine.reminderWarning case final warning?)
                  Panel(
                    color: growzaColor(context, amberLight),
                    child: Text(warning),
                  ),
                if (service.supported) ...[
                  Panel(
                    color: growzaColor(context, accentSoft),
                    bordered: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(tr(context, "تنبيهات الدراسة")),
                            subtitle: Text(
                              tr(
                                context,
                                "تنبيهات الاختبارات ومواعيد التقويم المستوردة.",
                              ),
                            ),
                            value: service.enabled && service.permissionGranted,
                            onChanged: service.busy
                                ? null
                                : service.setReminders,
                          ),
                        ),
                        if (service.examCount > 0)
                          Text(
                            tr(
                              context,
                              "عدد الاختبارات: {0}. تصلك تنبيهات قبلها بيوم، وفي يومها، وقبلها بساعة عند تحديد الوقت.",
                              [service.examCount],
                            ),
                          ),
                        if (!service.permissionGranted)
                          copy(
                            tr(
                              context,
                              "اسمح بتنبيهات Growza عند الطلب. إذا رفضتها سابقاً، فعّلها من إعدادات الهاتف.",
                            ),
                            12,
                            color: growzaColor(context, muted),
                          ),
                        SizedBox(height: 6),
                        copy(
                          tr(
                            context,
                            "تُفحص التحديثات دورياً في الخلفية. يعتمد وصول التنبيهات على جهازك ومصدر التقويم.",
                          ),
                          12,
                          color: growzaColor(context, muted),
                        ),
                      ],
                    ),
                  ),
                  for (final source in service.sources)
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 7,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                color: growzaColor(context, accent),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: copy(
                                  source.name,
                                  16,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              IconButton(
                                tooltip: tr(context, "إزالة {0}", [
                                  source.name,
                                ]),
                                onPressed: service.busy
                                    ? null
                                    : () => _remove(source),
                                icon: Icon(
                                  Icons.link_off_rounded,
                                  color: growzaColor(context, muted),
                                ),
                              ),
                            ],
                          ),
                          copy(
                            source.kind == CalendarKind.deadlines
                                ? tr(context, "مواعيد التسليم والمهام")
                                : source.kind == CalendarKind.classes
                                ? tr(context, "المحاضرات والاجتماعات")
                                : tr(context, "التسليمات والمحاضرات"),
                            13,
                            color: growzaColor(context, muted),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(tr(context, "تنبيهات هذا التقويم")),
                              value: source.reminders,
                              onChanged: service.busy
                                  ? null
                                  : (value) => service.setSourceReminders(
                                      source.id,
                                      value,
                                    ),
                            ),
                          ),
                          copy(
                            source.lastSync == null
                                ? tr(context, "بانتظار أول تحديث")
                                : tr(context, "آخر تحديث: {0} الساعة {1}", [
                                    dayLabel(context, source.lastSync!),
                                    clockLabel(source.lastSync!),
                                  ]),
                            12,
                            color: growzaColor(context, muted),
                          ),
                          if (source.error case final error?)
                            copy(
                              translatedMessage(context, error),
                              13,
                              color: growzaColor(context, amberInk),
                            ),
                          if (source.skipped > 0)
                            copy(
                              tr(
                                context,
                                "تعذّر استيراد {0} عنصراً لعدم دعم تواريخها أو منطقتها الزمنية.",
                                [source.skipped],
                              ),
                              12,
                              color: growzaColor(context, amberInk),
                            ),
                        ],
                      ),
                    ),
                  StudyButton(
                    service.busy
                        ? tr(context, "جارٍ التحديث…")
                        : tr(context, "تحديث التقاويم"),
                    service.busy ? null : service.refresh,
                    secondary: true,
                  ),
                  Wrap(
                    spacing: 7,
                    children: [
                      for (final (index, label) in [
                        tr(context, "القادم"),
                        tr(context, "متأخر"),
                        tr(context, "تم"),
                      ].indexed)
                        ChoiceChip(
                          label: Text(label),
                          selected: _filter == index,
                          onSelected: (_) => setState(() => _filter = index),
                        ),
                    ],
                  ),
                  if (items.isEmpty)
                    Panel(child: Text(tr(context, "لا توجد عناصر هنا."))),
                  for (final item in items)
                    CalendarEventTile(
                      item: item,
                      now: now,
                      onTap: () =>
                          showCalendarItem(context, service, item, now),
                    ),
                ],
              ],
            ],
          ),
        ),
      );
    },
  );
}

class CalendarImportScreen extends StatefulWidget {
  const CalendarImportScreen({
    super.key,
    required this.service,
    required this.now,
  });
  final CalendarService service;
  final DateTime Function() now;
  @override
  State<CalendarImportScreen> createState() => _CalendarImportScreenState();
}

class _CalendarImportScreenState extends State<CalendarImportScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'Blackboard');
  final _url = TextEditingController();
  CalendarKind _kind = CalendarKind.mixed;
  CalendarPreview? _preview;
  String? _error;
  bool _busy = false;
  bool _reminders = true;
  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = await widget.service.engine.feed.fetch(
        _url.text,
        _kind,
        widget.now(),
      );
      if (!mounted) return;
      if (preview.items.isEmpty && preview.skipped > 0) {
        throw CalendarImportException(
          tr(
            context,
            "تواريخ العناصر أو مناطقها الزمنية غير مدعومة. راجع التقويم الأصلي.",
          ),
        );
      }
      if (mounted) setState(() => _preview = preview);
    } on CalendarImportException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _subscribe() async {
    setState(() => _busy = true);
    final saved = await widget.service.subscribe(
      _name.text.trim(),
      _url.text,
      _kind,
      _preview!,
      _reminders,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error = widget.service.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return ConfirmDiscard(
      dirty:
          _url.text.trim().isNotEmpty ||
          _name.text != 'Blackboard' ||
          _kind != CalendarKind.mixed,
      child: Scaffold(
        appBar: AppBar(title: Text(tr(context, "إضافة تقويم"))),
        body: SafeArea(
          child: preview == null
              ? Form(
                  key: _form,
                  onChanged: () => setState(() {}),
                  child: ScreenList(
                    children: [
                      PageHeading(
                        tr(context, "ألصق رابط تقويمك"),
                        tr(context, "راجع المواعيد قبل ربط التقويم."),
                        eyebrow: tr(context, "الربط باستخدام رابط"),
                      ),
                      TextFormField(
                        controller: _name,
                        decoration: InputDecoration(
                          labelText: tr(context, "اسم التقويم"),
                        ),
                        validator: (value) => value!.trim().isEmpty
                            ? tr(context, "أدخل اسم التقويم.")
                            : null,
                      ),
                      TextFormField(
                        controller: _url,
                        textDirection: TextDirection.ltr,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        enableSuggestions: false,
                        maxLines: 3,
                        minLines: 2,
                        decoration: InputDecoration(
                          labelText: tr(context, "رابط مشاركة التقويم"),
                          hintText: tr(context, "https://… أو webcal://…"),
                        ),
                        validator: (value) => value!.trim().isEmpty
                            ? tr(context, "ألصق رابط مشاركة التقويم.")
                            : null,
                      ),
                      copy(
                        tr(context, "استخدم التقويم لـ"),
                        15,
                        weight: FontWeight.w700,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ChoiceChip(
                            label: Text(tr(context, "تقويم شامل")),
                            selected: _kind == CalendarKind.mixed,
                            onSelected: _busy
                                ? null
                                : (_) => setState(
                                    () => _kind = CalendarKind.mixed,
                                  ),
                          ),
                          ChoiceChip(
                            label: Text(tr(context, "التسليمات والمهام")),
                            selected: _kind == CalendarKind.deadlines,
                            onSelected: _busy
                                ? null
                                : (_) => setState(
                                    () => _kind = CalendarKind.deadlines,
                                  ),
                          ),
                          ChoiceChip(
                            label: Text(tr(context, "المحاضرات والاجتماعات")),
                            selected: _kind == CalendarKind.classes,
                            onSelected: _busy
                                ? null
                                : (_) => setState(
                                    () => _kind = CalendarKind.classes,
                                  ),
                          ),
                        ],
                      ),
                      Panel(
                        color: growzaColor(context, accentSoft),
                        bordered: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8,
                          children: [
                            copy(
                              tr(context, "من Blackboard"),
                              15,
                              weight: FontWeight.w700,
                            ),
                            copy(
                              tr(
                                context,
                                "التقويم ← الإعدادات ← مشاركة التقويم ← نسخ الرابط.",
                              ),
                              13,
                            ),
                            copy(
                              tr(
                                context,
                                "استخدم رابط الاشتراك الذي يفتح بيانات التقويم. يُحفظ الرابط على هذا الجهاز.",
                              ),
                              12,
                              color: growzaColor(context, muted),
                            ),
                          ],
                        ),
                      ),
                      if (_error case final error?)
                        copy(
                          translatedMessage(context, error),
                          13,
                          color: growzaColor(context, amberInk),
                        ),
                      StudyButton(
                        _busy
                            ? tr(context, "جارٍ قراءة التقويم…")
                            : tr(context, "معاينة التقويم"),
                        _busy ? null : _fetch,
                      ),
                    ],
                  ),
                )
              : ScreenList(
                  key: ValueKey('calendar-preview'),
                  children: [
                    PageHeading(
                      tr(context, "راجع المواعيد المستوردة"),
                      _name.text.trim(),
                      eyebrow: tr(context, "راجع قبل الربط"),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        Tag(
                          tr(context, "عدد العناصر: {0}", [
                            preview.items.length,
                          ]),
                        ),
                        Tag(
                          _kind == CalendarKind.deadlines
                              ? tr(context, "مواعيد التسليم")
                              : _kind == CalendarKind.classes
                              ? tr(context, "المحاضرات")
                              : tr(context, "شامل"),
                        ),
                      ],
                    ),
                    if (preview.skipped > 0)
                      Panel(
                        color: growzaColor(context, amberLight),
                        child: Text(
                          tr(
                            context,
                            "سيُتجاوز {0} عنصراً لعدم دعم تواريخها أو مناطقها الزمنية.",
                            [preview.skipped],
                          ),
                        ),
                      ),
                    if (_kind == CalendarKind.mixed)
                      Panel(
                        color: growzaColor(context, accentSoft),
                        bordered: false,
                        child: Text(
                          tr(
                            context,
                            "راجع الأنواع المكتشفة. يمكنك تغيير نوع العنصر إلى تسليم أو محاضرة بعد الربط.",
                          ),
                        ),
                      ),
                    if (preview.items.isEmpty)
                      Panel(
                        child: Text(
                          tr(
                            context,
                            "لا توجد مواعيد خلال السنة المقبلة. الربط يحفظ الرابط لاستقبال التحديثات لاحقاً.",
                          ),
                        ),
                      ),
                    for (final item in preview.items.take(8))
                      CalendarEventTile(item: item, now: widget.now()),
                    if (preview.items.length > 8)
                      copy(
                        tr(context, "وعناصر إضافية: {0}.", [
                          preview.items.length - 8,
                        ]),
                        13,
                        color: growzaColor(context, muted),
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(tr(context, "تفعيل تنبيهات التقويم")),
                      subtitle: Text(
                        tr(
                          context,
                          "عناصر جديدة، وتسليمات اليوم، وقبل الموعد بساعة.",
                        ),
                      ),
                      value: _reminders,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _reminders = value),
                    ),
                    Panel(
                      color: growzaColor(context, accentSoft),
                      bordered: false,
                      child: Text(
                        tr(
                          context,
                          "المواعيد دون وقت تتلقى تنبيه اليوم نفسه. تُحجز أوقات المحاضرات في خطة المذاكرة.",
                        ),
                      ),
                    ),
                    if (_error case final error?)
                      copy(
                        translatedMessage(context, error),
                        13,
                        color: growzaColor(context, amberInk),
                      ),
                    StudyButton(
                      _busy
                          ? tr(context, "جارٍ الربط…")
                          : tr(context, "ربط التقويم"),
                      _busy ? null : _subscribe,
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _preview = null;
                              _error = null;
                            }),
                      child: Text(tr(context, "تعديل الرابط")),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class CalendarEventTile extends StatelessWidget {
  const CalendarEventTile({
    super.key,
    required this.item,
    required this.now,
    this.onTap,
  });
  final CalendarItem item;
  final DateTime now;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final today = DateUtils.isSameDay(item.start, now);
    final soon =
        !item.dateOnly &&
        item.start.isAfter(now) &&
        item.start.difference(now) <= Duration(hours: 1);
    final status = item.completedAt(now)
        ? tr(context, "تم")
        : item.isPast(now)
        ? tr(context, "متأخر")
        : soon
        ? (item.deadline
              ? tr(context, "التسليم خلال ساعة")
              : tr(context, "يبدأ خلال ساعة"))
        : today
        ? (item.deadline ? tr(context, "التسليم اليوم") : tr(context, "اليوم"))
        : item.deadline
        ? tr(context, "موعد تسليم")
        : tr(context, "محاضرة");
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Panel(
        color: !item.completedAt(now) && (today || soon)
            ? growzaColor(context, amberLight)
            : Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              item.completedAt(now)
                  ? Icons.check_circle_outline
                  : item.deadline
                  ? Icons.assignment_outlined
                  : Icons.school_outlined,
              color: item.completedAt(now)
                  ? growzaColor(context, greenInk)
                  : growzaColor(context, accent),
              size: 25,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  copy(item.title, 15, weight: FontWeight.w700),
                  copy(
                    tr(context, "{0} · {1}", [
                      dayLabel(context, item.start),
                      item.dateOnly
                          ? tr(context, "طوال اليوم")
                          : clockLabel(item.start),
                    ]),
                    13,
                    color: growzaColor(context, muted),
                  ),
                  if (item.sourceName.isNotEmpty)
                    copy(
                      item.sourceName,
                      12,
                      color: growzaColor(context, muted),
                    ),
                  Tag(
                    status,
                    background: item.completedAt(now)
                        ? growzaColor(context, greenLight)
                        : growzaColor(context, accentSoft),
                    foreground: item.completedAt(now)
                        ? growzaColor(context, greenInk)
                        : growzaColor(context, accent),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: growzaColor(context, muted),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> showCalendarItem(
  BuildContext context,
  CalendarService service,
  CalendarItem item,
  DateTime now,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (context) => SingleChildScrollView(
    padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        copy(item.title, 22, weight: FontWeight.w700),
        copy(item.sourceName, 14, color: growzaColor(context, muted)),
        copy(
          tr(context, "{0} · {1}", [
            dayLabel(context, item.start),
            item.dateOnly
                ? tr(context, "طوال اليوم · الوقت غير محدد")
                : clockLabel(item.start),
          ]),
          15,
        ),
        if (item.location.isNotEmpty) copy(item.location, 14),
        if (!item.remoteDone &&
            item.end != null &&
            item.end!.isAfter(item.start))
          TextButton.icon(
            icon: Icon(Icons.swap_horiz_rounded),
            label: Text(
              item.deadline
                  ? tr(context, "اعتباره محاضرة")
                  : tr(context, "اعتباره موعد تسليم"),
            ),
            onPressed: service.busy
                ? null
                : () async {
                    final saved = await service.setDeadline(
                      item,
                      !item.deadline,
                    );
                    if (context.mounted && saved) Navigator.pop(context);
                  },
          ),
        if (item.description.isNotEmpty) SelectableText(item.description),
        if (item.dayHasPassed(now)) ...[
          Tag(
            tr(context, "اكتمل تلقائياً"),
            background: growzaColor(context, greenLight),
            foreground: growzaColor(context, greenInk),
          ),
          copy(
            tr(context, "هذا الموعد مكتمل في Growza لأن يومه قد مضى."),
            13,
            color: growzaColor(context, muted),
          ),
        ],
        if (item.deadline && !item.remoteDone && !item.dayHasPassed(now)) ...[
          copy(
            tr(
              context,
              "تحديد العنصر كمكتمل يتحكم في تنبيهاته داخل Growza. سلّم عملك عبر منصتك الدراسية.",
            ),
            13,
            color: growzaColor(context, muted),
          ),
          StudyButton(
            item.done
                ? tr(context, "جعله غير مكتمل")
                : tr(context, "إكماله في Growza"),
            service.busy
                ? null
                : () async {
                    final saved = await service.markDone(item, !item.done);
                    if (context.mounted && saved) Navigator.pop(context);
                  },
          ),
        ],
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, "إغلاق")),
        ),
      ],
    ),
  ),
);
