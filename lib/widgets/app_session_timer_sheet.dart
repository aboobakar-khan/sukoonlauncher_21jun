import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screen_time_provider.dart';
import '../providers/theme_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 🕐 APP SESSION TIMER — the "how long?" prompt + the "time's up" overlay.
//
// Orchestration lives in launcher_shell._checkNativeTimers: these widgets only
// FIRE callbacks (onStart / onSkip / onExtend / onExit). They never start,
// extend, or end sessions themselves — that single owner avoids the broken
// double-handling that left extend doing nothing.
// ═══════════════════════════════════════════════════════════════════════════

/// "How long do you want to spend?" — shown before a monitored app opens.
///
/// [show] resolves to:
///   • a positive int  → start a session of that many minutes
///   • 0               → open the app this once with no limit
///   • null            → dismissed / backed out (do nothing)
class AppSessionPrompt extends ConsumerStatefulWidget {
  final String packageName;
  final String appName;
  final int defaultMinutes;
  final VoidCallback onSkip; // open once, no limit
  final void Function(int minutes) onStart;

  const AppSessionPrompt({
    super.key,
    required this.packageName,
    required this.appName,
    required this.defaultMinutes,
    required this.onSkip,
    required this.onStart,
  });

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
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) => AppSessionPrompt(
        packageName: packageName,
        appName: appName,
        defaultMinutes: defaultMinutes,
        onSkip: () => Navigator.pop(ctx, 0),
        onStart: (minutes) => Navigator.pop(ctx, minutes),
      ),
    );
  }

  @override
  ConsumerState<AppSessionPrompt> createState() => _AppSessionPromptState();
}

class _AppSessionPromptState extends ConsumerState<AppSessionPrompt> {
  static const _timeOptions = [5, 15, 30, 60];

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(themeColorProvider).color;
    final today = ref
        .watch(screenTimeProvider)
        .todayUsage
        .where((e) => e.packageName == widget.packageName)
        .firstOrNull;
    final letter =
        widget.appName.isNotEmpty ? widget.appName[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101012),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 26),
            // App badge
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(letter,
                  style: TextStyle(
                      color: accent,
                      fontSize: 27,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),
            Text(
              'How long on ${widget.appName}?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xF2FFFFFF),
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Set an intention before you dive in.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            // Time chips — evenly filled row
            Row(
              children: [
                for (int i = 0; i < _timeOptions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _chip(_timeOptions[i], accent)),
                ],
              ],
            ),
            if (today != null && today.usageTime.inMinutes > 0) ...[
              const SizedBox(height: 18),
              Text(
                'Already ${_fmt(today.usageTime)} on this today',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
            const SizedBox(height: 18),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onSkip,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Open without a limit',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(int minutes, Color accent) {
    final isDefault = minutes == widget.defaultMinutes;
    final label = minutes < 60 ? '${minutes}m' : '${minutes ~/ 60}h';
    return GestureDetector(
      onTap: () => widget.onStart(minutes),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDefault
              ? accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDefault
                ? accent.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDefault ? accent : Colors.white.withValues(alpha: 0.78),
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    if (d.inHours > 0) {
      final m = d.inMinutes % 60;
      return m > 0 ? '${d.inHours}h ${m}m' : '${d.inHours}h';
    }
    return '${d.inMinutes}m';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ⏰ "TIME'S UP" OVERLAY — compassionate close + extend chips.
// ═══════════════════════════════════════════════════════════════════════════

class TimesUpOverlay extends ConsumerWidget {
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

  /// Show full-screen. The provided [onExit]/[onExtend] are the single owners
  /// of the session lifecycle (see launcher_shell).
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
      transitionDuration: const Duration(milliseconds: 360),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
      pageBuilder: (ctx, _, __) => TimesUpOverlay(
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

  String _fmt(Duration d) {
    if (d.inHours > 0) {
      final m = d.inMinutes % 60;
      return m > 0 ? '${d.inHours} h $m min' : '${d.inHours} h';
    }
    return '${d.inMinutes} min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(themeColorProvider).color;
    final showReflection = extensionsUsed >= 2;

    return Material(
      color: const Color(0xFF0A0A0A),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('﷽',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 22,
                      color: Colors.white.withValues(alpha: 0.5),
                      height: 1.5)),
              const SizedBox(height: 16),
              Text(
                'Your time on $appName is complete.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.5),
              ),
              const SizedBox(height: 10),
              Text(
                '"Indeed, in the remembrance of Allah do hearts find rest."\n— Surah Ar-Ra\'d (13:28)',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withValues(alpha: 0.4),
                    height: 1.6),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatCol(label: 'Spent today', value: _fmt(todayUsage)),
                  const SizedBox(width: 32),
                  _StatCol(label: 'Last 7 days', value: _fmt(weekUsage)),
                ],
              ),
              const SizedBox(height: 36),
              // Primary: leave the app
              GestureDetector(
                onTap: onExit,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Center(
                    child: Text('TAKE ME OUT OF HERE',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            letterSpacing: 0.5)),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text('A little more time',
                  style: TextStyle(
                      fontSize: 12, color: Colors.white.withValues(alpha: 0.25))),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ExtendChip(
                      label: '+1m', accent: accent, onTap: () => onExtend(1)),
                  if (!showReflection) ...[
                    const SizedBox(width: 10),
                    _ExtendChip(
                        label: '+5m', accent: accent, onTap: () => onExtend(5)),
                    const SizedBox(width: 10),
                    _ExtendChip(
                        label: '+15m',
                        accent: accent,
                        onTap: () => onExtend(15)),
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
                        color: const Color(0xFFD93025).withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    'You\'ve extended $extensionsUsed times.\n"And do not waste, for Allah does not love the wasteful." — Al-An\'am (6:141)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.4),
                        height: 1.5),
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
  const _StatCol({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: Colors.white.withValues(alpha: 0.35))),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.8))),
      ],
    );
  }
}

class _ExtendChip extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;
  const _ExtendChip(
      {required this.label, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.55))),
      ),
    );
  }
}
