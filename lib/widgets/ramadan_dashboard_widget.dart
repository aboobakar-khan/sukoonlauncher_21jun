import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ramadan_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/deen_mode_screen.dart';

/// Ramadan Dashboard Widget — Full Ramadan tracker
///
/// Features:
/// 1. Horizontally scrollable week strip at the top (Week 1–5 with date range)
/// 2. Taraweeh toggle + "See History" button
/// 3. Fasting checklist beside Taraweeh
/// 4. Week-specific spiritual history view when a week is selected
/// 5. All colours driven by the app's [themeColorProvider] (accent)
class RamadanDashboardWidget extends ConsumerStatefulWidget {
  const RamadanDashboardWidget({super.key});

  @override
  ConsumerState<RamadanDashboardWidget> createState() =>
      _RamadanDashboardWidgetState();
}

class _RamadanDashboardWidgetState
    extends ConsumerState<RamadanDashboardWidget> {
  // Which week is highlighted in the strip (null = current week auto-selected)
  int? _selectedWeek;
  // Whether the history panel is expanded
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final ramadan = ref.watch(ramadanProvider);
    if (!ramadan.isRamadan) return const SizedBox.shrink();

    final accent = ref.watch(themeColorProvider).color;
    final night = ramadan.currentNight;
    final hadith = ramadanHadith[(night - 1) % ramadanHadith.length];
    final activeWeek = _selectedWeek ?? ramadan.currentWeek;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 1. Horizontal Week Strip ─────────────────────────────
          _WeekStrip(
            ramadan: ramadan,
            accent: accent,
            activeWeek: activeWeek,
            onWeekTap: (w) => setState(() {
              _selectedWeek = w;
              _showHistory = true;
            }),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ───────────────────────────────────────────
                _buildHeader(ramadan, accent, night),

                const SizedBox(height: 12),

                // ── Progress Bar ─────────────────────────────────────
                _buildProgressBar(night, accent),

                const SizedBox(height: 14),

                // ── Daily Hadith ─────────────────────────────────────
                _buildHadith(hadith, accent),

                const SizedBox(height: 14),

                // ── Taraweeh + Fasting side-by-side ─────────────────
                Row(
                  children: [
                    Expanded(child: _buildTaraweehTile(ramadan, accent)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildFastingTile(ramadan, accent)),
                  ],
                ),

                const SizedBox(height: 12),

                // ── History toggle ────────────────────────────────────
                _buildHistoryToggle(accent, activeWeek),

                // ── History panel ─────────────────────────────────────
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 280),
                  crossFadeState: _showHistory
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: _WeekHistoryPanel(
                    ramadan: ramadan,
                    accent: accent,
                    week: activeWeek,
                  ),
                ),

                // ── Laylatul Qadr (last 10 only) ─────────────────────
                if (night >= 20) ...[
                  const SizedBox(height: 10),
                  _buildQadrRow(ramadan, accent),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────
  Widget _buildHeader(RamadanState ramadan, Color accent, int night) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.nightlight_round, color: accent, size: 16),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ramadan Mubarak',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'Night $night of 30',
              style: TextStyle(
                color: accent.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department_rounded,
                  color: accent, size: 13),
              const SizedBox(width: 4),
              Text(
                '${ramadan.taraweehCount}/${ramadan.currentNight}',
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Progress bar ─────────────────────────────────────────────────────
  Widget _buildProgressBar(int night, Color accent) {
    final progress = night / 30;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(
                height: 6,
                color: Colors.white.withValues(alpha: 0.05),
              ),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.5),
                        accent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(progress * 100).toInt()}% complete',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
            ),
            Text(
              '${30 - night} nights left',
              style: TextStyle(
                  color: accent.withValues(alpha: 0.45), fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  // ── Hadith ────────────────────────────────────────────────────────────
  Widget _buildHadith(Map<String, String> hadith, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${hadith['text']}"',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
              height: 1.55,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '— ${hadith['source']}',
              style: TextStyle(
                color: accent.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Taraweeh tile ──────────────────────────────────────────────────────
  Widget _buildTaraweehTile(RamadanState ramadan, Color accent) {
    final prayed = ramadan.isTaraweehTonight;
    return GestureDetector(
      onTap: () {
        ref.read(ramadanProvider.notifier).toggleTaraweeh();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: prayed
              ? accent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: prayed
                ? accent.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          children: [
            Icon(
              prayed
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: prayed ? accent : Colors.white.withValues(alpha: 0.25),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Taraweeh',
                    style: TextStyle(
                      color: Colors.white
                          .withValues(alpha: prayed ? 0.90 : 0.50),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    prayed ? 'Prayed ✓' : 'Tap to mark',
                    style: TextStyle(
                      color: prayed
                          ? accent.withValues(alpha: 0.65)
                          : Colors.white.withValues(alpha: 0.25),
                      fontSize: 10,
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

  // ── Fasting tile ───────────────────────────────────────────────────────
  Widget _buildFastingTile(RamadanState ramadan, Color accent) {
    final fasting = ramadan.isFastingToday;
    final fastColor = Color.lerp(accent, Colors.white, 0.25)!;
    return GestureDetector(
      onTap: () {
        ref.read(ramadanProvider.notifier).toggleFasting();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: fasting
              ? fastColor.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: fasting
                ? fastColor.withValues(alpha: 0.30)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          children: [
            Icon(
              fasting ? Icons.water_drop_rounded : Icons.water_drop_outlined,
              color:
                  fasting ? fastColor : Colors.white.withValues(alpha: 0.25),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fasting',
                    style: TextStyle(
                      color: Colors.white
                          .withValues(alpha: fasting ? 0.90 : 0.50),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    fasting ? 'Kept ✓' : 'Tap to mark',
                    style: TextStyle(
                      color: fasting
                          ? fastColor.withValues(alpha: 0.65)
                          : Colors.white.withValues(alpha: 0.25),
                      fontSize: 10,
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

  // ── History toggle ─────────────────────────────────────────────────────
  Widget _buildHistoryToggle(Color accent, int activeWeek) {
    return GestureDetector(
      onTap: () {
        setState(() => _showHistory = !_showHistory);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(Icons.history_rounded,
                color: accent.withValues(alpha: 0.7), size: 16),
            const SizedBox(width: 8),
            Text(
              _showHistory
                  ? 'Hide Week $activeWeek History'
                  : 'See Week $activeWeek History',
              style: TextStyle(
                color: accent.withValues(alpha: 0.75),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(
              _showHistory
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: accent.withValues(alpha: 0.4),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ── Laylatul Qadr row ─────────────────────────────────────────────────
  Widget _buildQadrRow(RamadanState ramadan, Color accent) {
    final isQadr = ramadan.laylatulQadrNights.contains(ramadan.currentNight);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DeenModeScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isQadr
              ? LinearGradient(colors: [
                  accent.withValues(alpha: 0.12),
                  accent.withValues(alpha: 0.05),
                ])
              : null,
          color: isQadr ? null : Colors.white.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isQadr
                ? accent.withValues(alpha: 0.30)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome,
                color: accent.withValues(alpha: isQadr ? 1.0 : 0.5), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isQadr ? 'Possible Laylatul Qadr!' : 'Laylatul Qadr',
                    style: TextStyle(
                      color: isQadr
                          ? accent
                          : Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    isQadr
                        ? 'Open Deen Mode →'
                        : ramadan.nextQadrNight != null
                            ? 'Next odd: Night ${ramadan.nextQadrNight}'
                            : 'Seek in odd nights',
                    style: TextStyle(
                      color: isQadr
                          ? accent.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.25),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [21, 23, 25, 27, 29].map((n) {
                final isPast = n < ramadan.currentNight;
                final isCur = n == ramadan.currentNight;
                return Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCur
                          ? accent
                          : isPast
                              ? accent.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontally scrollable week strip
// ─────────────────────────────────────────────────────────────────────────────
class _WeekStrip extends StatelessWidget {
  final RamadanState ramadan;
  final Color accent;
  final int activeWeek;
  final ValueChanged<int> onWeekTap;

  const _WeekStrip({
    required this.ramadan,
    required this.accent,
    required this.activeWeek,
    required this.onWeekTap,
  });

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _dateRange(int week) {
    final (start, end) = ramadan.weekRange(week);
    final s = ramadan.ramadanStart.add(Duration(days: start - 1));
    final e = ramadan.ramadanStart.add(Duration(days: end - 1));
    return '${s.day} ${_months[s.month]} – ${e.day} ${_months[e.month]}';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        physics: const BouncingScrollPhysics(),
        itemCount: ramadan.totalWeeks,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final week = index + 1;
          final isActive = week == activeWeek;
          final (start, end) = ramadan.weekRange(week);
          final totalInWeek = end - start + 1;
          final isPastOrCurrent = start <= ramadan.currentNight;
          final taraweehDone =
              ramadan.taraweehForWeek(week).length;
          final fastingDone =
              ramadan.fastingForWeek(week).length;

          return GestureDetector(
            onTap: () {
              onWeekTap(week);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? accent.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isActive
                      ? accent.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.08),
                  width: isActive ? 1.2 : 0.8,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Wk $week',
                        style: TextStyle(
                          color: isActive
                              ? accent
                              : Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isPastOrCurrent) ...[
                        const SizedBox(width: 6),
                        _MiniDotRow(
                          done: taraweehDone,
                          total: totalInWeek,
                          color: accent,
                        ),
                        if (fastingDone > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '💧$fastingDone',
                            style: const TextStyle(fontSize: 9),
                          ),
                        ],
                      ],
                    ],
                  ),
                  Text(
                    _dateRange(week),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.28),
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini dot row — taraweeh completion indicator
// ─────────────────────────────────────────────────────────────────────────────
class _MiniDotRow extends StatelessWidget {
  final int done;
  final int total;
  final Color color;

  const _MiniDotRow({
    required this.done,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        return Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done
                  ? color.withValues(alpha: 0.80)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Week history panel — shows per-night Taraweeh + Fasting for selected week
// ─────────────────────────────────────────────────────────────────────────────
class _WeekHistoryPanel extends ConsumerWidget {
  final RamadanState ramadan;
  final Color accent;
  final int week;

  const _WeekHistoryPanel({
    required this.ramadan,
    required this.accent,
    required this.week,
  });

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(ramadanProvider.notifier);
    final (startNight, endNight) = ramadan.weekRange(week);
    final taraweehDoneCount =
        ramadan.taraweehNights.where((n) => n >= startNight && n <= endNight).length;
    final fastingDoneCount =
        ramadan.fastingDays.where((n) => n >= startNight && n <= endNight).length;
    final fastColor = Color.lerp(accent, Colors.white, 0.25)!;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Panel header ────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.calendar_view_week_rounded,
                  color: accent.withValues(alpha: 0.6), size: 14),
              const SizedBox(width: 6),
              Text(
                'Week $week  ·  Nights $startNight–$endNight',
                style: TextStyle(
                  color: accent.withValues(alpha: 0.75),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _HistoryBadge(
                icon: Icons.nightlight_round,
                value: '$taraweehDoneCount/${endNight - startNight + 1}',
                color: accent,
              ),
              const SizedBox(width: 6),
              _HistoryBadge(
                icon: Icons.water_drop_rounded,
                value: '$fastingDoneCount/${endNight - startNight + 1}',
                color: fastColor,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Per-night rows ───────────────────────────────────────
          ...List.generate(endNight - startNight + 1, (i) {
            final night = startNight + i;
            final isFuture = night > ramadan.currentNight;
            final isToday = night == ramadan.currentNight;
            final didTaraweeh = ramadan.taraweehNights.contains(night);
            final didFast = ramadan.fastingDays.contains(night);
            final date =
                ramadan.ramadanStart.add(Duration(days: night - 1));
            final dateLabel =
                '${date.day} ${_months[date.month]}';

            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  // Night chip
                  Container(
                    width: 36,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday
                          ? accent.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isToday
                            ? accent.withValues(alpha: 0.40)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      'N$night',
                      style: TextStyle(
                        color: isToday
                            ? accent
                            : Colors.white
                                .withValues(alpha: isFuture ? 0.18 : 0.55),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 52,
                    child: Text(
                      dateLabel,
                      style: TextStyle(
                        color: Colors.white
                            .withValues(alpha: isFuture ? 0.16 : 0.38),
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Taraweeh chip (tappable)
                  GestureDetector(
                    onTap: isFuture
                        ? null
                        : () {
                            notifier.toggleTaraweehForNight(night);
                          },
                    child: _HistoryCheckChip(
                      label: 'Taraweeh',
                      checked: didTaraweeh,
                      color: accent,
                      isFuture: isFuture,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Fasting chip (tappable)
                  GestureDetector(
                    onTap: isFuture
                        ? null
                        : () {
                            notifier.toggleFastingForDay(night);
                          },
                    child: _HistoryCheckChip(
                      label: 'Fast',
                      checked: didFast,
                      color: fastColor,
                      isFuture: isFuture,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small count badge used in week history header
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _HistoryBadge({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.80), size: 10),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              color: color.withValues(alpha: 0.85),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tappable Taraweeh / Fasting check chip for history rows
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryCheckChip extends StatelessWidget {
  final String label;
  final bool checked;
  final Color color;
  final bool isFuture;

  const _HistoryCheckChip({
    required this.label,
    required this.checked,
    required this.color,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        isFuture ? Colors.white.withValues(alpha: 0.10) : color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: checked
            ? effectiveColor.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: checked
              ? effectiveColor.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            checked
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: checked
                ? effectiveColor
                : Colors.white.withValues(alpha: 0.20),
            size: 11,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: checked
                  ? effectiveColor.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.25),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
