import 'package:flutter/material.dart';

// ─── Year Dots Analytics Grid ─────────────────────────────────────────────────
// Hero 365-dot grid — designed to fill ~80% of the screen on first view.
// Past days filled by intensity, today highlighted, future faint.
// User picks color from 8 themes, saved to Hive.

/// Available color themes for the dots grid.
enum DotsColorTheme {
  gold('Gold', Color(0xFFC2A366)),
  camel('Camel', Color(0xFFC19A6B)),
  emerald('Emerald', Color(0xFF4CAF85)),
  orange('Orange', Color(0xFFFF8C42)),
  rose('Rose', Color(0xFFE8768A)),
  teal('Teal', Color(0xFF4DB6AC)),
  lavender('Lavender', Color(0xFFB39DDB)),
  sky('Sky', Color(0xFF64B5F6));

  final String label;
  final Color color;
  const DotsColorTheme(this.label, this.color);
}

/// Data for a single day's dot.
class DayDotData {
  /// 0.0 = empty, 1.0 = max intensity.
  final double intensity;
  final int rawCount;
  const DayDotData({this.intensity = 0.0, this.rawCount = 0});
}

/// Hero 365-dot year analytics grid.
/// Sized to fill [heroFraction] of the screen height.
/// [dataForDay] maps 1-based day-of-year → intensity data.
class YearDotsAnalyticsGrid extends StatelessWidget {
  final int year;
  final DotsColorTheme colorTheme;
  final DayDotData Function(int dayOfYear) dataForDay;
  final String subtitle;
  final List<String> legendLabels;

  const YearDotsAnalyticsGrid({
    super.key,
    required this.year,
    required this.colorTheme,
    required this.dataForDay,
    this.subtitle = '',
    this.legendLabels = const ['0', '1-2', '3-4', '5'],
  });

  static bool _isLeapYear(int y) =>
      (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  static int _daysInYear(int y) => _isLeapYear(y) ? 366 : 365;

  static int _dayOfYear(DateTime d) =>
      d.difference(DateTime(d.year, 1, 1)).inDays + 1;

  @override
  Widget build(BuildContext context) {
    final totalDays = _daysInYear(year);
    final now = DateTime.now();
    final todayDOY = now.year == year ? _dayOfYear(now) : -1;
    final baseColor = colorTheme.color;

    final screenH = MediaQuery.sizeOf(context).height;
    final screenW = MediaQuery.sizeOf(context).width;

    // 15 columns — bigger dots, wider grid
    const int columns = 15;
    final totalRows = (totalDays / columns).ceil();

    // Available width (outer padding 16+16 = 32)
    const double hPad = 32;
    final availW = screenW - hPad;

    // Target the grid to fill ≈78% of screen height
    const double overhead = 90.0; // header + legend + gaps (no month labels)
    final targetGridH = screenH * 0.78 - overhead;

    const double spacing = 4.0;
    final dotFromH = (targetGridH - spacing * (totalRows - 1)) / totalRows;
    final dotFromW = (availW - spacing * (columns - 1)) / columns;
    final dot = dotFromH.clamp(0.0, dotFromW).clamp(12.0, 32.0);

    final gridW = columns * dot + (columns - 1) * spacing;
    final gridH = totalRows * dot + (totalRows - 1) * spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$year',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.28),
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            // Progress pill
            _ProgressPill(
              todayDOY: todayDOY > 0 ? todayDOY : 0,
              totalDays: totalDays,
              color: baseColor,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Dot grid ─────────────────────────────────────────────────
        SizedBox(
          width: gridW,
          height: gridH,
          child: GridView.builder(
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: 1,
            ),
            itemCount: columns * totalRows,
            itemBuilder: (_, idx) {
              final dayNum = idx + 1;

              if (dayNum > totalDays) {
                return const SizedBox.shrink();
              }

              final data = dataForDay(dayNum);
              final isToday = dayNum == todayDOY;
              final isFuture = now.year == year && dayNum > todayDOY;

              Color dotColor;
              if (isFuture) {
                dotColor = Colors.white.withValues(alpha: 0.05);
              } else if (data.intensity <= 0) {
                dotColor = Colors.white.withValues(alpha: 0.09);
              } else if (data.intensity <= 0.33) {
                dotColor = baseColor.withValues(alpha: 0.40); // Adjusted for higher contrast
              } else if (data.intensity <= 0.66) {
                dotColor = baseColor.withValues(alpha: 0.70); // Adjusted
              } else {
                dotColor = baseColor;
              }

              return DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle, // Make them sharp pixels
                  borderRadius: BorderRadius.circular(2), // Slight rounding for pseudo-pixel feel
                  color: dotColor,
                  border: isToday
                      ? Border.all(color: Colors.white, width: 1.5)
                      : null,
                  boxShadow: data.intensity > 0.66
                      ? [
                          BoxShadow(
                            color: baseColor.withValues(alpha: 0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          )
                        ]
                      : null, // Add a faint glow for highly active pixels
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // ── Legend + today indicator ──────────────────────────────────
        Row(
          children: [
            _LegendDot(
              color: Colors.white.withValues(alpha: 0.09),
              label: legendLabels.isNotEmpty ? legendLabels[0] : '0',
            ),
            if (legendLabels.length > 1)
              _LegendDot(color: baseColor.withValues(alpha: 0.28), label: legendLabels[1]),
            if (legendLabels.length > 2)
              _LegendDot(color: baseColor.withValues(alpha: 0.60), label: legendLabels[2]),
            if (legendLabels.length > 3)
              _LegendDot(color: baseColor, label: legendLabels[3]),
            const Spacer(),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'today',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}

/// Compact progress pill: day X / total · mini bar.
class _ProgressPill extends StatelessWidget {
  final int todayDOY;
  final int totalDays;
  final Color color;

  const _ProgressPill({
    required this.todayDOY,
    required this.totalDays,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalDays > 0 ? (todayDOY / totalDays).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Day $todayDOY',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            ' / $totalDays',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.28),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
               borderRadius: BorderRadius.circular(2),
               color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Compact inline color theme picker — minimal dots row, no card.
class DotsColorPicker extends StatelessWidget {
  final DotsColorTheme selected;
  final ValueChanged<DotsColorTheme> onChanged;

  const DotsColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'COLOR',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.18),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 12),
        ...DotsColorTheme.values.map((theme) {
          final isSel = theme == selected;
          return GestureDetector(
            onTap: () {
              onChanged(theme);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSel ? 22 : 18,
              height: isSel ? 22 : 18,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.color.withValues(alpha: isSel ? 1.0 : 0.40),
                border: isSel
                    ? Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2.0)
                    : Border.all(color: theme.color.withValues(alpha: 0.15), width: 1.0),
              ),
            ),
          );
        }),
      ],
    );
  }
}

