import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/premium_provider.dart';
import '../../../screens/premium_paywall_screen.dart';
import '../providers/prayer_alarm_provider.dart';
import '../screens/prayer_alarm_settings_screen.dart';
import '../utils/prayer_time_utils.dart';

/// Compact dashboard card — prayer timeline with progress dots.
/// Shows: current/next prayer name, countdown, and a visual timeline.
class PrayerAlarmDashboardCard extends ConsumerStatefulWidget {
  const PrayerAlarmDashboardCard({super.key});

  @override
  ConsumerState<PrayerAlarmDashboardCard> createState() =>
      _PrayerAlarmDashboardCardState();
}

class _PrayerAlarmDashboardCardState
    extends ConsumerState<PrayerAlarmDashboardCard> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Tick every second to keep countdown live
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static const _allPrayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  static const _prayerAbbrev = ['FAJ', 'DHU', 'ASR', 'MAG', 'ISH'];

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(themeColorProvider).color;
    final alarmState = ref.watch(prayerAlarmProvider);
    final isPremium =
        ref.watch(hasFeatureProvider(PremiumFeature.prayerAlarm));
    final isSetup = alarmState.isSetupComplete;

    return GestureDetector(
      onTap: () {
        if (!isPremium) {
          showPremiumPaywall(context, triggerFeature: 'Salah Wake');
          return;
        }
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const PrayerAlarmSettingsScreen(),
            transitionsBuilder: (_, anim, __, child) => FadeTransition(
                opacity:
                    CurvedAnimation(parent: anim, curve: Curves.easeOut),
                child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: accent.withValues(alpha: 0.04),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: isSetup
                ? _buildTimeline(accent, alarmState)
                : _buildSetup(accent),
          ),
          if (!isPremium)
            Positioned(
              top: 10,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFC2A366).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color:
                          const Color(0xFFC2A366).withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded,
                        size: 9,
                        color: const Color(0xFFC2A366)
                            .withValues(alpha: 0.75)),
                    const SizedBox(width: 4),
                    Text('PRO',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFC2A366)
                              .withValues(alpha: 0.75),
                          letterSpacing: 0.5,
                        )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Setup state ─────────────────────────────────────────────────────────
  Widget _buildSetup(Color accent) {
    return Row(
      children: [
        Icon(Icons.mosque_rounded,
            size: 18, color: accent.withValues(alpha: 0.50)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Salah Wake',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.2)),
              const SizedBox(height: 2),
              Text('Tap to configure prayer alarms',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.22),
                      fontSize: 11)),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_ios_rounded,
            size: 11, color: Colors.white.withValues(alpha: 0.15)),
      ],
    );
  }

  // ── Timeline view — like reference image ────────────────────────────────
  Widget _buildTimeline(Color accent, PrayerAlarmState state) {
    final times = state.effectiveTimesMap;
    final enabledMap = state.enabledMap;

    // Parse all prayer times
    final prayerDateTimes = <String, DateTime>{};
    for (final name in _allPrayers) {
      final ts = times[name];
      if (ts == null) continue;
      final parsed = parseTimeStr(ts);
      if (parsed == null) continue;
      prayerDateTimes[name] = DateTime(
          _now.year, _now.month, _now.day, parsed.hour, parsed.minute);
    }

    // Find current (last passed) and next (upcoming) prayer
    String? currentName;
    String? nextName;
    int currentIndex = -1;
    int nextIndex = -1;

    for (int i = 0; i < _allPrayers.length; i++) {
      final name = _allPrayers[i];
      final dt = prayerDateTimes[name];
      if (dt == null) continue;

      if (dt.isBefore(_now) || dt.isAtSameMomentAs(_now)) {
        currentName = name;
        currentIndex = i;
      } else if (nextName == null) {
        nextName = name;
        nextIndex = i;
      }
    }

    // If no next prayer today, wrap around (next is Fajr tomorrow)
    if (nextName == null && currentName != null) {
      // All prayers passed — show Isha as current, no "next" today
      // Or show Fajr as next (tomorrow)
      nextName = 'Fajr';
      nextIndex = 0;
    }

    // Countdown to next prayer
    Duration? countdown;
    if (nextName != null) {
      final nextDt = prayerDateTimes[nextName];
      if (nextDt != null) {
        if (nextDt.isAfter(_now)) {
          countdown = nextDt.difference(_now);
        } else {
          // Next day's Fajr
          final tomorrowFajr = nextDt.add(const Duration(days: 1));
          countdown = tomorrowFajr.difference(_now);
        }
      }
    }

    // The display prayer is the "next upcoming" one — that's the hero
    final heroName = nextName ?? currentName ?? 'DHUHR';
    final heroCountdown = countdown;

    // Active Alarms Badge instead of bell icon
    final activeCount = enabledMap.values.where((e) => e).length;
    final totalCount = enabledMap.length; // Typically 5
    final alarmBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_active_rounded,
            size: 11,
            color: accent.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Text(
            '$activeCount/$totalCount',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: accent.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hero: Next prayer name + countdown ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    heroName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.92),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.40),
                        fontWeight: FontWeight.w400,
                      ),
                      children: [
                        const TextSpan(text: 'starting in '),
                        if (heroCountdown != null)
                          TextSpan(
                            text: _fmtCountdownLong(heroCountdown),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.80),
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else
                          TextSpan(
                            text: 'now',
                            style: TextStyle(
                              color: accent.withValues(alpha: 0.80),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            alarmBadge,
          ],
        ),

        const SizedBox(height: 16),

        // ── Timeline dots + progress line ──
        _buildTimelineDots(accent, currentIndex, nextIndex, enabledMap),
      ],
    );
  }

  Widget _buildTimelineDots(
    Color accent,
    int currentIndex,
    int nextIndex,
    Map<String, bool> enabledMap,
  ) {
    // Calculate progress position (0.0 to 1.0) along the timeline
    // If currentIndex == 0 and nextIndex == 1, we're between Fajr and Dhuhr
    double progress = 0.0;
    if (currentIndex >= 0) {
      // Base progress: the dot of the current prayer
      progress = currentIndex / (_allPrayers.length - 1);
      // Add partial progress toward next prayer based on time
      // (we keep it simple: show the line filled up to the current prayer dot)
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final dotSpacing = totalWidth / (_allPrayers.length - 1);

        return Column(
          children: [
            // Timeline line + dots
            SizedBox(
              height: 14,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Background line
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 6,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  // Progress line (filled portion)
                  if (currentIndex >= 0)
                    Positioned(
                      left: 0,
                      top: 6,
                      child: Container(
                        width: (dotSpacing * currentIndex).clamp(0.0, totalWidth),
                        height: 2,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  // Dots
                  ...List.generate(_allPrayers.length, (i) {
                    final isPassed = i <= currentIndex;
                    final isCurrent = i == currentIndex;
                    final isNext = i == nextIndex;
                    final isEnabled = enabledMap[_allPrayers[i]] ?? false;
                    final dotX = dotSpacing * i;

                    // Dot size and style
                    double dotSize = 8;
                    Color dotColor;
                    Color? borderColor;

                    if (isCurrent) {
                      dotSize = 10;
                      dotColor = accent;
                      borderColor = null;
                    } else if (isNext) {
                      dotSize = 8;
                      dotColor = Colors.transparent;
                      borderColor = accent.withValues(alpha: 0.50);
                    } else if (isPassed) {
                      dotColor = accent.withValues(alpha: 0.40);
                      borderColor = null;
                    } else {
                      dotColor = Colors.white.withValues(alpha: 0.10);
                      borderColor = null;
                    }

                    return Positioned(
                      left: dotX - dotSize / 2,
                      top: 7 - dotSize / 2,
                      child: Container(
                        width: dotSize,
                        height: dotSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                          border: borderColor != null
                              ? Border.all(color: borderColor, width: 1.5)
                              : null,
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.30),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_allPrayers.length, (i) {
                final isPassed = i <= currentIndex;
                final isCurrent = i == currentIndex;
                final isNext = i == nextIndex;

                Color labelColor;
                FontWeight labelWeight;
                if (isCurrent || isNext) {
                  labelColor = Colors.white.withValues(alpha: 0.70);
                  labelWeight = FontWeight.w600;
                } else if (isPassed) {
                  labelColor = Colors.white.withValues(alpha: 0.30);
                  labelWeight = FontWeight.w400;
                } else {
                  labelColor = Colors.white.withValues(alpha: 0.18);
                  labelWeight = FontWeight.w400;
                }

                return Text(
                  _prayerAbbrev[i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: labelWeight,
                    color: labelColor,
                    letterSpacing: 0.5,
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  String _fmtCountdownLong(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) {
      return '$h hrs, $m mins';
    }
    if (m > 0) {
      final s = d.inSeconds.remainder(60);
      return '$m mins, $s secs';
    }
    return '${d.inSeconds} secs';
  }
}
