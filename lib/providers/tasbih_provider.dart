import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/hive_box_manager.dart';

/// Achievement badge types
enum DhikrAchievement {
  firstCount('First Count', '🌟', 'Complete your first dhikr', 1),
  counter100('Century', '💯', 'Reach 100 total count', 100),
  counter1K('1K Counter', '🏆', 'Reach 1,000 total count', 1000),
  counter10K('10K Master', '👑', 'Reach 10,000 total count', 10000),
  streak3('3-Day Streak', '🔥', 'Count dhikr 3 days in a row', 3),
  streak7('Week Warrior', '⚡', 'Count dhikr 7 days in a row', 7),
  streak30('Month Master', '🌙', 'Count dhikr 30 days in a row', 30),
  dailyGoal('Daily Goal', '✅', 'Complete a full target', 1);
  
  final String name;
  final String emoji;
  final String description;
  final int requirement;
  
  const DhikrAchievement(this.name, this.emoji, this.description, this.requirement);
}

/// Tasbih state model - stores count per dhikr with enhanced stats
class TasbihState {
  final Map<int, int> dhikrCounts; // Count per dhikr index
  final int targetCount;
  final int totalAllTime;
  final int todayCount;
  final int monthlyTotal;
  final String lastDate;
  final int selectedDhikrIndex;
  final int streakDays;
  final String lastStreakDate;
  final List<String> unlockedAchievements;
  final bool soundEnabled;
  final int completedTargets; // How many times target was reached
  final Map<String, int> dailyHistory; // dateKey (YYYY-MM-DD) → total count that day

  TasbihState({
    Map<int, int>? dhikrCounts,
    this.targetCount = 33,
    this.totalAllTime = 0,
    this.todayCount = 0,
    this.monthlyTotal = 0,
    this.lastDate = '',
    this.selectedDhikrIndex = 0,
    this.streakDays = 0,
    this.lastStreakDate = '',
    List<String>? unlockedAchievements,
    Map<String, int>? dailyHistory,
    this.soundEnabled = false,
    this.completedTargets = 0,
  }) : dhikrCounts = dhikrCounts ?? {},
       unlockedAchievements = unlockedAchievements ?? [],
       dailyHistory = dailyHistory ?? {};

  // Get current count for selected dhikr
  int get currentCount => dhikrCounts[selectedDhikrIndex] ?? 0;
  
  // Get next milestone
  int get nextMilestone {
    final milestones = [100, 500, 1000, 5000, 10000, 50000, 100000];
    for (final m in milestones) {
      if (totalAllTime < m) return m;
    }
    return totalAllTime + 10000;
  }
  
  // Progress to next milestone
  double get milestoneProgress {
    final prev = [0, 100, 500, 1000, 5000, 10000, 50000].lastWhere((m) => m <= totalAllTime, orElse: () => 0);
    final next = nextMilestone;
    if (next == prev) return 1.0;
    return (totalAllTime - prev) / (next - prev);
  }

  TasbihState copyWith({
    Map<int, int>? dhikrCounts,
    int? targetCount,
    int? totalAllTime,
    int? todayCount,
    int? monthlyTotal,
    String? lastDate,
    int? selectedDhikrIndex,
    int? streakDays,
    String? lastStreakDate,
    List<String>? unlockedAchievements,
    bool? soundEnabled,
    int? completedTargets,
    Map<String, int>? dailyHistory,
  }) {
    return TasbihState(
      dhikrCounts: dhikrCounts ?? this.dhikrCounts,
      targetCount: targetCount ?? this.targetCount,
      totalAllTime: totalAllTime ?? this.totalAllTime,
      todayCount: todayCount ?? this.todayCount,
      monthlyTotal: monthlyTotal ?? this.monthlyTotal,
      lastDate: lastDate ?? this.lastDate,
      selectedDhikrIndex: selectedDhikrIndex ?? this.selectedDhikrIndex,
      streakDays: streakDays ?? this.streakDays,
      lastStreakDate: lastStreakDate ?? this.lastStreakDate,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      completedTargets: completedTargets ?? this.completedTargets,
      dailyHistory: dailyHistory ?? this.dailyHistory,
    );
  }

  Map<String, dynamic> toJson() => {
    'dhikrCounts': dhikrCounts.map((k, v) => MapEntry(k.toString(), v)),
    'targetCount': targetCount,
    'totalAllTime': totalAllTime,
    'todayCount': todayCount,
    'monthlyTotal': monthlyTotal,
    'lastDate': lastDate,
    'selectedDhikrIndex': selectedDhikrIndex,
    'streakDays': streakDays,
    'lastStreakDate': lastStreakDate,
    'unlockedAchievements': unlockedAchievements,
    'soundEnabled': soundEnabled,
    'completedTargets': completedTargets,
    'dailyHistory': dailyHistory,
  };

  factory TasbihState.fromJson(Map<String, dynamic> json) {
    // Parse dhikrCounts
    Map<int, int> counts = {};
    if (json['dhikrCounts'] != null) {
      final rawCounts = json['dhikrCounts'] as Map<String, dynamic>;
      counts = rawCounts.map((k, v) => MapEntry(int.parse(k), v as int));
    }
    // Migration: if old format with currentCount, migrate it
    if (json['currentCount'] != null && counts.isEmpty) {
      final oldCount = json['currentCount'] as int? ?? 0;
      final oldIndex = json['selectedDhikrIndex'] as int? ?? 0;
      counts[oldIndex] = oldCount;
    }

    // Parse dailyHistory
    Map<String, int> history = {};
    if (json['dailyHistory'] != null) {
      final rawHistory = json['dailyHistory'] as Map<String, dynamic>;
      history = rawHistory.map((k, v) => MapEntry(k, v as int));
    }
    
    return TasbihState(
      dhikrCounts: counts,
      targetCount: json['targetCount'] as int? ?? 33,
      totalAllTime: json['totalAllTime'] as int? ?? 0,
      todayCount: json['todayCount'] as int? ?? 0,
      monthlyTotal: json['monthlyTotal'] as int? ?? 0,
      lastDate: json['lastDate'] as String? ?? '',
      selectedDhikrIndex: json['selectedDhikrIndex'] as int? ?? 0,
      streakDays: json['streakDays'] as int? ?? 0,
      lastStreakDate: json['lastStreakDate'] as String? ?? '',
      unlockedAchievements: (json['unlockedAchievements'] as List<dynamic>?)?.cast<String>() ?? [],
      soundEnabled: json['soundEnabled'] as bool? ?? false,
      completedTargets: json['completedTargets'] as int? ?? 0,
      dailyHistory: history,
    );
  }
}

/// Dhikr preset with more options
class Dhikr {
  final String arabic;
  final String transliteration;
  final String meaning;
  final int defaultTarget;

  const Dhikr({
    required this.arabic,
    required this.transliteration,
    required this.meaning,
    this.defaultTarget = 33,
  });

  static const List<Dhikr> presets = [
    // Core Tasbihat (After Salah)
    Dhikr(
      arabic: 'سُبْحَانَ اللَّهِ',
      transliteration: 'SubhanAllah',
      meaning: 'Glory be to Allah',
      defaultTarget: 33,
    ),
    Dhikr(
      arabic: 'الْحَمْدُ لِلَّهِ',
      transliteration: 'Alhamdulillah',
      meaning: 'Praise be to Allah',
      defaultTarget: 33,
    ),
    Dhikr(
      arabic: 'اللَّهُ أَكْبَرُ',
      transliteration: 'Allahu Akbar',
      meaning: 'Allah is the Greatest',
      defaultTarget: 34,
    ),
    // Kalimah
    Dhikr(
      arabic: 'لَا إِلَٰهَ إِلَّا اللَّهُ',
      transliteration: 'La ilaha illallah',
      meaning: 'There is no god but Allah',
      defaultTarget: 100,
    ),
    // Istighfar
    Dhikr(
      arabic: 'أَسْتَغْفِرُ اللَّهَ',
      transliteration: 'Astaghfirullah',
      meaning: 'I seek forgiveness from Allah',
      defaultTarget: 100,
    ),
    Dhikr(
      arabic: 'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ',
      transliteration: 'Astaghfirullah al-Azeem',
      meaning: 'I seek forgiveness from Allah, the Mighty',
      defaultTarget: 100,
    ),
    // SubhanAllah variations
    Dhikr(
      arabic: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
      transliteration: 'SubhanAllahi wa bihamdihi',
      meaning: 'Glory and praise be to Allah',
      defaultTarget: 100,
    ),
    Dhikr(
      arabic: 'سُبْحَانَ اللَّهِ الْعَظِيمِ',
      transliteration: 'SubhanAllah al-Azeem',
      meaning: 'Glory be to Allah, the Mighty',
      defaultTarget: 100,
    ),
    // Salawat
    Dhikr(
      arabic: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ',
      transliteration: 'Allahumma salli ala Muhammad',
      meaning: 'O Allah, send blessings upon Muhammad',
      defaultTarget: 100,
    ),
    // Power of Allah
    Dhikr(
      arabic: 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
      transliteration: 'La hawla wa la quwwata illa billah',
      meaning: 'There is no power except with Allah',
      defaultTarget: 100,
    ),
    // Combined Tasbeeh
    Dhikr(
      arabic: 'سُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ وَلَا إِلَٰهَ إِلَّا اللَّهُ وَاللَّهُ أَكْبَرُ',
      transliteration: 'SubhanAllah wal Hamdulillah...',
      meaning: 'Glory to Allah, Praise to Allah, No god but Allah, Allah is Great',
      defaultTarget: 100,
    ),
    // Ya Allah
    Dhikr(
      arabic: 'يَا اللَّهُ',
      transliteration: 'Ya Allah',
      meaning: 'O Allah',
      defaultTarget: 100,
    ),
    // Ya Rahman
    Dhikr(
      arabic: 'يَا رَحْمَٰنُ',
      transliteration: 'Ya Rahman',
      meaning: 'O Most Merciful',
      defaultTarget: 100,
    ),
    // Ya Raheem
    Dhikr(
      arabic: 'يَا رَحِيمُ',
      transliteration: 'Ya Raheem',
      meaning: 'O Most Compassionate',
      defaultTarget: 100,
    ),
    // Custom counter
    Dhikr(
      arabic: '...',
      transliteration: 'Custom Count',
      meaning: 'Use for any dhikr',
      defaultTarget: 100,
    ),
    // Durood Ibrahim
    Dhikr(
      arabic: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ كَمَا صَلَّيْتَ عَلَى إِبْرَاهِيمَ... إِنَّكَ حَمِيدٌ مَجِيدٌ',
      transliteration: 'Durood Ibrahim',
      meaning: 'O Allah, send prayers upon Muhammad ﷺ and his family',
      defaultTarget: 10,
    ),
  ];
}

/// Tasbih provider
final tasbihProvider = StateNotifierProvider<TasbihNotifier, TasbihState>((ref) {
  return TasbihNotifier();
});

class TasbihNotifier extends StateNotifier<TasbihState> {
  static const String _boxName = 'tasbih_data';
  static const String _key = 'state';
  Box<String>? _box;

  /// Debounced save — during rapid tapping (dhikr can be 200+ bpm),
  /// we batch disk writes to at most once every 3 seconds.
  /// This eliminates ~1000 unnecessary Hive writes/day while keeping
  /// data safe (saved on every pause/dispose too).
  Timer? _saveDebounce;
  bool _hasPendingSave = false;

  TasbihNotifier() : super(TasbihState()) {
    _init();
  }

  Future<void> _init() async {
    _box = await HiveBoxManager.get<String>(_boxName);
    final saved = _box?.get(_key);
    if (saved != null) {
      try {
        final json = jsonDecode(saved) as Map<String, dynamic>;
        state = TasbihState.fromJson(json);
        _checkNewDay();
        // Set target to current dhikr's default
        final dhikr = Dhikr.presets[state.selectedDhikrIndex];
        state = state.copyWith(targetCount: dhikr.defaultTarget);
      } catch (e) {
        // Use default
      }
    }
  }

  void _checkNewDay() {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .split('T')[0];

    if (state.lastDate != today) {
      // ── Streak logic ──────────────────────────────────────────────────────
      int newStreak = state.streakDays;
      if (state.lastDate == yesterday && state.todayCount > 0) {
        newStreak = state.streakDays + 1; // consecutive day
      } else if (state.lastDate != yesterday && state.lastDate.isNotEmpty) {
        newStreak = 0; // streak broken
      }

      // ── Monthly reset ─────────────────────────────────────────────────────
      final lastMonth =
          state.lastDate.isNotEmpty ? state.lastDate.substring(0, 7) : '';
      final thisMonth = today.substring(0, 7);
      final monthlyTotal = lastMonth != thisMonth ? 0 : state.monthlyTotal;

      // ── New day: reset per-dhikr display counters ─────────────────────────
      // dhikrCounts → {} so every dhikr starts at 0 on a fresh day.
      // totalAllTime, dailyHistory, completedTargets, achievements are kept.
      state = state.copyWith(
        dhikrCounts: {}, // 🔄 reset individual dhikr counters for the new day
        todayCount: 0,
        completedTargets: 0, // daily target completions also reset per day
        lastDate: today,
        streakDays: newStreak,
        monthlyTotal: monthlyTotal,
      );
      _save();
    }
  }

  /// Immediate save — used for deliberate user actions (reset, settings, etc.)
  Future<void> _saveNow() async {
    _saveDebounce?.cancel();
    _hasPendingSave = false;
    _box ??= await HiveBoxManager.get<String>(_boxName);
    await _box?.put(_key, jsonEncode(state.toJson()));
  }

  /// Debounced save — used during rapid tapping.
  /// Schedules a disk write 3 seconds after the last call.
  /// If another call comes in before 3s, the timer resets.
  void _save() {
    _hasPendingSave = true;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 3), () {
      _saveNow();
    });
  }

  /// Flush any pending save to disk (call on app pause/dispose).
  Future<void> flushPendingSave() async {
    if (_hasPendingSave) await _saveNow();
  }

  @override
  void dispose() {
    // Ensure data is not lost on provider disposal
    _saveDebounce?.cancel();
    if (_hasPendingSave) {
      // Sync save — best-effort since dispose can't truly await
      _box?.put(_key, jsonEncode(state.toJson()));
    }
    super.dispose();
  }

  void increment() {
    // Update count for current dhikr
    final newCounts = Map<int, int>.from(state.dhikrCounts);
    final newCount = (newCounts[state.selectedDhikrIndex] ?? 0) + 1;
    newCounts[state.selectedDhikrIndex] = newCount;
    
    final today = DateTime.now().toIso8601String().split('T')[0];
    int newStreak = state.streakDays;
    
    // Check if this is first count today (start/continue streak)
    if (state.todayCount == 0) {
      final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().split('T')[0];
      if (state.lastStreakDate == yesterday) {
        newStreak = state.streakDays + 1;
      } else if (state.lastStreakDate != today) {
        newStreak = 1;
      }
    }
    
    // Check for target completion
    int completedTargets = state.completedTargets;
    if (newCount == state.targetCount) {
      completedTargets++;
    }

    // Update daily history (dateKey → total dhikr count that day)
    final newHistory = Map<String, int>.from(state.dailyHistory);
    newHistory[today] = (newHistory[today] ?? 0) + 1;
    
    state = state.copyWith(
      dhikrCounts: newCounts,
      totalAllTime: state.totalAllTime + 1,
      todayCount: state.todayCount + 1,
      monthlyTotal: state.monthlyTotal + 1,
      lastDate: today,
      streakDays: newStreak,
      lastStreakDate: today,
      completedTargets: completedTargets,
      dailyHistory: newHistory,
    );
    
    // Check and unlock achievements
    _checkAchievements();
    _save();
  }
  
  void _checkAchievements() {
    final unlocked = List<String>.from(state.unlockedAchievements);
    bool changed = false;
    
    // Check count-based achievements
    if (state.totalAllTime >= 1 && !unlocked.contains('firstCount')) {
      unlocked.add('firstCount');
      changed = true;
    }
    if (state.totalAllTime >= 100 && !unlocked.contains('counter100')) {
      unlocked.add('counter100');
      changed = true;
    }
    if (state.totalAllTime >= 1000 && !unlocked.contains('counter1K')) {
      unlocked.add('counter1K');
      changed = true;
    }
    if (state.totalAllTime >= 10000 && !unlocked.contains('counter10K')) {
      unlocked.add('counter10K');
      changed = true;
    }
    
    // Check streak achievements
    if (state.streakDays >= 3 && !unlocked.contains('streak3')) {
      unlocked.add('streak3');
      changed = true;
    }
    if (state.streakDays >= 7 && !unlocked.contains('streak7')) {
      unlocked.add('streak7');
      changed = true;
    }
    if (state.streakDays >= 30 && !unlocked.contains('streak30')) {
      unlocked.add('streak30');
      changed = true;
    }
    
    // Check daily goal
    if (state.completedTargets >= 1 && !unlocked.contains('dailyGoal')) {
      unlocked.add('dailyGoal');
      changed = true;
    }
    
    if (changed) {
      state = state.copyWith(unlockedAchievements: unlocked);
    }
  }

  void reset() {
    // Reset only current dhikr's count
    final newCounts = Map<int, int>.from(state.dhikrCounts);
    newCounts[state.selectedDhikrIndex] = 0;
    state = state.copyWith(dhikrCounts: newCounts);
    _saveNow();
  }

  void setTarget(int target) {
    state = state.copyWith(targetCount: target);
    _saveNow();
  }
  
  void toggleSound() {
    state = state.copyWith(soundEnabled: !state.soundEnabled);
    _saveNow();
  }

  void selectDhikr(int index) {
    if (index < 0 || index >= Dhikr.presets.length) return;
    
    final dhikr = Dhikr.presets[index];
    // Don't reset count - just switch dhikr and update target
    state = state.copyWith(
      selectedDhikrIndex: index,
      targetCount: dhikr.defaultTarget,
    );
    _saveNow();
  }

  void resetAllTime() {
    state = state.copyWith(
      totalAllTime: 0, 
      todayCount: 0,
      monthlyTotal: 0,
      dhikrCounts: {},
      streakDays: 0,
      completedTargets: 0,
      unlockedAchievements: [],
    );
    _saveNow();
  }
  
  // Get count for a specific dhikr
  int getCountForDhikr(int index) {
    return state.dhikrCounts[index] ?? 0;
  }
}
