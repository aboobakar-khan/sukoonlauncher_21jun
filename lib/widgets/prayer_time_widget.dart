import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/theme_provider.dart';
import '../providers/display_settings_provider.dart';
import '../providers/fasting_provider.dart';
import '../features/prayer_alarm/providers/prayer_alarm_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Time-of-day period — drives the widget visual theme
// ─────────────────────────────────────────────────────────────────────────────

enum _DayPeriod { morning, afternoon, evening, night }

_DayPeriod _getDayPeriod() {
  final hour = DateTime.now().hour;
  if (hour >= 4 && hour < 12) return _DayPeriod.morning;
  if (hour >= 12 && hour < 17) return _DayPeriod.afternoon;
  if (hour >= 17 && hour < 20) return _DayPeriod.evening;
  return _DayPeriod.night;
}

class _PeriodTheme {
  final List<Color> gradientColors;
  final List<double> gradientStops;
  final Color accentOverlay;
  final IconData icon;
  final String label;

  const _PeriodTheme({
    required this.gradientColors,
    required this.gradientStops,
    required this.accentOverlay,
    required this.icon,
    required this.label,
  });
}

_PeriodTheme _themeForPeriod(_DayPeriod period, Color accentColor) {
  switch (period) {
    case _DayPeriod.morning:
      return _PeriodTheme(
        gradientColors: [
          const Color(0xFF0D1B2E),
          const Color(0xFF162840),
          accentColor.withValues(alpha: 0.08),
        ],
        gradientStops: const [0.0, 0.55, 1.0],
        accentOverlay: const Color(0xFFFDB347),   // warm sunrise gold
        icon: Icons.wb_twilight_rounded,
        label: 'Morning',
      );
    case _DayPeriod.afternoon:
      return _PeriodTheme(
        gradientColors: [
          const Color(0xFF0A1A0E),
          const Color(0xFF0E2014),
          accentColor.withValues(alpha: 0.07),
        ],
        gradientStops: const [0.0, 0.55, 1.0],
        accentOverlay: const Color(0xFF6FB86A),   // midday green
        icon: Icons.wb_sunny_rounded,
        label: 'Afternoon',
      );
    case _DayPeriod.evening:
      return _PeriodTheme(
        gradientColors: [
          const Color(0xFF1A0D1A),
          const Color(0xFF260D26),
          accentColor.withValues(alpha: 0.07),
        ],
        gradientStops: const [0.0, 0.55, 1.0],
        accentOverlay: const Color(0xFFE87B40),   // sunset orange
        icon: Icons.wb_sunny_outlined,
        label: 'Evening',
      );
    case _DayPeriod.night:
      return _PeriodTheme(
        gradientColors: [
          const Color(0xFF0A1628),
          const Color(0xFF0D1E35),
          accentColor.withValues(alpha: 0.06),
        ],
        gradientStops: const [0.0, 0.55, 1.0],
        accentOverlay: const Color(0xFF7896E2),   // midnight blue
        icon: Icons.nights_stay_rounded,
        label: 'Night',
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PrayerTimeWidget — Unified Ramadan-focused card with time-of-day theming
// Auto-refreshes every minute to keep countdown + next-prayer current.
// Battery-friendly: one tick/min (not every second), timer cancelled on dispose.
// ─────────────────────────────────────────────────────────────────────────────

class PrayerTimeWidget extends ConsumerStatefulWidget {
  final bool forceHidePrayer;
  const PrayerTimeWidget({super.key, this.forceHidePrayer = false});

  @override
  ConsumerState<PrayerTimeWidget> createState() => _PrayerTimeWidgetState();
}

class _PrayerTimeWidgetState extends ConsumerState<PrayerTimeWidget> {
  Timer? _minuteTimer;
  // Tracks the last minute so we only rebuild when the minute actually changes
  int _lastMinute = -1;
  // Tracks the current day — triggers API re-fetch when date rolls over
  int _lastDay = -1;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _lastMinute = now.minute;
    _lastDay = now.day;
    _scheduleNextMinuteTick();

    // Also trigger a re-fetch if prayer times are not yet loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final alarmState = ref.read(prayerAlarmProvider);
      if (alarmState.todayTimes == null && alarmState.isSetupComplete) {
        ref.read(prayerAlarmProvider.notifier).fetchTodayPrayerTimes();
      }
      final fastState = ref.read(fastingProvider);
      if (!fastState.isLoaded && fastState.status != FastingStatus.loading) {
        ref.read(fastingProvider.notifier).fetch();
      }
    });
  }

  /// Schedules a one-shot timer that fires at the next whole minute boundary.
  /// On fire it rebuilds (if the minute changed) then re-schedules itself.
  /// This is far more battery-efficient than a periodic 1s timer because:
  /// - Timer wakes the CPU once per minute instead of 60x per minute.
  /// - The widget skips the setState if the minute hasn't actually advanced
  ///   (defensive guard against sub-second re-fires).
  void _scheduleNextMinuteTick() {
    _minuteTimer?.cancel();
    final now = DateTime.now();
    // Seconds until the next :00 of the next minute
    final secondsUntilNextMinute = 60 - now.second;
    _minuteTimer = Timer(Duration(seconds: secondsUntilNextMinute), _onMinuteTick);
  }

  void _onMinuteTick() {
    if (!mounted) return;
    final now = DateTime.now();
    final currentMinute = now.minute;
    final currentDay = now.day;

    // Day rolled over midnight → fetch new prayer & fasting times for today
    if (currentDay != _lastDay) {
      _lastDay = currentDay;
      // Non-blocking: fetch runs in background; UI rebuilds when provider updates
      final alarmState = ref.read(prayerAlarmProvider);
      if (alarmState.isSetupComplete) {
        ref.read(prayerAlarmProvider.notifier).fetchTodayPrayerTimes();
      }
      ref.read(fastingProvider.notifier).fetch();
    }

    if (currentMinute != _lastMinute) {
      _lastMinute = currentMinute;
      setState(() {}); // Redraw countdown + next prayer
    }
    // Re-schedule for the next minute boundary
    _scheduleNextMinuteTick();
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ DO NOT use `const` here. The parent's setState (fired every minute by
    // the timer) must propagate to this child so _getNextPrayer re-evaluates
    // against DateTime.now(). Using `const` makes Flutter skip the rebuild
    // because it considers the widget unchanged — this caused the bug where
    // the widget showed "Dhuhr" even after Maghrib time arrived.
    //
    // The _minuteKey forces Flutter to treat this as a new widget each minute,
    // guaranteeing the ConsumerWidget's build() re-runs with fresh time data.
    return _PrayerTimeWidgetContent(key: ValueKey(_lastMinute), forceHidePrayer: widget.forceHidePrayer);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal content — rebuilds every minute via the parent's ValueKey change,
// ensuring _getNextPrayer always evaluates against the current time.
// ─────────────────────────────────────────────────────────────────────────────

class _PrayerTimeWidgetContent extends ConsumerWidget {
  final bool forceHidePrayer;
  const _PrayerTimeWidgetContent({super.key, this.forceHidePrayer = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displaySettingsProvider);
    if ((!display.showPrayerWidget || forceHidePrayer) && !display.showFastingWidget) {
      return const SizedBox.shrink();
    }

    final accent = ref.watch(themeColorProvider).color;
    final alarmState = ref.watch(prayerAlarmProvider);
    final fastingState = ref.watch(fastingProvider);

    final nextPrayer = (display.showPrayerWidget && !forceHidePrayer) ? _getNextPrayer(alarmState, display.use24HourFormat) : null;
    final fastingRow = display.showFastingWidget ? _getFastingRow(fastingState, display.use24HourFormat) : null;

    // Ramadan day: Hijri month 9 = Ramadan
    final hijri = HijriCalendar.fromDate(DateTime.now());
    final isRamadan = hijri.hMonth == 9;
    final ramadanDay = isRamadan ? (hijri.hDay + display.ramadanDayOffset).clamp(1, 30) : 0;

    if (nextPrayer == null && fastingRow == null) return const SizedBox.shrink();

    // ── Time-of-day theming ──
    final period = _getDayPeriod();
    final periodTheme = _themeForPeriod(period, accent);
    final overlayColor = periodTheme.accentOverlay;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: periodTheme.gradientColors,
          stops: periodTheme.gradientStops,
        ),
        border: Border.all(
          color: overlayColor.withValues(alpha: 0.18),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: overlayColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // ── Period icon top-right decoration ──
          Positioned(
            top: -6,
            right: 16,
            child: _PeriodDecoration(
              color: overlayColor,
              icon: periodTheme.icon,
              period: period,
            ),
          ),

          // ── Period badge top-left ──
          Positioned(
            top: 8,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: overlayColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: overlayColor.withValues(alpha: 0.25),
                  width: 0.6,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(periodTheme.icon, size: 9, color: overlayColor.withValues(alpha: 0.8)),
                  const SizedBox(width: 4),
                  Text(
                    periodTheme.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: overlayColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Ramadan Day badge — top center ──
          if (isRamadan && display.showFastingWidget)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withValues(alpha: 0.22), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.nights_stay_rounded, size: 9, color: accent.withValues(alpha: 0.7)),
                      const SizedBox(width: 5),
                      Text(
                        'RAMADAN · DAY $ramadanDay',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: accent.withValues(alpha: 0.80),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Padding(
            padding: EdgeInsets.fromLTRB(18, isRamadan && display.showFastingWidget ? 34 : 30, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (nextPrayer != null)
                  _PrayerRow(prayer: nextPrayer, accent: overlayColor),

                if (nextPrayer != null && fastingRow != null) ...[
                  const SizedBox(height: 10),
                  _Divider(accent: overlayColor),
                  const SizedBox(height: 10),
                ],

                if (fastingRow != null)
                  _FastingRow(
                    data: fastingRow,
                    accent: overlayColor,
                    onRetry: (fastingState.status == FastingStatus.error)
                        ? () => ref.read(fastingProvider.notifier).fetch()
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Next Prayer ──────────────────────────────────────────────────────────

  _PrayerData? _getNextPrayer(PrayerAlarmState alarmState, bool use24h) {
    if (alarmState.todayTimes == null) return null;
    // Include Sunrise between Fajr and Dhuhr so users see countdown to sunrise
    const prayers = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final now = DateTime.now();
    final fmt = use24h ? 'HH:mm' : 'h:mm a';

    // ── Step 1: find the next prayer still in the future today ──
    for (final name in prayers) {
      final timeStr = alarmState.effectiveTimesMap[name];
      if (timeStr == null) continue;
      final parts = timeStr.split(':');
      if (parts.length != 2) continue;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final target = DateTime(now.year, now.month, now.day, h, m);
      if (target.isAfter(now)) {
        final diff = target.difference(now);
        return _PrayerData(
          name: name,
          time: DateFormat(fmt).format(target),
          countdown: _fmtDiff(diff),
          progress: 1.0 - (diff.inMinutes / 1440.0).clamp(0.0, 1.0),
        );
      }
    }

    // ── Step 2: all prayers passed today → show Fajr tomorrow ──
    // Get tomorrow's specific Fajr time (tomorrow's base API time + offset).
    final tomorrow = now.add(const Duration(days: 1));
    final fajrStr = alarmState.effectiveTimeFor('Fajr', tomorrow);
    if (fajrStr != null) {
      final parts = fajrStr.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final target = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, h, m);
        final diff = target.difference(now);
        return _PrayerData(
          name: 'Fajr',
          time: DateFormat(fmt).format(target),
          countdown: _fmtDiff(diff),
          progress: 1.0 - (diff.inMinutes / 1440.0).clamp(0.0, 1.0),
        );
      }
    }

    return null;
  }

  // ─── Fasting row ──────────────────────────────────────────────────────────

  _FastingData? _getFastingRow(FastingState state, bool use24h) {
    final fmt = use24h ? 'HH:mm' : 'h:mm a';
    if (state.status == FastingStatus.loading) {
      return const _FastingData(
        icon: Icons.nightlight_round,
        label: 'Loading…',
        time: '',
        countdown: '',
        isActive: false,
        isLoading: true,
      );
    }
    if (state.status == FastingStatus.error || !state.isLoaded) {
      final msg = (state.errorMessage ?? '').contains('Location')
          ? 'Set location in Settings'
          : 'Tap to retry';
      return _FastingData(
        icon: Icons.nightlight_round,
        label: msg,
        time: '',
        countdown: '',
        isActive: false,
      );
    }

    final now = DateTime.now();
    final sahur = _parse12h(state.times!.sahur, now);
    final iftar = _parse12h(state.times!.iftar, now);
    if (sahur == null || iftar == null) return null;

    final sahurDisplay = DateFormat(fmt).format(sahur);
    final iftarDisplay = DateFormat(fmt).format(iftar);

    if (now.isBefore(sahur)) {
      return _FastingData(
        icon: Icons.wb_twilight_rounded,
        label: 'SUHOOR',
        time: sahurDisplay,
        countdown: _fmtDiff(sahur.difference(now)),
        isActive: true,
      );
    } else if (now.isBefore(iftar)) {
      return _FastingData(
        icon: Icons.nightlight_round,
        label: 'IFTAR',
        time: iftarDisplay,
        countdown: _fmtDiff(iftar.difference(now)),
        isActive: true,
      );
    }

    return _FastingData(
      icon: Icons.wb_twilight_rounded,
      label: 'SUHOOR',
      time: sahurDisplay,
      countdown: 'tomorrow',
      isActive: false,
    );
  }

  DateTime? _parse12h(String s, DateTime base) {
    final str = s.trim();
    try {
      final parts = str.split(':');
      if (parts.length == 2 && !str.contains(' ')) {
        return DateTime(base.year, base.month, base.day,
            int.parse(parts[0]), int.parse(parts[1]));
      }
      final dt = DateFormat('h:mm a').parse(str);
      return DateTime(base.year, base.month, base.day, dt.hour, dt.minute);
    } catch (_) {
      return null;
    }
  }

  String _fmtDiff(Duration d) {
    if (d.inSeconds < 60) return 'now';
    if (d.inHours < 1) return 'in ${d.inMinutes}m';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return m > 0 ? 'in ${h}h ${m}m' : 'in ${h}h';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _PrayerData {
  final String name;
  final String time;
  final String countdown;
  final double progress; // 0..1 how close we are to this prayer
  const _PrayerData({
    required this.name,
    required this.time,
    required this.countdown,
    required this.progress,
  });
}

class _FastingData {
  final IconData icon;
  final String label;
  final String time;
  final String countdown;
  final bool isActive;
  final bool isLoading;
  const _FastingData({
    required this.icon,
    required this.label,
    required this.time,
    required this.countdown,
    required this.isActive,
    this.isLoading = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Prayer row widget
// ─────────────────────────────────────────────────────────────────────────────

class _PrayerRow extends StatelessWidget {
  final _PrayerData prayer;
  final Color accent;
  const _PrayerRow({required this.prayer, required this.accent});

  static const _prayerIcons = <String, IconData>{
    'Fajr':    Icons.wb_twilight_rounded,
    'Sunrise': Icons.wb_sunny_rounded,
    'Dhuhr':   Icons.light_mode_rounded,
    'Asr':     Icons.filter_drama_rounded,
    'Maghrib': Icons.nights_stay_rounded,
    'Isha':    Icons.nightlight_round,
  };

  @override
  Widget build(BuildContext context) {
    final iconData = _prayerIcons[prayer.name] ?? Icons.mosque_rounded;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Mosque icon + NEXT label
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.1),
          ),
          child: Icon(iconData, size: 15, color: accent.withValues(alpha: 0.65)),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NEXT',
              style: TextStyle(
                fontSize: 8.5,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            Text(
              prayer.name.toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const Spacer(),
        // Time + countdown stacked right-aligned
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              prayer.time,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: accent.withValues(alpha: 0.9),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 1),
            Text(
              prayer.countdown,
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thin divider with dot
// ─────────────────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  final Color accent;
  const _Divider({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 0.4,
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.25),
          ),
        ),
        Expanded(
          child: Container(
            height: 0.4,
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fasting row widget
// ─────────────────────────────────────────────────────────────────────────────

class _FastingRow extends StatelessWidget {
  final _FastingData data;
  final Color accent;
  final VoidCallback? onRetry;
  const _FastingRow({required this.data, required this.accent, this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (data.isLoading) {
      return Row(
        children: [
          Icon(data.icon, size: 13, color: accent.withValues(alpha: 0.6)),
          const SizedBox(width: 10),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.2,
              color: accent.withValues(alpha: 0.3),
            ),
          ),
        ],
      );
    }

    final timeColor = data.isActive
        ? Colors.white.withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.25);
    final labelColor = data.isActive
        ? accent.withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.2);
    final countdownColor = data.isActive
        ? accent.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.18);

    return GestureDetector(
      onTap: onRetry,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Active glow dot
          if (data.isActive)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.7),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
            )
          else
            const SizedBox(width: 14),

          Icon(data.icon, size: 13, color: accent.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label,
                style: TextStyle(
                  fontSize: 8.5,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
              if (data.countdown.isNotEmpty && data.label != data.countdown)
                Text(
                  data.countdown,
                  style: TextStyle(
                    fontSize: 10,
                    color: countdownColor,
                  ),
                ),
            ],
          ),
          const Spacer(),
          if (data.time.isNotEmpty)
            Text(
              data.time,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: timeColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          if (data.countdown.isNotEmpty && data.time.isEmpty)
            Text(
              data.countdown,
              style: TextStyle(fontSize: 12, color: countdownColor),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Period-of-day decoration (replaces crescent for non-night periods)
// ─────────────────────────────────────────────────────────────────────────────

class _PeriodDecoration extends StatelessWidget {
  final Color color;
  final IconData icon;
  final _DayPeriod period;
  const _PeriodDecoration({
    required this.color,
    required this.icon,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: CustomPaint(painter: _PeriodPainter(color, period)),
    );
  }
}

class _PeriodPainter extends CustomPainter {
  final Color color;
  final _DayPeriod period;
  const _PeriodPainter(this.color, this.period);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    if (period == _DayPeriod.night) {
      // Night: crescent moon shape
      final path = Path();
      final cx = size.width * 0.55;
      final cy = size.height * 0.45;
      final r = size.width * 0.3;
      path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      final cutPath = Path();
      cutPath.addOval(
          Rect.fromCircle(center: Offset(cx + r * 0.5, cy - r * 0.1), radius: r * 0.78));
      final crescent = Path.combine(PathOperation.difference, path, cutPath);
      canvas.drawPath(crescent, paint);
    } else if (period == _DayPeriod.morning) {
      // Morning: soft sunrise arc
      final arcPaint = Paint()
        ..color = color.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(size.width * 0.55, size.height * 0.65), radius: size.width * 0.28),
        3.14,
        3.14,
        false,
        arcPaint,
      );
      canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.65), size.width * 0.08, paint);
    } else if (period == _DayPeriod.afternoon) {
      // Afternoon: full circle sun with rays
      canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.45), size.width * 0.15, paint);
      final rayPaint = Paint()
        ..color = color.withValues(alpha: 0.09)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 8; i++) {
        final angle = (i * 3.14159 * 2) / 8;
        final cx = size.width * 0.55;
        final cy = size.height * 0.45;
        final r1 = size.width * 0.2;
        final r2 = size.width * 0.3;
        canvas.drawLine(
          Offset(cx + r1 * cos(angle), cy + r1 * sin(angle)),
          Offset(cx + r2 * cos(angle), cy + r2 * sin(angle)),
          rayPaint,
        );
      }
    } else {
      // Evening: sunset arcs
      final arcPaint = Paint()
        ..color = color.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(size.width * 0.55, size.height * 0.6), radius: size.width * 0.22),
        3.14,
        3.14,
        false,
        arcPaint,
      );
      final arcPaint2 = Paint()
        ..color = color.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(size.width * 0.55, size.height * 0.6), radius: size.width * 0.34),
        3.14,
        3.14,
        false,
        arcPaint2,
      );
    }

    // Tiny accent dots for all periods
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.25), 1.2, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.72), 0.9, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.65), 0.7, dotPaint);
  }

  @override
  bool shouldRepaint(_PeriodPainter old) => old.color != color || old.period != period;
}

// ─────────────────────────────────────────────────────────────────────────────
// HijriDateBadge — standalone, used elsewhere
// ─────────────────────────────────────────────────────────────────────────────

class HijriDateBadge extends ConsumerWidget {
  final double? fontSize;
  const HijriDateBadge({super.key, this.fontSize});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hijri date badge removed — always hidden
    return const SizedBox.shrink();
  }
}
