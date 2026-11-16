import 'dart:async';
import 'dart:convert';

import 'package:enough_icalendar/enough_icalendar.dart' as ical;
import 'package:http/http.dart' as http;
import 'package:rrule/rrule.dart';
import 'package:timezone/timezone.dart' as tz;

import 'calendar_data.dart';

Uri calendarUri(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      !['https', 'webcal'].contains(uri.scheme) ||
      uri.userInfo.isNotEmpty) {
    throw const CalendarImportException(
      'ألصق رابط اشتراك تقويم بصيغة HTTPS أو webcal.',
    );
  }
  return uri.replace(scheme: 'https').removeFragment();
}

class CalendarFeed {
  CalendarFeed({this._client});
  final http.Client? _client;
  Future<CalendarPreview> fetch(
    String link,
    CalendarKind kind,
    DateTime now,
  ) async {
    final client = _client ?? http.Client();
    try {
      return await _download(
        client,
        calendarUri(link),
        kind,
        now,
      ).timeout(const Duration(seconds: 25));
    } on CalendarImportException {
      rethrow;
    } on TimeoutException {
      throw const CalendarImportException(
        'استغرق خادم التقويم وقتاً طويلاً. حاول مجدداً.',
      );
    } catch (_) {
      throw const CalendarImportException(
        'تعذّر الوصول للتقويم. تحقّق من الاتصال ورابط الاشتراك.',
      );
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<CalendarPreview> _download(
    http.Client client,
    Uri uri,
    CalendarKind kind,
    DateTime now,
  ) async {
    final request = http.Request('GET', uri)
      ..headers['Accept'] = 'text/calendar, application/ics, text/plain'
      ..maxRedirects = 4;
    final response = await client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CalendarImportException(
        response.statusCode == 401 || response.statusCode == 403
            ? 'يتطلب الرابط تسجيل الدخول. انسخ رابط مشاركة التقويم من Blackboard.'
            : 'أعاد خادم التقويم خطأ. تحقّق من رابط المشاركة.',
      );
    }
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
      if (bytes.length > 4 * 1024 * 1024) {
        throw const CalendarImportException(
          'حجم التقويم أكبر من حد الاستيراد.',
        );
      }
    }
    final text = utf8
        .decode(bytes, allowMalformed: true)
        .replaceFirst('\uFEFF', '')
        .trim();
    if (!text.startsWith('BEGIN:VCALENDAR') ||
        !text.endsWith('END:VCALENDAR')) {
      throw const CalendarImportException(
        'هذا ليس رابط بيانات iCalendar. استخدم التقويم ← الإعدادات ← مشاركة التقويم في Blackboard.',
      );
    }
    return parseCalendar(text, kind, now);
  }
}

CalendarPreview parseCalendar(String text, CalendarKind kind, DateTime now) {
  late ical.VCalendar calendar;
  try {
    // The parser prints malformed lines. Keep private calendar data out of logs.
    calendar = runZoned(
      () => ical.VComponent.parse(text.trim()) as ical.VCalendar,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, message) {},
      ),
    );
  } catch (_) {
    throw const CalendarImportException(
      'تعذّرت قراءة بيانات التقويم. تحقّق من رابط الاشتراك.',
    );
  }
  final from = DateTime.utc(now.year, now.month, now.day - 7);
  final until = DateTime.utc(now.year + 1, now.month, now.day);
  final groups = <String, List<ical.VComponent>>{};
  var skipped = 0;
  for (final component in calendar.children) {
    if (component is! ical.VEvent && component is! ical.VTodo) continue;
    final uid = component['UID']?.textValue;
    if (uid == null || uid.isEmpty) {
      skipped++;
    } else {
      groups.putIfAbsent(uid, () => []).add(component);
    }
  }
  final items = <CalendarItem>[];
  for (final entry in groups.entries) {
    try {
      items.addAll(
        _expand(entry.key, entry.value, calendar.timezoneId, kind, from, until),
      );
      if (items.length > 4000) {
        throw const CalendarImportException(
          'عدد أحداث التقويم كبير جداً. جرّب تقويماً أصغر.',
        );
      }
    } on CalendarImportException {
      rethrow;
    } catch (_) {
      skipped += entry.value.length;
    }
  }
  items.sort((a, b) => a.start.compareTo(b.start));
  return CalendarPreview(
    calendar.calendarName ?? 'تقويم خارجي',
    items,
    skipped: skipped,
  );
}

List<CalendarItem> _expand(
  String uid,
  List<ical.VComponent> components,
  String? calendarZone,
  CalendarKind kind,
  DateTime from,
  DateTime until,
) {
  components.sort(
    (a, b) => (int.tryParse(a['SEQUENCE']?.textValue ?? '') ?? 0).compareTo(
      int.tryParse(b['SEQUENCE']?.textValue ?? '') ?? 0,
    ),
  );
  final main = components
      .where((item) => item['RECURRENCE-ID'] == null)
      .lastOrNull;
  final overrides = <DateTime, ical.VComponent>{};
  for (final item in components) {
    if (item['RECURRENCE-ID'] case final recurrence?) {
      overrides[_CalendarTime(recurrence, calendarZone).wall] = item;
    }
  }
  if (main == null) {
    return [
          for (final entry in overrides.entries)
            if (entry.value['STATUS']?.textValue != 'CANCELLED')
              _item(
                '$uid|${entry.key.toIso8601String()}',
                entry.value,
                calendarZone,
                kind,
              ),
        ]
        .where(
          (item) =>
              !item.start.toUtc().isBefore(from) &&
              item.start.toUtc().isBefore(until),
        )
        .toList();
  }
  if (main['STATUS']?.textValue == 'CANCELLED') return [];
  final startProperty = main['DTSTART'] ?? main['DUE'];
  if (startProperty == null) throw const FormatException('Missing date');
  final anchor = _CalendarTime(startProperty, calendarZone);
  final rule = main['RRULE']?.textValue;
  final additional = main.findProperties('RDATE').toList();
  final recurring = rule != null || additional.isNotEmpty;
  if (!recurring) {
    final item = _item(uid, main, calendarZone, kind);
    return item.isPast(from.toLocal()) || !item.start.toUtc().isBefore(until)
        ? []
        : [item];
  }
  final dates = <DateTime>{anchor.wall};
  if (rule != null &&
      anchor.wall.isBefore(until.add(const Duration(days: 3)))) {
    if (RegExp(r'FREQ=(SECONDLY|MINUTELY|HOURLY)').hasMatch(rule)) {
      throw const FormatException('Unsupported high frequency');
    }
    dates.addAll(
      RecurrenceRule.fromString('RRULE:$rule')
          .getInstances(
            start: anchor.wall,
            after: from.subtract(const Duration(days: 3)).isBefore(anchor.wall)
                ? anchor.wall
                : from.subtract(const Duration(days: 3)),
            before: until.add(const Duration(days: 3)),
            includeAfter: true,
          )
          .take(4001),
    );
  }
  for (final property in additional) {
    dates.addAll(_dateList(property, calendarZone));
  }
  for (final property in main.findProperties('EXDATE')) {
    dates.removeAll(_dateList(property, calendarZone));
  }
  if (dates.length > 4000) throw const FormatException('Too many occurrences');
  final result = <CalendarItem>[];
  for (final date in dates) {
    final override = overrides.remove(date);
    if (override?['STATUS']?.textValue == 'CANCELLED') continue;
    final item = _item(
      '$uid|${date.toIso8601String()}',
      override ?? main,
      calendarZone,
      kind,
      shift: override == null ? date.difference(anchor.wall) : Duration.zero,
    );
    if (!item.isPast(from.toLocal()) && item.start.toUtc().isBefore(until)) {
      result.add(item);
    }
  }
  for (final entry in overrides.entries) {
    if (entry.value['STATUS']?.textValue == 'CANCELLED') continue;
    final item = _item(
      '$uid|${entry.key.toIso8601String()}',
      entry.value,
      calendarZone,
      kind,
    );
    if (!item.isPast(from.toLocal()) && item.start.toUtc().isBefore(until)) {
      result.add(item);
    }
  }
  return result;
}

Iterable<DateTime> _dateList(ical.Property property, String? zone) =>
    property.textValue.split(',').map((value) {
      final parameters = property.definition.substring(
        0,
        property.definition.indexOf(':'),
      );
      return _CalendarTime(
        ical.DateTimeProperty('$parameters:$value'),
        zone,
      ).wall;
    });

CalendarItem _item(
  String uid,
  ical.VComponent component,
  String? zone,
  CalendarKind kind, {
  Duration shift = Duration.zero,
}) {
  final time = _CalendarTime(component['DUE'] ?? component['DTSTART']!, zone);
  String text(String name) => (component[name]?.textValue ?? '')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\N', '\n')
      .replaceAll(r'\,', ',')
      .replaceAll(r'\;', ';')
      .replaceAll(r'\\', '\\');
  final title = text('SUMMARY').trim();
  final start = time.instant(shift);
  DateTime? end;
  if (component['DTEND'] case final property?) {
    end = _CalendarTime(property, zone).instant(shift);
  } else if (component['DURATION'] case final property?) {
    end = start.add(ical.IsoDuration.parse(property.textValue).toDuration());
  } else if (time.dateOnly) {
    final wall = time.wall.add(shift);
    end = DateTime(wall.year, wall.month, wall.day + 1);
  }
  final hasDuration = end != null && end.isAfter(start);
  final looksLikeDeadline = RegExp(
    r'assignment|homework|assessment|quiz|exam|deadline|\bdue\b|واجب|اختبار|تسليم',
    caseSensitive: false,
  ).hasMatch(title);
  final deadline =
      component is ical.VTodo ||
      kind == CalendarKind.deadlines ||
      !hasDuration ||
      (kind == CalendarKind.mixed && (time.dateOnly || looksLikeDeadline));
  return CalendarItem(
    uid: uid,
    title: title.isEmpty ? 'عنصر تقويم بلا عنوان' : title,
    start: start,
    end: hasDuration ? end : null,
    dateOnly: time.dateOnly,
    deadline: deadline,
    description: text('DESCRIPTION'),
    location: text('LOCATION'),
    remoteDone: component['STATUS']?.textValue == 'COMPLETED',
  );
}

class _CalendarTime {
  _CalendarTime(ical.Property property, String? calendarZone)
    : dateOnly = property.textValue.length == 8 {
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$',
    ).firstMatch(property.textValue);
    if (match == null) throw const FormatException('Invalid calendar date');
    int number(int group) => int.parse(match.group(group) ?? '0');
    wall = DateTime.utc(
      number(1),
      number(2),
      number(3),
      number(4),
      number(5),
      number(6),
    );
    if (wall.month != number(2) ||
        wall.day != number(3) ||
        wall.hour != number(4) ||
        wall.minute != number(5)) {
      throw const FormatException('Invalid calendar date');
    }
    final id = property.parameters['TZID']?.textValue ?? calendarZone;
    floating = id == null && match.group(7) == null;
    if (match.group(7) != null) {
      location = tz.UTC;
    } else if (id == null || dateOnly) {
      location = tz.local;
    } else {
      final clean = id.replaceAll('"', '');
      final name = tz.timeZoneDatabase.locations.keys
          .where((name) => name == clean || clean.endsWith('/$name'))
          .firstOrNull;
      if (name == null) throw const FormatException('Unknown timezone');
      location = tz.getLocation(name);
    }
  }
  late final DateTime wall;
  late final tz.Location location;
  late final bool floating;
  final bool dateOnly;
  DateTime instant(Duration shift) {
    final date = wall.add(shift);
    if (dateOnly) return DateTime(date.year, date.month, date.day);
    if (floating) {
      return DateTime(
        date.year,
        date.month,
        date.day,
        date.hour,
        date.minute,
        date.second,
      );
    }
    return tz.TZDateTime(
      location,
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
      date.second,
    ).toLocal();
  }
}
