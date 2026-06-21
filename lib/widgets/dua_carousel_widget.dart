import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Time-of-day period — SAME system as prayer_time_widget for visual consistency
// ─────────────────────────────────────────────────────────────────────────────

enum _DayPeriod { morning, afternoon, evening, night }

_DayPeriod _currentPeriod() {
  final h = DateTime.now().hour;
  if (h >= 4 && h < 12) return _DayPeriod.morning;
  if (h >= 12 && h < 17) return _DayPeriod.afternoon;
  if (h >= 17 && h < 20) return _DayPeriod.evening;
  return _DayPeriod.night;
}

class _PeriodTheme {
  final List<Color> gradientColors;
  final List<double> gradientStops;
  final Color accent;
  final IconData icon;
  final String label;

  const _PeriodTheme({
    required this.gradientColors,
    required this.gradientStops,
    required this.accent,
    required this.icon,
    required this.label,
  });
}

_PeriodTheme _themeForPeriod(_DayPeriod p) {
  switch (p) {
    case _DayPeriod.morning:
      return const _PeriodTheme(
        gradientColors: [Color(0xFF0D1B2E), Color(0xFF162840), Color(0xFF1A2A44)],
        gradientStops: [0.0, 0.55, 1.0],
        accent: Color(0xFFFDB347),
        icon: Icons.wb_twilight_rounded,
        label: 'Morning',
      );
    case _DayPeriod.afternoon:
      return const _PeriodTheme(
        gradientColors: [Color(0xFF0A1A0E), Color(0xFF0E2014), Color(0xFF122818)],
        gradientStops: [0.0, 0.55, 1.0],
        accent: Color(0xFF6FB86A),
        icon: Icons.wb_sunny_rounded,
        label: 'Afternoon',
      );
    case _DayPeriod.evening:
      return const _PeriodTheme(
        gradientColors: [Color(0xFF1A0D1A), Color(0xFF260D26), Color(0xFF2A1028)],
        gradientStops: [0.0, 0.55, 1.0],
        accent: Color(0xFFE87B40),
        icon: Icons.wb_sunny_outlined,
        label: 'Evening',
      );
    case _DayPeriod.night:
      return const _PeriodTheme(
        gradientColors: [Color(0xFF0A1628), Color(0xFF0D1E35), Color(0xFF102440)],
        gradientStops: [0.0, 0.55, 1.0],
        accent: Color(0xFF7896E2),
        icon: Icons.nights_stay_rounded,
        label: 'Night',
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dua data model
// ─────────────────────────────────────────────────────────────────────────────

enum _DuaTime { suhoor, iftar, night, anytime }

class _Dua {
  final String title;
  final String arabic;
  final String translation;
  final _DuaTime bestTime;
  final String reference;
  final String emoji;

  const _Dua({
    required this.title,
    required this.arabic,
    required this.translation,
    required this.bestTime,
    this.reference = '',
    this.emoji = '🤲',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Dua collection — 14 essential duas (COMPLETE Arabic + English)
// ─────────────────────────────────────────────────────────────────────────────

const _duas = <_Dua>[
  _Dua(
    title: 'Laylat-al-Qadr',
    arabic: 'اللَّهُمَّ إِنَّكَ عَفُوٌّ تُحِبُّ الْعَفْوَ فَاعْفُ عَنِّي',
    translation: 'O Allah, You are the One Who pardons greatly, and loves to pardon, so pardon me.',
    bestTime: _DuaTime.night,
    reference: 'Tirmidhi 3513',
    emoji: '✨',
  ),
  _Dua(
    title: 'Iftar Dua',
    arabic: 'ذَهَبَ الظَّمَأُ وَابْتَلَّتِ الْعُرُوقُ وَثَبَتَ الْأَجْرُ إِنْ شَاءَ اللَّهُ',
    translation: 'The thirst has gone, the veins are moistened, and the reward is confirmed, if Allah wills.',
    bestTime: _DuaTime.iftar,
    reference: 'Abu Dawud 2357',
    emoji: '🌙',
  ),
  _Dua(
    title: 'Suhoor Dua',
    arabic: 'وَبِصَوْمِ غَدٍ نَّوَيْتُ مِنْ شَهْرِ رَمَضَانَ',
    translation: 'I intend to keep the fast for tomorrow in the month of Ramadan.',
    bestTime: _DuaTime.suhoor,
    emoji: '🌅',
  ),
  _Dua(
    title: 'Best of Both Worlds',
    arabic: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
    translation: 'Our Lord, give us good in this world and good in the Hereafter, and protect us from the torment of the Fire.',
    bestTime: _DuaTime.anytime,
    reference: 'Quran 2:201',
    emoji: '🕌',
  ),
  _Dua(
    title: 'Approaching Ramadan',
    arabic: 'اللَّهُمَّ سَلِّمْنِي لِرَمَضَانَ وَسَلِّمْ رَمَضَانَ لِي وَسَلِّمْهُ لِي مُتَقَبَّلًا',
    translation: 'O Allah, safeguard me for the month of Ramadan, and safeguard Ramadan for me, and accept it from me.',
    bestTime: _DuaTime.anytime,
    reference: 'Tabrani',
    emoji: '☪️',
  ),
  _Dua(
    title: 'Protection',
    arabic: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ رِضَاكَ وَالْجَنَّةَ وَأَعُوذُ بِكَ مِنْ سَخَطِكَ وَالنَّارِ',
    translation: 'O Allah, I ask You for Your pleasure and for Paradise, and I seek refuge in You from Your displeasure and from the Hellfire.',
    bestTime: _DuaTime.anytime,
    reference: 'Abu Dawud 1542',
    emoji: '🛡️',
  ),
  _Dua(
    title: 'Guidance',
    arabic: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْهُدَى وَالتُّقَى وَالْعَفَافَ وَالْغِنَى',
    translation: 'O Allah, I ask You for guidance, piety, chastity and self-sufficiency.',
    bestTime: _DuaTime.anytime,
    reference: 'Muslim 2721',
    emoji: '🧭',
  ),
  _Dua(
    title: 'Direction',
    arabic: 'اللَّهُمَّ اهْدِنِي وَسَدِّدْنِي',
    translation: 'O Allah, guide me and keep me on the right path.',
    bestTime: _DuaTime.anytime,
    reference: 'Muslim 2725',
    emoji: '🧭',
  ),
  _Dua(
    title: 'For the Deceased',
    arabic: 'اللَّهُمَّ اغْفِرْ لَهُ وَارْحَمْهُ وَعَافِهِ وَاعْفُ عَنْهُ وَأَكْرِمْ نُزُلَهُ وَوَسِّعْ مُدْخَلَهُ وَاغْسِلْهُ بِالْمَاءِ وَالثَّلْجِ وَالْبَرَدِ',
    translation: 'O Allah, forgive him, have mercy on him, keep him safe and pardon him, honour his reception, cause his entrance to be wide, and wash him with water, snow and hail.',
    bestTime: _DuaTime.anytime,
    reference: 'Muslim 963',
    emoji: '🕊️',
  ),
  _Dua(
    title: 'Steadfast in Prayer',
    arabic: 'رَبِّ اجْعَلْنِي مُقِيمَ الصَّلَاةِ وَمِنْ ذُرِّيَّتِي رَبَّنَا وَتَقَبَّلْ دُعَاءِ',
    translation: 'My Lord, make me an establisher of prayer, and many from my descendants. Our Lord, accept my supplication.',
    bestTime: _DuaTime.anytime,
    reference: 'Quran 14:40',
    emoji: '🕌',
  ),
  _Dua(
    title: 'Remembrance & Gratitude',
    arabic: 'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ',
    translation: 'O Allah, help me to remember You, to give thanks to You, and to worship You in the best of manners.',
    bestTime: _DuaTime.anytime,
    reference: 'Abu Dawud 1522',
    emoji: '📿',
  ),
  _Dua(
    title: 'Seeing Crescent Moon',
    arabic: 'اللَّهُمَّ أَهِلَّهُ عَلَيْنَا بِالْأَمْنِ وَالْإِيمَانِ وَالسَّلَامَةِ وَالْإِسْلَامِ رَبِّي وَرَبُّكَ اللَّهُ',
    translation: 'O Allah, bring it over us with security and faith, with safety and Islam. My Lord and your Lord is Allah.',
    bestTime: _DuaTime.night,
    reference: 'Tirmidhi 3451',
    emoji: '🌙',
  ),
  _Dua(
    title: 'Taraweeh',
    arabic: 'سُبْحَانَ ذِي الْمُلْكِ وَالْمَلَكُوتِ، سُبْحَانَ ذِي الْعِزَّةِ وَالْعَظَمَةِ وَالْهَيْبَةِ وَالْقُدْرَةِ وَالْكِبْرِيَاءِ وَالْجَبَرُوتِ، سُبْحَانَ الْمَلِكِ الْحَيِّ الَّذِي لَا يَنَامُ وَلَا يَمُوتُ، سُبُّوحٌ قُدُّوسٌ رَبُّ الْمَلَائِكَةِ وَالرُّوحِ',
    translation: 'Glory be to the Owner of the Kingdom and Dominion. Glory be to the Owner of Honour and Greatness and Awe and Power and Pride and Majesty. Glory be to the Sovereign, the Living, Who neither sleeps nor dies. All-Perfect, All-Holy, Lord of the Angels and the Spirit.',
    bestTime: _DuaTime.night,
    reference: 'Nasa\'i',
    emoji: '🌃',
  ),
  _Dua(
    title: 'Anger while Fasting',
    arabic: 'إِنِّي صَائِمٌ، إِنِّي صَائِمٌ',
    translation: 'I am fasting, I am fasting. (Say this when someone provokes you while fasting instead of responding with anger.)',
    bestTime: _DuaTime.anytime,
    reference: 'Bukhari & Muslim',
    emoji: '🤲',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Smart ordering: surface contextually-relevant duas first
// ─────────────────────────────────────────────────────────────────────────────

List<_Dua> _orderedDuas() {
  final hour = DateTime.now().hour;
  final list = List<_Dua>.from(_duas);

  int weight(_Dua d) {
    if (hour >= 3 && hour < 6) {
      if (d.bestTime == _DuaTime.suhoor) return 10;
      if (d.bestTime == _DuaTime.night) return 6;
    } else if (hour >= 17 && hour < 20) {
      if (d.bestTime == _DuaTime.iftar) return 10;
      if (d.bestTime == _DuaTime.night) return 5;
    } else if (hour >= 20 || hour < 3) {
      if (d.bestTime == _DuaTime.night) return 10;
      if (d.bestTime == _DuaTime.iftar) return 4;
    }
    return 1;
  }

  list.sort((a, b) => weight(b).compareTo(weight(a)));
  return list;
}

// ─────────────────────────────────────────────────────────────────────────────
// RamadanDuaWidget — Professional card matching prayer_time_widget design
// ─────────────────────────────────────────────────────────────────────────────

class RamadanDuaWidget extends StatefulWidget {
  const RamadanDuaWidget({super.key});

  @override
  State<RamadanDuaWidget> createState() => _RamadanDuaWidgetState();
}

class _RamadanDuaWidgetState extends State<RamadanDuaWidget> {
  late final PageController _pageController;
  late final List<_Dua> _ordered;
  final ValueNotifier<double> _pageNotifier = ValueNotifier(0.0);
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _ordered = _orderedDuas();
    _pageController = PageController()
      ..addListener(() {
        _pageNotifier.value = _pageController.page ?? 0.0;
      });
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = ((_pageController.page?.round() ?? 0) + 1) % _ordered.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    _pageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final period = _currentPeriod();
    final theme = _themeForPeriod(period);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradientColors,
          stops: theme.gradientStops,
        ),
        border: Border.all(
          color: theme.accent.withValues(alpha: 0.18),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.accent.withValues(alpha: 0.08),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // ── Period decoration top-right (crescent/sun arc) ──
            Positioned(
              top: -6,
              right: 16,
              child: _PeriodDecoration(color: theme.accent, period: period),
            ),

            // ── DUA badge top-left ──
            Positioned(
              top: 8,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.accent.withValues(alpha: 0.25),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🤲', style: const TextStyle(fontSize: 9)),
                    const SizedBox(width: 4),
                    Text(
                      'DUA',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: theme.accent.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Page counter top-right ──
            Positioned(
              top: 10,
              right: 14,
              child: ValueListenableBuilder<double>(
                valueListenable: _pageNotifier,
                builder: (_, page, _) {
                  final idx = page.round().clamp(0, _ordered.length - 1) + 1;
                  return Text(
                    '$idx / ${_ordered.length}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  );
                },
              ),
            ),

            // ── Card content (swipeable pages) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 30, 0, 0),
              child: SizedBox(
                height: 175,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _ordered.length,
                  onPageChanged: (_) {
                    _startAutoScroll();
                  },
                  itemBuilder: (_, index) {
                    return _DuaPage(
                      dua: _ordered[index],
                      accent: theme.accent,
                    );
                  },
                ),
              ),
            ),

            // ── Page dots at bottom ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: ValueListenableBuilder<double>(
                valueListenable: _pageNotifier,
                builder: (_, page, _) => _PageDots(
                  total: _ordered.length,
                  currentPage: page,
                  accent: theme.accent,
                ),
              ),
            ),

            // ── Subtle swipe hint chevrons ──
            Positioned(
              left: 5,
              top: 0,
              bottom: 0,
              child: Center(
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              right: 5,
              top: 0,
              bottom: 0,
              child: Center(
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single Dua page — Tap-to-flip: Arabic (front) ↔ Translation (back)
// ─────────────────────────────────────────────────────────────────────────────

class _DuaPage extends StatefulWidget {
  final _Dua dua;
  final Color accent;

  const _DuaPage({required this.dua, required this.accent});

  @override
  State<_DuaPage> createState() => _DuaPageState();
}

class _DuaPageState extends State<_DuaPage> with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  bool _showingFront = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flip() {
    if (_showingFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() => _showingFront = !_showingFront);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      behavior: HitTestBehavior.opaque,
      child: _FlipAnimBuilder(
        animation: _flipAnimation,
        builder: (context, _) {
          final angle = _flipAnimation.value * pi;
          final isFront = angle < pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateY(angle),
            child: isFront
                ? _buildFront()
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _buildBack(),
                  ),
          );
        },
      ),
    );
  }

  // ── FRONT: Arabic text + title ──
  Widget _buildFront() {
    final accent = widget.accent;
    final dua = widget.dua;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          // ── Title row: emoji + dua name + reference badge ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.10),
                ),
                child: Text(dua.emoji, style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ARABIC',
                      style: TextStyle(
                        fontSize: 7.5,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    Text(
                      dua.title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: accent.withValues(alpha: 0.85),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (dua.reference.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.18),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    dua.reference,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: accent.withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),
          _Divider(accent: accent),
          const SizedBox(height: 10),

          // ── Arabic text — full, scrollable ──
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  dua.arabic,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.7,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),

          // ── Tap hint ──
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app_rounded, size: 11,
                    color: accent.withValues(alpha: 0.30)),
                const SizedBox(width: 4),
                Text(
                  'Tap to see translation',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: accent.withValues(alpha: 0.30),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── BACK: English translation ──
  Widget _buildBack() {
    final accent = widget.accent;
    final dua = widget.dua;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          // ── Title row: same layout ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.10),
                ),
                child: Text(dua.emoji, style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRANSLATION',
                      style: TextStyle(
                        fontSize: 7.5,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    Text(
                      dua.title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: accent.withValues(alpha: 0.85),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (dua.reference.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.18),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    dua.reference,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: accent.withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),
          _Divider(accent: accent),
          const SizedBox(height: 10),

          // ── Translation — full, scrollable, in tinted container ──
          Expanded(
            child: Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    '" ${dua.translation} "',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.white.withValues(alpha: 0.65),
                      height: 1.55,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Tap hint ──
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app_rounded, size: 11,
                    color: accent.withValues(alpha: 0.30)),
                const SizedBox(width: 4),
                Text(
                  'Tap to see Arabic',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: accent.withValues(alpha: 0.30),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Helper AnimatedWidget for flip animation (avoids Flutter's AnimatedBuilder name)
class _FlipAnimBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;

  const _FlipAnimBuilder({required Animation<double> animation, required this.builder})
      : super(listenable: animation);

  @override
  Widget build(BuildContext context) => builder(context, null);
}

// ─────────────────────────────────────────────────────────────────────────────
// Thin divider with dot — identical to prayer_time_widget
// ─────────────────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  final Color accent;
  const _Divider({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(height: 0.4, color: Colors.white.withValues(alpha: 0.07)),
        ),
        Container(
          width: 4, height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.25),
          ),
        ),
        Expanded(
          child: Container(height: 0.4, color: Colors.white.withValues(alpha: 0.07)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Period decoration — identical to prayer_time_widget (crescent/sun/arcs)
// ─────────────────────────────────────────────────────────────────────────────

class _PeriodDecoration extends StatelessWidget {
  final Color color;
  final _DayPeriod period;
  const _PeriodDecoration({required this.color, required this.period});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56, height: 56,
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
      final path = Path();
      final cx = size.width * 0.55, cy = size.height * 0.45, r = size.width * 0.3;
      path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      final cutPath = Path();
      cutPath.addOval(Rect.fromCircle(center: Offset(cx + r * 0.5, cy - r * 0.1), radius: r * 0.78));
      canvas.drawPath(Path.combine(PathOperation.difference, path, cutPath), paint);
    } else if (period == _DayPeriod.morning) {
      final arcPaint = Paint()
        ..color = color.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(size.width * 0.55, size.height * 0.65), radius: size.width * 0.28),
        3.14, 3.14, false, arcPaint,
      );
      canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.65), size.width * 0.08, paint);
    } else if (period == _DayPeriod.afternoon) {
      canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.45), size.width * 0.15, paint);
      final rayPaint = Paint()
        ..color = color.withValues(alpha: 0.09)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 8; i++) {
        final angle = (i * 3.14159 * 2) / 8;
        final cx = size.width * 0.55, cy = size.height * 0.45;
        canvas.drawLine(
          Offset(cx + size.width * 0.2 * cos(angle), cy + size.width * 0.2 * sin(angle)),
          Offset(cx + size.width * 0.3 * cos(angle), cy + size.width * 0.3 * sin(angle)),
          rayPaint,
        );
      }
    } else {
      final arcPaint = Paint()
        ..color = color.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(size.width * 0.55, size.height * 0.6), radius: size.width * 0.22),
        3.14, 3.14, false, arcPaint,
      );
      final arcPaint2 = Paint()
        ..color = color.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(size.width * 0.55, size.height * 0.6), radius: size.width * 0.34),
        3.14, 3.14, false, arcPaint2,
      );
    }

    // Tiny accent dots
    final dotPaint = Paint()..color = color.withValues(alpha: 0.18)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.25), 1.2, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.72), 0.9, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.65), 0.7, dotPaint);
  }

  @override
  bool shouldRepaint(_PeriodPainter old) => old.color != color || old.period != period;
}

// ─────────────────────────────────────────────────────────────────────────────
// Minimal page indicator dots — accent-colored
// ─────────────────────────────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  final int total;
  final double currentPage;
  final Color accent;

  const _PageDots({required this.total, required this.currentPage, required this.accent});

  @override
  Widget build(BuildContext context) {
    const maxVisible = 7;
    final centerIndex = currentPage.round().clamp(0, total - 1);
    int start = (centerIndex - maxVisible ~/ 2).clamp(0, max(0, total - maxVisible));
    int end = min(start + maxVisible, total);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(end - start, (i) {
        final dotIndex = start + i;
        final dist = (currentPage - dotIndex).abs().clamp(0.0, 2.0);
        final active = dist < 0.5;
        final w = active ? 16.0 : 4.0;
        final opacity = lerpDouble(1.0, 0.25, dist / 2.0)!;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: w,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2.5),
            color: active
                ? accent.withValues(alpha: 0.7 * opacity)
                : Colors.white.withValues(alpha: 0.15 * opacity),
          ),
        );
      }),
    );
  }
}
