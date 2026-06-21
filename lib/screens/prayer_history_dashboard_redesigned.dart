import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/prayer_provider.dart';
import '../providers/premium_provider.dart';
import '../models/prayer_record.dart';
import '../widgets/year_dots_analytics.dart';
import '../widgets/swipe_back_wrapper.dart';
import '../providers/qadha_provider.dart';
import '../screens/qadha_estimation_wizard.dart';
import 'premium_paywall_screen.dart';

/// Prayer Analytics Dashboard - Redesigned for minimalism & professional UX
class PrayerHistoryDashboard extends ConsumerStatefulWidget {
  const PrayerHistoryDashboard({super.key});

  @override
  ConsumerState<PrayerHistoryDashboard> createState() => _PrayerHistoryDashboardState();
}

class _PrayerHistoryDashboardState extends ConsumerState<PrayerHistoryDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  // Minimalist color palette - gold accent only
  static const _gold = Color(0xFFC2A366);
  static const _bg = Color(0xFF000000);
  static const _cardBg = Color(0xFF0D0D0D);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(premiumProvider).isPremium;
    if (!isPremium) return _buildLockedScreen(context);

    final recordsMap = ref.watch(prayerRecordsMapProvider);
    final records = ref.watch(prayerRecordListProvider);

    return SwipeBackWrapper(
      child: Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _OverviewTab(recordsMap: recordsMap, records: records),
                  const _QadhaTab(),
                  _CalendarTab(
                    recordsMap: recordsMap,
                    selectedYear: _selectedYear,
                    selectedMonth: _selectedMonth,
                    onMonthChanged: (y, m) => setState(() {
                      _selectedYear = y;
                      _selectedMonth = m;
                    }),
                  ),
                  _AchievementsTab(recordsMap: recordsMap),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildLockedScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lock_outline, color: _gold, size: 36),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Prayer Analytics',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Track your spiritual journey with detailed\ninsights and progress metrics',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14, height: 1.6),
                      ),
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumPaywallScreen()));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
                          decoration: BoxDecoration(
                            color: _gold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Upgrade to Premium', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back_ios_new, color: Colors.white.withValues(alpha: 0.7), size: 18),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prayer Analytics', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                Text('Your spiritual journey', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _gold.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium_rounded, color: _gold, size: 14),
                const SizedBox(width: 4),
                Text('PRO', style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: _gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        dividerColor: Colors.transparent,
        labelColor: _gold,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Qadha'),
          Tab(text: 'Calendar'),
          Tab(text: 'Achievements'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// OVERVIEW TAB - Stats, streaks, insights
// ═══════════════════════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final Map<String, PrayerRecord> recordsMap;
  final List<PrayerRecord> records;
  
  const _OverviewTab({required this.recordsMap, required this.records});

  static const _gold = Color(0xFFC2A366);
  static const _cardBg = Color(0xFF0D0D0D);

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();
    
    final todayKey = _formatDate(DateTime.now());
    final todayCount = recordsMap[todayKey]?.completedCount ?? 0;

    int monthlyTotal = 0;
    final now = DateTime.now();
    for (int i = 1; i <= 31; i++) {
        final d = DateTime(now.year, now.month, i);
        if (d.month > now.month) break;
        final k = _formatDate(d);
        monthlyTotal += recordsMap[k]?.completedCount ?? 0;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildMetricsGrid(stats, todayCount, monthlyTotal),
        const SizedBox(height: 16),
        _buildStreakCard(stats, todayCount),
        const SizedBox(height: 16),
        _buildGoalCard(todayCount),
        const SizedBox(height: 24),
        _buildSectionLabel('WEEKLY ACTIVITY'),
        const SizedBox(height: 12),
        _buildWeeklyChart(stats),
        const SizedBox(height: 24),
        _buildNafilSection(context),
        const SizedBox(height: 24),
        _buildSectionLabel('RECENT PRAYERS'),
        const SizedBox(height: 12),
        _buildNamazHistory(),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.4),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }

  Map<String, dynamic> _calculateStats() {
    int currentStreak = 0, bestStreak = 0, tempStreak = 0;
    int totalPrayers = 0, perfectDays = 0;
    final prayerCounts = {'Fajr': 0, 'Dhuhr': 0, 'Asr': 0, 'Maghrib': 0, 'Isha': 0};

    final sorted = recordsMap.keys.toList()..sort();
    for (int i = sorted.length - 1; i >= 0; i--) {
      final r = recordsMap[sorted[i]];
      if (r != null) {
        totalPrayers += r.completedCount;
        if (r.completedCount == 5) perfectDays++;
        if (r.fajr) prayerCounts['Fajr'] = (prayerCounts['Fajr'] ?? 0) + 1;
        if (r.dhuhr) prayerCounts['Dhuhr'] = (prayerCounts['Dhuhr'] ?? 0) + 1;
        if (r.asr) prayerCounts['Asr'] = (prayerCounts['Asr'] ?? 0) + 1;
        if (r.maghrib) prayerCounts['Maghrib'] = (prayerCounts['Maghrib'] ?? 0) + 1;
        if (r.isha) prayerCounts['Isha'] = (prayerCounts['Isha'] ?? 0) + 1;
        
        if (r.completedCount >= 3) {
          tempStreak++;
          if (i == sorted.length - 1 || i == sorted.length - 2) currentStreak = tempStreak;
        } else {
          if (tempStreak > bestStreak) bestStreak = tempStreak;
          tempStreak = 0;
        }
      }
    }
    if (tempStreak > bestStreak) bestStreak = tempStreak;

    return {
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'totalPrayers': totalPrayers,
      'perfectDays': perfectDays,
      'prayerCounts': prayerCounts,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildMetricsGrid(Map<String, dynamic> stats, int todayCount, int monthlyTotal) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildMetric('${stats['totalPrayers']}', 'TOTAL PRAYERS', Icons.mosque_rounded),
              Container(width: 1, height: 48, color: Colors.white.withValues(alpha: 0.06)),
              _buildMetric('$todayCount', 'TODAY', Icons.today_rounded),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.05),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMetric('$monthlyTotal', 'THIS MONTH', Icons.calendar_month_rounded),
              Container(width: 1, height: 48, color: Colors.white.withValues(alpha: 0.06)),
              _buildMetric('${records.where((r) => r.tahajjud).length + records.where((r) => r.ishraq).length + records.where((r) => r.chasht).length + records.where((r) => r.awwabin).length}', 'TOTAL NAFIL', Icons.auto_awesome_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _gold.withValues(alpha: 0.5), size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(Map<String, dynamic> stats, int todayCount) {
    final streak = stats['currentStreak'] as int;
    final atRisk = todayCount < 3 && streak > 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: atRisk ? const Color(0xFFFF6B35).withValues(alpha: 0.04) : _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: atRisk 
              ? const Color(0xFFFF6B35).withValues(alpha: 0.2)
              : streak > 0 
                  ? _gold.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: streak > 0 
                  ? (atRisk ? const Color(0xFFFF6B35) : _gold).withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: streak > 0 
                    ? (atRisk ? const Color(0xFFFF6B35) : _gold).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  streak > 0 ? Icons.local_fire_department_rounded : Icons.star_outline_rounded,
                  color: streak > 0 
                      ? (atRisk ? const Color(0xFFFF6B35) : _gold)
                      : Colors.white.withValues(alpha: 0.3),
                  size: 28,
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$streak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DAY STREAK',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                if (atRisk) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Complete 3 prayers to save streak',
                    style: TextStyle(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(int todayCount) {
    const targetCount = 5;
    final progress = (todayCount / targetCount).clamp(0.0, 1.0);
    final isComplete = todayCount >= targetCount;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isComplete ? _gold.withValues(alpha: 0.04) : _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isComplete 
              ? _gold.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isComplete ? 'DAILY GOAL COMPLETED' : 'DAILY GOAL',
                  style: TextStyle(
                    color: isComplete 
                        ? _gold 
                        : Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$todayCount',
                      style: TextStyle(
                        color: isComplete ? _gold : Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      ' / $targetCount',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (!isComplete && targetCount > todayCount) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${targetCount - todayCount} remaining today',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation(
                    Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(
                    isComplete ? _gold : _gold.withValues(alpha: 0.8),
                  ),
                ),
                if (isComplete)
                  const Icon(Icons.check_rounded, color: _gold, size: 24)
                else
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(Map<String, dynamic> stats) {
    final weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    
    final now = DateTime.now();
    int currentWeekday = now.weekday; // 1=Mon, 7=Sun
    
    final days = List.generate(7, (i) {
      DateTime d = now.subtract(Duration(days: currentWeekday - 1 - i));
      if (d.isAfter(now)) return 0;
      final key = _formatDate(d);
      return recordsMap[key]?.completedCount ?? 0;
    });

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final count = days[i];
              double barHeight = count == 0 ? 4.0 : (count / 5 * 100);
              // Matches the image colors; standard gold and darker gold for 1 less.
              Color barColor = (count > 0 && count < 5) ? const Color(0xFF906927) : _gold;
              
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: 120, // fixed height area to bottom align bars
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (count > 0) ...[
                          Text(
                            '$count',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Container(
                          width: 38,
                          height: count == 0 ? 4 : barHeight,
                          decoration: BoxDecoration(
                            color: count > 0 ? barColor : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(count > 0 ? 6 : 2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    weekDays[i],
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildNamazHistory() {
    final now = DateTime.now();
    // Show last 7 days
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: i));
      final key = _formatDate(d);
      return {
        'date': d,
        'record': recordsMap[key],
      };
    });

    final prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final prayerIcons = [
      Icons.wb_twilight_rounded,
      Icons.wb_sunny_rounded,
      Icons.wb_sunny_outlined,
      Icons.nights_stay_outlined,
      Icons.dark_mode_rounded,
    ];

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: days.asMap().entries.map((entry) {
          final i = entry.key;
          final date = entry.value['date'] as DateTime;
          final record = entry.value['record'] as PrayerRecord?;
          final isLast = i == days.length - 1;
          final isToday = i == 0;
          final isYesterday = i == 1;
          final completed = record?.completedCount ?? 0;
          final prayed = [
            record?.fajr ?? false,
            record?.dhuhr ?? false,
            record?.asr ?? false,
            record?.maghrib ?? false,
            record?.isha ?? false,
          ];

          String dayLabel;
          if (isToday) {
            dayLabel = 'Today';
          } else if (isYesterday) {
            dayLabel = 'Yesterday';
          } else {
            final weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
            dayLabel = '${weekDays[date.weekday - 1]}, ${date.day} ${_monthAbbr(date.month)}';
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: isToday ? _gold.withValues(alpha: 0.02) : null,
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day label + count badge
                Row(
                  children: [
                    Text(
                      dayLabel,
                      style: TextStyle(
                        color: isToday ? _gold : Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: completed == 5
                            ? _gold.withValues(alpha: 0.15)
                            : completed > 0
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        completed == 5 ? '✓ PERFECT' : '$completed/5',
                        style: TextStyle(
                          color: completed == 5
                              ? _gold
                              : Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 5 prayer status pills
                Row(
                  children: List.generate(5, (pi) {
                    final done = prayed[pi];
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: pi < 4 ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: done
                              ? _gold.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: done
                                ? _gold.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              done ? Icons.check_circle_rounded : prayerIcons[pi],
                              size: 18,
                              color: done
                                  ? _gold
                                  : Colors.white.withValues(alpha: 0.15),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              prayerNames[pi],
                              style: TextStyle(
                                fontSize: 10,
                                color: done
                                    ? _gold.withValues(alpha: 0.9)
                                    : Colors.white.withValues(alpha: 0.3),
                                fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNafilSection(BuildContext context) {
    final recordsList = records;
    final totalTahajjud = recordsList.where((r) => r.tahajjud).length;
    final totalIshraq = recordsList.where((r) => r.ishraq).length;
    final totalChasht = recordsList.where((r) => r.chasht).length;
    final totalAwwabin = recordsList.where((r) => r.awwabin).length;

    final nafils = [
      {'name': 'Tahajjud', 'icon': Icons.bedtime_rounded, 'count': totalTahajjud},
      {'name': 'Ishraq', 'icon': Icons.wb_twilight_rounded, 'count': totalIshraq},
      {'name': 'Chasht', 'icon': Icons.light_mode_rounded, 'count': totalChasht},
      {'name': 'Awwabin', 'icon': Icons.nights_stay_rounded, 'count': totalAwwabin},
    ];
    final total = totalTahajjud + totalIshraq + totalChasht + totalAwwabin;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'NAFIL PRAYERS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.40),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showNiflInfoSheet(context),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 14,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFC2A366).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$total total',
                  style: TextStyle(
                    color: const Color(0xFFC2A366).withValues(alpha: 0.65),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: nafils.map((n) {
              final count = n['count'] as int;
              final maxCount = nafils.map((x) => x['count'] as int).fold<int>(0, (a, b) => a > b ? a : b);
              final frac = maxCount > 0 ? count / maxCount : 0.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Column(
                    children: [
                      Icon(n['icon'] as IconData,
                          size: 16,
                          color: count > 0
                              ? const Color(0xFFC2A366).withValues(alpha: 0.70)
                              : Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 8),
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.bottomCenter,
                        clipBehavior: Clip.hardEdge,
                        child: FractionallySizedBox(
                          heightFactor: frac.clamp(0.05, 1.0),
                          widthFactor: 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: count > 0
                                  ? const Color(0xFFC2A366).withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$count',
                        style: TextStyle(
                          color: count > 0
                              ? const Color(0xFFC2A366).withValues(alpha: 0.80)
                              : Colors.white.withValues(alpha: 0.20),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        n['name'] as String,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showNiflInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D0D),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: _gold, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Nafl Prayers Guide',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildNiflInfoItem(
                'Tahajjud',
                'Late night (last third of the night)',
                'The most virtuous prayer after the obligatory prayers. It illuminates the heart and brings one closer to Allah.',
                Icons.bedtime_rounded,
              ),
              const SizedBox(height: 16),
              _buildNiflInfoItem(
                'Ishraq',
                '15-20 mins after sunrise',
                'Offering 2-4 rakats brings the reward of a complete Hajj and Umrah (Tirmidhi).',
                Icons.wb_twilight_rounded,
              ),
              const SizedBox(height: 16),
              _buildNiflInfoItem(
                'Chasht (Duha)',
                'Mid-morning to before Dhuhr',
                'Charity for every joint in the body. Known as the prayer of the oft-returning (Awwabin) to Allah.',
                Icons.light_mode_rounded,
              ),
              const SizedBox(height: 16),
              _buildNiflInfoItem(
                'Awwabin',
                'Between Maghrib and Isha',
                '6 or more rakats for forgiveness of sins. "Whoever prays 6 rakats after Maghrib... it equals 12 years of worship."',
                Icons.nights_stay_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNiflInfoItem(String title, String time, String desc, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _gold, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    color: _gold.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _monthAbbr(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}
// ═══════════════════════════════════════════════════════════════════════════════
// CALENDAR TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _CalendarTab extends StatefulWidget {
  final Map<String, PrayerRecord> recordsMap;
  final int selectedYear;
  final int selectedMonth;
  final Function(int, int) onMonthChanged;

  const _CalendarTab({
    required this.recordsMap,
    required this.selectedYear,
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  //ignore: unused_field
  static const _gold = Color(0xFFC2A366);
  static const _cardBg = Color(0xFF0D0D0D);
  static const _hiveKey = 'prayer_dots_color';

  DotsColorTheme _colorTheme = DotsColorTheme.gold;

  @override
  void initState() {
    super.initState();
    _loadColorPref();
  }

  Future<void> _loadColorPref() async {
    final box = await Hive.openBox('settings');
    final idx = box.get(_hiveKey, defaultValue: 0) as int;
    if (idx >= 0 && idx < DotsColorTheme.values.length) {
      setState(() => _colorTheme = DotsColorTheme.values[idx]);
    }
  }

  Future<void> _saveColorPref(DotsColorTheme theme) async {
    final box = await Hive.openBox('settings');
    await box.put(_hiveKey, theme.index);
  }

  // Get data for day-of-year from prayer records
  DayDotData _prayerDataForDay(int dayOfYear) {
    final date = DateTime(widget.selectedYear, 1, 1).add(Duration(days: dayOfYear - 1));
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final count = widget.recordsMap[key]?.completedCount ?? 0;

    double intensity;
    if (count == 0) {
      intensity = 0.0;
    } else if (count <= 2) {
      intensity = 0.25;
    } else if (count <= 4) {
      intensity = 0.55;
    } else {
      intensity = 1.0;
    }
    return DayDotData(intensity: intensity, rawCount: count);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black, // High contrast pure black background
      child: CustomPaint(
        painter: _PremiumGridPainter(
          color: Colors.white.withValues(alpha: 0.03),
          spacing: 24,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // ══ HERO: Year 365 dots — wrapped in glassmorphic card ══
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardBg.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: YearDotsAnalyticsGrid(
                year: widget.selectedYear,
                colorTheme: _colorTheme,
                dataForDay: _prayerDataForDay,
                subtitle: 'Namaz • ${widget.selectedYear}',
                legendLabels: const ['0', '1-2', '3-4', '5'],
              ),
            ),
            const SizedBox(height: 24),
            // Color picker — inline, minimal, right below dots
            DotsColorPicker(
              selected: _colorTheme,
              onChanged: (theme) {
                setState(() => _colorTheme = theme);
                _saveColorPref(theme);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumGridPainter extends CustomPainter {
  final Color color;
  final double spacing;

  _PremiumGridPainter({required this.color, required this.spacing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    for (double i = 0; i <= size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i <= size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumGridPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.spacing != spacing;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACHIEVEMENTS TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _AchievementsTab extends StatelessWidget {
  final Map<String, PrayerRecord> recordsMap;

  const _AchievementsTab({required this.recordsMap});

  static const _gold = Color(0xFFC2A366);
  static const _cardBg = Color(0xFF0D0D0D);

  @override
  Widget build(BuildContext context) {
    final achievements = _calculateAchievements();
    final unlocked = achievements.where((a) => a['unlocked'] as bool).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _gold.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: _gold.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _gold.withValues(alpha: 0.2)),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.emoji_events_rounded,
                        color: _gold,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$unlocked of ${achievements.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Achievements unlocked',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: unlocked / achievements.length,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  valueColor: const AlwaysStoppedAnimation(_gold),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'MILESTONES',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemCount: achievements.length,
            itemBuilder: (context, index) {
              return _buildAchievementCard(achievements[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementCard(Map<String, dynamic> achievement) {
    final unlocked = achievement['unlocked'] as bool;
    final progress = achievement['progress'] as double;
    final tier = achievement['tier'] as String;
    final tierColor = _getTierColor(tier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unlocked 
            ? tierColor.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unlocked 
              ? tierColor.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.03),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                achievement['title'] as String,
                style: TextStyle(
                  color: unlocked ? tierColor : Colors.white.withValues(alpha: 0.3),
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tier.toUpperCase(),
                  style: TextStyle(
                    color: tierColor,
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            achievement['subtitle'] as String,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Text(
            achievement['description'] as String,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 10,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          if (!unlocked && progress > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                valueColor: AlwaysStoppedAnimation(tierColor.withValues(alpha: 0.4)),
                minHeight: 3,
              ),
            )
          else
            Row(
              children: [
                if (unlocked)
                  Icon(
                    Icons.check_rounded,
                    color: tierColor,
                    size: 14,
                  ),
                if (unlocked) const SizedBox(width: 4),
                Text(
                  unlocked ? 'Unlocked' : 'Locked',
                  style: TextStyle(
                    color: unlocked ? tierColor : Colors.white.withValues(alpha: 0.2),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'Bronze':
        return const Color(0xFFCD7F32);
      case 'Silver':
        return const Color(0xFFC0C0C0);
      case 'Gold':
        return const Color(0xFFFFD700);
      case 'Platinum':
        return const Color(0xFFE5E4E2);
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _calculateAchievements() {
    int totalPrayers = 0, perfectDays = 0, bestStreak = 0, tempStreak = 0, fajrCount = 0;
    
    for (final r in recordsMap.values) {
      totalPrayers += r.completedCount;
      if (r.completedCount == 5) perfectDays++;
      if (r.fajr) fajrCount++;
      
      if (r.completedCount >= 3) {
        tempStreak++;
      } else {
        if (tempStreak > bestStreak) bestStreak = tempStreak;
        tempStreak = 0;
      }
    }
    if (tempStreak > bestStreak) bestStreak = tempStreak;

    return [
      {
        'icon': Icons.wb_twilight_rounded,
        'title': '1st',
        'subtitle': 'PRAYER',
        'description': 'Complete your first prayer',
        'unlocked': totalPrayers > 0,
        'tier': 'Bronze',
        'progress': totalPrayers > 0 ? 1.0 : 0.0,
      },
      {
        'icon': Icons.star_rounded,
        'title': '1',
        'subtitle': 'PERFECT DAY',
        'description': 'Complete all 5 prayers in a day',
        'unlocked': perfectDays > 0,
        'tier': 'Bronze',
        'progress': perfectDays > 0 ? 1.0 : 0.0,
      },
      {
        'icon': Icons.local_fire_department_rounded,
        'title': '7',
        'subtitle': 'DAY STREAK',
        'description': 'Maintain a 7-day streak',
        'unlocked': bestStreak >= 7,
        'tier': 'Silver',
        'progress': (bestStreak / 7).clamp(0.0, 1.0),
      },
      {
        'icon': Icons.spa_rounded,
        'title': '100',
        'subtitle': 'PRAYERS',
        'description': 'Complete 100 prayers',
        'unlocked': totalPrayers >= 100,
        'tier': 'Silver',
        'progress': (totalPrayers / 100).clamp(0.0, 1.0),
      },
      {
        'icon': Icons.nightlight_round,
        'title': '30',
        'subtitle': 'DAY STREAK',
        'description': 'Maintain a 30-day streak',
        'unlocked': bestStreak >= 30,
        'tier': 'Gold',
        'progress': (bestStreak / 30).clamp(0.0, 1.0),
      },
      {
        'icon': Icons.emoji_events_rounded,
        'title': '10',
        'subtitle': 'PERFECT DAYS',
        'description': 'Achieve 10 perfect days',
        'unlocked': perfectDays >= 10,
        'tier': 'Gold',
        'progress': (perfectDays / 10).clamp(0.0, 1.0),
      },
      {
        'icon': Icons.auto_awesome_rounded,
        'title': '30',
        'subtitle': 'FAJR',
        'description': 'Pray Fajr 30 times',
        'unlocked': fajrCount >= 30,
        'tier': 'Gold',
        'progress': (fajrCount / 30).clamp(0.0, 1.0),
      },
      {
        'icon': Icons.military_tech_rounded,
        'title': '500',
        'subtitle': 'PRAYERS',
        'description': 'Complete 500 prayers',
        'unlocked': totalPrayers >= 500,
        'tier': 'Platinum',
        'progress': (totalPrayers / 500).clamp(0.0, 1.0),
      },
      {
        'icon': Icons.diamond_rounded,
        'title': '100',
        'subtitle': 'DAY STREAK',
        'description': 'Maintain a 100-day streak',
        'unlocked': bestStreak >= 100,
        'tier': 'Platinum',
        'progress': (bestStreak / 100).clamp(0.0, 1.0),
      },
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// QADHA TAB - Missed prayer tracking & estimation
// ═══════════════════════════════════════════════════════════════════════════════
class _QadhaTab extends ConsumerWidget {
  const _QadhaTab();

  static const _gold = Color(0xFFC2A366);
  static const _cardBg = Color(0xFF0D0D0D);

  static const List<Map<String, dynamic>> _prayers = [
    {'name': 'Fajr', 'icon': Icons.wb_twilight_rounded},
    {'name': 'Dhuhr', 'icon': Icons.wb_sunny_rounded},
    {'name': 'Asr', 'icon': Icons.wb_sunny_outlined},
    {'name': 'Maghrib', 'icon': Icons.nights_stay_outlined},
    {'name': 'Isha', 'icon': Icons.dark_mode_rounded},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qadha = ref.watch(qadhaRecordProvider);

    if (qadha == null || !qadha.isLocked) {
      return _buildEmptyState(context, ref);
    }

    return _buildTrackingView(context, ref, qadha);
  }

  // ── Empty state: invite user to estimate or manually set ──
  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.replay_rounded, color: _gold, size: 36),
            ),
            const SizedBox(height: 24),
            const Text(
              'Qadha Tracker',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track and make up your missed prayers.\nStart with an estimate or enter manually.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),

            // Estimation wizard button
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const QadhaEstimationWizard(),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _gold.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: _gold, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Estimate My Qadha',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Manual setup button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _showManualSetup(context, ref);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'Enter Manually',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Note
            Text(
              'Your intention to make up prayers\nis itself a beautiful act of worship',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tracking view: shows progress and prayer-by-prayer controls ──
  Widget _buildTrackingView(BuildContext context, WidgetRef ref, dynamic qadha) {
    final totalRemaining = qadha.totalRemaining as int;
    final grandTotal = qadha.grandTotal as int;
    final progress = qadha.progress as double;
    final completed = grandTotal - totalRemaining;
    final isComplete = totalRemaining == 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Progress overview card ──
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isComplete
                  ? _gold.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.05),
            ),
            gradient: isComplete
                ? LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      _gold.withValues(alpha: 0.05),
                      _cardBg,
                    ],
                  )
                : null,
          ),
          child: Column(
            children: [
              // Circle progress
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        valueColor: AlwaysStoppedAnimation(
                          isComplete ? _gold : _gold.withValues(alpha: 0.7),
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color:
                                isComplete ? _gold : Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isComplete)
                          Text(
                            'Complete!',
                            style: TextStyle(
                              color: _gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStat('$completed', 'Prayed'),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  _buildStat('$totalRemaining', 'Remaining'),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  _buildStat('$grandTotal', 'Total'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Quick action: Pray Full Day ──
        if (!isComplete)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                ref.read(qadhaRecordProvider.notifier).prayedFullDay();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _gold.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline_rounded,
                        color: _gold, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '+1 Full Day (all 5 prayers)',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Prayer-by-prayer tracking rows ──
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRAYER BREAKDOWN',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 14, color: _gold.withValues(alpha: 0.7)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Missed prayers from your main Salah Tracker are tracked and added here automatically.', 
                            style: TextStyle(color: _gold.withValues(alpha: 0.7), fontSize: 11)
                          )
                        ),
                      ]
                    )
                  ],
                ),
              ),
              ..._prayers.map((prayer) {
                final name = prayer['name'] as String;
                final remaining = qadha.remainingFor(name) as int;
                final total = qadha.totalFor(name) as int;
                if (total == 0) return const SizedBox.shrink();
                final isDone = remaining == 0;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDone
                          ? _gold.withValues(alpha: 0.04)
                          : Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDone
                            ? _gold.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isDone
                              ? Icons.check_circle_rounded
                              : prayer['icon'] as IconData,
                          size: 18,
                          color: isDone
                              ? _gold
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$remaining remaining',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          )
                        ),
                        // Add more + button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref.read(qadhaRecordProvider.notifier).addOne(name); 
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            child: Icon(Icons.add, size: 16, color: Colors.white.withValues(alpha: 0.35)),
                          )
                        ),
                        
                        const SizedBox(width: 10),
                        
                        // Main "I Prayed" button
                        GestureDetector(
                          onTap: isDone
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  ref
                                      .read(qadhaRecordProvider.notifier)
                                      .prayedOne(name);
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDone 
                                  ? Colors.white.withValues(alpha: 0.02) 
                                  : _gold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: isDone 
                                  ? null 
                                  : Border.all(color: _gold.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isDone) 
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(Icons.check_circle_outline_rounded, size: 14, color: _gold),
                                  ),
                                Text(
                                  isDone ? 'Done' : 'I Prayed',
                                  style: TextStyle(
                                    color: isDone 
                                        ? Colors.white.withValues(alpha: 0.2) 
                                        : _gold,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          )
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Actions: Re-estimate / Reset ──
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const QadhaEstimationWizard(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Center(
                    child: Text(
                      'Re-estimate',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => _showResetConfirmation(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Center(
                    child: Text(
                      'Reset',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Note
        Center(
          child: Text(
            'Every prayer made up is a step closer to Allah',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.2),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  void _showManualSetup(BuildContext context, WidgetRef ref) {
    final controllers = <String, TextEditingController>{
      'fajr': TextEditingController(text: '0'),
      'dhuhr': TextEditingController(text: '0'),
      'asr': TextEditingController(text: '0'),
      'maghrib': TextEditingController(text: '0'),
      'isha': TextEditingController(text: '0'),
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Enter Missed Prayers',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter your best estimate per prayer type',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            ..._prayers.map((prayer) {
              final name = prayer['name'] as String;
              final key = name.toLowerCase();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(prayer['icon'] as IconData,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 70,
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 80,
                      height: 36,
                      child: TextField(
                        controller: controllers[key],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.zero,
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color:
                                    Colors.white.withValues(alpha: 0.08)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color:
                                    Colors.white.withValues(alpha: 0.08)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: _gold.withValues(alpha: 0.4)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                final fajr =
                    int.tryParse(controllers['fajr']!.text) ?? 0;
                final dhuhr =
                    int.tryParse(controllers['dhuhr']!.text) ?? 0;
                final asr =
                    int.tryParse(controllers['asr']!.text) ?? 0;
                final maghrib =
                    int.tryParse(controllers['maghrib']!.text) ?? 0;
                final isha =
                    int.tryParse(controllers['isha']!.text) ?? 0;
                final total = fajr + dhuhr + asr + maghrib + isha;
                if (total == 0) {
                  Navigator.pop(ctx);
                  return;
                }
                await ref.read(qadhaRecordProvider.notifier).setTotals(
                      fajr: fajr,
                      dhuhr: dhuhr,
                      asr: asr,
                      maghrib: maghrib,
                      isha: isha,
                    );
                await ref.read(qadhaRecordProvider.notifier).lockTotals();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: _gold.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        color: _gold, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Lock & Start Tracking',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      for (final c in controllers.values) {
        c.dispose();
      }
    });
  }

  void _showResetConfirmation(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.refresh_rounded,
                size: 36, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Reset Qadha Tracker?',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "This will clear all your Qadha data.\nYou'll need to set up again.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color:
                                Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      ref.read(qadhaRecordProvider.notifier).reset();
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.orange
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.orange
                                .withValues(alpha: 0.25)),
                      ),
                      child: Center(
                        child: Text(
                          'Reset',
                          style: TextStyle(
                            color: Colors.orange
                                .withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}
