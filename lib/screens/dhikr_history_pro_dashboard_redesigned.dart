import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/tasbih_provider.dart';
import '../utils/hive_box_manager.dart';
import '../providers/premium_provider.dart';
import '../widgets/year_dots_analytics.dart';
import 'premium_paywall_screen.dart';
import '../widgets/swipe_back_wrapper.dart';

/// Dhikr Analytics Dashboard - Redesigned for minimalism & professional UX
class DhikrHistoryProDashboard extends ConsumerStatefulWidget {
  final int initialTab;
  final int initialAdhkarSection;
  
  const DhikrHistoryProDashboard({
    super.key,
    this.initialTab = 0,
    this.initialAdhkarSection = 0,
  });

  @override
  ConsumerState<DhikrHistoryProDashboard> createState() => _DhikrHistoryProDashboardState();
}

class _DhikrHistoryProDashboardState extends ConsumerState<DhikrHistoryProDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Minimalist color palette - gold accent only
  static const _gold = Color(0xFFC2A366);
  static const _bg = Color(0xFF000000);
  static const _cardBg = Color(0xFF0D0D0D);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
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

    final tasbihState = ref.watch(tasbihProvider);

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
                  physics: const ClampingScrollPhysics(),
                  children: [
                    _OverviewTab(state: tasbihState),
                    _DhikrCalendarTab(state: tasbihState),
                    _AdhkarTab(initialSection: widget.initialAdhkarSection),
                    _AchievementsTab(state: tasbihState),
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
                        'Dhikr Analytics',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Track your dhikr journey with detailed\ninsights and achievements',
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
                Text('Dhikr Analytics', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                Text('Remember Allah always', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Calendar'),
          Tab(text: 'Adhkar'),
          Tab(text: 'Achievements'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// OVERVIEW TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final TasbihState state;
  
  const _OverviewTab({required this.state});

  static const _gold = Color(0xFFC2A366);
  static const _cardBg = Color(0xFF0D0D0D);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildMetricsGrid(),
        const SizedBox(height: 16),
        _buildStreakCard(),
        const SizedBox(height: 16),
        _buildGoalCard(),
        const SizedBox(height: 24),
        _buildSectionLabel('Weekly Activity'),
        const SizedBox(height: 12),
        _buildWeeklyStats(),
        if (state.dhikrCounts.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionLabel('Dhikr Breakdown'),
          const SizedBox(height: 12),
          _buildDhikrBreakdown(),
        ],
        const SizedBox(height: 24),
        _buildSectionLabel('Next Milestone'),
        const SizedBox(height: 12),
        _buildMilestone(),
      ],
    );
  }

  Widget _buildMetricsGrid() {
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
              _buildMetric(_formatNumber(state.totalAllTime), 'TOTAL DHIKR', Icons.all_inclusive_rounded),
              Container(width: 1, height: 48, color: Colors.white.withValues(alpha: 0.06)),
              _buildMetric('${state.todayCount}', 'TODAY', Icons.today_rounded),
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
              _buildMetric('${state.monthlyTotal}', 'THIS MONTH', Icons.calendar_month_rounded),
              Container(width: 1, height: 48, color: Colors.white.withValues(alpha: 0.06)),
              _buildMetric('${state.completedTargets}', 'GOALS MET', Icons.task_alt_rounded),
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

  Widget _buildStreakCard() {
    final streak = state.streakDays;
    final atRisk = state.todayCount == 0 && streak > 0;

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
                    'Count dhikr today to save your streak',
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

  Widget _buildGoalCard() {
    final progress = state.targetCount > 0 
        ? (state.todayCount / state.targetCount).clamp(0.0, 1.0) 
        : 0.0;
    final isComplete = state.todayCount >= state.targetCount;

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
                      '${state.todayCount}',
                      style: TextStyle(
                        color: isComplete ? _gold : Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      ' / ${state.targetCount}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (!isComplete && state.targetCount > state.todayCount) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${state.targetCount - state.todayCount} remaining today',
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

  Widget _buildWeeklyStats() {
    final today = DateTime.now();
    final startOfMonth = DateTime(today.year, today.month, 1);
    final daysInMonth = today.difference(startOfMonth).inDays + 1;
    final avgPerDay = daysInMonth > 0 ? (state.monthlyTotal / daysInMonth) : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          _buildWeeklyStat(
            '${state.todayCount}',
            'TODAY',
            isPrimary: true,
          ),
          Container(
            width: 1,
            height: 48,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          _buildWeeklyStat(
            '~${(avgPerDay * 7).toStringAsFixed(0)}',
            'WEEKLY EST',
            isPrimary: false,
          ),
          Container(
            width: 1,
            height: 48,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          _buildWeeklyStat(
            avgPerDay.toStringAsFixed(1),
            'DAILY AVG',
            isPrimary: false,
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyStat(String value, String label, {required bool isPrimary}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: isPrimary ? _gold : Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
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
    );
  }

  Widget _buildDhikrBreakdown() {
    const dhikrNames = [
      'SubhanAllah',
      'Alhamdulillah',
      'Allahu Akbar',
      'La ilaha illallah',
      'Astaghfirullah',
      'Astaghfirullah al-Azeem',
      'SubhanAllahi wa bihamdihi',
      'SubhanAllah al-Azeem',
      'Allahumma salli ala Muhammad',
      'La hawla wa la quwwata',
      'Combined Tasbeeh',
    ];

    final sorted = state.dhikrCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = sorted.isNotEmpty ? sorted.first.value : 1;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: sorted.take(6).map((entry) {
          final name = entry.key < dhikrNames.length 
              ? dhikrNames[entry.key] 
              : 'Dhikr ${entry.key}';
          final pct = maxCount > 0 ? entry.value / maxCount : 0.0;
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    name,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: (pct * 1000).toInt(),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _gold.withValues(alpha: 0.4),
                                  _gold,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: _gold.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1000 - (pct * 1000).toInt(),
                          child: const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${entry.value}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMilestone() {
    final milestones = [100, 500, 1000, 5000, 10000, 50000, 100000, 500000, 1000000];
    final next = milestones.firstWhere(
      (m) => m > state.totalAllTime,
      orElse: () => 1000000,
    );
    final prev = milestones.lastWhere(
      (m) => m <= state.totalAllTime,
      orElse: () => 0,
    );
    final progress = prev < next ? (state.totalAllTime - prev) / (next - prev) : 0.0;
    final remaining = next - state.totalAllTime;
    final isComplete = state.totalAllTime >= 1000000;

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
                  isComplete ? 'ALL MILESTONES COMPLETED' : 'NEXT MILESTONE',
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
                      _formatNumber(state.totalAllTime),
                      style: TextStyle(
                        color: isComplete ? _gold : Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      ' / ${_formatNumber(next)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (!isComplete && remaining > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${_formatNumber(remaining)} remaining',
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
                  value: progress.clamp(0.0, 1.0),
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

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DHIKR CALENDAR TAB - 365-dot year grid
// ═══════════════════════════════════════════════════════════════════════════════
class _DhikrCalendarTab extends StatefulWidget {
  final TasbihState state;
  const _DhikrCalendarTab({required this.state});

  @override
  State<_DhikrCalendarTab> createState() => _DhikrCalendarTabState();
}

class _DhikrCalendarTabState extends State<_DhikrCalendarTab> {
  static const _gold = Color(0xFFC2A366);
  static const _cardBg = Color(0xFF0D0D0D);
  static const _hiveKey = 'dhikr_dots_color';

  DotsColorTheme _colorTheme = DotsColorTheme.emerald;

  @override
  void initState() {
    super.initState();
    _loadColorPref();
  }

  Future<void> _loadColorPref() async {
    final box = await Hive.openBox('settings');
    final idx = box.get(_hiveKey, defaultValue: 2) as int; // default emerald (index 2)
    if (idx >= 0 && idx < DotsColorTheme.values.length) {
      setState(() => _colorTheme = DotsColorTheme.values[idx]);
    }
  }

  Future<void> _saveColorPref(DotsColorTheme theme) async {
    final box = await Hive.openBox('settings');
    await box.put(_hiveKey, theme.index);
  }

  // Determine intensity bucket for dhikr daily count
  // Use adaptive thresholds based on user's target
  DayDotData _dhikrDataForDay(int dayOfYear) {
    final year = DateTime.now().year;
    final date = DateTime(year, 1, 1).add(Duration(days: dayOfYear - 1));
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final count = widget.state.dailyHistory[key] ?? 0;

    // Intensity thresholds: 0, 1-33, 34-99, 100+
    double intensity;
    if (count == 0) {
      intensity = 0.0;
    } else if (count <= 33) {
      intensity = 0.25;
    } else if (count <= 99) {
      intensity = 0.55;
    } else {
      intensity = 1.0;
    }
    return DayDotData(intensity: intensity, rawCount: count);
  }

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final history = widget.state.dailyHistory;

    // Calculate year stats
    int activeDays = 0;
    int yearTotal = 0;
    int bestDay = 0;
    history.forEach((key, count) {
      if (key.startsWith('$year-')) {
        if (count > 0) activeDays++;
        yearTotal += count;
        if (count > bestDay) bestDay = count;
      }
    });

    return Container(
      color: Colors.black, // High contrast pure black background
      child: CustomPaint(
        painter: _PremiumGridPainter(
          color: Colors.white.withValues(alpha: 0.03),
          spacing: 24,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          physics: const ClampingScrollPhysics(),
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
                year: year,
                colorTheme: _colorTheme,
                dataForDay: _dhikrDataForDay,
                subtitle: 'Dhikr • $year',
                legendLabels: const ['0', '1-33', '34-99', '100+'],
              ),
            ),
          const SizedBox(height: 14),
          // Color picker — inline, minimal
          DotsColorPicker(
            selected: _colorTheme,
            onChanged: (theme) {
              setState(() => _colorTheme = theme);
              _saveColorPref(theme);
            },
          ),

          // ══ scroll indicator ══
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              children: [
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.06))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Year Stats',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.18),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.06))),
              ],
            ),
          ),

          // ══ Year stats (below fold) ══
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Row(
              children: [
                _buildStatItem('$activeDays', 'Active Days'),
                Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.06)),
                _buildStatItem(_formatNumber(yearTotal), 'Year Total'),
                Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.06)),
                _buildStatItem(_formatNumber(bestDay), 'Best Day'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── tip card ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _colorTheme.color.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _colorTheme.color.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, color: _colorTheme.color.withValues(alpha: 0.4), size: 10),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Brighter dot = more dhikr that day. Count daily to fill your year.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.32),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _gold,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ADHKAR TAB - Morning/Evening Adhkar, 99 Names, Prophetic Duas
// ═══════════════════════════════════════════════════════════════════════════════
class _AdhkarTab extends StatefulWidget {
  final int initialSection;
  
  const _AdhkarTab({this.initialSection = 0});

  @override
  State<_AdhkarTab> createState() => _AdhkarTabState();
}

class _AdhkarTabState extends State<_AdhkarTab> {
  int _selectedSection = 0;
  Map<String, int> _adhkarProgress = {};
  int _namesLearned = 0;

  static const _gold = Color(0xFFC2A366);
  static const _cardBg = Color(0xFF0D0D0D);

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.initialSection;
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final box = await HiveBoxManager.get('adhkar_data');
      final today = DateTime.now().toIso8601String().split('T')[0];
      final saved = box.get('adhkar_progress_$today');
      if (saved != null && saved is Map) {
        setState(() => _adhkarProgress = Map<String, int>.from(saved));
      }
      final names = box.get('names_learned');
      if (names != null) setState(() => _namesLearned = names as int);
    } catch (_) {}
  }

  Future<void> _saveProgress() async {
    try {
      final box = await HiveBoxManager.get('adhkar_data');
      final today = DateTime.now().toIso8601String().split('T')[0];
      await box.put('adhkar_progress_$today', _adhkarProgress);
      await box.put('names_learned', _namesLearned);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSectionSelector(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: _buildSectionContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionSelector() {
    final sections = ['Morning', 'Evening', '99 Names', 'Duas'];
    final icons = [Icons.wb_sunny_outlined, Icons.nightlight_outlined, Icons.auto_awesome_outlined, Icons.favorite_outline];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: List.generate(sections.length, (i) {
          final sel = _selectedSection == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedSection = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? _gold.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(icons[i], size: 18, color: sel ? _gold : Colors.white.withValues(alpha: 0.3)),
                    const SizedBox(height: 3),
                    Text(
                      sections[i],
                      style: TextStyle(
                        color: sel ? _gold : Colors.white.withValues(alpha: 0.3),
                        fontSize: 10,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionContent() {
    switch (_selectedSection) {
      case 0:
        return _buildAdhkarList(
          _getMorningAdhkar(), 'Morning Adhkar', '\u0623\u0630\u0643\u0627\u0631 \u0627\u0644\u0635\u0628\u0627\u062D',
          Icons.wb_sunny_outlined,
        );
      case 1:
        return _buildAdhkarList(
          _getEveningAdhkar(), 'Evening Adhkar', '\u0623\u0630\u0643\u0627\u0631 \u0627\u0644\u0645\u0633\u0627\u0621',
          Icons.nightlight_outlined,
        );
      case 2:
        return _build99Names();
      case 3:
        return _buildPropheticDuas();
      default:
        return _buildAdhkarList(
          _getMorningAdhkar(), 'Morning Adhkar', '\u0623\u0630\u0643\u0627\u0631 \u0627\u0644\u0635\u0628\u0627\u062D',
          Icons.wb_sunny_outlined,
        );
    }
  }

  Widget _buildAdhkarList(List<Map<String, dynamic>> adhkar, String title, String arabic, IconData icon) {
    final completed = adhkar.where((a) => (_adhkarProgress[a['key']] ?? 0) >= (a['count'] as int)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(arabic, style: TextStyle(color: _gold.withValues(alpha: 0.5), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$completed/${adhkar.length}',
                  style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Adhkar items
        ...adhkar.map((dhikr) {
          final key = dhikr['key'] as String;
          final target = dhikr['count'] as int;
          final current = _adhkarProgress[key] ?? 0;
          final isDone = current >= target;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDone ? _gold.withValues(alpha: 0.04) : _cardBg.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDone ? _gold.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dhikr['arabic'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Amiri', height: 1.8),
                ),
                const SizedBox(height: 8),
                Text(
                  dhikr['translation'] as String,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '$current / $target',
                      style: TextStyle(
                        color: isDone ? _gold : Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (!isDone)
                      GestureDetector(
                        onTap: () {
                          setState(() => _adhkarProgress[key] = (current + 1).clamp(0, target));
                          _saveProgress();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _gold.withValues(alpha: 0.2)),
                          ),
                          child: Text('Tap +1', style: TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_rounded, color: _gold, size: 16),
                      ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _build99Names() {
    final names = _get99Names();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.auto_awesome_outlined, color: _gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Asma ul Husna', style: TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('\u0623\u0633\u0645\u0627\u0621 \u0627\u0644\u0644\u0647 \u0627\u0644\u062D\u0633\u0646\u0649', style: TextStyle(color: _gold.withValues(alpha: 0.5), fontSize: 12)),
                  ],
                ),
              ),
              Text(
                '$_namesLearned/${names.length}',
                style: TextStyle(color: _gold.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Names grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: names.asMap().entries.map((e) {
            final learned = e.key < _namesLearned;
            return GestureDetector(
              onTap: () {
                if (!learned && e.key <= _namesLearned) {
                  setState(() => _namesLearned = e.key + 1);
                  _saveProgress();
                }
              },
              child: Container(
                width: (MediaQuery.of(context).size.width - 56) / 3,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: learned ? _gold.withValues(alpha: 0.08) : _cardBg.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: learned ? _gold.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      e.value['arabic']!,
                      style: TextStyle(
                        color: learned ? _gold : Colors.white.withValues(alpha: 0.5),
                        fontSize: 16,
                        fontFamily: 'Amiri',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      e.value['english']!,
                      style: TextStyle(
                        color: learned ? Colors.white.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.3),
                        fontSize: 9,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPropheticDuas() {
    final duas = _getPropheticDuas();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.favorite_outline, color: _gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prophetic Duas', style: TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('Authentic supplications', style: TextStyle(color: _gold.withValues(alpha: 0.5), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Duas list
        ...duas.map((d) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                d['arabic']!,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Amiri', height: 1.8),
              ),
              const SizedBox(height: 8),
              Text(
                d['translation']!,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontStyle: FontStyle.italic, height: 1.5),
              ),
              const SizedBox(height: 6),
              Text(
                d['source']!,
                style: TextStyle(color: _gold.withValues(alpha: 0.4), fontSize: 10),
              ),
            ],
          ),
        )),
      ],
    );
  }

  // ─── DATA ───
  List<Map<String, dynamic>> _getMorningAdhkar() {
    return [
      {'key': 'morning_ayatul_kursi', 'arabic': '\u0627\u0644\u0644\u0651\u064E\u0647\u064F \u0644\u0627 \u0625\u0650\u0644\u0670\u0648\u0644\u064E \u0625\u0650\u0644\u0651\u064E\u0627 \u0647\u064F\u0648\u064E \u0627\u0644\u0652\u062D\u064E\u064A\u0651\u064F \u0627\u0644\u0652\u0642\u064E\u064A\u0651\u064F\u0648\u0645\u064F', 'translation': 'Allah, there is no god but He, the Living, the Self-Subsisting', 'count': 1},
      {'key': 'morning_ikhlas', 'arabic': '\u0642\u064F\u0644\u0652 \u0647\u064F\u0648\u064E \u0627\u0644\u0644\u0651\u064E\u0647\u064F \u0623\u064E\u062D\u064E\u062F\u064C', 'translation': 'Say: He is Allah, the One', 'count': 3},
      {'key': 'morning_falaq', 'arabic': '\u0642\u064F\u0644\u0652 \u0623\u064E\u0639\u064F\u0648\u0632\u064F \u0628\u0650\u0631\u064E\u0628\u0651\u0650 \u0627\u0644\u0652\u0641\u064E\u0644\u064E\u0642\u0650', 'translation': 'Say: I seek refuge in the Lord of daybreak', 'count': 3},
      {'key': 'morning_naas', 'arabic': '\u0642\u064F\u0644\u0652 \u0623\u064E\u0639\u064F\u0648\u0632\u064F \u0628\u0650\u0631\u064E\u0628\u0651\u0650 \u0627\u0644\u0646\u0651\u064E\u0627\u0633\u0650', 'translation': 'Say: I seek refuge in the Lord of mankind', 'count': 3},
      {'key': 'morning_master', 'arabic': '\u0627\u0644\u0644\u0651\u064E\u0647\u064F\u0645\u0651\u064E \u0623\u064E\u0646\u0652\u062A\u064E \u0631\u064E\u0628\u0651\u0650\u064A \u0644\u0627 \u0625\u0650\u0644\u0670\u0648\u0644\u064E \u0625\u0650\u0644\u0651\u064E\u0627 \u0623\u064E\u0646\u0652\u062A\u064E', 'translation': 'O Allah, You are my Lord, none has the right to be worshipped but You', 'count': 1},
      {'key': 'morning_subhanallah', 'arabic': '\u0633\u064F\u0628\u0652\u062D\u064E\u0627\u0646\u064E \u0627\u0644\u0644\u0651\u064E\u0647\u0650 \u0648\u064E\u0628\u0650\u062D\u064E\u0645\u0652\u062F\u0650\u0647\u0650', 'translation': 'Glory and praise be to Allah', 'count': 100},
    ];
  }

  List<Map<String, dynamic>> _getEveningAdhkar() {
    return [
      {'key': 'evening_ayatul_kursi', 'arabic': '\u0627\u0644\u0644\u0651\u064E\u0647\u064F \u0644\u0627 \u0625\u0650\u0644\u0670\u0648\u0644\u064E \u0625\u0650\u0644\u0651\u064E\u0627 \u0647\u064F\u0648\u064E \u0627\u0644\u0652\u062D\u064E\u064A\u0651\u064F \u0627\u0644\u0652\u0642\u064E\u064A\u0651\u064F\u0648\u0645\u064F', 'translation': 'Allah, there is no god but He, the Living, the Self-Subsisting', 'count': 1},
      {'key': 'evening_ikhlas', 'arabic': '\u0642\u064F\u0644\u0652 \u0647\u064F\u0648\u064E \u0627\u0644\u0644\u0651\u064E\u0647\u064F \u0623\u064E\u062D\u064E\u062F\u064C', 'translation': 'Say: He is Allah, the One', 'count': 3},
      {'key': 'evening_falaq', 'arabic': '\u0642\u064F\u0644\u0652 \u0623\u064E\u0639\u064F\u0648\u0632\u064F \u0628\u0650\u0631\u064E\u0628\u0651\u0650 \u0627\u0644\u0652\u0641\u064E\u0644\u064E\u0642\u0650', 'translation': 'Say: I seek refuge in the Lord of daybreak', 'count': 3},
      {'key': 'evening_naas', 'arabic': '\u0642\u064F\u0644\u0652 \u0623\u064E\u0639\u064F\u0648\u0632\u064F \u0628\u0650\u0631\u064E\u0628\u0651\u0650 \u0627\u0644\u0646\u0651\u064E\u0627\u0633\u0650', 'translation': 'Say: I seek refuge in the Lord of mankind', 'count': 3},
      {'key': 'evening_protection', 'arabic': '\u0623\u064E\u0639\u064F\u0648\u0632\u064F \u0628\u0650\u0643\u064E\u0644\u0650\u0645\u064E\u0627\u062A\u0650 \u0627\u0644\u0644\u0651\u064E\u0647\u0650 \u0627\u0644\u062A\u0651\u064E\u062A\u0641\u064E\u0645\u0650 \u0645\u0650\u0646 \u0634\u064E\u0631\u0651\u0650 \u0645\u064E\u0627 \u062E\u064E\u0644\u064E\u0642\u064E', 'translation': 'I seek refuge in the perfect words of Allah from the evil of what He created', 'count': 3},
      {'key': 'evening_subhanallah', 'arabic': '\u0633\u064F\u0628\u0652\u062D\u064E\u0627\u0646\u064E \u0627\u0644\u0644\u0651\u064E\u0647\u0650 \u0648\u064E\u0628\u0650\u062D\u064E\u0645\u0652\u062F\u0650\u0647\u0650', 'translation': 'Glory and praise be to Allah', 'count': 100},
    ];
  }

  List<Map<String, String>> _get99Names() {
    return [
      {'arabic': '\u0627\u0644\u0631\u0651\u064E\u062D\u0652\u0645\u064E\u0646\u064F', 'english': 'The Most Gracious'},
      {'arabic': '\u0627\u0644\u0631\u0651\u064E\u062D\u0650\u064A\u0645\u064F', 'english': 'The Most Merciful'},
      {'arabic': '\u0627\u0644\u0652\u0645\u064E\u0644\u0650\u0643\u064F', 'english': 'The King'},
      {'arabic': '\u0627\u0644\u0652\u0642\u064F\u062F\u0651\u064F\u0648\u0633\u064F', 'english': 'The Most Holy'},
      {'arabic': '\u0627\u0644\u0633\u0651\u064E\u0644\u0627\u0645\u064F', 'english': 'The Source of Peace'},
      {'arabic': '\u0627\u0644\u0652\u0645\u064F\u0624\u0652\u0645\u0650\u0646\u064F', 'english': 'The Guardian of Faith'},
      {'arabic': '\u0627\u0644\u0652\u0645\u064F\u0647\u064E\u064A\u0652\u0645\u0650\u0646\u064F', 'english': 'The Protector'},
      {'arabic': '\u0627\u0644\u0652\u0639\u064E\u0632\u0650\u064A\u0632\u064F', 'english': 'The Mighty'},
      {'arabic': '\u0627\u0644\u0652\u062C\u064E\u0628\u0651\u064E\u0627\u0631\u064F', 'english': 'The Compeller'},
      {'arabic': '\u0627\u0644\u0652\u0645\u064F\u062A\u064E\u0643\u064E\u0628\u0651\u0650\u0631\u064F', 'english': 'The Majestic'},
      {'arabic': '\u0627\u0644\u0652\u062E\u064E\u0627\u0644\u0650\u0642\u064F', 'english': 'The Creator'},
      {'arabic': '\u0627\u0644\u0652\u0628\u064E\u0627\u0631\u0650\u0626\u064F', 'english': 'The Evolver'},
      {'arabic': '\u0627\u0644\u0652\u0645\u064F\u0635\u064E\u0648\u0651\u0650\u0631\u064F', 'english': 'The Fashioner'},
      {'arabic': '\u0627\u0644\u0652\u063A\u064E\u0641\u0651\u064E\u0627\u0631\u064F', 'english': 'The Forgiver'},
      {'arabic': '\u0627\u0644\u0652\u0642\u064E\u0647\u0651\u064E\u0627\u0631\u064F', 'english': 'The Subduer'},
      {'arabic': '\u0627\u0644\u0652\u0648\u064E\u0647\u0651\u064E\u0627\u0628\u064F', 'english': 'The Bestower'},
      {'arabic': '\u0627\u0644\u0631\u0651\u064E\u0632\u0651\u064E\u0627\u0642\u064F', 'english': 'The Provider'},
      {'arabic': '\u0627\u0644\u0652\u0641\u064E\u062A\u0651\u064E\u0627\u062D\u064F', 'english': 'The Opener'},
      {'arabic': '\u0627\u064E\u0644\u0652\u0639\u064E\u0644\u0650\u064A\u0652\u0645\u064F', 'english': 'The All-Knowing'},
      {'arabic': '\u0627\u0644\u0652\u0642\u064E\u0627\u0628\u0650\u0636\u064F', 'english': 'The Constrictor'},
      {'arabic': '\u0627\u0644\u0652\u0628\u064E\u0627\u0633\u0650\u0637\u064F', 'english': 'The Expander'},
      {'arabic': '\u0627\u0644\u0652\u062E\u064E\u0627\u0641\u0650\u0636\u064F', 'english': 'The Abaser'},
      {'arabic': '\u0627\u0644\u0631\u0651\u064E\u0627\u0641\u0650\u0639\u064F', 'english': 'The Exalter'},
      {'arabic': '\u0627\u0644\u0652\u0645\u064F\u0639\u0650\u0632\u0651\u064F', 'english': 'The Honorer'},
      {'arabic': '\u0627\u0644\u0645\u064F\u0632\u0650\u0644\u0651\u064F', 'english': 'The Humiliator'},
      {'arabic': '\u0627\u0644\u0633\u0651\u064E\u0645\u0650\u064A\u0639\u064F', 'english': 'The All-Hearing'},
      {'arabic': '\u0627\u0644\u0652\u0628\u064E\u0635\u0650\u064A\u0631\u064F', 'english': 'The All-Seeing'},
      {'arabic': '\u0627\u0644\u0652\u062D\u064E\u0643\u064E\u0645\u064F', 'english': 'The Judge'},
      {'arabic': '\u0627\u0644\u0652\u0639\u064E\u062F\u0652\u0644\u064F', 'english': 'The Just'},
      {'arabic': '\u0627\u0644\u0644\u0651\u064E\u0637\u0650\u064A\u0641\u064F', 'english': 'The Subtle One'},
    ];
  }

  List<Map<String, String>> _getPropheticDuas() {
    return [
      {'arabic': '\u0631\u064E\u0628\u0651\u064E\u0646\u064E\u0627 \u0622\u062A\u0650\u0646\u064E\u0627 \u0641\u0650\u064A \u0627\u0644\u062F\u0651\u064F\u0646\u0652\u064A\u064E\u0627 \u062D\u064E\u0633\u064E\u0646\u064E\u0629\u064B \u0648\u064E\u0641\u0650\u064A \u0627\u0644\u0652\u0622\u062E\u0650\u0631\u064E\u0629\u0650 \u062D\u064E\u0633\u064E\u0646\u064E\u0629\u064B \u0648\u064E\u0642\u0650\u0646\u064E\u0627 \u0639\u064E\u0632\u064E\u0628\u064E \u0627\u0644\u0646\u0651\u064E\u0627\u0631\u0650', 'translation': 'Our Lord, give us good in this world and good in the Hereafter, and protect us from the punishment of the Fire.', 'source': 'Al-Baqarah 2:201'},
      {'arabic': '\u0644\u064E\u0627 \u062A\u062E\u0632\u064A\u0646\u064A \u0628\u064A\u0646\u064A \u0648\u0628\u064A\u0646\u0643َ شَرًّا', 'translation': 'Do not place between me and them (my enemies) any barrier of evil.', 'source': 'Al-Mumtahanah 60:5'},
      {'arabic': '\u0631\u064E\u0628\u0651\u064E\u0646\u064E\u0627 \u0644\u0627 \u062A\u064F\u0632\u0650\u063A\u0652 \u0642\u064F\u0644\u064F\u0648\u0628\u064E\u0646\u064E\u0627 \u0628\u064E\u0639\u0652\u062F\u064E \u0625\u0650\u0632\u0652 \u0647\u064E\u062F\u064E\u064A\u0652\u062A\u064E\u0646\u064E\u0627', 'translation': 'Our Lord, do not let our hearts deviate after You have guided us.', 'source': 'Aal Imran 3:8'},
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACHIEVEMENTS TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _AchievementsTab extends StatelessWidget {
  final TasbihState state;

  const _AchievementsTab({required this.state});

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
                            letterSpacing: 0.2,
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
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: achievements.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (ctx, i) => _buildAchievementCard(achievements[i]),
        ),
      ],
    );
  }

  Widget _buildAchievementCard(Map<String, dynamic> achievement) {
    final unlocked = achievement['unlocked'] as bool;
    final tier = achievement['tier'] as String;
    final progress = achievement['progress'] as double;
    final tierColor = _getTierColor(tier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unlocked ? tierColor.withValues(alpha: 0.05) : _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unlocked
              ? tierColor.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: unlocked
                      ? tierColor.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.03),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  achievement['icon'] as IconData,
                  color: unlocked
                      ? tierColor
                      : Colors.white.withValues(alpha: 0.15),
                  size: 20,
                ),
              ),
              if (unlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tier.toUpperCase(),
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            achievement['title'] as String,
            style: TextStyle(
              color: unlocked
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'MILESTONE',
            style: TextStyle(
              color: unlocked
                  ? tierColor.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.2),
              fontSize: 9,
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
    final total = state.totalAllTime;
    final streak = state.streakDays;
    final targets = state.completedTargets;

    return [
      {
        'icon': Icons.spa_rounded,
        'title': 'First Step',
        'description': 'Complete your first dhikr',
        'unlocked': total > 0,
        'tier': 'Bronze',
        'progress': total > 0 ? 1.0 : 0.0,
      },
      {
        'icon': Icons.grade_rounded,
        'title': 'Century Club',
        'description': 'Reach 100 total dhikr',
        'unlocked': total >= 100,
        'tier': 'Bronze',
        'progress': (total / 100).clamp(0.0, 1.0),
      },
      {
        'icon': Icons.local_fire_department_rounded,
        'title': 'Week Warrior',
        'description': 'Maintain a 7-day streak',
        'unlocked': streak >= 7,
        'tier': 'Silver',
        'progress': (streak / 7).clamp(0.0, 1.0),
      },
      {
        'icon': Icons.ads_click_rounded,
        'title': 'Goal Getter',
        'description': 'Complete daily target 10 times',
        'unlocked': targets >= 10,
        'tier': 'Silver',
        'progress': (targets / 10).clamp(0.0, 1.0),
      },
      {
        'icon': Icons.brightness_auto_rounded,
        'title': 'Devoted',
        'description': 'Reach 1,000 total dhikr',
        'unlocked': total >= 1000,
        'tier': 'Gold',
        'progress': (total / 1000).clamp(0.0, 1.0),
      },
      {
        'icon': Icons.nightlight_round,
        'title': 'Month Master',
        'description': 'Maintain a 30-day streak',
        'unlocked': streak >= 30,
        'tier': 'Gold',
        'progress': (streak / 30).clamp(0.0, 1.0),
      },
      {
        'icon': Icons.auto_awesome_rounded,
        'title': 'Rising Star',
        'description': 'Reach 10,000 total dhikr',
        'unlocked': total >= 10000,
        'tier': 'Platinum',
        'progress': (total / 10000).clamp(0.0, 1.0),
      },
      {
        'icon': Icons.diamond_rounded,
        'title': 'Dhikr Master',
        'description': 'Reach 100,000 total dhikr',
        'unlocked': total >= 100000,
        'tier': 'Platinum',
        'progress': (total / 100000).clamp(0.0, 1.0),
      },
    ];
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
