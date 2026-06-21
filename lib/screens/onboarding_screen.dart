import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'warmup_screen.dart';
import '../utils/hive_box_manager.dart';

// ─── Sukoon Premium Onboarding ──────────────────────────────────
//
// 7-page storytelling flow. No swipe navigation — Next/Back buttons only.
// Skip button top-right only.
// No location permission ask.
// Set Default Launcher is the final page (with Finish).
//
// Pages:
//  1. Welcome       — emotional hook, brand identity
//  2. The Problem   — what's broken with normal phones
//  3. Features      — faith + focus + calm overview
//  4. Prayer Times  — salah alarms, adhan, Ramadan
//  5. Productivity  — focus tools, screen wellness
//  6. Personalise   — clock styles, themes, widgets
//  7. Activate      — set as default launcher + Finish

// ─── Palette ────────────────────────────────────────────────────
const _kLeafGreen = Color(0xFF6B8F71);
const _kLeafDark = Color(0xFF4A6B4F);
const _kBeige = Color(0xFFF5F0E8);
const _kBeigeDark = Color(0xFFE8E0D0);
const _kInk = Color(0xFF1A2A1C);
const _kInkSoft = Color(0xFF3D5240);
const _kInkMuted = Color(0xFF6B7D6E);

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  int _page = 0;
  static const int _totalPages = 7;

  late AnimationController _entranceCtrl;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entranceFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.1, 0.8, curve: Curves.easeOutCubic),
    ));
    _entranceCtrl.forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    super.dispose();
  }

  // ─── Navigation ─────────────────────────────────────────────

  Future<void> _completeOnboarding() async {
    final box = await HiveBoxManager.get('settingsBox');
    await box.put('onboarding_completed', true);
  }

  void _goTo(int index) {
    if (index < 0 || index >= _totalPages) return;
    _entranceCtrl.reset();
    setState(() => _page = index);
    _entranceCtrl.forward();
  }

  void _next() => _goTo(_page + 1);
  void _back() => _goTo(_page - 1);

  void _setDefaultAndNext() async {
    try {
      const platform = MethodChannel('com.sukoon.launcher/launcher');
      await platform.invokeMethod('openHomeLauncherSettings');
    } catch (e) {
      debugPrint('Home settings error: $e');
    }
    // After the user returns from the system launcher picker, finish onboarding.
    _finish();
  }

  void _finish() async {
    await _completeOnboarding();
    if (mounted) _navigateToLauncher();
  }

  void _skipToLauncher() async {
    await _completeOnboarding();
    if (mounted) _navigateToLauncher();
  }

  void _navigateToLauncher() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const WarmupScreen(),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────

  Widget _buildCurrentPage() {
    switch (_page) {
      case 0:
        return _PageWelcome(fade: _entranceFade, slide: _entranceSlide);
      case 1:
        return _PageProblem(fade: _entranceFade, slide: _entranceSlide);
      case 2:
        return _PageFeatures(fade: _entranceFade, slide: _entranceSlide);
      case 3:
        return _PagePrayer(fade: _entranceFade, slide: _entranceSlide);
      case 4:
        return _PageProductivity(fade: _entranceFade, slide: _entranceSlide);
      case 5:
        return _PagePersonalise(fade: _entranceFade, slide: _entranceSlide);
      case 6:
        return _PageActivate(
          fade: _entranceFade,
          slide: _entranceSlide,
          onSetDefault: _setDefaultAndNext,
          onFinish: _finish,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFirst = _page == 0;
    final isLast = _page == _totalPages - 1;

    return Scaffold(
      backgroundColor: _kBeige,
      body: Stack(
        children: [
          // Organic background
          Positioned.fill(child: _OrganicBackground(pulse: _pulseAnim)),

          SafeArea(
            child: Column(
              children: [
                // ── Top bar: progress + skip ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 20, 0),
                  child: Row(
                    children: [
                      // Progress dots
                      Expanded(
                        child: _ProgressBar(current: _page, total: _totalPages),
                      ),
                      const SizedBox(width: 16),
                      // Skip — only on non-last pages
                      if (!isLast)
                        GestureDetector(
                          onTap: _skipToLauncher,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 4),
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _kInkMuted.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Page content ──
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: child,
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_page),
                      child: _buildCurrentPage(),
                    ),
                  ),
                ),

                // ── Bottom navigation: Back / Next or Finish ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Row(
                    children: [
                      // Back button — invisible on first page
                      if (!isFirst)
                        GestureDetector(
                          onTap: _back,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: _kInk.withValues(alpha: 0.05),
                              border: Border.all(
                                color: _kInk.withValues(alpha: 0.07),
                              ),
                            ),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              size: 20,
                              color: _kInkSoft.withValues(alpha: 0.5),
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 52),

                      const SizedBox(width: 12),

                      // Next / Finish button
                      Expanded(
                        child: GestureDetector(
                          onTap: isLast ? _finish : _next,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: _kLeafGreen,
                              boxShadow: [
                                BoxShadow(
                                  color: _kLeafGreen.withValues(alpha: 0.28),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isLast ? 'Get Started' : 'Next',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    isLast
                                        ? Icons.check_rounded
                                        : Icons.arrow_forward_rounded,
                                    size: 17,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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

// ═════════════════════════════════════════════════════════════════
// ORGANIC BACKGROUND — subtle living texture
// ═════════════════════════════════════════════════════════════════

class _OrganicBackground extends StatelessWidget {
  final Animation<double> pulse;
  const _OrganicBackground({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final v = pulse.value;
        return CustomPaint(
          painter: _OrganicPainter(breathe: v),
          size: Size.infinite,
        );
      },
    );
  }
}

class _OrganicPainter extends CustomPainter {
  final double breathe;
  _OrganicPainter({required this.breathe});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final p1 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.8, -0.6),
        radius: 0.9,
        colors: [
          _kLeafGreen.withValues(alpha: 0.06 + breathe * 0.02),
          _kLeafGreen.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p1);

    final p2 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.7, 0.7),
        radius: 0.8,
        colors: [
          _kLeafDark.withValues(alpha: 0.04 + breathe * 0.015),
          _kLeafDark.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p2);

    final p3 = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.5,
        colors: [
          _kBeigeDark.withValues(alpha: 0.3 + breathe * 0.05),
          _kBeigeDark.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p3);
  }

  @override
  bool shouldRepaint(_OrganicPainter old) => old.breathe != breathe;
}

// ═════════════════════════════════════════════════════════════════
// PROGRESS BAR
// ═════════════════════════════════════════════════════════════════

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            height: 3,
            margin: EdgeInsets.only(right: i < total - 1 ? 5 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: i <= current
                  ? _kLeafGreen.withValues(alpha: 0.7)
                  : _kInk.withValues(alpha: 0.08),
            ),
          ),
        );
      }),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// PAGE 1: WELCOME
// ═════════════════════════════════════════════════════════════════

class _PageWelcome extends StatelessWidget {
  final Animation<double> fade;
  final Animation<Offset> slide;
  const _PageWelcome({required this.fade, required this.slide});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: _kLeafGreen.withValues(alpha: 0.18),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/app_icon.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'Assalamu Alaikum',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Welcome to Sukoon',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _kLeafGreen.withValues(alpha: 0.7),
                  letterSpacing: 0.2,
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Your phone should serve\nyour soul, not steal it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: _kInkSoft.withValues(alpha: 0.7),
                  height: 1.5,
                  letterSpacing: -0.2,
                ),
              ),

              const SizedBox(height: 36),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TrustBadge(icon: Icons.shield_outlined, label: 'Private'),
                  const SizedBox(width: 24),
                  _TrustBadge(icon: Icons.eco_outlined, label: 'Ad-free'),
                  const SizedBox(width: 24),
                  _TrustBadge(icon: Icons.favorite_border_rounded, label: 'Free'),
                ],
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// PAGE 2: THE PROBLEM
// ═════════════════════════════════════════════════════════════════

class _PageProblem extends StatelessWidget {
  final Animation<double> fade;
  final Animation<Offset> slide;
  const _PageProblem({required this.fade, required this.slide});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _kLeafGreen.withValues(alpha: 0.08),
                  border:
                      Border.all(color: _kLeafGreen.withValues(alpha: 0.12)),
                ),
                child: Text(
                  'Average: 96 phone unlocks a day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: _kLeafDark.withValues(alpha: 0.75),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'What if your home screen\nbrought you closer to Allah\ninstead of further away?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                  letterSpacing: -0.5,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 18),

              Text(
                'Sukoon replaces the chaos with calm.\nBuilt around prayer, purpose and presence.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _kInkSoft.withValues(alpha: 0.6),
                  height: 1.65,
                ),
              ),

              const SizedBox(height: 32),

              _ContrastRow(
                beforeIcon: Icons.notifications_active_outlined,
                beforeText: 'Endless notifications',
                afterIcon: Icons.notifications_paused_outlined,
                afterText: 'Filtered calm',
              ),
              const SizedBox(height: 10),
              _ContrastRow(
                beforeIcon: Icons.grid_view_rounded,
                beforeText: 'App clutter',
                afterIcon: Icons.search_rounded,
                afterText: 'Quick search',
              ),
              const SizedBox(height: 10),
              _ContrastRow(
                beforeIcon: Icons.phone_android_outlined,
                beforeText: 'Mindless scrolling',
                afterIcon: Icons.self_improvement_rounded,
                afterText: 'Intentional use',
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// PAGE 3: FEATURES OVERVIEW
// ═════════════════════════════════════════════════════════════════

class _PageFeatures extends StatelessWidget {
  final Animation<double> fade;
  final Animation<Offset> slide;
  const _PageFeatures({required this.fade, required this.slide});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 1),

              Text(
                'BUILT FOR YOUR DEEN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                  color: _kLeafGreen.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Everything you need.\nNothing you don\'t.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                  letterSpacing: -0.5,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 24),

              _FeatureCard(
                icon: Icons.mosque_rounded,
                title: 'Prayer & Ramadan',
                desc: 'GPS adhan alarms for all 5 prayers. Suhoor & Iftar countdowns, Islamic calendar.',
              ),
              const SizedBox(height: 10),
              _FeatureCard(
                icon: Icons.auto_stories_rounded,
                title: 'Quran, Hadith & Dhikr',
                desc: 'Full Quran with tafseer, 9 hadith collections, dhikr counter with streak tracking.',
              ),
              const SizedBox(height: 10),
              _FeatureCard(
                icon: Icons.spa_rounded,
                title: 'Digital Wellness',
                desc: 'Kahf Mode, Pomodoro timer, app time limits, app timer tracking.',
              ),
              const SizedBox(height: 10),
              _FeatureCard(
                icon: Icons.dashboard_customize_rounded,
                title: 'Fully Customisable',
                desc: '6 clock styles, wallpapers, themes, charity log, and more.',
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// PAGE 4: PRAYER & SALAH
// ═════════════════════════════════════════════════════════════════

class _PagePrayer extends StatelessWidget {
  final Animation<double> fade;
  final Animation<Offset> slide;
  const _PagePrayer({required this.fade, required this.slide});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kLeafGreen.withValues(alpha: 0.09),
                  border: Border.all(
                      color: _kLeafGreen.withValues(alpha: 0.18), width: 1.5),
                ),
                child: Icon(Icons.mosque_rounded,
                    size: 30, color: _kLeafGreen.withValues(alpha: 0.8)),
              ),

              const SizedBox(height: 22),

              const Text(
                'Never Miss a Prayer',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Sukoon calculates accurate salah times\nfor your exact city — automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: _kInkSoft.withValues(alpha: 0.6),
                ),
              ),

              const SizedBox(height: 28),

              _DetailRow(
                icon: Icons.alarm_rounded,
                title: 'Adhan Alarms',
                subtitle: 'Individual on/off for each of the 5 prayers',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.nightlight_round,
                title: 'Ramadan Mode',
                subtitle: 'Suhoor & Iftar countdowns on your home screen',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.calendar_today_rounded,
                title: 'Islamic Calendar',
                subtitle: 'Hijri date always visible. Key dates highlighted.',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.history_toggle_off_rounded,
                title: 'Prayer History',
                subtitle: 'Track your consistency with weekly reports',
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// PAGE 5: PRODUCTIVITY & FOCUS
// ═════════════════════════════════════════════════════════════════

class _PageProductivity extends StatelessWidget {
  final Animation<double> fade;
  final Animation<Offset> slide;
  const _PageProductivity({required this.fade, required this.slide});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kLeafGreen.withValues(alpha: 0.09),
                  border: Border.all(
                      color: _kLeafGreen.withValues(alpha: 0.18), width: 1.5),
                ),
                child: Icon(Icons.self_improvement_rounded,
                    size: 30, color: _kLeafGreen.withValues(alpha: 0.8)),
              ),

              const SizedBox(height: 22),

              const Text(
                'Focus on What Matters',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Sukoon gives you the tools to cut\ndistractions and protect your time.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: _kInkSoft.withValues(alpha: 0.6),
                ),
              ),

              const SizedBox(height: 28),

              _DetailRow(
                icon: Icons.timer_rounded,
                title: 'Pomodoro Timer',
                subtitle: 'Work sessions with built-in breaks. Stay deep.',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.shield_rounded,
                title: 'App Blocker',
                subtitle: 'Block social media during salah or study time',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.bar_chart_rounded,
                title: 'App Timer Tracking',
                subtitle: 'See exactly where your hours go each day',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.do_not_disturb_on_rounded,
                title: 'Kahf Mode',
                subtitle: 'One tap to silence everything — total presence',
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// PAGE 6: PERSONALISE
// ═════════════════════════════════════════════════════════════════

class _PagePersonalise extends StatelessWidget {
  final Animation<double> fade;
  final Animation<Offset> slide;
  const _PagePersonalise({required this.fade, required this.slide});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kLeafGreen.withValues(alpha: 0.09),
                  border: Border.all(
                      color: _kLeafGreen.withValues(alpha: 0.18), width: 1.5),
                ),
                child: Icon(Icons.palette_rounded,
                    size: 30, color: _kLeafGreen.withValues(alpha: 0.8)),
              ),

              const SizedBox(height: 22),

              const Text(
                'Make It Yours',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'A launcher that adapts to your taste,\nnot the other way around.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: _kInkSoft.withValues(alpha: 0.6),
                ),
              ),

              const SizedBox(height: 28),

              _DetailRow(
                icon: Icons.access_time_rounded,
                title: '6 Clock Styles',
                subtitle: 'From minimalist digits to elegant Arabic numerals',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.wallpaper_rounded,
                title: 'Wallpapers & Themes',
                subtitle: 'Curated Islamic wallpapers and themes',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.volunteer_activism_rounded,
                title: 'Charity Log',
                subtitle: 'Track your Sadaqah. Set daily giving goals.',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.apps_rounded,
                title: 'Favourite Apps',
                subtitle: 'Pin up to 7 apps on your home screen — instant access',
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// PAGE 7: ACTIVATE — Set as default launcher (FINAL PAGE)
// ═════════════════════════════════════════════════════════════════

class _PageActivate extends StatelessWidget {
  final Animation<double> fade;
  final Animation<Offset> slide;
  final VoidCallback onSetDefault;
  final VoidCallback onFinish;

  const _PageActivate({
    required this.fade,
    required this.slide,
    required this.onSetDefault,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kLeafGreen.withValues(alpha: 0.1),
                  border: Border.all(
                    color: _kLeafGreen.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.home_rounded,
                  size: 30,
                  color: _kLeafGreen.withValues(alpha: 0.85),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'One Last Step',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Set Sukoon as your default launcher\nso it becomes your home screen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: _kInkSoft.withValues(alpha: 0.6),
                ),
              ),

              const SizedBox(height: 28),

              _SetupStep(number: '1', text: 'Tap "Set as Default Launcher"'),
              const SizedBox(height: 12),
              _SetupStep(number: '2', text: 'Select Sukoon from the list'),
              const SizedBox(height: 12),
              _SetupStep(number: '3', text: 'Choose "Always"'),

              const SizedBox(height: 28),

              // Set Default CTA
              GestureDetector(
                onTap: onSetDefault,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: _kLeafGreen,
                    boxShadow: [
                      BoxShadow(
                        color: _kLeafGreen.withValues(alpha: 0.28),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Set as Default Launcher',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'You can change this anytime in Android Settings.',
                style: TextStyle(
                  fontSize: 11,
                  color: _kInkMuted.withValues(alpha: 0.4),
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// SHARED COMPONENTS
// ═════════════════════════════════════════════════════════════════

/// Trust badge
class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kLeafGreen.withValues(alpha: 0.07),
            border:
                Border.all(color: _kLeafGreen.withValues(alpha: 0.12)),
          ),
          child:
              Icon(icon, size: 20, color: _kLeafGreen.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _kInkMuted.withValues(alpha: 0.55),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

/// Before → After contrast pill row
class _ContrastRow extends StatelessWidget {
  final IconData beforeIcon;
  final String beforeText;
  final IconData afterIcon;
  final String afterText;

  const _ContrastRow({
    required this.beforeIcon,
    required this.beforeText,
    required this.afterIcon,
    required this.afterText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.5),
        border: Border.all(color: _kInk.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Icon(beforeIcon,
              size: 15, color: _kInkMuted.withValues(alpha: 0.3)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              beforeText,
              style: TextStyle(
                fontSize: 12,
                color: _kInkMuted.withValues(alpha: 0.35),
                decoration: TextDecoration.lineThrough,
                decorationColor: _kInkMuted.withValues(alpha: 0.2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 13,
              color: _kLeafGreen.withValues(alpha: 0.5),
            ),
          ),
          Icon(afterIcon,
              size: 15, color: _kLeafGreen.withValues(alpha: 0.7)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              afterText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kLeafDark.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Feature card
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.6),
        border: Border.all(color: _kLeafGreen.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _kInk.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _kLeafGreen.withValues(alpha: 0.09),
              border:
                  Border.all(color: _kLeafGreen.withValues(alpha: 0.14)),
            ),
            child: Icon(icon,
                size: 20, color: _kLeafGreen.withValues(alpha: 0.8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kInk.withValues(alpha: 0.85),
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: _kInkSoft.withValues(alpha: 0.5),
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

/// Detail row — icon + title + subtitle (used in deep-dive pages)
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _DetailRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            color: _kLeafGreen.withValues(alpha: 0.08),
            border: Border.all(color: _kLeafGreen.withValues(alpha: 0.13)),
          ),
          child:
              Icon(icon, size: 19, color: _kLeafGreen.withValues(alpha: 0.75)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kInk.withValues(alpha: 0.85),
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: _kInkSoft.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Numbered setup step
class _SetupStep extends StatelessWidget {
  final String number;
  final String text;
  const _SetupStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kLeafGreen.withValues(alpha: 0.08),
            border:
                Border.all(color: _kLeafGreen.withValues(alpha: 0.15)),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kLeafGreen.withValues(alpha: 0.75),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: _kInkSoft.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}


