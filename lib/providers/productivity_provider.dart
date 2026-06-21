import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/productivity_models.dart';
import '../utils/hive_box_manager.dart';
import '../services/native_app_blocker_service.dart';

const _uuid = Uuid();

// ═══════════════════════════════════════════════════════════════════════════════
// 📋 TODO PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

class TodoNotifier extends StateNotifier<List<TodoItem>> {
  Box<TodoItem>? _box;

  TodoNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    _box = await HiveBoxManager.get<TodoItem>('productivity_todos');
    state = _box!.values.toList()..sort(_sortTodos);
  }

  int _sortTodos(TodoItem a, TodoItem b) {
    // Incomplete first, then by priority (high→low), then by due date
    if (a.isCompleted != b.isCompleted) {
      return a.isCompleted ? 1 : -1;
    }
    if (a.priority != b.priority) return b.priority.compareTo(a.priority);
    if (a.dueDate != null && b.dueDate != null) {
      return a.dueDate!.compareTo(b.dueDate!);
    }
    if (a.dueDate != null) return -1;
    if (b.dueDate != null) return 1;
    return b.createdAt.compareTo(a.createdAt);
  }

  Future<TodoItem> addTodo({
    required String title,
    DateTime? dueDate,
    int priority = 1,
    String category = 'general',
    String? linkedEventId,
    String? linkedDoubtId,
  }) async {
    final todo = TodoItem(
      id: _uuid.v4(),
      title: title,
      createdAt: DateTime.now(),
      dueDate: dueDate,
      priority: priority,
      category: category,
      linkedEventId: linkedEventId,
      linkedDoubtId: linkedDoubtId,
    );
    await _box?.put(todo.id, todo);
    state = [...state.where((t) => t.id != todo.id), todo]..sort(_sortTodos);
    return todo;
  }

  Future<void> toggleTodo(String id) async {
    final todo = _box?.get(id);
    if (todo != null) {
      todo.isCompleted = !todo.isCompleted;
      await todo.save();
      state = _box!.values.toList()..sort(_sortTodos);
    }
  }

  Future<void> updateTodo(String id, {String? title, DateTime? dueDate, int? priority, String? category}) async {
    final todo = _box?.get(id);
    if (todo != null) {
      if (title != null) todo.title = title;
      if (dueDate != null) todo.dueDate = dueDate;
      if (priority != null) todo.priority = priority;
      if (category != null) todo.category = category;
      await todo.save();
      state = _box!.values.toList()..sort(_sortTodos);
    }
  }

  Future<void> deleteTodo(String id) async {
    await _box?.delete(id);
    state = state.where((t) => t.id != id).toList();
  }

  List<TodoItem> getByCategory(String category) {
    if (category == 'all') return state;
    return state.where((t) => t.category == category).toList();
  }

  List<TodoItem> getTodosForDate(DateTime date) {
    return state.where((t) {
      if (t.dueDate == null) return false;
      return t.dueDate!.year == date.year &&
          t.dueDate!.month == date.month &&
          t.dueDate!.day == date.day;
    }).toList();
  }

  int get completedToday {
    final now = DateTime.now();
    return state.where((t) =>
        t.isCompleted &&
        t.createdAt.year == now.year &&
        t.createdAt.month == now.month &&
        t.createdAt.day == now.day).length;
  }

  int get pendingCount => state.where((t) => !t.isCompleted).length;
}

final todoProvider = StateNotifierProvider<TodoNotifier, List<TodoItem>>(
  (ref) => TodoNotifier(),
);

// ═══════════════════════════════════════════════════════════════════════════════
// 🍅 POMODORO PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

enum PomodoroState { idle, focusing, shortBreak, longBreak, paused }

/// Individual session log entry
class FocusSessionLog {
  final DateTime startTime;
  final int durationMinutes;
  final String type; // 'focus', 'short_break', 'long_break'
  final String? category;

  FocusSessionLog({
    required this.startTime,
    required this.durationMinutes,
    required this.type,
    this.category,
  });

  Map<String, dynamic> toJson() => {
    'start': startTime.millisecondsSinceEpoch,
    'dur': durationMinutes,
    'type': type,
    'cat': category,
  };

  factory FocusSessionLog.fromJson(Map<String, dynamic> json) => FocusSessionLog(
    startTime: DateTime.fromMillisecondsSinceEpoch(json['start'] as int),
    durationMinutes: json['dur'] as int,
    type: json['type'] as String,
    category: json['cat'] as String?,
  );
}

class PomodoroTimerState {
  final PomodoroState state;
  final PomodoroState? previousState;
  final int remainingSeconds;
  final int completedSessions;
  final int totalFocusMinutesToday;
  final int totalBreakMinutesToday;
  final String? activeTodoId;
  final PomodoroSettings settings;
  final List<FocusSessionLog> todayLogs;

  PomodoroTimerState({
    this.state = PomodoroState.idle,
    this.previousState,
    this.remainingSeconds = 1500,
    this.completedSessions = 0,
    this.totalFocusMinutesToday = 0,
    this.totalBreakMinutesToday = 0,
    this.activeTodoId,
    PomodoroSettings? settings,
    List<FocusSessionLog>? todayLogs,
  }) : settings = settings ?? PomodoroSettings(),
       todayLogs = todayLogs ?? [];

  PomodoroTimerState copyWith({
    PomodoroState? state,
    PomodoroState? previousState,
    int? remainingSeconds,
    int? completedSessions,
    int? totalFocusMinutesToday,
    int? totalBreakMinutesToday,
    String? activeTodoId,
    PomodoroSettings? settings,
    List<FocusSessionLog>? todayLogs,
    bool clearTodoId = false,
    bool clearPreviousState = false,
  }) {
    return PomodoroTimerState(
      state: state ?? this.state,
      previousState: clearPreviousState ? null : (previousState ?? this.previousState),
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      completedSessions: completedSessions ?? this.completedSessions,
      totalFocusMinutesToday: totalFocusMinutesToday ?? this.totalFocusMinutesToday,
      totalBreakMinutesToday: totalBreakMinutesToday ?? this.totalBreakMinutesToday,
      activeTodoId: clearTodoId ? null : (activeTodoId ?? this.activeTodoId),
      settings: settings ?? this.settings,
      todayLogs: todayLogs ?? this.todayLogs,
    );
  }

  String get timeDisplay {
    final min = remainingSeconds ~/ 60;
    final sec = remainingSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  double get progress {
    final effectiveState = state == PomodoroState.paused ? previousState ?? PomodoroState.focusing : state;
    final total = effectiveState == PomodoroState.focusing
        ? settings.focusMinutes * 60
        : effectiveState == PomodoroState.longBreak
            ? settings.longBreakMinutes * 60
            : settings.shortBreakMinutes * 60;
    if (total == 0) return 0;
    return 1.0 - (remainingSeconds / total);
  }

  /// Total work+break time today
  int get totalTimeToday => totalFocusMinutesToday + totalBreakMinutesToday;

  /// Average session length from logs
  double get avgSessionMinutes {
    final focusLogs = todayLogs.where((l) => l.type == 'focus').toList();
    if (focusLogs.isEmpty) return 0;
    return focusLogs.fold<int>(0, (sum, l) => sum + l.durationMinutes) / focusLogs.length;
  }

  /// Short break count today
  int get shortBreakCount => todayLogs.where((l) => l.type == 'short_break').length;

  /// Long break count today
  int get longBreakCount => todayLogs.where((l) => l.type == 'long_break').length;
}

class PomodoroNotifier extends StateNotifier<PomodoroTimerState> {
  PomodoroNotifier() : super(PomodoroTimerState()) {
    _loadSettings();
    _loadDailyStats();
    _loadCumulativeMinutes();
  }

  DateTime? _sessionStartTime;
  Timer? _internalTimer;
  Box? _dailyStatsBox;
  Box<PomodoroSettings>? _settingsBox;

  /// Wall-clock anchor for drift-free timing
  DateTime? _timerAnchor;
  int _anchorRemainingSeconds = 0;

  /// Cumulative all-time focus minutes (persisted)
  int _cumulativeFocusMinutes = 0;
  int get cumulativeFocusMinutes => _cumulativeFocusMinutes;

  @override
  void dispose() {
    _internalTimer?.cancel();
    super.dispose();
  }

  /// Start the internal ticker (wall-clock anchored).
  /// Uses 1-second interval for UI updates. The wall-clock anchor
  /// ensures accuracy even if ticks are late (e.g. during background).
  void _ensureTickerRunning() {
    _internalTimer?.cancel();
    _timerAnchor = DateTime.now();
    _anchorRemainingSeconds = state.remainingSeconds;
    _internalTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      tick();
    });
  }

  /// Stop the internal ticker
  void _stopTicker() {
    _internalTimer?.cancel();
    _internalTimer = null;
  }

  Future<void> _loadSettings() async {
    _settingsBox = await HiveBoxManager.get<PomodoroSettings>('pomodoro_settings');
    if (_settingsBox!.isNotEmpty) {
      final settings = _settingsBox!.getAt(0)!;
      state = state.copyWith(
        settings: settings,
        remainingSeconds: settings.focusMinutes * 60,
      );
    }
  }

  /// Load cumulative all-time focus minutes
  Future<void> _loadCumulativeMinutes() async {
    _dailyStatsBox ??= await HiveBoxManager.get('pomodoro_daily_stats');
    _cumulativeFocusMinutes = _dailyStatsBox!.get('cumulativeFocusMinutes', defaultValue: 0) as int;
  }

  /// Persist cumulative all-time focus minutes
  Future<void> _saveCumulativeMinutes() async {
    _dailyStatsBox ??= await HiveBoxManager.get('pomodoro_daily_stats');
    _dailyStatsBox!.put('cumulativeFocusMinutes', _cumulativeFocusMinutes);
  }

  /// Load persisted daily stats (resets if it's a new day)
  Future<void> _loadDailyStats() async {
    _dailyStatsBox ??= await HiveBoxManager.get('pomodoro_daily_stats');
    final box = _dailyStatsBox!;
    final savedDate = box.get('date', defaultValue: '');
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (savedDate == today) {
      final focusMins = box.get('focusMinutes', defaultValue: 0) as int;
      final breakMins = box.get('breakMinutes', defaultValue: 0) as int;
      final sessions = box.get('sessions', defaultValue: 0) as int;
      final logsRaw = box.get('logs', defaultValue: <dynamic>[]) as List<dynamic>;
      final logs = logsRaw.map((e) {
        if (e is Map) return FocusSessionLog.fromJson(Map<String, dynamic>.from(e));
        return null;
      }).whereType<FocusSessionLog>().toList();
      state = state.copyWith(
        totalFocusMinutesToday: focusMins,
        totalBreakMinutesToday: breakMins,
        completedSessions: sessions,
        todayLogs: logs,
      );
    } else {
      // New day — reset stats
      await box.put('date', today);
      await box.put('focusMinutes', 0);
      await box.put('breakMinutes', 0);
      await box.put('sessions', 0);
      await box.put('logs', <dynamic>[]);
    }
  }

  /// Persist daily stats to Hive
  Future<void> _saveDailyStats() async {
    _dailyStatsBox ??= await HiveBoxManager.get('pomodoro_daily_stats');
    final box = _dailyStatsBox!;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await box.put('date', today);
    await box.put('focusMinutes', state.totalFocusMinutesToday);
    await box.put('breakMinutes', state.totalBreakMinutesToday);
    await box.put('sessions', state.completedSessions);
    await box.put('logs', state.todayLogs.map((l) => l.toJson()).toList());
    // Also save per-date logs for the history date pills
    await _saveLogsForDate(today, state.todayLogs);
  }

  void startFocus({String? todoId}) {
    _sessionStartTime = DateTime.now();
    state = state.copyWith(
      state: PomodoroState.focusing,
      remainingSeconds: state.settings.focusMinutes * 60,
      activeTodoId: todoId,
    );
    _ensureTickerRunning();
  }

  void startBreak() {
    _sessionStartTime = DateTime.now();
    // Always short break — no long break system
    state = state.copyWith(
      state: PomodoroState.shortBreak,
      remainingSeconds: state.settings.shortBreakMinutes * 60,
    );
    _ensureTickerRunning();
  }

  /// Skip forward: if focusing → log partial focus then start short break;
  ///               if on break → log partial break then start focus
  void skipForward() {
    _stopTicker();
    final now = DateTime.now();
    if (state.state == PomodoroState.focusing || state.state == PomodoroState.paused) {
      // Log partial focus session
      final elapsed = _sessionStartTime != null
          ? (now.difference(_sessionStartTime!).inSeconds / 60).round()
          : 0;
      final actualMins = elapsed.clamp(0, state.settings.focusMinutes);
      if (actualMins >= _minSessionMinutes) {
        final newLogs = List<FocusSessionLog>.from(state.todayLogs)
          ..add(FocusSessionLog(
            startTime: _sessionStartTime ?? now,
            durationMinutes: actualMins,
            type: 'focus',
          ));
        _cumulativeFocusMinutes += actualMins;
        state = state.copyWith(
          completedSessions: state.completedSessions + 1,
          totalFocusMinutesToday: state.totalFocusMinutesToday + actualMins,
          todayLogs: newLogs,
        );
        _saveDailyStats();
        _saveCumulativeMinutes();
      }
      _sessionStartTime = null;
      _timerAnchor = null;
      startBreak();
    } else if (state.state == PomodoroState.shortBreak) {
      // Log partial break
      final elapsed = _sessionStartTime != null
          ? (now.difference(_sessionStartTime!).inSeconds / 60).round()
          : 0;
      final actualMins = elapsed.clamp(0, state.settings.shortBreakMinutes);
      if (actualMins >= _minSessionMinutes) {
        final newLogs = List<FocusSessionLog>.from(state.todayLogs)
          ..add(FocusSessionLog(
            startTime: _sessionStartTime ?? now,
            durationMinutes: actualMins,
            type: 'short_break',
          ));
        state = state.copyWith(
          totalBreakMinutesToday: state.totalBreakMinutesToday + actualMins,
          todayLogs: newLogs,
        );
        _saveDailyStats();
      }
      _sessionStartTime = null;
      _timerAnchor = null;
      startFocus(todoId: state.activeTodoId);
    }
  }

  /// Skip backward: restart current phase from full duration
  void skipBackward() {
    _stopTicker();
    _sessionStartTime = DateTime.now();
    _timerAnchor = null;
    if (state.state == PomodoroState.shortBreak) {
      state = state.copyWith(
        remainingSeconds: state.settings.shortBreakMinutes * 60,
      );
    } else {
      state = state.copyWith(
        state: PomodoroState.focusing,
        remainingSeconds: state.settings.focusMinutes * 60,
      );
    }
    _ensureTickerRunning();
  }

  void tick() {
    if (state.state == PomodoroState.idle || state.state == PomodoroState.paused) return;

    // Wall-clock calculation — immune to Timer.periodic drift
    if (_timerAnchor != null) {
      final elapsed = DateTime.now().difference(_timerAnchor!).inSeconds;
      final computed = _anchorRemainingSeconds - elapsed;
      final remaining = computed < 0 ? 0 : computed;
      if (remaining <= 0) {
        _onTimerComplete();
        return;
      }
      state = state.copyWith(remainingSeconds: remaining);
    } else {
      // Fallback: simple decrement
      if (state.remainingSeconds <= 0) {
        _onTimerComplete();
        return;
      }
      state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
    }
  }

  /// Minimum duration (minutes) a session must reach to be recorded in stats.
  /// Sessions shorter than this are discarded as accidental/noise.
  static const int _minSessionMinutes = 3;

  void _onTimerComplete() {
    _stopTicker();
    _timerAnchor = null;
    final now = DateTime.now();
    if (state.state == PomodoroState.focusing) {
      final focusMins = state.settings.focusMinutes;
      final actualMins = _sessionStartTime != null
          ? (now.difference(_sessionStartTime!).inSeconds / 60).round().clamp(1, focusMins)
          : focusMins;
      // Only record sessions that are at least _minSessionMinutes long
      if (actualMins >= _minSessionMinutes) {
        final newLogs = List<FocusSessionLog>.from(state.todayLogs)
          ..add(FocusSessionLog(
            startTime: _sessionStartTime ?? now,
            durationMinutes: actualMins,
            type: 'focus',
          ));
        _cumulativeFocusMinutes += actualMins;
        state = state.copyWith(
          completedSessions: state.completedSessions + 1,
          totalFocusMinutesToday: state.totalFocusMinutesToday + actualMins,
          state: PomodoroState.idle,
          todayLogs: newLogs,
        );
        _saveDailyStats();
        _saveCumulativeMinutes();
      } else {
        state = state.copyWith(state: PomodoroState.idle);
      }
      if (state.settings.autoStartBreaks) {
        startBreak();
      }
    } else {
      // Short break complete (no long break)
      final breakMins = state.settings.shortBreakMinutes;
      final actualMins = _sessionStartTime != null
          ? (now.difference(_sessionStartTime!).inSeconds / 60).round().clamp(1, breakMins)
          : breakMins;
      // Only record breaks that are at least _minSessionMinutes long
      if (actualMins >= _minSessionMinutes) {
        final newLogs = List<FocusSessionLog>.from(state.todayLogs)
          ..add(FocusSessionLog(
            startTime: _sessionStartTime ?? now,
            durationMinutes: actualMins,
            type: 'short_break',
          ));
        state = state.copyWith(
          state: PomodoroState.idle,
          totalBreakMinutesToday: state.totalBreakMinutesToday + actualMins,
          todayLogs: newLogs,
        );
        _saveDailyStats();
      } else {
        state = state.copyWith(state: PomodoroState.idle);
      }
      if (state.settings.autoStartFocus) {
        startFocus(todoId: state.activeTodoId);
      }
    }
    _sessionStartTime = null;
  }

  void pause() {
    _stopTicker();
    // Snapshot the remaining seconds at pause time (wall-clock accurate)
    if (_timerAnchor != null) {
      final elapsed = DateTime.now().difference(_timerAnchor!).inSeconds;
      final computed = _anchorRemainingSeconds - elapsed;
      final remaining = computed < 0 ? 0 : computed;
      state = state.copyWith(
        previousState: state.state,
        state: PomodoroState.paused,
        remainingSeconds: remaining,
      );
    } else {
      state = state.copyWith(
        previousState: state.state,
        state: PomodoroState.paused,
      );
    }
    _timerAnchor = null;
  }

  void resume() {
    if (state.state != PomodoroState.paused || state.previousState == null) return;
    state = state.copyWith(
      state: state.previousState,
      clearPreviousState: true,
    );
    _ensureTickerRunning();
  }

  void reset() {
    _stopTicker();
    _sessionStartTime = null;
    _timerAnchor = null;
    _anchorRemainingSeconds = 0;
    state = state.copyWith(
      state: PomodoroState.idle,
      remainingSeconds: state.settings.focusMinutes * 60,
      clearTodoId: true,
      clearPreviousState: true,
    );
  }

  Future<void> updateSettings(PomodoroSettings settings) async {
    _settingsBox ??= await HiveBoxManager.get<PomodoroSettings>('pomodoro_settings');
    if (_settingsBox!.isEmpty) {
      await _settingsBox!.add(settings);
    } else {
      await _settingsBox!.putAt(0, settings);
    }
    state = state.copyWith(settings: settings);
    if (state.state == PomodoroState.idle) {
      state = state.copyWith(remainingSeconds: settings.focusMinutes * 60);
    }
  }

  /// Save logs for a specific date key (yyyy-MM-dd) for historic day pills
  Future<void> _saveLogsForDate(String dateKey, List<FocusSessionLog> logs) async {
    _dailyStatsBox ??= await HiveBoxManager.get('pomodoro_daily_stats');
    _dailyStatsBox!.put('logs_$dateKey', logs.map((l) => l.toJson()).toList());
  }

  /// Load logs for a specific date key — returns empty list if none stored
  Future<List<FocusSessionLog>> logsForDate(String dateKey) async {
    _dailyStatsBox ??= await HiveBoxManager.get('pomodoro_daily_stats');
    final raw = _dailyStatsBox!.get('logs_$dateKey', defaultValue: <dynamic>[]) as List<dynamic>;
    return raw.map((e) {
      if (e is Map) return FocusSessionLog.fromJson(Map<String, dynamic>.from(e));
      return null;
    }).whereType<FocusSessionLog>().toList();
  }

  /// Total focus minutes for a date key (yyyy-MM-dd)
  Future<int> focusMinutesForDate(String dateKey) async {
    final logs = await logsForDate(dateKey);
    return logs.where((l) => l.type == 'focus').fold<int>(0, (s, l) => s + l.durationMinutes);
  }
}

final pomodoroProvider =
    StateNotifierProvider<PomodoroNotifier, PomodoroTimerState>(
  (ref) => PomodoroNotifier(),
);

// ═══════════════════════════════════════════════════════════════════════════════
// 📝 ACADEMIC DOUBTS PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

class AcademicDoubtNotifier extends StateNotifier<List<AcademicDoubt>> {
  Box<AcademicDoubt>? _box;

  AcademicDoubtNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    _box = await HiveBoxManager.get<AcademicDoubt>('academic_doubts');
    state = _box!.values.toList()
      ..sort((a, b) {
        if (a.isResolved != b.isResolved) return a.isResolved ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  Future<AcademicDoubt> addDoubt({
    required String subject,
    required String question,
    int urgency = 1,
    List<String>? tags,
  }) async {
    final doubt = AcademicDoubt(
      id: _uuid.v4(),
      subject: subject,
      question: question,
      createdAt: DateTime.now(),
      urgency: urgency,
      tags: tags,
    );
    await _box?.put(doubt.id, doubt);
    state = [...state, doubt]..sort((a, b) {
        if (a.isResolved != b.isResolved) return a.isResolved ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });
    return doubt;
  }

  Future<void> resolveDoubt(String id, String answer) async {
    final doubt = _box?.get(id);
    if (doubt != null) {
      doubt.answer = answer;
      doubt.isResolved = true;
      doubt.resolvedAt = DateTime.now();
      await doubt.save();
      state = _box!.values.toList()..sort((a, b) {
          if (a.isResolved != b.isResolved) return a.isResolved ? 1 : -1;
          return b.createdAt.compareTo(a.createdAt);
        });
    }
  }

  Future<void> updateDoubt(String id, {String? question, String? subject, int? urgency, List<String>? tags}) async {
    final doubt = _box?.get(id);
    if (doubt != null) {
      if (question != null) doubt.question = question;
      if (subject != null) doubt.subject = subject;
      if (urgency != null) doubt.urgency = urgency;
      if (tags != null) doubt.tags = tags;
      await doubt.save();
      state = _box!.values.toList()..sort((a, b) {
          if (a.isResolved != b.isResolved) return a.isResolved ? 1 : -1;
          return b.createdAt.compareTo(a.createdAt);
        });
    }
  }

  Future<void> deleteDoubt(String id) async {
    await _box?.delete(id);
    state = state.where((d) => d.id != id).toList();
  }

  List<AcademicDoubt> getBySubject(String subject) {
    return state.where((d) => d.subject == subject).toList();
  }

  List<String> get allSubjects {
    return state.map((d) => d.subject).toSet().toList()..sort();
  }

  int get unresolvedCount => state.where((d) => !d.isResolved).length;
}

final academicDoubtProvider =
    StateNotifierProvider<AcademicDoubtNotifier, List<AcademicDoubt>>(
  (ref) => AcademicDoubtNotifier(),
);

// ═══════════════════════════════════════════════════════════════════════════════
// 📅 EVENTS PROVIDER (Calendar-integrated)
// ═══════════════════════════════════════════════════════════════════════════════

class ProductivityEventNotifier extends StateNotifier<List<ProductivityEvent>> {
  Box<ProductivityEvent>? _box;

  ProductivityEventNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    _box = await HiveBoxManager.get<ProductivityEvent>('productivity_events');
    state = _box!.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Future<ProductivityEvent> addEvent({
    required String title,
    String? description,
    required DateTime startTime,
    DateTime? endTime,
    String color = 'C2A366',
    bool isAllDay = false,
    String? linkedTodoId,
    String? linkedBlockRuleId,
    bool hasReminder = false,
    int reminderMinutesBefore = 15,
    String repeatType = 'none',
  }) async {
    final event = ProductivityEvent(
      id: _uuid.v4(),
      title: title,
      description: description,
      startTime: startTime,
      endTime: endTime,
      color: color,
      isAllDay: isAllDay,
      linkedTodoId: linkedTodoId,
      linkedBlockRuleId: linkedBlockRuleId,
      hasReminder: hasReminder,
      reminderMinutesBefore: reminderMinutesBefore,
      repeatType: repeatType,
    );
    await _box?.put(event.id, event);
    state = [...state, event]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return event;
  }

  Future<void> updateEvent(String id, {
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? color,
    String? linkedBlockRuleId,
  }) async {
    final event = _box?.get(id);
    if (event != null) {
      if (title != null) event.title = title;
      if (description != null) event.description = description;
      if (startTime != null) event.startTime = startTime;
      if (endTime != null) event.endTime = endTime;
      if (color != null) event.color = color;
      if (linkedBlockRuleId != null) event.linkedBlockRuleId = linkedBlockRuleId;
      await event.save();
      state = _box!.values.toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
    }
  }

  Future<void> deleteEvent(String id) async {
    await _box?.delete(id);
    state = state.where((e) => e.id != id).toList();
  }

  List<ProductivityEvent> getEventsForDate(DateTime date) {
    return state.where((e) {
      final eventDate = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
      final targetDate = DateTime(date.year, date.month, date.day);
      return eventDate == targetDate;
    }).toList();
  }

  Set<DateTime> get eventDates {
    return state.map((e) => DateTime(
      e.startTime.year, e.startTime.month, e.startTime.day,
    )).toSet();
  }

  ProductivityEvent? getActiveEvent() {
    final now = DateTime.now();
    try {
      return state.firstWhere(
        (e) => e.startTime.isBefore(now) && (e.endTime?.isAfter(now) ?? e.startTime.day == now.day),
      );
    } catch (_) {
      return null;
    }
  }

  List<ProductivityEvent> getUpcoming({int limit = 5}) {
    final now = DateTime.now();
    return state.where((e) => e.startTime.isAfter(now)).take(limit).toList();
  }
}

final productivityEventProvider =
    StateNotifierProvider<ProductivityEventNotifier, List<ProductivityEvent>>(
  (ref) => ProductivityEventNotifier(),
);

/// Convenience provider: event dates for calendar dots
final productivityEventDatesProvider = Provider<Set<DateTime>>((ref) {
  final events = ref.watch(productivityEventProvider);
  return events.map((e) => DateTime(
    e.startTime.year, e.startTime.month, e.startTime.day,
  )).toSet();
});

/// Convenience provider: events for a specific date
final eventsForDateProvider = Provider.family<List<ProductivityEvent>, DateTime>((ref, date) {
  final events = ref.watch(productivityEventProvider);
  return events.where((e) {
    final d = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
    final t = DateTime(date.year, date.month, date.day);
    return d == t;
  }).toList();
});

// ═══════════════════════════════════════════════════════════════════════════════
// 🛡️ APP BLOCK RULES PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

class AppBlockRuleNotifier extends StateNotifier<List<AppBlockRule>> {
  Box<AppBlockRule>? _box;
  Timer? _expiryTimer;

  AppBlockRuleNotifier() : super([]) {
    _init();
  }

  Future<void> _init() async {
    _box = await HiveBoxManager.get<AppBlockRule>('app_block_rules');
    // Clean up any already-expired rules on startup
    await _cleanExpiredRules();
    state = _box!.values.toList();
    // Sync to native blocker on startup
    _syncToNativeBlocker();
    // Only start the expiry timer if there are rules that actually need it
    _scheduleExpiryTimerIfNeeded();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  /// Start the periodic expiry checker ONLY when there are enabled
  /// duration-based rules that can expire. Stops the timer when none
  /// remain — avoids a 15-second poll loop running the entire app
  /// lifetime for nothing (battery waste).
  void _scheduleExpiryTimerIfNeeded() {
    final hasExpirableRules = state.any(
      (r) => r.isEnabled && (r.expiresAt != null || r.snoozedUntil != null),
    );

    if (hasExpirableRules && _expiryTimer == null) {
      _expiryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _checkAndExpireRules();
      });
    } else if (!hasExpirableRules && _expiryTimer != null) {
      _expiryTimer?.cancel();
      _expiryTimer = null;
    }
  }

  /// Check for expired duration-based rules and disable them.
  /// Called periodically by the timer to ensure blocks don't persist
  /// after their duration has elapsed.
  Future<void> _checkAndExpireRules() async {
    if (_box == null) return;
    final now = DateTime.now();
    bool changed = false;

    for (final rule in _box!.values) {
      if (rule.isEnabled && rule.expiresAt != null && now.isAfter(rule.expiresAt!)) {
        rule.isEnabled = false;
        await rule.save();
        changed = true;
      }
      // A snooze that has elapsed ("turns back on tomorrow") resumes the rule.
      if (rule.snoozedUntil != null && !now.isBefore(rule.snoozedUntil!)) {
        rule.snoozedUntil = null;
        await rule.save();
        changed = true;
      }
    }

    if (changed) {
      state = _box!.values.toList();
      _syncToNativeBlocker();
      // Re-evaluate whether the timer is still needed
      _scheduleExpiryTimerIfNeeded();
    }
  }

  /// Remove rules that have already expired (cleanup on startup).
  Future<void> _cleanExpiredRules() async {
    if (_box == null) return;
    final now = DateTime.now();
    for (final rule in _box!.values.toList()) {
      if (rule.isEnabled && rule.expiresAt != null && now.isAfter(rule.expiresAt!)) {
        rule.isEnabled = false;
        await rule.save();
      }
    }
  }

  /// Check if a rule is currently active (not expired).
  bool _isRuleActive(AppBlockRule rule) {
    if (!rule.isEnabled) return false;
    // Temporarily paused ("turns back on tomorrow") — inactive until it resumes.
    if (rule.isSnoozed) return false;

    // Check expiry first — duration-based rules have an absolute deadline
    if (rule.expiresAt != null) {
      if (DateTime.now().isAfter(rule.expiresAt!)) return false;
      // If not expired yet, it's active (duration-based rules are always
      // active until their expiresAt, regardless of hour:minute matching)
      return true;
    }

    final now = DateTime.now();
    if (rule.isTimeBased) {
      // Scheduled (recurring) rule — check day + time window
      if (rule.startHour == null || rule.endHour == null) return false;
      if (!rule.activeDays.contains(now.weekday)) return false;

      final startMin = rule.startHour! * 60 + (rule.startMinute ?? 0);
      final endMin = rule.endHour! * 60 + (rule.endMinute ?? 0);
      final nowMin = now.hour * 60 + now.minute;

      if (startMin <= endMin) {
        // Same-day window: e.g. 09:00–17:00
        // Use strict < for end so block lifts at exactly endHour:endMinute:00
        return nowMin >= startMin && nowMin < endMin;
      } else {
        // Overnight (e.g. 22:00 → 06:00)
        return nowMin >= startMin || nowMin < endMin;
      }
    } else {
      // Manual toggle — always active when enabled
      return true;
    }
  }

  /// Sync all currently-blocked packages to the native foreground service.
  /// This is the key integration point — the native service will monitor
  /// the foreground app and block any that are in this list.
  void _syncToNativeBlocker() {
    final allBlockedPackages = <String>{};

    for (final rule in state) {
      if (_isRuleActive(rule)) {
        allBlockedPackages.addAll(rule.blockedPackages);
      }
    }

    NativeAppBlockerService.updateBlockedPackages(allBlockedPackages.toList());
  }

  Future<AppBlockRule> addRule({
    required String name,
    List<String>? blockedPackages,
    bool isTimeBased = false,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    List<int>? activeDays,
    String? linkedEventId,
    String blockMessage = 'Stay focused! 🌙',
    bool allowBreaks = true,
    bool isHardBlock = false,
    DateTime? expiresAt,
  }) async {
    final rule = AppBlockRule(
      id: _uuid.v4(),
      name: name,
      blockedPackages: blockedPackages,
      isTimeBased: isTimeBased,
      startHour: startHour,
      startMinute: startMinute,
      endHour: endHour,
      endMinute: endMinute,
      activeDays: activeDays,
      linkedEventId: linkedEventId,
      blockMessage: blockMessage,
      allowBreaks: allowBreaks,
      isHardBlock: isHardBlock,
      expiresAt: expiresAt,
    );
    await _box?.put(rule.id, rule);
    state = [...state, rule];
    _syncToNativeBlocker();
    _scheduleExpiryTimerIfNeeded();
    return rule;
  }

  Future<void> toggleRule(String id) async {
    final rule = _box?.get(id);
    if (rule != null) {
      // Hard-blocked rules cannot be toggled
      if (rule.isHardBlock) return;
      rule.isEnabled = !rule.isEnabled;
      if (rule.isEnabled) rule.breaksTaken = 0; // Reset breaks on re-enable
      await rule.save();
      state = _box!.values.toList();
      _syncToNativeBlocker();
      _scheduleExpiryTimerIfNeeded();
    }
  }

  Future<void> updateRule(String id, {
    String? name,
    List<String>? blockedPackages,
    bool? isTimeBased,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    List<int>? activeDays,
    String? linkedEventId,
    String? blockMessage,
  }) async {
    final rule = _box?.get(id);
    if (rule != null) {
      if (name != null) rule.name = name;
      if (blockedPackages != null) rule.blockedPackages = blockedPackages;
      if (isTimeBased != null) rule.isTimeBased = isTimeBased;
      if (startHour != null) rule.startHour = startHour;
      if (startMinute != null) rule.startMinute = startMinute;
      if (endHour != null) rule.endHour = endHour;
      if (endMinute != null) rule.endMinute = endMinute;
      if (activeDays != null) rule.activeDays = activeDays;
      if (linkedEventId != null) rule.linkedEventId = linkedEventId;
      if (blockMessage != null) rule.blockMessage = blockMessage;
      await rule.save();
      state = _box!.values.toList();
      _syncToNativeBlocker();
    }
  }

  Future<void> deleteRule(String id) async {
    final rule = _box?.get(id);
    // Hard-blocked rules cannot be deleted
    if (rule != null && rule.isHardBlock) return;
    await _box?.delete(id);
    state = state.where((r) => r.id != id).toList();
    _syncToNativeBlocker();
    _scheduleExpiryTimerIfNeeded();
  }

  Future<void> takeBreak(String id) async {
    final rule = _box?.get(id);
    if (rule != null && rule.allowBreaks && rule.breaksTaken < rule.maxBreaksPerSession) {
      rule.breaksTaken++;
      await rule.save();
      state = _box!.values.toList();
    }
  }

  /// Check if a package is currently blocked by ANY active rule
  bool isAppBlocked(String packageName) {
    for (final rule in state) {
      if (!rule.blockedPackages.contains(packageName)) continue;
      if (_isRuleActive(rule)) return true;
    }
    return false;
  }

  /// Get the block message for a blocked app
  String? getBlockMessage(String packageName) {
    for (final rule in state) {
      if (!rule.blockedPackages.contains(packageName)) continue;
      if (_isRuleActive(rule)) return rule.blockMessage;
    }
    return null;
  }

  /// Get all active rules right now
  List<AppBlockRule> get activeRules {
    return state.where(_isRuleActive).toList();
  }

  /// Force-disable a rule, bypassing isHardBlock guard.
  /// Used by: 10-tap hard block removal screen & expiry timer.
  Future<void> forceDisableRule(String id) async {
    final rule = _box?.get(id);
    if (rule == null) return;
    rule.isEnabled = false;
    rule.snoozedUntil = null;
    await rule.save();
    state = _box!.values.toList();
    _syncToNativeBlocker();
    _scheduleExpiryTimerIfNeeded();
  }

  /// Turn a rule fully ON — enabled and not snoozed.
  Future<void> enableRule(String id) async {
    final rule = _box?.get(id);
    if (rule == null) return;
    rule.isEnabled = true;
    rule.snoozedUntil = null;
    rule.breaksTaken = 0;
    await rule.save();
    state = _box!.values.toList();
    _syncToNativeBlocker();
    _scheduleExpiryTimerIfNeeded();
  }

  /// Pause a rule until the next local midnight ("turns back on tomorrow").
  /// The rule stays enabled/scheduled — it just won't block until it resumes.
  Future<void> snoozeRuleUntilTomorrow(String id) async {
    final rule = _box?.get(id);
    if (rule == null) return;
    final now = DateTime.now();
    final tomorrow =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    rule.isEnabled = true;
    rule.snoozedUntil = tomorrow;
    await rule.save();
    state = _box!.values.toList();
    _syncToNativeBlocker();
    _scheduleExpiryTimerIfNeeded();
  }
}


final appBlockRuleProvider =
    StateNotifierProvider<AppBlockRuleNotifier, List<AppBlockRule>>(
  (ref) => AppBlockRuleNotifier(),
);

// ═══════════════════════════════════════════════════════════════════════════════
// 🏷️ FOCUS CATEGORY PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

class FocusCategoryState {
  final List<String> categories;
  final String? activeCategory;

  const FocusCategoryState({
    this.categories = const ['Studying', 'Prototyping', 'Homework', 'Reading', 'Work'],
    this.activeCategory,
  });

  FocusCategoryState copyWith({
    List<String>? categories,
    String? activeCategory,
    bool clearActive = false,
  }) {
    return FocusCategoryState(
      categories: categories ?? this.categories,
      activeCategory: clearActive ? null : (activeCategory ?? this.activeCategory),
    );
  }
}

class FocusCategoryNotifier extends StateNotifier<FocusCategoryState> {
  Box<List>? _box;
  
  FocusCategoryNotifier() : super(const FocusCategoryState()) {
    _init();
  }

  Future<void> _init() async {
    _box = await HiveBoxManager.get<List>('focus_categories');
    final saved = _box!.get('categories');
    if (saved != null && saved.isNotEmpty) {
      state = state.copyWith(categories: saved.cast<String>());
    }
    final active = _box!.get('activeCategory');
    if (active != null && active.isNotEmpty) {
      state = state.copyWith(activeCategory: active.first as String);
    }
  }

  Future<void> _save() async {
    _box ??= await HiveBoxManager.get<List>('focus_categories');
    _box!.put('categories', state.categories);
    _box!.put('activeCategory',
        state.activeCategory != null ? [state.activeCategory] : []);
  }

  void select(String category) {
    state = state.copyWith(
      activeCategory: category,
      clearActive: state.activeCategory == category,
    );
    _save();
  }

  Future<void> add(String category) async {
    if (category.isEmpty || state.categories.contains(category)) return;
    state = state.copyWith(categories: [...state.categories, category]);
    await _save();
  }

  Future<void> remove(String category) async {
    state = state.copyWith(
      categories: state.categories.where((c) => c != category).toList(),
      clearActive: state.activeCategory == category,
    );
    await _save();
  }
}

final focusCategoryProvider =
    StateNotifierProvider<FocusCategoryNotifier, FocusCategoryState>(
  (ref) => FocusCategoryNotifier(),
);

// ═══════════════════════════════════════════════════════════════════════════════
// 🏆 FOCUS STREAK PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

class FocusStreakNotifier extends StateNotifier<int> {
  Box? _box;
  
  FocusStreakNotifier() : super(0) {
    _init();
  }

  Future<void> _init() async {
    _box = await HiveBoxManager.get('focus_streak');
    final lastDate = _box!.get('lastFocusDate') as String?;
    final streak = _box!.get('streak') as int? ?? 0;
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year}-${yesterday.month}-${yesterday.day}';

    if (lastDate == todayStr) {
      state = streak;
    } else if (lastDate == yesterdayStr) {
      state = streak; // hasn't focused today yet, but streak preserved
    } else {
      state = 0; // streak broken
      _box!.put('streak', 0);
    }
  }

  Future<void> recordSession() async {
    _box ??= await HiveBoxManager.get('focus_streak');
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final lastDate = _box!.get('lastFocusDate') as String?;

    if (lastDate != todayStr) {
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayStr = '${yesterday.year}-${yesterday.month}-${yesterday.day}';
      final currentStreak = _box!.get('streak') as int? ?? 0;

      if (lastDate == yesterdayStr || lastDate == null) {
        state = currentStreak + 1;
      } else {
        state = 1; // streak was broken, start fresh
      }
      _box!.put('streak', state);
      _box!.put('lastFocusDate', todayStr);
    }
  }
}

final focusStreakProvider =
    StateNotifierProvider<FocusStreakNotifier, int>(
  (ref) => FocusStreakNotifier(),
);
