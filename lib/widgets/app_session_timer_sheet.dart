import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screen_time_provider.dart';
import '../providers/theme_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 🕐 APP SESSION TIMER SHEETS
//
// Psychology principles applied:
//  1. PRE-COMMITMENT: Asking "how long?" before opening creates an intention
//     contract. Research shows pre-commitment reduces impulsive usage by 30%.
//  2. CHOICE ARCHITECTURE: Default options are 5/10/15 mins (not 30/60).
//     Short defaults leverage anchoring bias toward less screen time.
//  3. COMPASSIONATE FRAMING: "Time's up" screen uses soft language
//     ("You've been here X minutes") not shame ("You're addicted!").
//  4. FRICTION GRADIENT: First extension is easy (+5m), subsequent ones
//     require more taps and show usage stats → progressive friction.
//  5. AWARENESS OVER BLOCKING: We show today + weekly usage data to let
//     the user build self-insight. No hard blocks — user always has choice.
// ═══════════════════════════════════════════════════════════════════════════════

/// "How long do you want to spend?" bottom sheet — shown before app launch
class AppSessionPrompt extends ConsumerStatefulWidget {
  final String packageName;
  final String appName;
  final int defaultMinutes;
  final VoidCallback onSkip;   // User chose to skip (launch without timer)
  final void Function(int minutes) onStart;  // User chose a time

  const AppSessionPrompt({
    super.key,
    required this.packageName,
    required this.appName,
    required this.defaultMinutes,
    required this.onSkip,
    required this.onStart,
  });

  /// Show as a modal bottom sheet. Returns the chosen minutes, or null if skipped.
  static Future<int?> show(
    BuildContext context, {
    required String packageName,
    required String appName,
    int defaultMinutes = 15,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => AppSessionPrompt(
        packageName: packageName,
        appName: appName,
        defaultMinutes: defaultMinutes,
        onSkip: () => Navigator.pop(ctx),
        onStart: (minutes) => Navigator.pop(ctx, minutes),
      ),
    );
  }

  @override
  ConsumerState<AppSessionPrompt> createState() => _AppSessionPromptState();
}

class _AppSessionPromptState extends ConsumerState<AppSessionPrompt> {
  static const _timeOptions = [1, 5, 15, 45];

  // Hard-hitting lines from top fighters, stoics & speakers
  static const _nudges = [
    'Discipline is doing what\nyou hate like you love it.\n— Mike Tyson',
    'You have power over your mind,\nnot outside events.\nRealise this, and you will find strength.\n— Marcus Aurelius',
    'Don\'t watch the clock;\ndo what it does.\nKeep going.\n— Sam Levenson',
    'The secret of your future\nis hidden in your daily routine.\n— Mike Murdock',
    'We suffer more in imagination\nthan in reality.\n— Seneca',
    'Hard choices, easy life.\nEasy choices, hard life.\n— Jerzy Gregorek',
    'Everybody wants to be a beast,\nuntil it\'s time to do\nwhat beasts do.\n— Eric Thomas',
    'Your time is limited.\nDon\'t waste it living\nsomeone else\'s life.\n— Steve Jobs',
    'Lose an hour in the morning\nand you will be all day\nhunting for it.\n— Richard Whately',
    'The two most powerful warriors\nare patience and time.\n— Leo Tolstoy',
  ];

  late final String _nudge;

  @override
  void initState() {
    super.initState();
    final i = DateTime.now().millisecondsSinceEpoch % _nudges.length;
    _nudge = _nudges[i];
  }

  @override
  Widget build(BuildContext context) {
    final screenTime = ref.watch(screenTimeProvider);
    final todayEntry = screenTime.todayUsage
        .where((e) => e.packageName == widget.packageName)
        .firstOrNull;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── Handle ──
            Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),

            // ── Nudge quote ──
            Text(
              _nudge,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w200,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.45,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // ── Question line ──
            Text(
              'How long on ${widget.appName}?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.3),
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // ── Time chips ──
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _timeOptions.map((min) {
                final label = min < 60
                    ? '${min}m'
                    : min == 60 ? '1h' : '1h 30m';
                return GestureDetector(
                  onTap: () {
                    widget.onStart(min);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.09),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // ── Today usage — only if present, very subtle ──
            if (todayEntry != null && todayEntry.usageTime.inMinutes > 0) ...[
              const SizedBox(height: 24),
              Text(
                'Today already: ${_formatDuration(todayEntry.usageTime)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.2),
                  letterSpacing: 0.3,
                ),
              ),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      final m = d.inMinutes % 60;
      return m > 0 ? '${d.inHours}h ${m}m' : '${d.inHours}h';
    }
    return '${d.inMinutes}m';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ⏰ "TIME'S UP" OVERLAY — Circular progress + usage stats + extension chips
//
// Matches minimalist launcher design:
//  • Circular progress indicator (like the screenshot)
//  • "Spent today" + "Last 7 days" stats
//  • Big "TAKE ME OUT OF HERE" exit button
//  • Small "More time" chips with progressive friction
// ═══════════════════════════════════════════════════════════════════════════════

class TimesUpOverlay extends ConsumerStatefulWidget {
  final String appName;
  final int minutesSpent;
  final int extensionsUsed;
  final Duration todayUsage;
  final Duration weekUsage;
  final VoidCallback onExit;
  final void Function(int) onExtend;

  const TimesUpOverlay({
    super.key,
    required this.appName,
    required this.minutesSpent,
    required this.extensionsUsed,
    this.todayUsage = Duration.zero,
    this.weekUsage = Duration.zero,
    required this.onExit,
    required this.onExtend,
  });

  /// Show as a full-screen dialog
  static void showAsDialog(
    BuildContext context, {
    required String appName,
    required int minutesSpent,
    required int extensionsUsed,
    Duration todayUsage = Duration.zero,
    Duration weekUsage = Duration.zero,
    required VoidCallback onExit,
    required void Function(int) onExtend,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (ctx, anim, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        );
      },
      pageBuilder: (ctx, _, _) => TimesUpOverlay(
        appName: appName,
        minutesSpent: minutesSpent,
        extensionsUsed: extensionsUsed,
        todayUsage: todayUsage,
        weekUsage: weekUsage,
        onExit: () {
          Navigator.pop(ctx);
          onExit();
        },
        onExtend: (mins) {
          Navigator.pop(ctx);
          onExtend(mins);
        },
      ),
    );
  }

  @override
  ConsumerState<TimesUpOverlay> createState() => _TimesUpOverlayState();
}

class _TimesUpOverlayState extends ConsumerState<TimesUpOverlay> {

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _fmt(Duration d) {
    if (d.inHours > 0) {
      final m = d.inMinutes % 60;
      return m > 0 ? '${d.inHours} h $m min' : '${d.inHours} h';
    }
    return '${d.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(themeColorProvider).color;
    // After 2 extensions, reduce options (progressive friction)
    final showReflection = widget.extensionsUsed >= 2;

    return Material(
      color: const Color(0xFF0A0A0A),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Message ──
              Text(
                '﷽',
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your time on ${widget.appName} is complete.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                '"Indeed, in the remembrance of Allah do hearts find rest."\n— Surah Ar-Ra\'d (13:28)',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.white.withValues(alpha: 0.4),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // ── Usage stats row ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatCol(
                    label: 'Spent today',
                    value: _fmt(widget.todayUsage),
                    accent: accent,
                  ),
                  const SizedBox(width: 32),
                  _StatCol(
                    label: 'Last 7 days',
                    value: _fmt(widget.weekUsage),
                    accent: accent,
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // ── Primary CTA: TAKE ME OUT OF HERE ──
              GestureDetector(
                onTap: () {
                  ref.read(screenTimeProvider.notifier).endSession();
                  widget.onExit();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Center(
                    child: Text(
                      'TAKE ME OUT OF HERE',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── "More time" label + extension chips ──
              Text(
                'More time',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ExtendChip(label: '+1m', onTap: () {
                    ref.read(screenTimeProvider.notifier).extendSession(1);
                    widget.onExtend(1);
                  }),
                  const SizedBox(width: 10),
                  if (!showReflection) ...[
                    _ExtendChip(label: '+5m', onTap: () {
                      ref.read(screenTimeProvider.notifier).extendSession(5);
                      widget.onExtend(5);
                    }),
                    const SizedBox(width: 10),
                    _ExtendChip(label: '+10m', onTap: () {
                      ref.read(screenTimeProvider.notifier).extendSession(10);
                      widget.onExtend(10);
                    }),
                  ],
                ],
              ),

              if (showReflection) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFD93025).withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    'You\'ve extended ${widget.extensionsUsed} times.\n"And do not waste, for Allah does not love the wasteful." — Al-An\'am (6:141)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _StatCol({required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _ExtendChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ExtendChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.09),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
