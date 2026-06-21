import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/zen_mode_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/zen_mode_entry_screen.dart';

/// ─────────────────────────────────────────────
/// Zen Mode Widget — Dashboard compact card
/// Theme-aware: follows app accent color
/// ─────────────────────────────────────────────

class ZenModeWidget extends ConsumerWidget {
  const ZenModeWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zen = ref.watch(zenModeProvider);
    final accent = ref.watch(themeColorProvider).color;

    final cardBg = const Color(0xFF111111);
    final activeColor = accent;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ZenModeEntryScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: zen.isActive
              ? accent.withValues(alpha: 0.08)
              : cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: zen.isActive
                ? accent.withValues(alpha: 0.35)
                : accent.withValues(alpha: 0.12),
            width: zen.isActive ? 1.5 : 1,
          ),
          boxShadow: zen.isActive
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.08),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: activeColor.withValues(alpha: 0.12),
                    border: Border.all(
                      color: activeColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    Icons.nights_stay_rounded,
                    color: activeColor.withValues(alpha: 0.8),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kahf Mode',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        zen.isActive
                            ? '${zen.remainingFormatted} remaining'
                            : 'Block everything. Be present.',
                        style: TextStyle(
                          color: zen.isActive
                              ? accent.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.35),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // CTA button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: activeColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (zen.isActive)
                        Icon(Icons.timer_rounded, size: 14, color: accent.withValues(alpha: 0.9)),
                      if (zen.isActive) const SizedBox(width: 4),
                      Text(
                        zen.isActive ? 'Active' : 'Start →',
                        style: TextStyle(
                          color: activeColor.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Active indicator bar
            if (zen.isActive) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: zen.progress,
                  minHeight: 3,
                  backgroundColor: accent.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(accent.withValues(alpha: 0.6)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

