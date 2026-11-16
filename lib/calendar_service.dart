import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'calendar_data.dart';
import 'study_data.dart';
import 'study_storage.dart';
import 'exam_calendar.dart';
import 'calendar_feed.dart';
import 'calendar_notifications.dart';
import 'calendar_repository.dart';

Future<List<StudySubject>> loadExamSubjects() async =>
    (await const StudyStorage().load()).subjects;

Future<String> loadNotificationLanguage() async =>
    (await const StudyStorage().load()).languageCode ??
    (PlatformDispatcher.instance.locale.languageCode == 'ar' ? 'ar' : 'en');

const calendarSyncTask = 'com.example.istudy.calendarSync';

@pragma('vm:entry-point')
void calendarCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final engine = CalendarEngine(
      examLoader: loadExamSubjects,
      languageLoader: loadNotificationLanguage,
    );
    try {
      await engine.initialize();
      return await engine.refreshAll();
    } catch (_) {
      return false;
    } finally {
      await engine.repository.close();
    }
  });
}

class CalendarEngine {
  CalendarEngine({
    CalendarRepository? repository,
    CalendarFeed? feed,
    CalendarNotifications? notifications,
    DateTime Function()? now,
    this.examLoader,
    this.languageLoader,
  }) : repository = repository ?? CalendarRepository(),
       feed = feed ?? CalendarFeed(),
       notifications = notifications ?? CalendarNotifications(),
       now = now ?? DateTime.now;
  final CalendarRepository repository;
  final CalendarFeed feed;
  final CalendarNotifications notifications;
  final DateTime Function() now;
  String? reminderWarning;
  final Future<List<StudySubject>> Function()? examLoader;
  final Future<String> Function()? languageLoader;
  int examCount = 0;

  Future<void> updateReminders() async {
    try {
      notifications.languageCode = await languageLoader?.call() ?? 'ar';
      final subjects = await examLoader?.call() ?? <StudySubject>[];
      examCount = subjects.length;
      await notifications.reconcile(
        repository,
        now(),
        exams: examCalendarItems(
          subjects,
          languageCode: notifications.languageCode,
        ),
      );
      reminderWarning = null;
    } catch (_) {
      reminderWarning =
          'حُفظ التقويم، وتعذّرت جدولة بعض التنبيهات. حدّث للمحاولة مجدداً.';
    }
  }

  Future<void> initialize({VoidCallback? onOpen}) async {
    await repository.database;
    notifications.languageCode = await languageLoader?.call() ?? 'ar';
    await notifications.initialize(onOpen: onOpen);
  }

  Future<void> subscribe(
    String name,
    String link,
    CalendarKind kind,
    CalendarPreview preview, {
    bool reminders = true,
  }) => repository.withLock(() async {
    final uri = calendarUri(link).toString();
    final sources = await repository.sources();
    if (sources.any((source) => source.url == uri)) {
      throw const CalendarImportException('هذا التقويم مرتبط بالفعل.');
    }
    final id = await repository.addSource(
      name,
      uri,
      kind,
      reminders: reminders,
    );
    try {
      await repository.storePreview(id, preview, now());
    } catch (_) {
      await repository.removeSource(id);
      rethrow;
    }
    await updateReminders();
  });

  Future<bool> refreshAll() => repository.withLock(() async {
    var success = true;
    for (final source in await repository.sources()) {
      try {
        final preview = await feed.fetch(source.url, source.kind, now());
        final before = (await repository.items())
            .where((item) => item.sourceId == source.id)
            .toList();
        final known = before.map((item) => item.uid).toSet();
        final changes = await repository.storePreview(
          source.id,
          preview,
          now(),
        );
        final activeIds = (await repository.items())
            .where(
              (item) => item.sourceId == source.id && !item.completedAt(now()),
            )
            .map((item) => item.id)
            .toSet();
        for (final old in before) {
          if (!activeIds.contains(old.id)) {
            await notifications.cancel(old.id * 3);
          }
        }
        if (source.reminders && await repository.remindersEnabled()) {
          try {
            await notifications.showChanges(
              changes
                  .where(
                    (item) =>
                        !known.contains(item.uid) && !item.completedAt(now()),
                  )
                  .toList(),
              added: true,
            );
            await notifications.showChanges(
              changes
                  .where(
                    (item) =>
                        known.contains(item.uid) && !item.completedAt(now()),
                  )
                  .toList(),
              added: false,
            );
          } catch (_) {
            reminderWarning = 'حُدّث التقويم، وتعذّر إظهار تنبيه التغيير.';
          }
        }
      } on CalendarImportException catch (error) {
        await repository.syncError(source.id, error.message);
        success = false;
      } catch (_) {
        await repository.syncError(
          source.id,
          'تعذّر تحديث التقويم. حاول مجدداً.',
        );
        success = false;
      }
    }
    await updateReminders();
    return success;
  });

  Future<void> remove(int id) => repository.withLock(() async {
    final removed = (await repository.items()).where(
      (item) => item.sourceId == id,
    );
    for (final item in removed) {
      await notifications.cancel(item.id * 3);
    }
    await repository.removeSource(id);
    await updateReminders();
  });

  Future<void> markDone(CalendarItem item, bool done) =>
      repository.withLock(() async {
        await repository.markDone(item.id, done);
        await notifications.cancel(item.id * 3);
        await updateReminders();
      });

  Future<void> setReminders(bool enabled) => repository.withLock(() async {
    await repository.setRemindersEnabled(enabled);
    await updateReminders();
  });

  Future<void> setSourceReminders(int id, bool value) =>
      repository.withLock(() async {
        await repository.setSourceReminders(id, value);
        if (!value) {
          for (final item in (await repository.items()).where(
            (item) => item.sourceId == id,
          )) {
            await notifications.cancel(item.id * 3);
          }
        }
        await updateReminders();
      });
  Future<void> setDeadline(CalendarItem item, bool deadline) =>
      repository.withLock(() async {
        if (!deadline && (item.end == null || !item.end!.isAfter(item.start))) {
          throw const CalendarImportException(
            'تحتاج المحاضرة إلى وقتَي بدء ونهاية محددين.',
          );
        }
        await repository.setDeadline(item.id, deadline);
        await updateReminders();
      });
}

class CalendarService extends ChangeNotifier {
  CalendarService({this._engine, bool? supported, this.background = true})
    : supported =
          supported ??
          (!kIsWeb &&
              [
                TargetPlatform.android,
                TargetPlatform.iOS,
              ].contains(defaultTargetPlatform));
  CalendarEngine? _engine;
  CalendarEngine get engine => _engine ??= CalendarEngine(
    examLoader: loadExamSubjects,
    languageLoader: loadNotificationLanguage,
  );
  final bool supported;
  final bool background;
  bool loading = true;
  bool busy = false;
  bool enabled = false;
  bool permissionGranted = false;
  bool openSchedule = false;
  DateTime? openDate;
  bool _examsDirty = false;
  int get examCount => engine.examCount;
  String? error;
  String? backgroundError;
  List<CalendarSource> sources = [];
  List<CalendarItem> items = [];
  bool _disposed = false;
  bool _initialized = false;
  Timer? _refreshTimer;
  DateTime? _lastAttempt;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!supported) {
      loading = false;
      _notify();
      return;
    }
    try {
      await engine.initialize(
        onOpen: () {
          openDate = engine.notifications.openedDate;
          openSchedule = true;
          _notify();
        },
      );
      if (background) {
        try {
          await Workmanager().initialize(calendarCallbackDispatcher);
        } catch (_) {
          backgroundError = 'التحديث في الخلفية غير متاح. استخدم التحديث للبحث عن عناصر جديدة.';
        }
      }
      await _reload();
      await _backgroundTask();
      await engine.repository.withLock(engine.updateReminders);
      _refreshTimer ??= Timer.periodic(const Duration(minutes: 1), (_) {
        refreshIfNeeded();
      });
    } catch (_) {
      error = 'تعذّر فتح التقاويم الخارجية. حاول مجدداً.';
    } finally {
      loading = false;
      _notify();
    }
    if (_examsDirty) await syncExams();
    if (error == null) await refreshIfNeeded();
  }

  Future<void> _reload() async {
    sources = await engine.repository.sources();
    items = await engine.repository.items();
    enabled = await engine.repository.remindersEnabled();
    try {
      permissionGranted = await engine.notifications.permitted();
    } catch (_) {
      permissionGranted = false;
    }
  }

  Future<void> _backgroundTask() async {
    if (!background) return;
    try {
      if (sources.isEmpty) {
        await Workmanager().cancelByUniqueName(calendarSyncTask);
      } else {
        await Workmanager().registerPeriodicTask(
          calendarSyncTask,
          calendarSyncTask,
          frequency: const Duration(minutes: 15),
          initialDelay: const Duration(minutes: 15),
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        );
      }
      backgroundError = null;
    } catch (_) {
      backgroundError =
          'التحديث في الخلفية غير متاح. استخدم التحديث للبحث عن عناصر جديدة.';
    }
  }

  Future<bool> _run(Future<void> Function() operation) async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      await operation();
      await _reload();
      await _backgroundTask();
      return true;
    } on CalendarImportException catch (failure) {
      error = failure.message;
    } catch (_) {
      error = 'تعذّر تحديث التقاويم الخارجية. حاول مجدداً.';
    } finally {
      busy = false;
      _notify();
      if (_examsDirty) {
        _examsDirty = false;
        unawaited(syncExams());
      }
    }
    return false;
  }

  Future<void> syncExams() async {
    if (!supported || _disposed) return;
    if (loading || busy) {
      _examsDirty = true;
      return;
    }
    _examsDirty = false;
    await _run(() => engine.repository.withLock(engine.updateReminders));
  }

  Future<void> refreshIfNeeded() async {
    if (!supported || loading || busy || error != null) return;
    try {
      await _reload();
      await engine.repository.withLock(engine.updateReminders);
    } catch (_) {
      error = 'تعذّرت قراءة التقاويم المحفوظة. حاول مجدداً.';
      _notify();
      return;
    }
    _notify();
    final cutoff = engine.now().subtract(const Duration(minutes: 15));
    if (_lastAttempt != null && _lastAttempt!.isAfter(cutoff)) return;
    if (sources.any(
      (source) => source.lastSync == null || source.lastSync!.isBefore(cutoff),
    )) {
      await refresh();
    }
  }

  Future<bool> refresh() => _run(() async {
    _lastAttempt = engine.now();
    await engine.refreshAll();
  });
  Future<bool> subscribe(
    String name,
    String url,
    CalendarKind kind,
    CalendarPreview preview,
    bool reminders,
  ) => _run(() async {
    await engine.subscribe(name, url, kind, preview, reminders: reminders);
    if (reminders && (!enabled || !permissionGranted)) {
      var permitted = false;
      try {
        permitted = await engine.notifications.requestPermission();
      } catch (_) {
        engine.reminderWarning =
            'رُبط التقويم. فعّل التنبيهات من إعدادات الهاتف لاستقبالها.';
      }
      await engine.setReminders(permitted);
    }
  });
  Future<bool> remove(int id) => _run(() => engine.remove(id));
  Future<bool> markDone(CalendarItem item, bool done) =>
      _run(() => engine.markDone(item, done));
  Future<bool> setReminders(bool value) => _run(() async {
    final granted = !value || await engine.notifications.requestPermission();
    await engine.setReminders(value && granted);
  });
  Future<bool> setSourceReminders(int id, bool value) =>
      _run(() => engine.setSourceReminders(id, value));
  Future<bool> setDeadline(CalendarItem item, bool deadline) =>
      _run(() => engine.setDeadline(item, deadline));

  Future<void> retry() async {
    if (loading || busy) return;
    loading = true;
    error = null;
    _initialized = false;
    _notify();
    await initialize();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    super.dispose();
  }
}
