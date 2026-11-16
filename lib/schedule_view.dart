import 'app_strings.dart';

import 'package:flutter/material.dart';

import 'calendar_data.dart';
import 'app_theme.dart';
import 'study_data.dart';
import 'app_header.dart';

final scheduleCanvas = canvas;
final scheduleInk = ink;
final scheduleSage = accentSoft;
final _secondary = muted;
final _rule = outline;

bool _onDay(DateTime start, DateTime? end, DateTime day) {
  final from = DateUtils.dateOnly(day);
  final until = DateTime(day.year, day.month, day.day + 1);
  return start.isBefore(until) &&
      (end == null ? !start.isBefore(from) : end.isAfter(from));
}

class ScheduleView extends StatelessWidget {
  const ScheduleView({
    super.key,
    required this.day,
    required this.now,
    required this.sessions,
    required this.calendarItems,
    required this.onDayChanged,
    required this.onAdd,
    required this.onBack,
    required this.onStart,
    required this.sessionMenu,
    required this.onCalendarItem,
    this.onCalendars,
    this.onAdjust,
    this.calendarCount = 0,
    this.calendarLoading = false,
    this.hasConflict = false,
    this.isSessionPending,
    this.subjects = const [],
    this.onExam,
  });

  final List<StudySubject> subjects;
  final ValueChanged<StudySubject>? onExam;
  final DateTime day;
  final DateTime now;
  final List<StudySession> sessions;
  final List<CalendarItem> calendarItems;
  final ValueChanged<DateTime> onDayChanged;
  final VoidCallback onAdd;
  final VoidCallback onBack;
  final ValueChanged<StudySession> onStart;
  final Widget Function(StudySession) sessionMenu;
  final ValueChanged<CalendarItem> onCalendarItem;
  final VoidCallback? onCalendars;
  final VoidCallback? onAdjust;
  final int calendarCount;
  final bool calendarLoading;
  final bool hasConflict;
  final bool Function(StudySession)? isSessionPending;

  bool _hasPending(DateTime date) =>
      subjects.any(
        (s) =>
            DateUtils.isSameDay(s.exam, date) &&
            (s.exam == DateUtils.dateOnly(s.exam)
                    ? dayOffset(s.exam, 1)
                    : s.exam)
                .isAfter(now),
      ) ||
      sessions.any(
        (s) =>
            (isSessionPending?.call(s) ?? !s.completed) &&
            _onDay(s.start, s.endWithBreak, date),
      ) ||
      calendarItems.any(
        (e) =>
            !e.completedAt(now) &&
            (e.deadline || !e.isPast(now)) &&
            _onDay(e.start, e.deadline ? null : e.end, date),
      );

  Future<void> _pickDate(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: tr(context, "اختر يوماً"),
    );
    if (selected != null) onDayChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final selectedSessions =
        sessions.where((s) => _onDay(s.start, s.endWithBreak, day)).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final selectedCalendar = calendarItems
        .where((e) => _onDay(e.start, e.deadline ? null : e.end, day))
        .toList();
    final entries = <({DateTime time, bool allDay, Widget child})>[];
    final nextSession = selectedSessions
        .where((s) => !s.completed && s.endWithBreak.isAfter(now))
        .firstOrNull;
    for (final subject in subjects.where(
      (s) => DateUtils.isSameDay(s.exam, day),
    )) {
      final allDay = subject.exam == DateUtils.dateOnly(subject.exam);
      entries.add((
        time: subject.exam,
        allDay: allDay,
        child: _TimelineRow(
          time: allDay
              ? tr(context, "طوال اليوم")
              : _time(context, subject.exam),
          title: tr(context, "اختبار · {0}", [subject.name]),
          subtitle: allDay
              ? tr(context, "موعد اختبار · الوقت غير محدد")
              : tr(context, "اختبار"),
          dotColor: Color(0xffa8794c),
          icon: Icons.school_outlined,
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: growzaColor(context, _secondary),
          ),
          onTap: onExam == null ? null : () => onExam!(subject),
        ),
      ));
    }
    for (final session in selectedSessions) {
      entries.add((
        time: session.start,
        allDay: false,
        child: ScheduleSessionRow(
          session: session,
          now: now,
          day: day,
          highlighted: session == nextSession,
          workPending: isSessionPending?.call(session) ?? !session.completed,
          onStart: () => onStart(session),
          menu: sessionMenu(session),
        ),
      ));
    }
    for (final item in selectedCalendar) {
      final status = item.completedAt(now)
          ? tr(context, "تم")
          : item.isPast(now)
          ? (item.deadline ? tr(context, "متأخر") : tr(context, "انتهى"))
          : item.deadline
          ? tr(context, "موعد تسليم")
          : tr(context, "محاضرة");
      final continued = item.start.isBefore(DateUtils.dateOnly(day));
      entries.add((
        time: item.start,
        allDay: item.dateOnly,
        child: _TimelineRow(
          time: item.dateOnly
              ? tr(context, "طوال اليوم")
              : continued
              ? tr(context, "جارٍ")
              : _time(context, item.start),
          dotColor: item.completedAt(now)
              ? growzaColor(context, _secondary)
              : item.deadline
              ? Color(0xffa8794c)
              : Color(0xff8c9b80),
          title: item.title,
          subtitle: [
            if (item.sourceName.isNotEmpty) item.sourceName,
            status,
            if (!item.deadline && item.end != null && !item.dateOnly)
              tr(context, "حتى {0}", [_time(context, item.end!)]),
          ].join(' · '),
          completed: item.completedAt(now),
          icon: item.deadline
              ? Icons.assignment_outlined
              : Icons.school_outlined,
          onTap: () => onCalendarItem(item),
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: growzaColor(context, _secondary),
          ),
        ),
      ));
    }
    entries.sort((a, b) {
      if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
      return a.time.compareTo(b.time);
    });
    final dates =
        <DateTime>[
              ...subjects.map((s) => s.exam),
              ...sessions.map((s) => s.start),
              ...calendarItems
                  .where((e) => !e.completedAt(now))
                  .map((e) => e.start),
            ]
            .where(
              (d) => !d.isBefore(DateTime(day.year, day.month, day.day + 1)),
            )
            .toList()
          ..sort();
    final weekStart = DateTime(day.year, day.month, day.day - day.weekday + 1);
    final localizations = MaterialLocalizations.of(context);
    return ColoredBox(
      color: growzaColor(context, scheduleCanvas),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560),
          child: Stack(
            children: [
              ListView(
                key: PageStorageKey('daily-schedule'),
                padding: EdgeInsetsDirectional.fromSTEB(22, 10, 22, 94),
                children: [
                  AppHeader(),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        tooltip: tr(context, "العودة للرئيسية"),
                        onPressed: onBack,
                        icon: Icon(
                          Icons.chevron_left_rounded,
                          color: growzaColor(context, scheduleInk),
                        ),
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(context, "الجدول"),
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                                color: growzaColor(context, scheduleInk),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              tr(context, "خطّط ليومك، واترك مساحة للغد."),
                              style: TextStyle(
                                fontSize: 12,
                                color: growzaColor(context, _secondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: tr(context, "اختر تاريخاً"),
                        onPressed: () => _pickDate(context),
                        icon: Icon(
                          Icons.calendar_month_outlined,
                          size: 22,
                          color: growzaColor(context, scheduleInk),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () => _pickDate(context),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    localizations.formatMonthYear(day),
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.expand_more_rounded, size: 19),
                              ],
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => onDayChanged(DateUtils.dateOnly(now)),
                        child: Text(
                          tr(context, "اليوم"),
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        tooltip: tr(context, "الأسبوع السابق"),
                        onPressed: () => onDayChanged(
                          DateTime(day.year, day.month, day.day - 7),
                        ),
                        icon: Icon(Icons.chevron_left_rounded, size: 20),
                      ),
                      IconButton(
                        tooltip: tr(context, "الأسبوع التالي"),
                        onPressed: () => onDayChanged(
                          DateTime(day.year, day.month, day.day + 7),
                        ),
                        icon: Icon(Icons.chevron_right_rounded, size: 20),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var offset = 0; offset < 7; offset++)
                        Expanded(
                          child: _DayButton(
                            date: DateTime(
                              weekStart.year,
                              weekStart.month,
                              weekStart.day + offset,
                            ),
                            selected: day,
                            today: now,
                            hasPending: _hasPending(
                              DateTime(
                                weekStart.year,
                                weekStart.month,
                                weekStart.day + offset,
                              ),
                            ),
                            onSelect: onDayChanged,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 17),
                  Divider(height: 1, color: growzaColor(context, _rule)),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 5),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      children: [
                        if (onCalendars != null && calendarCount > 0)
                          TextButton.icon(
                            onPressed: onCalendars,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                            icon: Icon(Icons.link_rounded, size: 18),
                            label: Text(
                              calendarCount == 0
                                  ? tr(context, "إضافة رابط تقويم")
                                  : tr(context, "التقاويم · {0}", [
                                      calendarCount,
                                    ]),
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        if (onAdjust != null)
                          TextButton.icon(
                            onPressed: onAdjust,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                            icon: Icon(Icons.tune_rounded, size: 16),
                            label: Text(
                              tr(context, "تغيّر وقتك؟"),
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            tr(context, "الخطط: {0}", [entries.length]),
                            style: TextStyle(
                              fontSize: 12,
                              color: growzaColor(context, _secondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (calendarLoading)
                    LinearProgressIndicator(
                      minHeight: 2,
                      color: growzaColor(context, scheduleInk),
                      backgroundColor: growzaColor(context, scheduleSage),
                    ),
                  if (hasConflict)
                    Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 17,
                            color: Color(0xffa8794c),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr(
                                context,
                                "تتعارض محاضرة مع جلسة مذاكرة. راجع خطتك من «تغيّر وقتك؟».",
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: growzaColor(
                                  context,
                                  scheduleInk,
                                ).withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 10),
                  if (entries.isEmpty)
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(28, 30, 28, 36),
                      child: Column(
                        children: [
                          Icon(
                            Icons.wb_sunny_outlined,
                            size: 32,
                            color: Color(0xff9da78f),
                          ),
                          SizedBox(height: 16),
                          Text(
                            tr(context, "مساحة لالتقاط الأنفاس."),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: growzaColor(context, scheduleInk),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            tr(
                              context,
                              "لا توجد خطط لهذا اليوم. أضف جلسة مذاكرة أو اختر يوماً آخر.",
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: growzaColor(context, _secondary),
                            ),
                          ),
                          if (dates.isNotEmpty) ...[
                            SizedBox(height: 14),
                            TextButton(
                              onPressed: () =>
                                  onDayChanged(DateUtils.dateOnly(dates.first)),
                              child: Text(
                                tr(context, "الخطة التالية · {0}", [
                                  localizations.formatShortMonthDay(
                                    dates.first,
                                  ),
                                ]),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    for (final entry in entries) entry.child,
                ],
              ),
              PositionedDirectional(
                end: 20,
                bottom: 16,
                child: FloatingActionButton(
                  heroTag: 'add-schedule-session',
                  key: const ValueKey('schedule-add'),
                  tooltip: tr(context, "إضافة للجدول"),
                  onPressed: onAdd,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  elevation: 2,
                  shape: CircleBorder(),
                  child: Icon(Icons.add_rounded, size: 28),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _time(BuildContext context, DateTime date) => MaterialLocalizations.of(
  context,
).formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: false);

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.date,
    required this.selected,
    required this.today,
    required this.hasPending,
    required this.onSelect,
  });
  final DateTime date;
  final DateTime selected;
  final DateTime today;
  final bool hasPending;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final weekdays = [
      tr(context, "الاثنين"),
      tr(context, "الثلاثاء"),
      tr(context, "الأربعاء"),
      tr(context, "الخميس"),
      tr(context, "الجمعة"),
      tr(context, "السبت"),
      tr(context, "الأحد"),
    ];
    final active = DateUtils.isSameDay(date, selected);
    final isToday = DateUtils.isSameDay(date, today);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        selected: active,
        hint: hasPending
            ? tr(context, "خطط غير مكتملة")
            : tr(context, "لا توجد خطط غير مكتملة"),
        label: MaterialLocalizations.of(context).formatFullDate(date),
        button: true,
        child: InkWell(
          key: ValueKey('schedule-day-${date.year}-${date.month}-${date.day}'),
          onTap: () => onSelect(date),
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 11),
            child: ExcludeSemantics(
              child: Column(
                children: [
                  Text(
                    weekdays[date.weekday - 1],
                    style: TextStyle(
                      fontSize: 10,
                      color: growzaColor(context, _secondary),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isToday || active
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: active
                          ? growzaColor(context, greenInk)
                          : growzaColor(context, scheduleInk),
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    key: hasPending
                        ? ValueKey(
                            'schedule-pending-${date.year}-${date.month}-${date.day}',
                          )
                        : null,
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasPending
                          ? (active
                                ? growzaColor(context, greenInk)
                                : Color(0xff8c9b80))
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ScheduleSessionRow extends StatelessWidget {
  const ScheduleSessionRow({
    super.key,
    required this.session,
    required this.now,
    required this.day,
    required this.highlighted,
    required this.onStart,
    required this.menu,
    this.workPending,
  });
  final StudySession session;
  final DateTime now;
  final DateTime day;
  final bool highlighted;
  final VoidCallback onStart;
  final Widget menu;
  final bool? workPending;

  @override
  Widget build(BuildContext context) {
    final continued = session.start.isBefore(DateUtils.dateOnly(day));
    final pending = workPending ?? !session.completed;
    final status = session.completed
        ? (pending
              ? tr(context, "انتهى التركيز · الموضوع مفتوح")
              : tr(context, "مكتمل"))
        : !session.endWithBreak.isAfter(now)
        ? tr(context, "فاتت")
        : session.fixed
        ? tr(context, "ثابتة")
        : null;
    return _TimelineRow(
      time: continued ? tr(context, "جارٍ") : _time(context, session.start),
      title: session.topic,
      subtitle: [
        subjectLabel(session.subject, context: context),
        tr(context, "{0} د", [session.minutes]),
        ?status,
      ].join(' · '),
      highlighted: highlighted,
      completed: session.completed && !pending,
      dotColor: highlighted
          ? growzaColor(context, scheduleInk)
          : Color(0xff8c9b80),
      icon: session.completed
          ? (pending ? Icons.timelapse_rounded : Icons.check_rounded)
          : Icons.auto_stories_outlined,
      trailing: menu,
      onTap: session.completed ? null : onStart,
      detail: highlighted
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 10),
                Text(
                  tr(context, "{0} – {1} · بعدها استراحة 5 دقائق", [
                    _time(context, session.start),
                    _time(
                      context,
                      session.start.add(Duration(minutes: session.minutes)),
                    ),
                  ]),
                  style: TextStyle(
                    fontSize: 11,
                    color: growzaColor(context, _secondary),
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 2),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: growzaColor(context, scheduleInk),
                  ),
                  onPressed: onStart,
                  icon: Icon(Icons.play_arrow_rounded, size: 19),
                  label: Text(
                    tr(context, "ابدأ التركيز"),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.dotColor,
    required this.icon,
    required this.trailing,
    this.highlighted = false,
    this.completed = false,
    this.onTap,
    this.detail,
  });
  final String time;
  final String title;
  final String subtitle;
  final Color dotColor;
  final IconData icon;
  final Widget trailing;
  final bool highlighted;
  final bool completed;
  final VoidCallback? onTap;
  final Widget? detail;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 57,
          child: Padding(
            padding: EdgeInsetsDirectional.only(top: 17, end: 6),
            child: Text(
              time,
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: growzaColor(context, _secondary),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 14,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              PositionedDirectional(
                top: 0,
                bottom: 0,
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: growzaColor(context, _rule),
                ),
              ),
              PositionedDirectional(
                top: 20,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: growzaColor(context, scheduleCanvas),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Material(
              color: highlighted
                  ? growzaColor(context, scheduleSage)
                  : growzaColor(context, surface).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(13),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(13, 12, 2, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: 3),
                            child: Icon(
                              icon,
                              size: 17,
                              color: completed
                                  ? growzaColor(context, _secondary)
                                  : growzaColor(context, scheduleInk),
                            ),
                          ),
                          SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                    color: completed
                                        ? growzaColor(context, _secondary)
                                        : growzaColor(context, scheduleInk),
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.45,
                                    color: growzaColor(context, _secondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing,
                        ],
                      ),
                      if (detail != null)
                        Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: 26,
                            end: 12,
                          ),
                          child: detail,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
