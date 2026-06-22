import 'package:flutter/material.dart';

/// Unified minimalist blocker screen — used across ALL entry points:
/// home clock favorites, app list, quick search, and native overlay fallback.
///
/// Design: Deep black bg, single red accent, breathing block icon,
/// short rotating motivation, "Go Back" button.
class BlockedAppScreen extends StatefulWidget {
  final String appName;
  final bool autoDismiss;
  final VoidCallback? onDismiss;

  const BlockedAppScreen({
    super.key,
    required this.appName,
    this.autoDismiss = false,
    this.onDismiss,
  });

  /// Show as a full-screen dialog (home clock, app list)
  static void showAsDialog(BuildContext context, String appName) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Blocked',
      barrierColor: Colors.black.withValues(alpha: 0.92),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        );
      },
      pageBuilder: (ctx, _, _) => BlockedAppScreen(appName: appName),
    );
  }

  @override
  State<BlockedAppScreen> createState() => _BlockedAppScreenState();
}

class _BlockedAppScreenState extends State<BlockedAppScreen>
    with SingleTickerProviderStateMixin {
  // ── Colors ──
  static const _blockRed = Color(0xFFD93025);
  static const _bgDark = Color(0xFF0A0A0A);
  static const _subtleWhite = Colors.white;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  static const _motivations = [
    'This urge will pass.\nYour discipline won\'t.',
    'Every second of resistance\nrewires your brain.',
    'You chose to block this.\nTrust your better self.',
    'The discomfort is temporary.\nThe growth is permanent.',
    'Stay the course.\nYour future self thanks you.',
    'Distraction steals time\nyou can never get back.',
  ];

  late String _motivation;

  @override
  void initState() {
    super.initState();
    _motivation = _motivations[DateTime.now().millisecond % _motivations.length];
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    if (widget.autoDismiss) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _close();
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _close() {
    if (widget.onDismiss != null) {
      widget.onDismiss!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bgDark,
      child: SafeArea(
        child: GestureDetector(
          onTap: _close,
          behavior: HitTestBehavior.opaque,
          child: SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // ── Pulsing block icon ──
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, _) => Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _blockRed.withValues(alpha: 0.06 * _pulseAnim.value),
                        border: Border.all(
                          color: _blockRed.withValues(alpha: 0.15 * _pulseAnim.value),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.block_rounded,
                        color: _blockRed.withValues(alpha: 0.4 + 0.4 * _pulseAnim.value),
                        size: 36,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── App name ──
                  Text(
                    widget.appName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _subtleWhite.withValues(alpha: 0.35),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── "Blocked" label ──
                  Text(
                    'BLOCKED',
                    style: TextStyle(
                      color: _blockRed.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Short motivation ──
                  Text(
                    _motivation,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _subtleWhite.withValues(alpha: 0.55),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.6,
                      letterSpacing: 0.1,
                    ),
                  ),

                  const Spacer(flex: 3),

                  // ── Go Back button ──
                  GestureDetector(
                    onTap: () {
                      _close();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _subtleWhite.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _subtleWhite.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Go Back',
                          style: TextStyle(
                            color: _subtleWhite.withValues(alpha: 0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
