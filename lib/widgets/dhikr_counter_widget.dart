import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tasbih_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/islamic_theme_provider.dart';

import '../screens/dhikr_history_pro_dashboard_redesigned.dart';

/// Dhikr Counter Widget — Clean Minimalist Redesign
/// 
/// Principles:
/// 1. Ultra-minimal — no visual noise, pure focus
/// 2. Theme-consistent — adapts to light/dark mode
/// 3. Tap anywhere on counter → increment
/// 4. Smooth progress arc + haptic feedback
/// 5. Compact: header + dhikr pills + counter circle + actions
class DhikrCounterWidget extends ConsumerStatefulWidget {
  const DhikrCounterWidget({super.key});

  @override
  ConsumerState<DhikrCounterWidget> createState() => _DhikrCounterWidgetState();
}

class _DhikrCounterWidgetState extends ConsumerState<DhikrCounterWidget>
    with TickerProviderStateMixin {
  late AnimationController _countAnimController;
  late Animation<double> _scaleAnimation;

  // Dhikr list perfectly aligned with Dhikr.presets in tasbih_provider
  static const List<Map<String, String>> _dhikrList = [
    {
      'arabic': 'سُبْحَانَ اللَّهِ', 'transliteration': 'SubhanAllah',
      'meaning': 'Glory be to Allah', 'virtue': 'A tree planted in Jannah',
    },
    {
      'arabic': 'الْحَمْدُ لِلَّهِ', 'transliteration': 'Alhamdulillah',
      'meaning': 'Praise be to Allah', 'virtue': 'Fills the scales',
    },
    {
      'arabic': 'اللَّهُ أَكْبَرُ', 'transliteration': 'Allahu Akbar',
      'meaning': 'Allah is the Greatest', 'virtue': 'Fills the heavens',
    },
    {
      'arabic': 'لَا إِلَٰهَ إِلَّا اللَّهُ', 'transliteration': 'La ilaha illallah',
      'meaning': 'There is no god but Allah', 'virtue': 'Best of all dhikr',
    },
    {
      'arabic': 'أَسْتَغْفِرُ اللَّهَ', 'transliteration': 'Astaghfirullah',
      'meaning': 'I seek forgiveness from Allah', 'virtue': 'Sins forgiven like sea foam',
    },
    {
      'arabic': 'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ', 'transliteration': 'Astaghfirullah al-Azeem',
      'meaning': 'I seek forgiveness from Allah, the Mighty', 'virtue': 'Brings peace to the heart',
    },
    {
      'arabic': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', 'transliteration': 'SubhanAllahi wa bihamdihi',
      'meaning': 'Glory and praise be to Allah', 'virtue': 'Beloved words to Allah — Muslim',
    },
    {
      'arabic': 'سُبْحَانَ اللَّهِ الْعَظِيمِ', 'transliteration': 'SubhanAllah al-Azeem',
      'meaning': 'Glory be to Allah, the Mighty', 'virtue': 'Heavy on the scales — Bukhari',
    },
    {
      'arabic': 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ', 'transliteration': 'Allahumma salli ala Muhammad',
      'meaning': 'O Allah, send blessings upon Muhammad ﷺ', 'virtue': '10 blessings for each one — Muslim',
    },
    {
      'arabic': 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ', 'transliteration': 'La hawla wa la quwwata illa billah',
      'meaning': 'There is no power except with Allah', 'virtue': 'A treasure of Jannah — Bukhari',
    },
    {
      'arabic': 'سُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ...', 'transliteration': 'SubhanAllah wal Hamdulillah...',
      'meaning': 'Glory to Allah, Praise to Allah...', 'virtue': 'Four most beloved words to Allah',
    },
    {
      'arabic': 'يَا اللَّهُ', 'transliteration': 'Ya Allah',
      'meaning': 'O Allah', 'virtue': 'Calling upon the Creator',
    },
    {
      'arabic': 'يَا رَحْمَٰنُ', 'transliteration': 'Ya Rahman',
      'meaning': 'O Most Merciful', 'virtue': 'Invoking His endless mercy',
    },
    {
      'arabic': 'يَا رَحِيمُ', 'transliteration': 'Ya Raheem',
      'meaning': 'O Most Compassionate', 'virtue': 'Invoking His special compassion',
    },
    {
      'arabic': '...', 'transliteration': 'Custom Count',
      'meaning': 'Use for any dhikr', 'virtue': 'Your personal adhkar',
    },
    // New authentic Durood requested
    {
      'arabic': 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ كَمَا صَلَّيْتَ عَلَى إِبْرَاهِيمَ... إِنَّكَ حَمِيدٌ مَجِيدٌ', 'transliteration': 'Durood Ibrahim',
      'meaning': 'O Allah, send prayers upon Muhammad ﷺ and his family', 'virtue': 'The most authentic Durood in Salah — Bukhari',
    },
  ];

  @override
  void initState() {
    super.initState();
    _countAnimController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _countAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _countAnimController.dispose();
    super.dispose();
  }

  void _incrementCount() {
    HapticFeedback.mediumImpact();
    _countAnimController.forward().then((_) => _countAnimController.reverse());
    ref.read(tasbihProvider.notifier).increment();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final tc = ref.watch(islamicThemeColorsProvider);
    final tasbih = ref.watch(tasbihProvider);
    final dhikr = _dhikrList[tasbih.selectedDhikrIndex % _dhikrList.length];
    final progress = tasbih.currentCount / tasbih.targetCount;
    final done = tasbih.currentCount >= tasbih.targetCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header — tap to open dashboard ──
        _buildHeader(themeColor.color, tasbih, tc),

        const SizedBox(height: 8),

        // ── Dhikr selector — horizontal pills ──
        _buildDhikrSelector(tasbih.selectedDhikrIndex, themeColor.color, tc),

        const SizedBox(height: 16),

        // ── Main counter — tap area ──
        _buildCounter(dhikr, tasbih, progress, done, themeColor.color, tc),

        const SizedBox(height: 10),

        // ── Quick actions ──
        _buildActions(tasbih, tc),
      ],
    );
  }

  Widget _buildHeader(Color accent, dynamic tasbih, IslamicThemeColors tc) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const DhikrHistoryProDashboard(),
            transitionsBuilder: (_, anim, _, child) {
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 280),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Text(
              'DHIKR',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w600,
                color: accent.withValues(alpha: 0.7),
              ),
            ),
            if (tasbih.streakDays > 0) ...[
              const SizedBox(width: 8),
              Icon(Icons.local_fire_department_rounded, size: 11, color: accent.withValues(alpha: 0.7)),
              const SizedBox(width: 2),
              Text('${tasbih.streakDays}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: accent.withValues(alpha: 0.7))),
            ],
            const Spacer(),
            Text(_formatNumber(tasbih.totalAllTime),
              style: TextStyle(fontSize: 11, color: tc.textSecondary.withValues(alpha: 0.6))),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: tc.textSecondary.withValues(alpha: 0.4), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDhikrSelector(int selectedIndex, Color accent, IslamicThemeColors tc) {
    return SizedBox(
      height: 28,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _dhikrList.length,
        itemBuilder: (context, i) {
          final selected = i == selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () {
                ref.read(tasbihProvider.notifier).selectDhikr(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? accent.withValues(alpha: 0.4) : tc.surface.withValues(alpha: 0.3),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _dhikrList[i]['transliteration']!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? Colors.white.withValues(alpha: 0.95) : tc.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCounter(Map<String, String> dhikr, dynamic tasbih, double progress, bool done, Color accent, IslamicThemeColors tc) {
    return GestureDetector(
      onTap: _incrementCount,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          children: [
            // Arabic text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                dhikr['arabic']!,
                style: TextStyle(
                  // Dynamic font size for longer texts like Durood Ibrahim
                  fontSize: dhikr['arabic']!.length > 80 ? 18 : (dhikr['arabic']!.length > 40 ? 22 : 26),
                  fontWeight: FontWeight.w400,
                  color: tc.text.withValues(alpha: 0.95),
                  height: 1.6,
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dhikr['meaning']!,
              style: TextStyle(fontSize: 11, color: tc.textSecondary.withValues(alpha: 0.7), fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Progress ring + count
            SizedBox(
              width: 120, // increased from 80
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: math.min(progress, 1.0)),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    builder: (_, val, _) {
                      return CustomPaint(
                        size: const Size(120, 120),
                        painter: _ArcPainter(
                          progress: val,
                          bgColor: tc.surface.withValues(alpha: 0.3),
                          fgColor: done ? const Color(0xFF4ADE80) : const Color(0xFF81C784), // light leaf green line
                          stroke: 5, // slightly thicker stroke
                        ),
                      );
                    },
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 120),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Text(
                          '${tasbih.currentCount}',
                          key: ValueKey(tasbih.currentCount),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w300,
                            color: done ? const Color(0xFF4ADE80) : tc.text.withValues(alpha: 0.9),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      Text('/ ${tasbih.targetCount}',
                        style: TextStyle(fontSize: 10, color: tc.textSecondary.withValues(alpha: 0.6))),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),
            Text(
              dhikr['virtue']!,
              style: TextStyle(
                fontSize: 9,
                color: done ? const Color(0xFF4ADE80).withValues(alpha: 0.8) : tc.textSecondary.withValues(alpha: 0.6),
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(dynamic tasbih, IslamicThemeColors tc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              ref.read(tasbihProvider.notifier).reset();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, color: tc.textSecondary.withValues(alpha: 0.5), size: 13),
                  const SizedBox(width: 4),
                  Text('Reset',
                    style: TextStyle(fontSize: 11, color: tc.textSecondary.withValues(alpha: 0.5), fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          ),
          Container(
            width: 1, height: 12,
            color: tc.surface.withValues(alpha: 0.3),
          ),
          GestureDetector(
            onTap: () => _showTargetPicker(context, ref, tasbih.targetCount, tc),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_rounded, color: tc.textSecondary.withValues(alpha: 0.5), size: 13),
                  const SizedBox(width: 4),
                  Text('${tasbih.targetCount}',
                    style: TextStyle(fontSize: 11, color: tc.textSecondary.withValues(alpha: 0.5), fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTargetPicker(BuildContext context, WidgetRef ref, int currentTarget, IslamicThemeColors tc) {
    final themeColor = ref.read(themeColorProvider);
    final targets = [33, 99, 100, 500, 1000];
    showModalBottomSheet(
      context: context,
      backgroundColor: tc.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set Target',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: tc.text)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: targets.map((t) {
                final sel = t == currentTarget;
                return GestureDetector(
                  onTap: () {
                    ref.read(tasbihProvider.notifier).setTarget(t);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? themeColor.color.withValues(alpha: 0.15) : tc.surface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? themeColor.color : tc.surface.withValues(alpha: 0.5),
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Text('$t',
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600,
                        color: sel ? themeColor.color : tc.textSecondary)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

/// Minimal arc painter
class _ArcPainter extends CustomPainter {
  final double progress;
  final Color bgColor;
  final Color fgColor;
  final double stroke;

  _ArcPainter({
    required this.progress,
    required this.bgColor,
    required this.fgColor,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = fgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.progress != progress || old.fgColor != fgColor;
}
