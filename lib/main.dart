import 'account_service.dart';
import 'backup_screen.dart';
import 'workspace_backup.dart';
import 'workspace_actions.dart';
import 'welcome_screen.dart';
import 'auth_screen.dart';
import 'growth_rules.dart';
import 'app_preferences.dart';
import 'study_recommendation.dart';
import 'ai_topics_screen.dart';
import 'pdf_topic_import.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'calendar_screen.dart';
import 'calendar_service.dart';

import 'focus_timer.dart';
import 'focus_record.dart';
import 'growth_ledger.dart';
import 'session_completion.dart';
import 'exam_editor.dart';
import 'home_view.dart';
import 'plan_review.dart';
import 'session_editor.dart';
import 'schedule_view.dart';
import 'study_data.dart';
import 'study_garden.dart';
import 'study_planner.dart';
import 'study_storage.dart';
import 'study_ui.dart';
import 'app_appearance.dart';
import 'subject_setup.dart';
import 'subject_details.dart';
import 'plant_visual.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Noto Naskh Arabic',
    ], await rootBundle.loadString('assets/fonts/OFL-NotoNaskhArabic.txt'));
  });
  runApp(GrowzaApp(storage: StudyStorage(), calendars: CalendarService()));
}

class GrowzaApp extends StatefulWidget {
  const GrowzaApp({
    super.key,
    this.timerNow,
    this.storage,
    this.calendars,
    this.showWelcome = true,
    this.accounts,
  });

  final DateTime Function()? timerNow;
  final StudyStorage? storage;
  final CalendarService? calendars;
  final bool showWelcome;
  final AccountService? accounts;

  @override
  State<GrowzaApp> createState() => _GrowzaAppState();
}

class _GrowzaAppState extends State<GrowzaApp> {
  ThemeMode _themeMode = ThemeMode.system;
  String? _languageCode = 'ar';
  final _homeKey = GlobalKey<_StudyHomeState>();
  final _navigatorKey = GlobalKey<NavigatorState>();
  String? _accountId;
  late bool _welcome = widget.showWelcome;
  late final AccountService _accounts = widget.accounts ?? AccountService();
  @override
  void initState() {
    super.initState();
    _accountId = _accounts.session?.userId;
    _accounts.addListener(_accountChanged);
    _accounts.restore().then((_) {
      if (mounted && _accounts.session != null) {
        setState(() => _welcome = false);
      }
    });
  }

  @override
  void dispose() {
    _accounts.removeListener(_accountChanged);
    if (widget.accounts == null) _accounts.dispose();
    super.dispose();
  }

  void _accountChanged() {
    final id = _accounts.session?.userId;
    final signedOut = _accountId != null && id == null;
    _accountId = id;
    if (mounted && signedOut) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      setState(() => _welcome = true);
    }
  }

  void _continueGuest() => setState(() => _welcome = false);
  Future<void> _openEntry(BuildContext context, bool create) async {
    await Navigator.of(context).push(
      GrowzaRoute(
        builder: (routeContext) => AuthScreen(
          createAccount: create,
          onAuthenticated: () {
            Navigator.of(routeContext).pop();
            _continueGuest();
          },
          onGuest: () {
            Navigator.of(routeContext).pop();
            _continueGuest();
          },
        ),
      ),
    );
  }

  void _languageChanged(String? code) => setState(() => _languageCode = code);
  void _appearanceChanged(bool? dark) => setState(
    () => _themeMode = dark == null
        ? ThemeMode.system
        : dark
        ? ThemeMode.dark
        : ThemeMode.light,
  );
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Growza',
    navigatorKey: _navigatorKey,
    locale: _languageCode == null
        ? null
        : Locale(_languageCode!, _languageCode == 'ar' ? 'SA' : 'US'),
    supportedLocales: const [Locale('ar', 'SA'), Locale('en', 'US')],
    localeResolutionCallback: (locale, supported) =>
        locale?.languageCode == 'ar'
        ? const Locale('ar', 'SA')
        : const Locale('en', 'US'),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    debugShowCheckedModeBanner: false,
    theme: buildGrowzaTheme(),
    darkTheme: buildGrowzaTheme(brightness: Brightness.dark),
    themeMode: _themeMode,
    builder: (context, child) => AnnotatedRegion(
      value: growzaSystemBarsFor(Theme.of(context).brightness),
      child: AccountScope(
        service: _accounts,
        child: GrowzaPreferences(
          languageCode: _languageCode,
          themeMode: _themeMode,
          onLanguage: (value) => _homeKey.currentState?._changeLanguage(value),
          onTheme: (value) => _homeKey.currentState?._changeTheme(value),
          child: WorkspaceActions(
            onBackup: () => _homeKey.currentState?._openBackup(),
            child: child!,
          ),
        ),
      ),
    ),
    home: Builder(
      builder: (context) => Stack(
        children: [
          Offstage(
            offstage: _welcome,
            child: TickerMode(
              enabled: !_welcome,
              child: _StudyHome(
                key: _homeKey,
                onLanguageChanged: _languageChanged,
                timerNow: widget.timerNow,
                storage: widget.storage,
                calendars: widget.calendars,
                onAppearanceChanged: _appearanceChanged,
              ),
            ),
          ),
          if (_welcome)
            WelcomeScreen(
              onSignIn: () => _openEntry(context, false),
              onCreate: () => _openEntry(context, true),
              onGuest: _continueGuest,
            ),
        ],
      ),
    ),
  );
}

class _StudyHome extends StatefulWidget {
  const _StudyHome({
    super.key,
    required this.onLanguageChanged,
    this.timerNow,
    this.storage,
    this.calendars,
    required this.onAppearanceChanged,
  });

  final DateTime Function()? timerNow;
  final StudyStorage? storage;
  final ValueChanged<bool?> onAppearanceChanged;
  final ValueChanged<String?> onLanguageChanged;
  final CalendarService? calendars;

  @override
  State<_StudyHome> createState() => _StudyHomeState();
}

enum _SessionAction { edit, delete, toggleFixed }

enum _SubjectAction { edit, exam, viewExam, reminders, aiTopics, delete }

enum _PartAction { edit, delete }

class _StudyHomeState extends State<_StudyHome> {
  Future<void> _suggestTopics(StudySubject subject) async {
    final topics = await showAiTopics(
      context,
      subject: subject.name,
      pdfName: subject.pdfName,
      existingTitles: subject.parts.map((p) => p.title).toList(),
    );
    if (!mounted || topics == null || !topics.hasTopics) return;
    final index = _workspace.subjects.indexWhere((s) => s.id == subject.id);
    if (index < 0) return;
    final current = _workspace.subjects[index];
    setState(
      () => _workspace.subjects[index] = appendPdfTopics(current, topics),
    );
    _save();
  }

  StudyWorkspace _workspace = StudyWorkspace();
  Future<void> _saveQueue = Future.value();
  late bool _loading = widget.storage != null;
  bool _loadFailed = false;
  late final AppLifecycleListener _lifecycle;
  Timer? _dateRefresh;
  FocusTimer? _timer;
  StudySession? _timerSession;
  String? _lastTimerKey;
  int _tab = 0;
  DateTime? _scheduleDay;
  String? _studySelection;
  String? _homeSelectionId;
  final _subjectSearch = TextEditingController();

  DateTime _now() => widget.timerNow?.call() ?? DateTime.now();
  List<StudySubject> get _subjects => _workspace.subjects;
  List<StudySession> get _sessions =>
      [..._workspace.sessions]..sort((a, b) => a.start.compareTo(b.start));
  List<StudyTask> get _tasks => pendingTasks(_subjects);
  List<StudyBlock> get _calendarBlocks => [
    for (final item in widget.calendars?.items ?? [])
      if (!item.deadline && !item.completedAt(_now()) && item.end != null)
        (start: item.start, end: item.end!),
  ];

  bool _conflictsWithCalendar(StudySession session) => _calendarBlocks.any(
    (block) =>
        session.start.isBefore(block.end) &&
        block.start.isBefore(session.endWithBreak),
  );

  void _calendarsChanged() {
    if (!mounted) return;
    setState(() {
      if (widget.calendars!.openSchedule) {
        _tab = 2;
        _scheduleDay = widget.calendars!.openDate ?? DateUtils.dateOnly(_now());
        widget.calendars!.openDate = null;
        widget.calendars!.openSchedule = false;
      }
    });
  }

  Future<void> _openCalendars() => Navigator.push<void>(
    context,
    GrowzaRoute(
      builder: (context) =>
          ExternalCalendarsScreen(service: widget.calendars!, now: _now),
    ),
  );

  Future<void> _addToSchedule() async {
    final calendars = widget.calendars;
    if (calendars == null) {
      await _editSession();
      return;
    }
    final external = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_task_rounded),
                title: Text(tr(context, 'إضافة جلسة مذاكرة')),
                onTap: () => Navigator.pop(context, false),
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: Text(tr(context, 'إضافة جدول خارجي (اختياري)')),
                subtitle: Text(
                  tr(context, 'ألصق رابط مشاركة التقويم من Blackboard.'),
                ),
                onTap: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (!mounted || external == null) return;
    if (!external) {
      await _editSession();
      return;
    }
    await Navigator.push<void>(
      context,
      GrowzaRoute(
        builder: (_) => CalendarImportScreen(service: calendars, now: _now),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _dateRefresh = Timer.periodic(Duration(minutes: 1), (_) {
      if (mounted && _tab == 0) setState(() {});
    });
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _timer?.refresh();
        setState(() {});
        widget.calendars?.refreshIfNeeded();
      },
    );
    if (widget.storage != null) _load();
    widget.calendars?.addListener(_calendarsChanged);
    widget.calendars?.initialize();
  }

  Future<void> _load() async {
    try {
      final workspace = await widget.storage!.load();
      if (!mounted) return;
      setState(() {
        _workspace = workspace;
        final saved = workspace.activeTimer;
        if (saved != null) {
          try {
            _timerSession = saved['session'] == null
                ? null
                : StudySession.fromJson(
                    Map<String, dynamic>.from(saved['session'] as Map),
                  );
            _timer = FocusTimer.restore(
              Map<String, dynamic>.from(saved['timer'] as Map),
              onFocusCompleted: () {},
              onFocusRecorded: _recordFocus,
              subjectId: _subjects
                  .where((s) => s.name == _timerSession?.subject)
                  .firstOrNull
                  ?.id,
              now: widget.timerNow,
            );
            _timer!.addListener(_timerChanged);
          } catch (_) {
            _timer?.dispose();
            _timer = null;
            _timerSession = null;
            workspace.activeTimer = null;
          }
        }
        _loading = false;
        _loadFailed = false;
      });
      widget.onAppearanceChanged(workspace.darkMode);
      widget.onLanguageChanged(workspace.languageCode);
      _timer?.refresh();
      _save();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  void _openBackup() {
    Navigator.of(context).push(
      GrowzaRoute(
        builder: (_) => BackupScreen(
          snapshot: () async {
            if (_loading || _loadFailed) {
              throw StateError('Workspace not available');
            }
            _save();
            await _saveQueue;
            final result = const StudyStorage().decode(
              const StudyStorage().encode(_workspace),
            );
            if (widget.calendars case final calendars?) {
              if (calendars.supported) {
                result.backupCalendars = await calendars.engine.repository
                    .backupSnapshot();
              }
            }
            return result;
          },
          canImport: () =>
              !(_timer?.hasProgress ?? false) &&
              widget.calendars?.busy != true &&
              !_loading &&
              !_loadFailed,
          onApply: (workspace) async {
            if (workspace.backupCalendars != null &&
                widget.calendars?.supported != true) {
              throw const BackupException(
                'التقاويم غير متاحة على هذا الجهاز. لم تتغير بياناتك.',
              );
            }
            if (_timer?.hasProgress == true) {
              throw StateError('Timer is active');
            }
            await _saveQueue;
            Future<void> apply() async {
              final storage = widget.storage;
              final original = storage?.encode(_workspace);
              if (storage != null) {
                await storage.save(storage.encode(workspace));
              }
              try {
                if (workspace.backupCalendars case final data?) {
                  await widget.calendars?.engine.repository.restoreBackup(
                    data,
                    replace: workspace.backupReplaceCalendars,
                  );
                }
              } catch (_) {
                if (storage != null && original != null) {
                  await storage.save(original);
                }
                rethrow;
              }
            }

            final calendars = widget.calendars;
            if (calendars != null && calendars.supported) {
              await calendars.engine.repository.withLock(apply);
            } else {
              await apply();
            }
            if (!mounted) return;
            _timer?.dispose();
            _timer = null;
            _timerSession = null;
            _lastTimerKey = null;
            setState(() {
              _workspace = workspace;
              _homeSelectionId = null;
              _studySelection = null;
              _tab = 0;
            });
            if (widget.storage != null) await _load();
            await widget.calendars?.syncExams();
            if (!mounted) return;
            widget.onAppearanceChanged(workspace.darkMode);
            widget.onLanguageChanged(workspace.languageCode);
          },
        ),
      ),
    );
  }

  void _changeLanguage(String? code) {
    if (code != null && code != 'ar' && code != 'en') return;
    _workspace.languageCode = code;
    widget.onLanguageChanged(code);
    _save();
  }

  void _changeTheme(bool? dark) {
    _workspace.darkMode = dark;
    widget.onAppearanceChanged(dark);
    _save();
  }

  void _save() {
    final storage = widget.storage;
    if (storage == null || _loading || _loadFailed) return;
    _workspace.activeTimer =
        _timer == null ||
            _timer!.phase == TimerPhase.finished ||
            !_timer!.hasProgress
        ? null
        : {'timer': _timer!.toJson(), 'session': _timerSession?.toJson()};
    final snapshot = storage.encode(_workspace);
    _saveQueue = _saveQueue.then((_) async {
      try {
        await storage.save(snapshot);
        if (mounted) await widget.calendars?.syncExams();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, "تعذّر حفظ التغييرات على هذا الجهاز.")),
            action: SnackBarAction(
              label: tr(context, "إعادة المحاولة"),
              onPressed: _save,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    widget.calendars?.removeListener(_calendarsChanged);
    _lifecycle.dispose();
    _dateRefresh?.cancel();
    _subjectSearch.dispose();
    _timer?.dispose();
    super.dispose();
  }

  StudyTask? _taskFor(PartKey? key) {
    if (key == null) return null;
    final subject = _subjects.where((s) => s.name == key.subject).firstOrNull;
    final part = subject?.parts.where((part) => part.id == key.id).firstOrNull;
    return subject == null || part == null
        ? null
        : (subject: subject, part: part);
  }

  Future<void> _focusTask(StudyTask task) {
    return _focus(
      session: StudySession(
        task.subject.name,
        task.part.title,
        _now(),
        task.part.minutes,
        partId: task.part.id,
      ),
    );
  }

  Future<void> _focus({StudySession? session}) async {
    if (_pendingReview != null && !await _reviewPending()) return;
    if (!mounted) return;
    _timer?.refresh();
    if ((_timer?.hasProgress ?? false) &&
        (_timer?.phase == TimerPhase.focus || _timer!.isRunning)) {
      if (_timerSession == session ||
          (session?.partKey != null &&
              _timerSession?.partKey == session?.partKey &&
              _timer?.phase == TimerPhase.focus)) {
        _openTimer();
        return;
      }
      final replace = await _confirm(
        tr(context, "تغيير الجلسة؟"),
        tr(context, "بدء مؤقت جديد سينهي جلسة التركيز أو الاستراحة الحالية."),
        tr(context, "تغيير الجلسة"),
      );
      if (!mounted || !replace) return;
    }
    _timer?.finishFocus();
    if (_pendingReview != null && !await _reviewPending()) return;
    if (!mounted) return;
    _timer?.dispose();
    setState(() {
      _homeSelectionId = null;
      _timerSession = session;
      _timer = FocusTimer(
        focusLength: Duration(minutes: session?.minutes ?? 25),
        now: widget.timerNow,
        onFocusCompleted: () {},
        onFocusRecorded: _recordFocus,
        subjectId: _subjects
            .where((s) => s.name == session?.subject)
            .firstOrNull
            ?.id,
      );
    });
    _timer!.addListener(_timerChanged);
    _lastTimerKey = null;
    _timer!.toggle();
    _save();
    await _openTimer();
  }

  void _recordFocus(FocusRecord record) {
    if (!_workspace.growth.add(record)) return;
    setState(() {
      if (record.subjectId != null) _workspace.pendingFocusReviewId = record.id;
      if (record.completed) _workspace.focusCount++;
      final active = _timerSession;
      if (record.completed && active != null && !active.completed) {
        if (active.partKey case final key?) {
          _workspace.sessions.removeWhere(
            (session) => session.partKey == key && !session.completed,
          );
        } else {
          _workspace.sessions.remove(active);
        }
        final completed = active.copyWith(completed: true);
        _workspace.sessions.add(completed);
        _timerSession = completed;
      }
    });
    _save();
  }

  void _timerChanged() {
    if (!mounted) return;
    _rememberStudiedSubject();
    final key = _timer?.persistenceKey;
    if (key != _lastTimerKey) {
      _lastTimerKey = key;
      _save();
    }
  }

  FocusRecord? get _pendingReview => _workspace.growth.records
      .where((r) => r.id == _workspace.pendingFocusReviewId)
      .firstOrNull;

  GrowthLedger _previewLedger() {
    final ledger = GrowthLedger(_workspace.growth.records);
    final draft = _timer?.previewRecord();
    if (draft != null) ledger.add(draft);
    return ledger;
  }

  Future<bool> _reviewPending() async {
    final record = _pendingReview;
    if (record == null) return true;
    final subject = _subjects
        .where((s) => s.id == record.subjectId)
        .firstOrNull;
    if (subject == null) {
      _workspace.pendingFocusReviewId = null;
      _save();
      return true;
    }
    final before = GrowthLedger(
      _workspace.growth.records.where((r) => r.id != record.id),
    );
    final review = await Navigator.push<FocusReview>(
      context,
      GrowzaRoute(
        builder: (_) => SessionCompletionScreen(
          subject: subject,
          record: record,
          before: before.forSubject(
            subject.id,
            now: _now(),
            exam: subject.exam,
            completedTopics: subject.completedCount,
            totalTopics: subject.parts.length,
            target: _workspace.targetFor(subject),
          ),
          after: _workspace.growthFor(subject, _now()),
          growthForQuality: (quality) =>
              GrowthLedger([
                ..._workspace.growth.records.where((r) => r.id != record.id),
                record.withQuality(quality),
              ]).forSubject(
                subject.id,
                now: _now(),
                exam: subject.exam,
                completedTopics: subject.completedCount,
                totalTopics: subject.parts.length,
                target: _workspace.targetFor(subject),
              ),
          notice: _workspace.growth.forDay(_now()).message,
        ),
      ),
    );
    if (!mounted || review == null) return false;
    final selected = review.topics;
    setState(() {
      _workspace.growth.setQuality(record.id, review.quality);
      final index = _subjects.indexWhere((s) => s.id == subject.id);
      if (index >= 0) {
        final current = _subjects[index];
        _subjects[index] = current.withParts([
          for (final p in current.parts)
            selected.contains(p.id) ? p.markComplete() : p,
        ]);
        _workspace.sessions.removeWhere(
          (session) =>
              !session.completed &&
              session.subject == current.name &&
              selected.contains(session.partId),
        );
      }
      _workspace.pendingFocusReviewId = null;
    });
    _save();
    return true;
  }

  Future<void> _openTimer() async {
    if (_pendingReview != null && !await _reviewPending()) return;
    if (!mounted || _timer == null) return;
    final timer = _timer!;
    if (timer.phase == TimerPhase.focus &&
        !timer.isRunning &&
        timer.hasProgress) {
      timer.toggle();
    }
    final session = _timerSession;
    final subject = _subjects.where((s) => s.id == timer.subjectId).firstOrNull;
    final result = await Navigator.push<FocusRecord>(
      context,
      GrowzaRoute(
        builder: (_) => FocusScreen(
          timer: timer,
          subject: subjectLabel(
            subject?.name ?? session?.subject ?? 'General study',
            context: context,
          ),
          topic: _taskFor(session?.partKey)?.part.title ?? session?.topic ?? '',
          returnOnFocusEnd: true,
          growth: subject == null
              ? null
              : () => _previewLedger().forSubject(
                  subject.id,
                  now: _now(),
                  exam: subject.exam,
                  completedTopics: subject.completedCount,
                  totalTopics: subject.parts.length,
                  target: _workspace.targetFor(subject),
                  isFocusing: timer.isRunning,
                ),
          notice: () => _previewLedger().forDay(_now()).message,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null && _pendingReview != null) {
      final reviewed = await _reviewPending();
      if (mounted &&
          reviewed &&
          identical(timer, _timer) &&
          timer.phase == TimerPhase.rest) {
        await _openTimer();
      }
    }
  }

  Future<bool> _confirm(String title, String message, String action) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr(context, "إلغاء")),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _editSession([StudySession? session]) async {
    if (session != null && _isActive(session)) {
      _showMessage(tr(context, "أنهِ جلسة التركيز الحالية أولاً."));
      return;
    }
    final edited = await Navigator.push<StudySession>(
      context,
      GrowzaRoute(
        builder: (context) => SessionEditor(
          session: session,
          subjects: _subjects,
          occupied: _sessions.where((item) => item != session).toList(),
          task: _taskFor(session?.partKey),
          now: _now(),
          initialDate: _tab == 2 ? _scheduleDay : null,
          blocked: _calendarBlocks,
        ),
      ),
    );
    if (!mounted || edited == null) return;
    if (!edited.completed && _conflictsWithCalendar(edited)) {
      _showMessage(
        tr(context, "يتعارض الوقت مع محاضرة مستوردة. اختر وقتاً آخر."),
      );
      return;
    }
    setState(() {
      _scheduleDay = DateUtils.dateOnly(edited.start);
      if (session == null) {
        _workspace.sessions.add(edited);
      } else {
        _workspace.sessions[_workspace.sessions.indexOf(session)] = edited;
      }
    });
    _save();
  }

  bool _isActive(StudySession session) =>
      _timer?.phase == TimerPhase.focus &&
      (_timer?.hasProgress ?? false) &&
      (_timerSession == session ||
          (session.partKey != null &&
              _timerSession?.partKey == session.partKey));

  Future<void> _deleteSession(StudySession session) async {
    if (_isActive(session)) {
      _showMessage(tr(context, "أنهِ جلسة التركيز الحالية أولاً."));
      return;
    }
    final confirmed = await _confirm(
      tr(context, "حذف الجلسة؟"),
      tr(context, "حذف «{0}» من جدولك؟", [session.topic]),
      tr(context, "حذف الجلسة"),
    );
    if (!mounted || !confirmed) return;
    setState(() => _workspace.sessions.remove(session));
    _save();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _editPart({
    StudySubject? subject,
    StudyTask? task,
    bool remainingTime = false,
  }) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _timer?.refresh();
    if (task != null &&
        _timerSession?.partKey == task.key &&
        _timer?.phase == TimerPhase.focus &&
        (_timer?.hasProgress ?? false)) {
      _showMessage(tr(context, "أنهِ جلسة هذا الموضوع قبل تعديله."));
      return false;
    }
    subject = task?.subject ?? subject;
    final result = await Navigator.push<StudySubject>(
      context,
      GrowzaRoute(
        builder: (context) => SubjectSetup(
          now: _now,
          subject: subject,
          part: task?.part,
          remainingTime: remainingTime,
          existingNames: _subjects
              .map((subject) => subject.name.toLowerCase())
              .toList(),
        ),
      ),
    );
    if (!mounted || result == null) return false;
    setState(() {
      if (subject == null) {
        _subjects.add(result);
        _tab = 0;
      } else {
        _subjects[_subjects.indexOf(subject)] = result;
        if (task != null) {
          final updatedPart = result.parts.firstWhere(
            (part) => part.id == task.part.id,
          );
          for (final (index, session) in _workspace.sessions.indexed) {
            if (!session.completed &&
                session.partKey == task.key &&
                session.topic != updatedPart.title) {
              _workspace.sessions[index] = session.copyWith(
                topic: updatedPart.title,
              );
            }
          }
        }
      }
    });
    _save();
    if (subject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(context, "حُفظت المادة وأُضيف الاختبار إلى جدولك.")),
          action: SnackBarAction(
            label: tr(context, "عرض الاختبار"),
            onPressed: () => setState(() {
              _scheduleDay = DateUtils.dateOnly(result.exam);
              _tab = 2;
            }),
          ),
        ),
      );
    }
    return true;
  }

  void _finishPart(PartKey key) {
    final task = _taskFor(key);
    if (task == null || task.part.completed) return;
    setState(() {
      _subjects[_subjects.indexOf(task.subject)] = task.subject.withParts([
        for (final part in task.subject.parts)
          part.id == key.id ? part.markComplete() : part,
      ]);
      _workspace.sessions.removeWhere(
        (session) => session.partKey == key && !session.completed,
      );
    });
    _save();
  }

  Future<void> _adjustPlan() async {
    _timer?.refresh();
    if (_timerSession?.partKey != null && _isActive(_timerSession!)) {
      _showMessage(tr(context, "أنهِ جلسة التركيز الحالية أولاً."));
      return;
    }
    final plan = await Navigator.push<StudyPlan>(
      context,
      GrowzaRoute(
        builder: (context) => PlanReview(
          tasks: _tasks,
          sessions: _sessions,
          now: _now,
          blocked: _calendarBlocks,
        ),
      ),
    );
    if (!mounted || plan == null) return;
    if (plan.scheduled.any(_conflictsWithCalendar)) {
      _showMessage(
        tr(context, "تغيّر موعد محاضرة مستوردة. راجع وقت المذاكرة."),
      );
      return;
    }
    setState(() {
      _workspace.sessions
        ..removeWhere(plan.replaced.values.contains)
        ..addAll(plan.scheduled);
      _tab = 2;
      _scheduleDay = plan.scheduled.firstOrNull?.start ?? _now();
    });
    _save();
    _showMessage(tr(context, "حُدّثت خطة المذاكرة."));
  }

  void _toggleFixed(StudySession session) {
    if (_isActive(session)) {
      _showMessage(tr(context, "أنهِ جلسة التركيز الحالية أولاً."));
      return;
    }
    setState(() {
      _workspace.sessions[_workspace.sessions.indexOf(session)] = session
          .copyWith(fixed: !session.fixed);
    });
    _save();
  }

  List<StudySubject> get _activeSubjects => _subjects
      .where((s) => !_workspace.growthFor(s, _now()).harvested)
      .toList();

  List<StudySubject> get _studiedSubjects => _workspace.recentSubjects
      .map(
        (name) => _activeSubjects
            .where((subject) => subject.name == name)
            .firstOrNull,
      )
      .whereType<StudySubject>()
      .toList();

  List<StudySubject> get _recentSubjects {
    final names = <String>{};
    return [
      for (final subject in [..._studiedSubjects, ..._activeSubjects.reversed])
        if (names.add(subject.name)) subject,
    ].take(3).toList();
  }

  StudySubject? get _recommendedSubject =>
      recommendSubject(_activeSubjects, _workspace.recentSubjects, _now());
  StudySubject? get _homeSubject =>
      _activeSubjects.where((s) => s.id == _homeSelectionId).firstOrNull ??
      (_timer?.hasProgress == true
          ? _activeSubjects.where((s) => s.id == _timer?.subjectId).firstOrNull
          : null) ??
      _recommendedSubject;

  Future<void> _startSubject(StudySubject subject) => _focus(
    session: StudySession(
      subject.name,
      subject.nextPart?.title ?? 'مراجعة',
      _now(),
      subject.nextPart?.minutes ?? 25,
      partId: subject.nextPart?.id,
    ),
  );

  void _rememberStudiedSubject() {
    if (_timer?.phase != TimerPhase.focus || !(_timer?.isRunning ?? false)) {
      return;
    }
    final name = _timerSession?.subject;
    if (name == null ||
        !_subjects.any((subject) => subject.name == name) ||
        _workspace.recentSubjects.firstOrNull == name) {
      return;
    }
    setState(() {
      _workspace.recentSubjects
        ..remove(name)
        ..insert(0, name);
    });
    _save();
  }

  void _openSubject(StudySubject subject) => setState(() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _studySelection = subject.name;
    _tab = 1;
  });

  void _allSubjects() => setState(() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _studySelection = null;
    _subjectSearch.clear();
    _tab = 1;
  });

  Widget _homeTimerAction() {
    final timer = _timer;
    final subject = _homeSubject;
    final switching =
        _homeSelectionId != null && _homeSelectionId != timer?.subjectId;
    final resume =
        !switching &&
        timer?.hasProgress == true &&
        (timer?.phase == TimerPhase.focus || timer!.isRunning);
    return StudyButton(
      _pendingReview != null
          ? tr(context, "مراجعة الجلسة")
          : resume
          ? tr(context, "متابعة المؤقت")
          : subject?.nextPart != null
          ? tr(context, 'ابدأ: {0} · {1}', [
              subject!.name,
              subject.nextPart!.title,
            ])
          : tr(context, "ابدأ المذاكرة"),
      _pendingReview != null || resume
          ? _openTimer
          : subject == null
          ? null
          : () => _startSubject(subject),
      key: ValueKey('home-start-study'),
    );
  }

  List<Widget> _homeScreen() => [
    StudyHeader(),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: PageHeading(
            tr(context, "مستعد للمذاكرة؟"),
            tr(context, "أكمل من حيث توقفت."),
            size: 26,
          ),
        ),
        if (_tasks.isNotEmpty)
          TextButton(
            onPressed: _adjustPlan,
            child: Text(tr(context, "تغيّر وقتك؟")),
          ),
      ],
    ),
    HomeProgressCard(
      subject: _homeSubject,
      growth: _homeSubject == null
          ? null
          : _workspace.growthFor(
              _homeSubject!,
              _now(),
              isFocusing:
                  _timer?.subjectId == _homeSubject!.id &&
                  _timer?.isRunning == true &&
                  _timer?.phase == TimerPhase.focus,
            ),
      onPreview: () => showGrowthPreview(
        context,
        subjectName: _homeSubject?.name,
        target: _homeSubject == null
            ? GrowthRules.fallbackTarget
            : _workspace.targetFor(_homeSubject!),
        noTopics: _homeSubject?.parts.isEmpty == true,
      ),
      now: _now(),
      hasSubjects: _subjects.isNotEmpty,
      recommended:
          _homeSelectionId == null &&
          _timer?.hasProgress != true &&
          _homeSubject?.nextPart != null &&
          _homeSubject?.id == _recommendedSubject?.id,
      wasStudied:
          _homeSelectionId == null &&
          _workspace.recentSubjects.firstOrNull == _homeSubject?.name,
      nextPart: _homeSubject?.nextPart,
      onOpen: () => _openSubject(_homeSubject!),
      onAdd: _editPart,
    ),
    if (_subjects.isNotEmpty) ...[
      if (_activeSubjects.isNotEmpty ||
          _pendingReview != null ||
          (_timer?.hasProgress == true &&
              _timer?.phase == TimerPhase.focus)) ...[
        if (_timer case final timer?)
          ListenableBuilder(
            listenable: timer,
            builder: (context, _) => _homeTimerAction(),
          )
        else
          _homeTimerAction(),
      ],
      if (_workspace.growth.currentStreak(_now()) > 0)
        Text(
          tr(context, 'سلسلة التركيز (أيام): {0}', [
            _workspace.growth.currentStreak(_now()),
          ]),
          key: const ValueKey('focus-streak'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: GrowzaPalette.of(context).secondaryText,
            fontSize: 13,
          ),
        ),
      if (_activeSubjects.isNotEmpty)
        HomeSubjects(
          subjects: _activeSubjects,
          growthFor: (s) => _workspace.growthFor(s, _now()),
          recentSubjects: _recentSubjects,
          studiedNames: _workspace.recentSubjects,
          selectedId: _homeSubject?.id,
          onOpen: (subject) => setState(() => _homeSelectionId = subject.id),
          onViewAll: _allSubjects,
        ),
      StudyGarden(
        showActivePlants: false,
        compact: true,
        progress: [
          for (final subject in _subjects)
            (
              id: subject.id,
              subject: subject.name,
              completed: subject.completedCount,
              total: subject.parts.length,
              growth: _workspace.growthFor(
                subject,
                _now(),
                isFocusing:
                    _timer?.subjectId == subject.id &&
                    _timer?.isRunning == true &&
                    _timer?.phase == TimerPhase.focus,
              ),
            ),
        ],
        onAddSubject: _editPart,
      ),
    ],
  ];

  List<Widget> _studyScreen(BuildContext context) => [
    StudyHeader(),
    PageHeading(
      _studySelection ?? tr(context, "موادك"),
      tr(context, "تابع مواضيع المذاكرة لكل اختبار."),
      eyebrow: tr(context, "كل موادك في مكان واحد"),
    ),
    if (_studySelection != null)
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: _allSubjects,
          icon: Icon(Icons.arrow_back_rounded, size: 17),
          label: Text(tr(context, "كل المواد")),
        ),
      ),
    StudyButton(tr(context, "أضف مادة"), _editPart),
    if (_subjects.isNotEmpty && _studySelection == null)
      TextField(
        controller: _subjectSearch,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: tr(context, "ابحث عن مادة أو موضوع"),
          prefixIcon: Icon(Icons.search_rounded),
          suffixIcon: _subjectSearch.text.isEmpty
              ? null
              : IconButton(
                  tooltip: tr(context, "مسح البحث"),
                  onPressed: () => setState(_subjectSearch.clear),
                  icon: Icon(Icons.close_rounded),
                ),
        ),
      ),
    if (_subjects.isNotEmpty && _visibleSubjects.isEmpty)
      Text(tr(context, "لا توجد مواد تطابق بحثك.")),
    if (_subjects.isEmpty)
      Panel(child: Text(tr(context, "ستظهر موادك ومواضيع المذاكرة هنا."))),
    for (final subject in _visibleSubjects)
      Padding(
        key: ValueKey('study-subject-${subject.name}'),
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Row(
              children: [
                PlantThumbnail(
                  stage: _workspace.growthFor(subject, _now()).stage,
                  progress: _workspace.growthFor(subject, _now()).stageProgress,
                  flowerCount: subject.completedCount,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 3,
                    children: [
                      copy(subject.name, 17, weight: FontWeight.w700),
                      copy(
                        tr(context, "{0} · {1} · الاختبار {2}", [
                          tr(
                            context,
                            plantStageLabels[_workspace
                                .growthFor(subject, _now())
                                .stage]!,
                          ),
                          subject.parts.isEmpty
                              ? tr(context, "لا توجد مواضيع بعد")
                              : tr(context, "المواضيع: {0} من {1}", [
                                  subject.completedCount,
                                  subject.parts.length,
                                ]),
                          examLabel(context, subject.exam),
                        ]),
                        13,
                        color: growzaColor(context, muted),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_SubjectAction>(
                  tooltip: tr(context, "خيارات {0}", [subject.name]),
                  onSelected: (action) => switch (action) {
                    _SubjectAction.viewExam => setState(() {
                      _scheduleDay = DateUtils.dateOnly(subject.exam);
                      _tab = 2;
                    }),
                    _SubjectAction.reminders => _openCalendars(),
                    _SubjectAction.aiTopics => _suggestTopics(subject),
                    _SubjectAction.edit => _editSubject(subject),
                    _SubjectAction.exam => _editExam(subject),
                    _SubjectAction.delete => _deleteSubject(subject),
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _SubjectAction.viewExam,
                      child: Text(tr(context, "عرض الاختبار")),
                    ),
                    if (widget.calendars != null)
                      PopupMenuItem(
                        value: _SubjectAction.reminders,
                        child: Text(tr(context, "تنبيهات الاختبار")),
                      ),
                    PopupMenuItem(
                      value: _SubjectAction.aiTopics,
                      child: Text(tr(context, 'اقترح المواضيع من الملف')),
                    ),
                    PopupMenuItem(
                      value: _SubjectAction.edit,
                      child: Text(tr(context, "تعديل المادة")),
                    ),
                    PopupMenuItem(
                      value: _SubjectAction.exam,
                      child: Text(tr(context, "تعديل الاختبار")),
                    ),
                    PopupMenuItem(
                      value: _SubjectAction.delete,
                      child: Text(tr(context, "حذف المادة")),
                    ),
                  ],
                ),
              ],
            ),
            if (subject.pdfName case final pdf?)
              copy(
                tr(context, "مرجع PDF · {0}", [pdf]),
                13,
                color: growzaColor(context, muted),
              ),
            for (final part in subject.parts)
              Row(
                children: [
                  IconButton(
                    tooltip: part.completed
                        ? tr(context, "إعادة فتح {0}", [part.title])
                        : tr(context, "إكمال {0}", [part.title]),
                    onPressed: () =>
                        _togglePart((subject: subject, part: part)),
                    icon: Icon(
                      part.completed
                          ? Icons.check_circle_outline
                          : Icons.circle_outlined,
                      color: part.completed
                          ? growzaColor(context, greenInk)
                          : growzaColor(context, muted),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 3,
                      children: [
                        copy(part.title, 14, weight: FontWeight.w600),
                        if (part.pdfName != null)
                          Text(
                            part.pdfName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (part.startPage != null && part.endPage != null)
                          Text(
                            tr(context, 'صفحات {0}–{1}', [
                              part.startPage,
                              part.endPage,
                            ]),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        copy(
                          part.completed
                              ? tr(context, "مكتمل")
                              : tr(context, "التقدير: {0} د{1}", [
                                  part.minutes,
                                  part.priority ? tr(context, " · أولوية") : '',
                                ]),
                          12,
                          color: growzaColor(context, muted),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<_PartAction>(
                    tooltip: tr(context, "خيارات الموضوع {0}", [part.title]),
                    onSelected: (action) => switch (action) {
                      _PartAction.edit => _editPart(
                        task: (subject: subject, part: part),
                      ),
                      _PartAction.delete => _deletePart((
                        subject: subject,
                        part: part,
                      )),
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: _PartAction.edit,
                        child: Text(tr(context, "تعديل الموضوع")),
                      ),
                      PopupMenuItem(
                        value: _PartAction.delete,
                        child: Text(tr(context, "حذف الموضوع")),
                      ),
                    ],
                  ),
                  if (!part.completed) ...[
                    IconButton(
                      tooltip: tr(context, "ذاكر {0}", [part.title]),
                      onPressed: () =>
                          _focusTask((subject: subject, part: part)),
                      icon: Icon(
                        Icons.play_arrow_rounded,
                        color: growzaColor(context, accent),
                      ),
                    ),
                  ],
                ],
              ),
            TextButton.icon(
              onPressed: () => _editPart(subject: subject),
              icon: Icon(Icons.add_rounded),
              label: Text(tr(context, "أضف موضوعاً")),
            ),
          ],
        ),
      ),
  ];

  List<StudySubject> get _visibleSubjects {
    final query = _subjectSearch.text.trim().toLowerCase();
    return _subjects.where((subject) {
      if (_studySelection != null) return subject.name == _studySelection;
      return query.isEmpty ||
          subject.name.toLowerCase().contains(query) ||
          subject.parts.any((part) => part.title.toLowerCase().contains(query));
    }).toList();
  }

  Future<void> _editSubject(StudySubject subject) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final result = await Navigator.push<StudySubject>(
      context,
      GrowzaRoute(
        builder: (_) => SubjectDetails(
          subject: subject,
          existingNames: _subjects.map((s) => s.name).toList(),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      final index = _subjects.indexWhere((s) => s.name == subject.name);
      _subjects[index] = result;
      for (var i = 0; i < _workspace.sessions.length; i++) {
        final session = _workspace.sessions[i];
        if (session.subject == subject.name) {
          _workspace.sessions[i] = session.copyWith(subject: result.name);
        }
      }
      for (var i = 0; i < _workspace.recentSubjects.length; i++) {
        if (_workspace.recentSubjects[i] == subject.name) {
          _workspace.recentSubjects[i] = result.name;
        }
      }
      if (_timerSession?.subject == subject.name) {
        _timerSession = _timerSession!.copyWith(subject: result.name);
      }
      if (_studySelection == subject.name) _studySelection = result.name;
    });
    _save();
  }

  Future<void> _deletePart(StudyTask task) async {
    _timer?.refresh();
    if (_timerSession?.partKey == task.key &&
        _timer?.phase == TimerPhase.focus &&
        (_timer?.hasProgress ?? false)) {
      _showMessage(tr(context, "أنهِ جلسة هذا الموضوع قبل حذفه."));
      return;
    }
    if (!await _confirm(
      tr(context, "حذف الموضوع؟"),
      tr(
        context,
        "حذف {0} وجلساته غير المكتملة؟ تبقى الجلسات المكتملة في سجلك.",
        [task.part.title],
      ),
      tr(context, "حذف الموضوع"),
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      final index = _subjects.indexWhere((s) => s.name == task.subject.name);
      final current = _subjects[index];
      _subjects[index] = current.withParts(
        current.parts.where((p) => p.id != task.part.id).toList(),
      );
      _workspace.sessions.removeWhere(
        (s) => s.partKey == task.key && !s.completed,
      );
      if (_timerSession?.partKey == task.key) {
        _timer?.dispose();
        _timer = null;
        _timerSession = null;
      }
    });
    _save();
  }

  Future<void> _deleteSubject(StudySubject subject) async {
    if (_timerSession?.subject == subject.name &&
        _timer?.phase == TimerPhase.focus &&
        (_timer?.hasProgress ?? false)) {
      _showMessage(tr(context, "أنهِ جلسة هذه المادة قبل حذفها."));
      return;
    }
    if (!await _confirm(
      tr(context, "حذف المادة؟"),
      tr(context, "حذف {0} ومواضيعها واختبارها وجلسات المذاكرة؟", [
        subject.name,
      ]),
      tr(context, "حذف المادة"),
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      if (_timerSession?.subject == subject.name) {
        _timer?.dispose();
        _timer = null;
        _timerSession = null;
      }
      if (_pendingReview?.subjectId == subject.id) {
        _workspace.pendingFocusReviewId = null;
      }
      _subjects.removeWhere((s) => s.name == subject.name);
      _workspace.sessions.removeWhere((s) => s.subject == subject.name);
      _workspace.recentSubjects.remove(subject.name);
      _studySelection = null;
    });
    _save();
  }

  void _togglePart(StudyTask task) {
    if (_timerSession?.partKey == task.key &&
        _timer?.phase == TimerPhase.focus &&
        (_timer?.hasProgress ?? false)) {
      _showMessage(tr(context, "أنهِ جلسة التركيز الحالية أولاً."));
      return;
    }
    if (!task.part.completed) {
      _finishPart(task.key);
      return;
    }
    setState(() {
      final subject = _subjects.firstWhere((s) => s.name == task.subject.name);
      _subjects[_subjects.indexOf(subject)] = subject.withParts([
        for (final p in subject.parts)
          p.id == task.part.id
              ? StudyPart(
                  p.id,
                  p.title,
                  p.minutes,
                  priority: p.priority,
                  startPage: p.startPage,
                  endPage: p.endPage,
                  pdfName: p.pdfName,
                )
              : p,
      ]);
    });
    _save();
  }

  Future<void> _editExam(StudySubject subject) async {
    final date = await Navigator.push<DateTime>(
      context,
      GrowzaRoute(
        builder: (context) => ExamEditor(subject: subject, now: _now()),
      ),
    );
    if (!mounted || date == null) return;
    setState(() {
      final index = _subjects.indexWhere((s) => s.name == subject.name);
      final current = _subjects[index];
      _subjects[index] = StudySubject(
        current.name,
        date,
        current.parts,
        id: current.id,
        pdfName: current.pdfName,
        nextPartId: current.nextPartId,
      );
      _scheduleDay = DateUtils.dateOnly(date);
    });
    _save();
    _showMessage(
      tr(context, "حُدّث الاختبار في جدولك. راجع الخطة إذا تغيّر الموعد."),
    );
  }

  Widget _scheduleScreen(BuildContext context) {
    final calendars = widget.calendars;
    return ScheduleView(
      day: _scheduleDay ?? _now(),
      now: _now(),
      sessions: _sessions,
      subjects: _subjects,
      onExam: _editExam,
      isSessionPending: (session) {
        final part = _taskFor(session.partKey)?.part;
        return part == null ? !session.completed : !part.completed;
      },
      calendarItems: calendars?.items ?? [],
      calendarCount: calendars?.sources.length ?? 0,
      calendarLoading: calendars?.loading ?? false,
      onDayChanged: (day) => setState(() => _scheduleDay = day),
      onBack: () => setState(() => _tab = 0),
      onAdd: _addToSchedule,
      onStart: (session) => _focus(session: session),
      onCalendars: calendars == null ? null : _openCalendars,
      onAdjust: _tasks.isEmpty ? null : _adjustPlan,
      hasConflict: _sessions.any(
        (session) => !session.completed && _conflictsWithCalendar(session),
      ),
      onCalendarItem: (item) =>
          showCalendarItem(context, calendars!, item, _now()),
      sessionMenu: (session) => PopupMenuButton<_SessionAction>(
        tooltip: tr(context, "خيارات جلسة {0}", [session.topic]),
        onSelected: (action) => switch (action) {
          _SessionAction.edit => _editSession(session),
          _SessionAction.delete => _deleteSession(session),
          _SessionAction.toggleFixed => _toggleFixed(session),
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _SessionAction.edit,
            child: Text(tr(context, "تعديل")),
          ),
          if (session.partId != null && !session.completed)
            PopupMenuItem(
              value: _SessionAction.toggleFixed,
              child: Text(
                session.fixed
                    ? tr(context, "السماح بإعادة الجدولة")
                    : tr(context, "تثبيت هذا الوقت"),
              ),
            ),
          PopupMenuItem(
            value: _SessionAction.delete,
            child: Text(tr(context, "حذف")),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadFailed) {
      return Scaffold(
        body: SafeArea(
          child: ScreenList(
            children: [
              StudyHeader(),
              PageHeading(
                tr(context, "تعذّر فتح Growza"),
                tr(
                  context,
                  "حاول تحميل خطة المذاكرة المحفوظة على هذا الجهاز مجدداً.",
                ),
              ),
              StudyButton(tr(context, "إعادة المحاولة"), () {
                setState(() => _loading = true);
                _load();
              }),
            ],
          ),
        ),
      );
    }
    return GrowzaAppearance(
      isDark: Theme.of(context).brightness == Brightness.dark,
      onToggle: () {
        _workspace.darkMode = Theme.of(context).brightness != Brightness.dark;
        widget.onAppearanceChanged(_workspace.darkMode);
        _save();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: _tab == 2
              ? _scheduleScreen(context)
              : ScreenList(
                  key: ValueKey(_tab),
                  children: _tab == 0 ? _homeScreen() : _studyScreen(context),
                ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          backgroundColor: growzaColor(context, canvas),
          indicatorColor: growzaColor(context, accentSoft),
          onDestinationSelected: (index) => setState(() {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            _tab = index;
            if (index == 1) _studySelection = null;
          }),
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              label: tr(context, "الرئيسية"),
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              label: tr(context, "المواد"),
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              label: tr(context, "الجدول"),
            ),
          ],
        ),
      ),
    );
  }
}
