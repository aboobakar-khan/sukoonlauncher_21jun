import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screen_time_provider.dart';
import '../providers/installed_apps_provider.dart';
import '../providers/theme_provider.dart';
import '../services/native_app_blocker_service.dart';

// ════════════════════════════════════════════════════════════════════════
//  APP TIMER — one screen: Usage insight + gentle limits.
//  Merges the old analytics + settings screens. Privacy-first onboarding,
//  honest permission model (Usage · Accessibility · Appear-on-top · Notifs),
//  100% on-device. No data leaves the phone.
// ════════════════════════════════════════════════════════════════════════

class AppTimerScreen extends ConsumerStatefulWidget {
  const AppTimerScreen({super.key});

  @override
  ConsumerState<AppTimerScreen> createState() => _AppTimerScreenState();
}

class _AppTimerScreenState extends ConsumerState<AppTimerScreen>
    with WidgetsBindingObserver {
  // Tabs: 0 = Usage, 1 = Limits
  int _tab = 0;
  // 7-day chart selection (0 = today)
  int _selectedDay = 0;

  // Live permission status (rechecked on resume — no fixed-delay races)
  bool? _usage; // required
  bool _a11y = false; // precise detection
  bool _overlay = false; // reliable nudge
  bool _notif = true; // background notification (A13+)

  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPerms(initialLoad: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permissions are toggled in system settings (outside the app) — re-read
    // them whenever the user returns so the UI is always truthful.
    if (state == AppLifecycleState.resumed) _refreshPerms();
  }

  Future<void> _refreshPerms({bool initialLoad = false}) async {
    final usage = await NativeAppBlockerService.hasUsageStatsPermission();
    final a11y = await NativeAppBlockerService.hasAccessibilityPermission();
    final overlay = await NativeAppBlockerService.hasOverlayPermission();
    final notif = await NativeAppBlockerService.hasNotificationPermission();
    if (!mounted) return;
    setState(() {
      _usage = usage;
      _a11y = a11y;
      _overlay = overlay;
      _notif = notif;
    });
    if (usage) _loadStats();
  }

  Future<void> _loadStats() async {
    if (_loadingStats) return;
    setState(() => _loadingStats = true);
    await ref.read(screenTimeProvider.notifier).refreshUsageStats();
    if (mounted) setState(() => _loadingStats = false);
  }

  // ── design tokens ──
  static const _bg = Color(0xFF0A0A0A);
  static const _card = Color(0x0DFFFFFF); // white @ ~5%
  static const _cardBorder = Color(0x14FFFFFF); // white @ ~8%
  static const _text = Color(0xF2FFFFFF); // white @ 95%
  static const _text2 = Color(0x80FFFFFF); // 50%
  static const _text3 = Color(0x4DFFFFFF); // 30%

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(themeColorProvider).color;
    final st = ref.watch(screenTimeProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(accent),
            Expanded(
              child: _usage == null
                  ? const Center(
                      child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _text3)))
                  : (_usage == false
                      ? _onboarding(accent)
                      : _content(accent, st)),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════ HEADER
  Widget _header(Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
      child: Row(
        children: [
          _circleBtn(Icons.arrow_back_ios_new_rounded,
              () => Navigator.of(context).maybePop()),
          const SizedBox(width: 4),
          const Text('App Timer',
              style: TextStyle(
                  color: _text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4)),
          const Spacer(),
          if (_usage == true)
            _circleBtn(Icons.refresh_rounded, _loadStats),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: _card),
        child: Icon(icon, color: _text2, size: 18),
      ),
    );
  }

  // ══════════════════════════════════════════════════════ ONBOARDING
  Widget _onboarding(Color accent) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      physics: const BouncingScrollPhysics(),
      children: [
        const SizedBox(height: 8),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16)),
          child: Icon(Icons.hourglass_bottom_rounded, color: accent, size: 28),
        ),
        const SizedBox(height: 18),
        const Text('Mindful screen time',
            style: TextStyle(
                color: _text,
                fontSize: 23,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5)),
        const SizedBox(height: 8),
        const Text(
          'See where your time goes and set gentle limits on the apps that pull you in.',
          style: TextStyle(color: _text2, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 18),
        // Privacy reassurance — the heart of the pitch
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1A12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E3A28)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_rounded,
                  color: Color(0xFF5BBF7A), size: 19),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                        color: _text2, fontSize: 12.5, height: 1.5),
                    children: [
                      TextSpan(
                          text: '100% on your device.  ',
                          style: TextStyle(
                              color: Color(0xFF8FD6A3),
                              fontWeight: FontWeight.w700)),
                      TextSpan(
                          text:
                              'Sukoon never collects, stores, or sends your usage anywhere. No account, no internet, no tracking — these permissions power on-device timers only.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SectionLabel('PERMISSIONS'),
        const SizedBox(height: 10),
        _permRow(
          accent: accent,
          icon: Icons.bar_chart_rounded,
          title: 'Usage Access',
          tag: 'Required',
          subtitle: 'See which apps you use and for how long.',
          granted: _usage == true,
          onEnable: () async {
            await NativeAppBlockerService.requestUsageStatsPermission();
          },
        ),
        _permRow(
          accent: accent,
          icon: Icons.accessibility_new_rounded,
          title: 'Accessibility',
          tag: 'Precise',
          subtitle:
              'Detect the open app instantly so limits trigger right on time.',
          granted: _a11y,
          onEnable: NativeAppBlockerService.requestAccessibilityPermission,
        ),
        _permRow(
          accent: accent,
          icon: Icons.layers_rounded,
          title: 'Appear on top',
          tag: 'Reliable',
          subtitle: 'Show your gentle reminder over the app you\'re in.',
          granted: _overlay,
          onEnable: NativeAppBlockerService.requestOverlayPermission,
        ),
        _permRow(
          accent: accent,
          icon: Icons.notifications_none_rounded,
          title: 'Notifications',
          tag: 'Optional',
          subtitle: 'Keep the timer alive quietly in the background.',
          granted: _notif,
          onEnable: () async {
            await NativeAppBlockerService.requestNotificationPermission();
          },
        ),
        const SizedBox(height: 20),
        if (_usage != true)
          const Text(
            'Usage Access is the only one required to begin. The rest make limits more precise and reliable — enable them anytime.',
            style: TextStyle(color: _text3, fontSize: 12, height: 1.5),
          ),
      ],
    );
  }

  Widget _permRow({
    required Color accent,
    required IconData icon,
    required String title,
    required String tag,
    required String subtitle,
    required bool granted,
    required Future<void> Function() onEnable,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: granted
                    ? const Color(0x265BBF7A)
                    : accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon,
                color: granted ? const Color(0xFF5BBF7A) : accent, size: 19),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _text,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 7),
                  Text(tag,
                      style: TextStyle(
                          color: tag == 'Required'
                              ? accent
                              : _text3,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                ]),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        color: _text2, fontSize: 11.5, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          granted
              ? const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF5BBF7A), size: 22)
              : GestureDetector(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    await onEnable();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('Enable',
                        style: TextStyle(
                            color: accent,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════ CONTENT (granted)
  Widget _content(Color accent, ScreenTimeState st) {
    return Column(
      children: [
        _privacyStrip(),
        const SizedBox(height: 12),
        _segmented(accent),
        const SizedBox(height: 6),
        Expanded(
          child: _tab == 0
              ? _usageView(accent, st)
              : _limitsView(accent, st),
        ),
      ],
    );
  }

  Widget _privacyStrip() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.lock_outline_rounded, color: Color(0xFF5BBF7A), size: 13),
          SizedBox(width: 7),
          Text('On-device only · nothing is collected or shared',
              style: TextStyle(
                  color: _text2, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _segmented(Color accent) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _seg('Usage', 0, accent),
          _seg('Limits', 1, accent),
        ],
      ),
    );
  }

  Widget _seg(String label, int idx, Color accent) {
    final on = _tab == idx;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_tab != idx) {
            HapticFeedback.selectionClick();
            setState(() => _tab = idx);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: on ? accent.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: on ? accent : _text2,
                  fontSize: 13.5,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════ USAGE VIEW
  Widget _usageView(Color accent, ScreenTimeState st) {
    final daily = st.dailyStats;
    if (daily.isEmpty) {
      return _emptyState(
        icon: Icons.insights_rounded,
        title: _loadingStats ? 'Loading usage…' : 'No usage yet today',
        subtitle: _loadingStats
            ? null
            : 'Come back after using a few apps — your day will appear here.',
      );
    }
    final dayIdx = _selectedDay.clamp(0, daily.length - 1);
    final selected = daily[dayIdx];
    final today = daily[0];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      physics: const BouncingScrollPhysics(),
      children: [
        _todayHero(accent, today, daily.length > 1 ? daily[1] : null),
        const SizedBox(height: 22),
        const _SectionLabel('LAST 7 DAYS'),
        const SizedBox(height: 10),
        _barChart(accent, daily),
        const SizedBox(height: 22),
        _SectionLabel(
            dayIdx == 0 ? 'TODAY · APPS' : '${_dayLabel(selected.date)} · APPS'),
        const SizedBox(height: 10),
        _appBreakdown(accent, selected),
      ],
    );
  }

  Widget _todayHero(Color accent, DailyUsageStat today, DailyUsageStat? yest) {
    final h = today.totalTime.inHours;
    final m = today.totalTime.inMinutes.remainder(60);
    Widget? delta;
    if (yest != null && yest.totalTime.inMinutes > 0) {
      final tMs = today.totalTime.inMilliseconds;
      final yMs = yest.totalTime.inMilliseconds;
      final pct = (((tMs - yMs) / yMs) * 100).round();
      final isMore = tMs > yMs;
      delta = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (isMore ? const Color(0xFFE07A5F) : const Color(0xFF5BBF7A))
              .withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isMore ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 12,
              color: isMore ? const Color(0xFFE07A5F) : const Color(0xFF5BBF7A)),
          const SizedBox(width: 3),
          Text('${pct.abs()}% vs yesterday',
              style: TextStyle(
                  color: isMore
                      ? const Color(0xFFE07A5F)
                      : const Color(0xFF5BBF7A),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
        ]),
      );
    }
    final mostUsed = today.apps.isNotEmpty ? today.apps.first : null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Today',
              style: TextStyle(color: _text2, fontSize: 13)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('${h}h ${m}m',
                  style: const TextStyle(
                      color: _text,
                      fontSize: 42,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -1.5)),
              const Spacer(),
              if (delta != null) delta,
            ],
          ),
          if (mostUsed != null) ...[
            const SizedBox(height: 16),
            Container(height: 0.5, color: _cardBorder),
            const SizedBox(height: 14),
            Row(children: [
              _avatar(mostUsed.appName, accent, 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Most used',
                        style: TextStyle(color: _text3, fontSize: 11)),
                    const SizedBox(height: 1),
                    Text(mostUsed.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Text(_fmt(mostUsed.usageTime),
                  style: TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _barChart(Color accent, List<DailyUsageStat> daily) {
    final maxMs = daily
        .map((d) => d.totalTime.inMilliseconds)
        .fold<int>(0, (a, b) => b > a ? b : a);
    if (maxMs == 0) {
      return _miniCard(child: const Text('No data yet',
          style: TextStyle(color: _text3, fontSize: 12)));
    }
    final reversed = daily.reversed.toList(); // oldest → newest
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 108,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < reversed.length; i++)
                  Builder(builder: (_) {
                    final day = reversed[i];
                    final origIdx = reversed.length - 1 - i; // 0 = today
                    final on = _selectedDay == origIdx;
                    final ratio = day.totalTime.inMilliseconds / maxMs;
                    final barH = (ratio * 84).clamp(4.0, 84.0);
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedDay = origIdx);
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedOpacity(
                              opacity: on ? 1 : 0,
                              duration: const Duration(milliseconds: 160),
                              child: Text(_fmtShort(day.totalTime),
                                  style: TextStyle(
                                      color: accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              height: barH,
                              decoration: BoxDecoration(
                                color: on
                                    ? accent
                                    : accent.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (int i = 0; i < reversed.length; i++)
                Expanded(
                  child: Text(
                    reversed.length - 1 - i == 0
                        ? 'Today'
                        : _weekdayLetter(reversed[i].date),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _selectedDay == reversed.length - 1 - i
                          ? accent
                          : _text3,
                      fontSize: 10.5,
                      fontWeight: _selectedDay == reversed.length - 1 - i
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _appBreakdown(Color accent, DailyUsageStat day) {
    final apps = day.apps;
    if (apps.isEmpty) {
      return _miniCard(child: const Text('No app usage recorded',
          style: TextStyle(color: _text3, fontSize: 12)));
    }
    // Sum-to-100: denominator is the sum of the listed apps, not the native
    // total (which double-counts) — so the percentages are trustworthy.
    final sumMs = apps.fold<int>(0, (a, e) => a + e.usageTime.inMilliseconds);
    final maxMs = apps
        .map((e) => e.usageTime.inMilliseconds)
        .fold<int>(0, (a, b) => b > a ? b : a);
    final shown = apps.take(12).toList();
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          for (int i = 0; i < shown.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 62),
                child: Container(height: 0.5, color: _cardBorder),
              ),
            _appRow(accent, shown[i], sumMs, maxMs, i == 0),
          ],
        ],
      ),
    );
  }

  Widget _appRow(Color accent, AppUsageEntry app, int sumMs, int maxMs,
      bool top) {
    final pct = sumMs > 0
        ? ((app.usageTime.inMilliseconds / sumMs) * 100).round()
        : 0;
    final ratio = maxMs > 0 ? app.usageTime.inMilliseconds / maxMs : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        children: [
          Row(children: [
            _avatar(app.appName, accent, 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _text,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 1),
                  Text('$pct% of total',
                      style: const TextStyle(color: _text3, fontSize: 11)),
                ],
              ),
            ),
            Text(_fmt(app.usageTime),
                style: TextStyle(
                    color: top ? accent : _text2,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: const Color(0x12FFFFFF),
              valueColor: AlwaysStoppedAnimation(
                  accent.withValues(alpha: top ? 0.8 : 0.45)),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════ LIMITS VIEW
  Widget _limitsView(Color accent, ScreenTimeState st) {
    final configs = st.appConfigs.entries.toList()
      ..sort((a, b) => _nameFor(a.key).toLowerCase()
          .compareTo(_nameFor(b.key).toLowerCase()));
    final needReliability = st.featureEnabled && (!_a11y || !_overlay);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      physics: const BouncingScrollPhysics(),
      children: [
        // Master toggle
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.self_improvement_rounded,
                  color: accent, size: 21),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gentle reminders',
                      style: TextStyle(
                          color: _text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text('A calm nudge when you reach a limit.',
                      style: TextStyle(color: _text2, fontSize: 12)),
                ],
              ),
            ),
            CupertinoSwitch(
              value: st.featureEnabled,
              activeTrackColor: accent,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                ref.read(screenTimeProvider.notifier).setEnabled(v);
              },
            ),
          ]),
        ),

        // Reliability nudge (only when on + something missing)
        if (needReliability) ...[
          const SizedBox(height: 10),
          _reliabilityNudge(accent),
        ],

        const SizedBox(height: 22),
        Row(children: [
          const _SectionLabel('MONITORED APPS'),
          const Spacer(),
          GestureDetector(
            onTap: () => _showAddApps(accent),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, color: accent, size: 16),
                const SizedBox(width: 4),
                Text('Add app',
                    style: TextStyle(
                        color: accent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        if (configs.isEmpty)
          _miniCard(
            child: Column(children: const [
              Icon(Icons.timelapse_rounded, color: _text3, size: 26),
              SizedBox(height: 10),
              Text('No apps yet',
                  style: TextStyle(
                      color: _text, fontSize: 14, fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text('Add an app to set a gentle time limit.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _text2, fontSize: 12)),
            ]),
          )
        else ...[
          for (final e in configs) _limitRow(accent, e.key, e.value),
          const SizedBox(height: 12),
          const Text('Tap a limit to change it · swipe a row to remove',
              textAlign: TextAlign.center,
              style: TextStyle(color: _text3, fontSize: 11.5)),
        ],
      ],
    );
  }

  Widget _reliabilityNudge(Color accent) {
    final missing = <String>[];
    if (!_a11y) missing.add('Accessibility');
    if (!_overlay) missing.add('Appear-on-top');
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        if (!_a11y) {
          await NativeAppBlockerService.requestAccessibilityPermission();
        } else if (!_overlay) {
          await NativeAppBlockerService.requestOverlayPermission();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0x1AE0A45F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x33E0A45F)),
        ),
        child: Row(children: [
          const Icon(Icons.bolt_rounded, color: Color(0xFFE0A45F), size: 19),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'For on-time, in-place reminders, enable ${missing.join(' & ')}.',
              style: const TextStyle(
                  color: Color(0xFFEAC18A), fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(width: 8),
          const Text('Fix',
              style: TextStyle(
                  color: Color(0xFFE0A45F),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _limitRow(Color accent, String pkg, AppTimerConfig cfg) {
    final name = _nameFor(pkg);
    final limitLabel =
        cfg.alwaysAsk ? 'Ask each time' : '${cfg.defaultMinutes}m';
    final on = cfg.enabled;
    return Dismissible(
      key: ValueKey('limit_$pkg'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        ref.read(screenTimeProvider.notifier).removeAppTimer(pkg);
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0x33E05A4F),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Color(0xFFE07A6F), size: 22),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: Row(children: [
          Opacity(opacity: on ? 1 : 0.4, child: _avatar(name, accent, 36)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: on ? _text : _text2,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500)),
          ),
          GestureDetector(
            onTap: () => _showLimitPicker(accent, pkg, name, cfg),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: on ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.schedule_rounded,
                    color: accent.withValues(alpha: on ? 1 : 0.5), size: 14),
                const SizedBox(width: 5),
                Text(limitLabel,
                    style: TextStyle(
                        color: accent.withValues(alpha: on ? 1 : 0.5),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
                Icon(Icons.expand_more_rounded,
                    color: accent.withValues(alpha: on ? 0.7 : 0.4), size: 15),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          CupertinoSwitch(
            value: on,
            activeTrackColor: accent,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              ref.read(screenTimeProvider.notifier)
                  .updateAppTimer(pkg, enabled: v);
            },
          ),
        ]),
      ),
    );
  }

  // ── Add apps sheet ──
  void _showAddApps(Color accent) {
    HapticFeedback.selectionClick();
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          final st = ref.read(screenTimeProvider);
          final all = ref.read(installedAppsProvider);
          final q = searchCtrl.text.trim().toLowerCase();
          final list = all
              .where((a) => a.packageName != 'com.sukoon.launcher')
              .where((a) => q.isEmpty || a.displayName.toLowerCase().contains(q))
              .toList()
            ..sort((a, b) {
              final ca = st.appConfigs.containsKey(a.packageName) ? 0 : 1;
              final cb = st.appConfigs.containsKey(b.packageName) ? 0 : 1;
              if (ca != cb) return ca - cb;
              return a.displayName.toLowerCase()
                  .compareTo(b.displayName.toLowerCase());
            });
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.82,
            decoration: const BoxDecoration(
              color: Color(0xFF141414),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(children: [
              const SizedBox(height: 10),
              Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _text3, borderRadius: BorderRadius.circular(2))),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Add apps to monitor',
                      style: TextStyle(
                          color: _text,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (_) => setSheet(() {}),
                  style: const TextStyle(color: _text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search apps…',
                    hintStyle: const TextStyle(color: _text3, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: _text3, size: 20),
                    filled: true,
                    fillColor: _card,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final app = list[i];
                    final added = st.appConfigs.containsKey(app.packageName);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        final n = ref.read(screenTimeProvider.notifier);
                        if (added) {
                          n.removeAppTimer(app.packageName);
                        } else {
                          n.addAppTimer(app.packageName);
                        }
                        setSheet(() {});
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 9),
                        child: Row(children: [
                          _avatar(app.displayName, accent, 36),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(app.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _text, fontSize: 14)),
                          ),
                          Icon(
                            added
                                ? Icons.check_circle_rounded
                                : Icons.add_circle_outline_rounded,
                            color: added ? accent : _text3,
                            size: 22,
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ]),
          );
        });
      },
    ).whenComplete(searchCtrl.dispose);
  }

  // ── Limit picker sheet ──
  void _showLimitPicker(
      Color accent, String pkg, String name, AppTimerConfig cfg) {
    HapticFeedback.selectionClick();
    const presets = [5, 10, 15, 30, 45, 60, 90];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141414),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: _text3, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 18),
            Text('Limit for $name',
                style: const TextStyle(
                    color: _text, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            // Ask each time
            GestureDetector(
              onTap: () {
                ref.read(screenTimeProvider.notifier)
                    .updateAppTimer(pkg, alwaysAsk: true);
                Navigator.pop(ctx);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cfg.alwaysAsk
                      ? accent.withValues(alpha: 0.16)
                      : _card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: cfg.alwaysAsk
                          ? accent.withValues(alpha: 0.4)
                          : _cardBorder),
                ),
                child: Row(children: [
                  Icon(Icons.help_outline_rounded,
                      color: cfg.alwaysAsk ? accent : _text2, size: 19),
                  const SizedBox(width: 12),
                  Text('Ask me each time',
                      style: TextStyle(
                          color: cfg.alwaysAsk ? accent : _text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('OR A FIXED LIMIT',
                  style: TextStyle(
                      color: _text3,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final m in presets)
                  GestureDetector(
                    onTap: () {
                      ref.read(screenTimeProvider.notifier).updateAppTimer(
                          pkg, alwaysAsk: false, defaultMinutes: m);
                      Navigator.pop(ctx);
                    },
                    child: Builder(builder: (_) {
                      final sel = !cfg.alwaysAsk && cfg.defaultMinutes == m;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 11),
                        decoration: BoxDecoration(
                          color: sel
                              ? accent.withValues(alpha: 0.18)
                              : _card,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                              color: sel
                                  ? accent.withValues(alpha: 0.4)
                                  : _cardBorder),
                        ),
                        child: Text('${m}m',
                            style: TextStyle(
                                color: sel ? accent : _text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      );
                    }),
                  ),
              ],
            ),
          ]),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════ shared bits
  Widget _emptyState(
      {required IconData icon, required String title, String? subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _text3, size: 34),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _text, fontSize: 15, fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _text2, fontSize: 12.5, height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniCard({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _cardBorder),
        ),
        child: Center(child: child),
      );

  Widget _avatar(String name, Color accent, double size) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: Text(letter,
          style: TextStyle(
              color: accent,
              fontSize: size * 0.42,
              fontWeight: FontWeight.w700)),
    );
  }

  String _nameFor(String pkg) {
    final apps = ref.read(installedAppsProvider);
    for (final a in apps) {
      if (a.packageName == pkg) return a.displayName;
    }
    final seg = pkg.split('.');
    return seg.isNotEmpty ? _cap(seg.last) : pkg;
  }

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _fmtShort(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return m > 0 ? '${h}h$m' : '${h}h';
    return '${m}m';
  }

  String _dayLabel(String date) {
    final dt = DateTime.tryParse(date);
    if (dt == null) return date;
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return wd[(dt.weekday - 1) % 7];
  }

  String _weekdayLetter(String date) {
    final dt = DateTime.tryParse(date);
    if (dt == null) return '';
    const wd = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return wd[(dt.weekday - 1) % 7];
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: Color(0x66FFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3));
  }
}
