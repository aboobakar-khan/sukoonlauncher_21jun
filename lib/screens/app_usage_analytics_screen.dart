import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screen_time_provider.dart';
import '../providers/theme_provider.dart';
import '../services/native_app_blocker_service.dart';

// ─── Design Tokens ──────────────────────────────────────────────────────────
const _bg = Color(0xFF000000);
final _card = Colors.white.withValues(alpha: 0.04);
final _border = Colors.white.withValues(alpha: 0.07);
final _textHigh = Colors.white.withValues(alpha: 0.85);
final _textMed = Colors.white.withValues(alpha: 0.45);
final _textLow = Colors.white.withValues(alpha: 0.22);

/// App Usage Analytics — Apple/Samsung inspired minimal design.
/// Shows: daily bar chart, today's per-app list, 7-day trend.
/// All data comes from Android UsageStatsManager — zero extra battery cost.
class AppUsageAnalyticsScreen extends ConsumerStatefulWidget {
  const AppUsageAnalyticsScreen({super.key});

  @override
  ConsumerState<AppUsageAnalyticsScreen> createState() =>
      _AppUsageAnalyticsScreenState();
}

class _AppUsageAnalyticsScreenState
    extends ConsumerState<AppUsageAnalyticsScreen> {
  // Which day index is selected in the bar chart (0 = today)
  int _selectedDay = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // If data already exists (pre-fetched by caller), render immediately
    // and refresh silently in background. If no data yet, show loader.
    final hasData = ref.read(screenTimeProvider).dailyStats.isNotEmpty;
    if (hasData) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _silentRefresh());
    } else {
      _load();
    }
  }

  /// Full load — shows spinner (only used when there is truly no data yet)
  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    await ref.read(screenTimeProvider.notifier).refreshDailyStats();
    if (mounted) setState(() => _loading = false);
  }

  /// Silent background refresh — UI stays visible, data updates when ready
  Future<void> _silentRefresh() async {
    if (_loading) return;
    await ref.read(screenTimeProvider.notifier).refreshDailyStats();
  }

  /// Letter avatar — zero async, renders instantly, looks clean
  Widget _appIcon(String appName, String packageName, Color accent, {double size = 36}) {
    final letter = appName.isNotEmpty ? appName[0].toUpperCase() : '?';
    // Derive a stable hue from the package name for variety
    final hue = (packageName.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
    final color = HSLColor.fromAHSL(1.0, hue, 0.45, 0.38).toColor();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: size * 0.44,
            fontWeight: FontWeight.w600,
            color: color.withValues(alpha: 0.9),
            height: 1,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(themeColorProvider).color;
    final st = ref.watch(screenTimeProvider);
    final daily = st.dailyStats; // index 0 = today

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'App Timer',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textHigh,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: _textMed),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, size: 20, color: _textMed),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading && daily.isEmpty
          ? _buildLoading(accent)
          : daily.isEmpty
              ? _buildNoPermission(accent)
              : _buildContent(accent, daily),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOADING
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLoading(Color accent) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: accent.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text('Loading usage data…',
              style: TextStyle(color: _textMed, fontSize: 13)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NO PERMISSION
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNoPermission(Color accent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_clock_outlined, size: 28, color: accent.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            Text(
              'Usage Access Required',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textHigh),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Grant "Usage Access" permission so Sukoon can show your app timer data.',
              style: TextStyle(fontSize: 13, color: _textMed, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () async {
                await NativeAppBlockerService.requestUsageStatsPermission();
                await Future.delayed(const Duration(milliseconds: 800));
                await _load();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                ),
                child: Text(
                  'Grant Access',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MAIN CONTENT
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildContent(Color accent, List<DailyUsageStat> daily) {
    final selected = _selectedDay < daily.length ? daily[_selectedDay] : null;
    final todayStat = daily.isNotEmpty ? daily[0] : null;

    return RefreshIndicator(
      onRefresh: _load,
      color: accent,
      backgroundColor: const Color(0xFF111111),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 8),

          // ═══════════════════════════════════════════════════════════════
          // 1. TODAY HERO — big number like Apple Screen Time
          // ═══════════════════════════════════════════════════════════════
          if (todayStat != null) _buildTodayHero(accent, todayStat),

          const SizedBox(height: 28),

          // ═══════════════════════════════════════════════════════════════
          // 2. 7-DAY BAR CHART
          // ═══════════════════════════════════════════════════════════════
          _buildSectionHeader('DAILY AVERAGE', subtitle: '7 days'),
          const SizedBox(height: 12),
          _buildBarChart(accent, daily),

          const SizedBox(height: 28),

          // ═══════════════════════════════════════════════════════════════
          // 3. SELECTED DAY APP LIST
          // ═══════════════════════════════════════════════════════════════
          if (selected != null) ...[
            _buildSectionHeader(
              _selectedDay == 0 ? 'TODAY — APP BREAKDOWN' : '${_dayLabel(selected.date)} — APP BREAKDOWN',
            ),
            const SizedBox(height: 12),
            _buildAppList(accent, selected),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TODAY HERO CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTodayHero(Color accent, DailyUsageStat today) {
    final h = today.totalTime.inHours;
    final m = today.totalTime.inMinutes.remainder(60);
    final topApp = today.apps.isNotEmpty ? today.apps.first : null;

    // Compare today vs YESTERDAY (index 1 in dailyStats)
    final st = ref.watch(screenTimeProvider);
    final daily = st.dailyStats;
    final yesterday = daily.length > 1 ? daily[1] : null;

    // Percentage change: (today - yesterday) / yesterday * 100
    String? pctLabel;
    bool isMore = false;
    if (yesterday != null && yesterday.totalTime.inMinutes > 0) {
      final todayMs = today.totalTime.inMilliseconds.toDouble();
      final ystMs = yesterday.totalTime.inMilliseconds.toDouble();
      final pct = ((todayMs - ystMs) / ystMs * 100).round().abs();
      isMore = todayMs > ystMs;
      pctLabel = isMore ? '+$pct% vs yesterday' : '-$pct% vs yesterday';
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today', style: TextStyle(fontSize: 12, color: _textMed, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                h > 0 ? '${h}h ${m}m' : '${m}m',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w200,
                  color: _textHigh,
                  letterSpacing: -1,
                  height: 1.0,
                ),
              ),
              const Spacer(),
              if (pctLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isMore
                        ? Colors.orange.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isMore
                          ? Colors.orange.withValues(alpha: 0.2)
                          : Colors.green.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMore ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 12,
                        color: isMore
                            ? Colors.orange.withValues(alpha: 0.7)
                            : Colors.green.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        pctLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isMore
                              ? Colors.orange.withValues(alpha: 0.9)
                              : Colors.green.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (topApp != null) ...[
            const SizedBox(height: 14),
            Container(height: 0.5, color: _border),
            const SizedBox(height: 14),
            Row(
              children: [
                _appIcon(topApp.appName, topApp.packageName, accent, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Most used',
                        style: TextStyle(fontSize: 10, color: _textMed),
                      ),
                      Text(
                        topApp.appName,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textHigh),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatDuration(topApp.usageTime),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: accent.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 7-DAY BAR CHART
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBarChart(Color accent, List<DailyUsageStat> daily) {
    if (daily.isEmpty) return const SizedBox.shrink();

    // Max for scaling
    final maxMs = daily.fold<int>(0, (m, d) => math.max(m, d.totalTime.inMilliseconds));
    if (maxMs == 0) return const SizedBox.shrink();

    final reversed = daily.reversed.toList(); // oldest → newest (left → right)

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          // Bars
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(reversed.length, (i) {
                final day = reversed[i];
                final originalIndex = reversed.length - 1 - i; // 0 = today
                final isSelected = _selectedDay == originalIndex;
                final ratio = maxMs > 0 ? day.totalTime.inMilliseconds / maxMs : 0.0;
                final barH = math.max(4.0, ratio * 84);
                final barColor = isSelected
                    ? accent
                    : accent.withValues(alpha: 0.25);

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() => _selectedDay = originalIndex);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Time label above selected bar
                        AnimatedOpacity(
                          opacity: isSelected ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              _formatDurationShort(day.totalTime),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          height: barH,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          // Day labels
          Row(
            children: List.generate(reversed.length, (i) {
              final day = reversed[i];
              final originalIndex = reversed.length - 1 - i;
              final isSelected = _selectedDay == originalIndex;
              return Expanded(
                child: Text(
                  originalIndex == 0 ? 'Today' : _shortDayLabel(day.date),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected ? accent : _textLow,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // APP LIST FOR SELECTED DAY
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAppList(Color accent, DailyUsageStat selected) {
    final apps = selected.apps;
    if (apps.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Center(
          child: Text('No usage data', style: TextStyle(color: _textLow, fontSize: 13)),
        ),
      );
    }

    final maxMs = apps.fold<int>(0, (m, a) => math.max(m, a.usageTime.inMilliseconds));
    final totalMs = selected.totalTime.inMilliseconds;
    final st = ref.watch(screenTimeProvider);

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: List.generate(math.min(apps.length, 10), (i) {
          final app = apps[i];
          final ratio = maxMs > 0 ? app.usageTime.inMilliseconds / maxMs : 0.0;
          final pct = totalMs > 0
              ? (app.usageTime.inMilliseconds / totalMs * 100).round()
              : 0;

          // Pick a color variant for each bar
          final barColor = HSLColor.fromColor(accent)
              .withLightness(
                ((HSLColor.fromColor(accent).lightness - 0.05 * i).clamp(0.3, 0.75)),
              )
              .withSaturation(
                (HSLColor.fromColor(accent).saturation * (1 - 0.05 * i)).clamp(0.2, 1.0),
              )
              .toColor();

          final hasTimer = st.hasTimerFor(app.packageName);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Row(
                  children: [
                    // App icon
                    _appIcon(app.appName, app.packageName, accent, size: 36),
                    const SizedBox(width: 12),
                    // App name + rank
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.appName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _textHigh,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '$pct% of total',
                            style: TextStyle(fontSize: 11, color: _textLow),
                          ),
                        ],
                      ),
                    ),
                    // Duration
                    Text(
                      _formatDuration(app.usageTime),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: i == 0 ? accent : _textHigh,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // ── Timer toggle icon ──
                    GestureDetector(
                      onTap: () async {
                        if (hasTimer) {
                          await ref.read(screenTimeProvider.notifier).removeAppTimer(app.packageName);
                        } else {
                          // Enable feature if not already on
                          if (!st.featureEnabled) {
                            await ref.read(screenTimeProvider.notifier).setEnabled(true);
                          }
                          await ref.read(screenTimeProvider.notifier).addAppTimer(
                            app.packageName,
                            defaultMinutes: 15,
                            alwaysAsk: true,
                          );
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: hasTimer
                              ? accent.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: hasTimer
                                ? accent.withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Icon(
                          hasTimer ? Icons.timer_rounded : Icons.timer_outlined,
                          size: 16,
                          color: hasTimer
                              ? accent
                              : Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Progress bar
              Padding(
                padding: const EdgeInsets.fromLTRB(62, 0, 14, 10),
                child: LayoutBuilder(builder: (ctx, box) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Stack(
                      children: [
                        Container(
                          height: 3,
                          width: box.maxWidth,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          height: 3,
                          width: box.maxWidth * ratio,
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              if (i < math.min(apps.length, 10) - 1)
                Container(height: 0.5, color: _border, margin: const EdgeInsets.symmetric(horizontal: 14)),
            ],
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, {String? subtitle}) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: _textLow,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: _textLow.withValues(alpha: 0.6)),
          ),
        ],
      ],
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${d.inSeconds}s';
  }

  String _formatDurationShort(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h${m > 0 ? ' ${m}m' : ''}';
    if (m > 0) return '${m}m';
    return '${d.inSeconds}s';
  }

  String _dayLabel(String date) {
    // "2026-03-05" → "Thu, Mar 5"
    try {
      final parts = date.split('-');
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${days[dt.weekday - 1]}, ${months[dt.month]} ${dt.day}';
    } catch (_) {
      return date;
    }
  }

  String _shortDayLabel(String date) {
    try {
      final parts = date.split('-');
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      return days[dt.weekday - 1];
    } catch (_) {
      return '';
    }
  }
}
