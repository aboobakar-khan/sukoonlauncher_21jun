import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/tasbih_provider.dart';
import '../providers/arabic_font_provider.dart';
import '../providers/islamic_theme_provider.dart';
import '../providers/theme_provider.dart';
import '../features/quran/providers/quran_provider.dart';
import '../features/quran/screens/surah_list_screen.dart';
import '../features/quran/widgets/tafseer_bottom_sheet.dart';
import '../features/hadith_dua/screens/minimalist_hadith_screen.dart';
import '../features/hadith_dua/screens/minimalist_dua_screen.dart';
import '../utils/smooth_page_route.dart';

// ─── Deen Mode ───────────────────────────────────────────────────────────────
// A curated, distraction-free Islamic experience.
// Only: Islamic Hub (Quran · Hadith · Dua) + Dhikr Counter + Phone Calls
// No social media, no notifications, no distractions — pure Deen.
// ─────────────────────────────────────────────────────────────────────────────

class DeenModeScreen extends ConsumerStatefulWidget {
  const DeenModeScreen({super.key});

  @override
  ConsumerState<DeenModeScreen> createState() => _DeenModeScreenState();
}

class _DeenModeScreenState extends ConsumerState<DeenModeScreen>
    with TickerProviderStateMixin {
  // ── Design Tokens — warm Islamic palette ──
  static const _cream = Color(0xFFFDF6EC);
  static const _warmWhite = Color(0xFFF8F2E8);
  static const _gold = Color(0xFFC2A366);
  static const _goldDark = Color(0xFFA68B5B);
  Color get _green => ref.watch(themeColorProvider).color;
  Color get _greenDark => Color.lerp(_green, const Color(0xFF000000), 0.25)!;
  static const _brown = Color(0xFF2C1810);
  static const _brownMed = Color(0xFF5C4033);
  static const _brownLight = Color(0xFF8B7355);
  static const _border = Color(0xFFE8DFD0);
  static const _cardBg = Color(0xFFFFFFFF);

  late AnimationController _pulseCtrl;
  late AnimationController _countAnimCtrl;
  late Animation<double> _scaleAnim;

  bool _isDndActive = false;
  DateTime? _enteredAt; // track time spent for friction dialog

  // DND channel — block notifications only
  static const _dndChannel = MethodChannel('com.sukoon.launcher/dnd');

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _countAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _countAnimCtrl, curve: Curves.easeInOut),
    );
    _enteredAt = DateTime.now();
    // Check DND permission and enable on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDndPermissionAndEnable();
    });
  }

  @override
  void dispose() {
    _disableDnd();
    _pulseCtrl.dispose();
    _countAnimCtrl.dispose();
    super.dispose();
  }

  // ─── DND permission check + enable ───
  Future<void> _checkDndPermissionAndEnable() async {
    if (!mounted) return;
    try {
      final hasPermission = await _dndChannel.invokeMethod('hasDndPermission') == true;
      debugPrint('DND: hasDndPermission = $hasPermission');
      if (!hasPermission) {
        if (!mounted) return;
        // Show permission dialog
        final granted = await _showDndPermissionDialog();
        if (!granted) return;
        // Re-check after user returns from settings — give more time
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        final nowHas = await _dndChannel.invokeMethod('hasDndPermission') == true;
        debugPrint('DND: After permission request, hasDndPermission = $nowHas');
        if (!nowHas) return;
      }
      await _enableDnd();
    } catch (e) {
      debugPrint('DND: Permission check error: $e');
      // DND API not available on this device
    }
  }

  Future<bool> _showDndPermissionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: _cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.notifications_off_rounded, color: _gold, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                'Do Not Disturb Access',
                style: TextStyle(color: _brown, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                'Deen Mode needs Do Not Disturb access to silence all notifications.\n\nPlease find "Sukoon" and enable it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _brownMed.withValues(alpha: 0.7),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () async {
                  await _dndChannel.invokeMethod('requestDndPermission');
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Center(
                    child: Text(
                      'Grant Permission',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text(
                      'Skip',
                      style: TextStyle(color: _brownLight, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }

  // ─── DND (notifications-only blocking) ───
  Future<void> _enableDnd() async {
    try {
      final result = await _dndChannel.invokeMethod('enableDND');
      if (mounted) setState(() => _isDndActive = result == true);
    } catch (e) {
      debugPrint('DND enable error: $e');
      // Retry once after a short delay
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        final result = await _dndChannel.invokeMethod('enableDND');
        if (mounted) setState(() => _isDndActive = result == true);
      } catch (_) {
        if (mounted) setState(() => _isDndActive = false);
      }
    }
  }

  Future<void> _disableDnd() async {
    if (!_isDndActive) return;
    try {
      await _dndChannel.invokeMethod('disableDND');
      if (mounted) setState(() => _isDndActive = false);
    } catch (e) {
      debugPrint('DND disable error: $e');
    }
  }

  // ─── Exit friction — make leaving hard ───
  Future<bool> _showExitFriction() async {
    final timeSpent = DateTime.now().difference(_enteredAt ?? DateTime.now());
    final minutes = timeSpent.inMinutes;

    // Pick a motivational message based on time spent
    final String motivationTitle;
    final String motivationBody;
    final String stayLabel;

    if (minutes < 5) {
      motivationTitle = 'Already leaving?';
      motivationBody =
          'You\'ve only been here ${ minutes < 1 ? "less than a minute" : "$minutes minute${minutes == 1 ? '' : 's'}" }.\n\n'
          'The Prophet ﷺ said:\n"The most beloved deeds to Allah are the most consistent, even if small."\n\n'
          'Stay a little longer — your soul deserves this peace.';
      stayLabel = 'Stay in Deen Mode';
    } else if (minutes < 15) {
      motivationTitle = 'MashaAllah, $minutes minutes!';
      motivationBody =
          'You\'re building a beautiful habit.\n\n'
          '"Verily, in the remembrance of Allah do hearts find rest." — Quran 13:28\n\n'
          'Continue your journey — every second counts.';
      stayLabel = 'Keep Going';
    } else {
      motivationTitle = 'Beautiful session!';
      motivationBody =
          'You\'ve spent $minutes minutes in Deen Mode — MashaAllah!\n\n'
          'May Allah accept your efforts and grant you tranquility.\n\n'
          'Are you sure you want to leave?';
      stayLabel = 'Stay a bit more';
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // Get theme colors based on current mode
        final themeMode = ref.read(islamicThemeProvider);
        final isDark = themeMode == IslamicThemeMode.dark;
        final tc = IslamicThemeColors.fromMode(themeMode);
        
        return Dialog(
          backgroundColor: tc.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mosque icon
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        tc.accent.withValues(alpha: 0.15),
                        tc.green.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Text('🕌', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(height: 20),
                Text(
                  motivationTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tc.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  motivationBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tc.textSecondary.withValues(alpha: 0.75),
                    fontSize: 13.5,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                // STAY button — prominent, accent color
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, false),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [tc.accent, tc.accent.withValues(alpha: 0.8)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: tc.accent.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        stayLabel,
                        style: TextStyle(
                          color: isDark ? Colors.black87 : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // LEAVE button — muted, less prominent, with countdown text
                _ExitButton(
                  onConfirm: () => Navigator.pop(ctx, true),
                  textColor: tc.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
    return result == true;
  }

  void _onDhikrTap() {
    ref.read(tasbihProvider.notifier).increment();
    _countAnimCtrl.forward().then((_) => _countAnimCtrl.reverse());
  }

  @override
  Widget build(BuildContext context) {
    final tasbih = ref.watch(tasbihProvider);
    final arabicFont = ref.watch(arabicFontProvider);
    final themeMode = ref.watch(islamicThemeProvider);
    final isDark = themeMode == IslamicThemeMode.dark;

    // Dynamic colors based on theme toggle
    final bgColor = isDark ? const Color(0xFF000000) : _cream;
    final cardColor = isDark ? const Color(0xFF111111) : _cardBg;
    final borderColor = isDark ? const Color(0xFF1A1A1A) : _border;
    final textPrimary = isDark ? const Color(0xFFE8E0D4) : _brown;
    final textSecondary = isDark ? const Color(0xFFA89880) : _brownMed;
    final statusBrightness = isDark ? Brightness.light : Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bgColor,
        statusBarIconBrightness: statusBrightness,
        systemNavigationBarColor: bgColor,
        systemNavigationBarIconBrightness: statusBrightness,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final shouldLeave = await _showExitFriction();
          if (shouldLeave && context.mounted) {
            await _disableDnd();
            if (context.mounted) Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: Column(
              children: [
                // ── Header ──
                _buildHeader(context, bgColor: bgColor, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary, isDark: isDark),

                // ── Content ──
                Expanded(
                  child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    children: [
                      // Bismillah greeting
                      _buildBismillah(isDark: isDark, cardColor: cardColor, borderColor: borderColor),
                      const SizedBox(height: 20),

                      // Verse of the Moment
                      _buildVerseCard(ref, arabicFont, isDark: isDark, cardColor: cardColor, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary),
                      const SizedBox(height: 20),

                      // Dhikr Counter (inline)
                      _buildDhikrCounter(tasbih, isDark: isDark, cardColor: cardColor, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary),
                      const SizedBox(height: 20),

                      // Islamic Hub — Quran, Hadith, Dua
                      _buildIslamicHub(context, isDark: isDark, cardColor: cardColor, borderColor: borderColor, textPrimary: textPrimary),
                      const SizedBox(height: 20),

                      // Quick Call
                      _buildCallCard(context, isDark: isDark, cardColor: cardColor, borderColor: borderColor, textPrimary: textPrimary, textSecondary: textSecondary),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  // HEADER
  // ────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, {
    required Color bgColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              final shouldLeave = await _showExitFriction();
              if (shouldLeave && context.mounted) {
                await _disableDnd();
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back_rounded, color: isDark ? _gold : _brownMed, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deen Mode',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                _isDndActive
                    ? '� Notifications silenced · Pure focus'
                    : 'Distraction-free · Pure focus',
                style: TextStyle(
                  color: _isDndActive
                      ? _greenDark.withValues(alpha: 0.7)
                      : textSecondary.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Dark / Light mode toggle
          GestureDetector(
            onTap: () {
              ref.read(islamicThemeProvider.notifier).toggle();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? _gold.withValues(alpha: 0.12) : _gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _gold.withValues(alpha: isDark ? 0.25 : 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: _gold,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isDark ? 'Dark' : 'Light',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isDndActive) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.notifications_off_rounded, color: _green, size: 14),
            ),
          ],
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────
  // BISMILLAH GREETING
  // ────────────────────────────────────────────────
  Widget _buildBismillah({required bool isDark, required Color cardColor, required Color borderColor}) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final glow = 0.04 + (_pulseCtrl.value * 0.04);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _gold.withValues(alpha: glow + 0.03),
                _gold.withValues(alpha: glow),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _gold.withValues(alpha: 0.12)),
          ),
          child: Column(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [_gold, _goldDark, _gold],
                ).createShader(bounds),
                child: const Text(
                  'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'In the name of Allah, the Most Gracious, the Most Merciful',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? const Color(0xFFA89880).withValues(alpha: 0.8) : _brownLight.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────
  // VERSE OF THE MOMENT
  // ────────────────────────────────────────────────
  Widget _buildVerseCard(WidgetRef ref, dynamic arabicFont, {required bool isDark, required Color cardColor, required Color borderColor, required Color textPrimary, required Color textSecondary}) {
    return Consumer(
      builder: (context, ref, child) {
        final verseAsync = ref.watch(randomVerseProvider);
        return verseAsync.when(
          data: (verse) {
            if (verse == null) return const SizedBox.shrink();
            return GestureDetector(
              onTap: () => ref.invalidate(randomVerseProvider),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.auto_awesome, color: _gold, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Verse of the Moment',
                          style: TextStyle(
                            color: _goldDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.refresh_rounded, color: textSecondary.withValues(alpha: 0.4), size: 16),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Arabic
                    Text(
                      verse['arabic'] as String,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 22,
                        height: 1.9,
                        fontWeight: FontWeight.w400,
                        fontFamily: arabicFont.fontFamily,
                      ),
                    ),
                    if (verse['translation'] != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        verse['translation'] as String,
                        style: TextStyle(
                          color: textSecondary.withValues(alpha: 0.6),
                          fontSize: 13,
                          height: 1.55,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    // Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${verse['surahTransliteration']} ${verse['verseNumber']}',
                            style: TextStyle(
                              color: _goldDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            TafseerBottomSheet.show(
                              context,
                              surahId: verse['surahId'] as int,
                              ayahId: verse['verseNumber'] as int,
                              surahName: verse['surahTransliteration'] as String,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _green.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.menu_book_outlined, size: 12, color: _greenDark),
                                const SizedBox(width: 4),
                                Text(
                                  'Tafseer',
                                  style: TextStyle(
                                    color: _greenDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
    );
  }

  // ────────────────────────────────────────────────
  // DHIKR COUNTER (Inline compact)
  // ────────────────────────────────────────────────
  Widget _buildDhikrCounter(TasbihState tasbih, {required bool isDark, required Color cardColor, required Color borderColor, required Color textPrimary, required Color textSecondary}) {
    final dhikrList = [
      {'arabic': 'سُبْحَانَ اللهِ', 'trans': 'SubhanAllah', 'meaning': 'Glory be to Allah'},
      {'arabic': 'الْحَمْدُ لِلَّهِ', 'trans': 'Alhamdulillah', 'meaning': 'Praise be to Allah'},
      {'arabic': 'اللهُ أَكْبَرُ', 'trans': 'Allahu Akbar', 'meaning': 'Allah is the Greatest'},
      {'arabic': 'لَا إِلَهَ إِلَّا اللهُ', 'trans': 'La ilaha illallah', 'meaning': 'None worthy of worship but Allah'},
      {'arabic': 'أَسْتَغْفِرُ اللهَ', 'trans': 'Astaghfirullah', 'meaning': 'I seek forgiveness from Allah'},
      {'arabic': 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللهِ', 'trans': 'La hawla wa la quwwata illa billah', 'meaning': 'No power except with Allah'},
    ];

    final currentIdx = tasbih.selectedDhikrIndex.clamp(0, dhikrList.length - 1);
    final current = dhikrList[currentIdx];
    final count = tasbih.currentCount;
    final target = tasbih.targetCount;
    final progress = target > 0 ? (count / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.touch_app_rounded, color: _green, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Dhikr Counter',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              // Dhikr selector — tap to cycle
              GestureDetector(
                onTap: () {
                  final next = (tasbih.selectedDhikrIndex + 1) % dhikrList.length;
                  ref.read(tasbihProvider.notifier).selectDhikr(next);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _gold.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        current['trans']!,
                        style: TextStyle(
                          color: _goldDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.swap_horiz_rounded, color: _goldDark, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Dhikr Stats Row (total, today, target) ──
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _gold.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${tasbih.totalAllTime}',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total',
                        style: TextStyle(
                          color: textSecondary.withValues(alpha: 0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _green.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${tasbih.todayCount}',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Today',
                        style: TextStyle(
                          color: textSecondary.withValues(alpha: 0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _gold.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${tasbih.targetCount}',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Target',
                        style: TextStyle(
                          color: textSecondary.withValues(alpha: 0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Arabic text
          Text(
            current['arabic']!,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            current['meaning']!,
            style: TextStyle(
              color: textSecondary.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),

          // Counter circle — tap to increment
          GestureDetector(
            onTap: _onDhikrTap,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1A1A1A) : _warmWhite,
                  border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : _border, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.08),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Progress ring
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CustomPaint(
                        painter: _ProgressRingPainter(
                          progress: progress,
                          color: _gold,
                          bgColor: _border.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    // Count
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$count',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          '/ $target',
                          style: TextStyle(
                            color: textSecondary.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSmallAction(Icons.refresh_rounded, 'Reset', () {
                ref.read(tasbihProvider.notifier).reset();
              }),
              const SizedBox(width: 24),
              _buildSmallAction(Icons.skip_next_rounded, 'Next', () {
                final next = (tasbih.selectedDhikrIndex + 1) % dhikrList.length;
                ref.read(tasbihProvider.notifier).selectDhikr(next);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallAction(IconData icon, String label, VoidCallback onTap) {
    // Read the current islamic theme so these buttons respect dark/light mode.
    final themeMode = ref.watch(islamicThemeProvider);
    final isDark = themeMode == IslamicThemeMode.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : _warmWhite;
    final borderColor = isDark ? const Color(0xFF2A2A2A) : _border;
    final iconColor = isDark ? const Color(0xFFA89880) : _brownMed;
    final labelColor = isDark ? const Color(0xFF6B6055) : _brownLight;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────
  // ISLAMIC HUB — Quran · Hadith · Dua
  // ────────────────────────────────────────────────
  Widget _buildIslamicHub(BuildContext context, {required bool isDark, required Color cardColor, required Color borderColor, required Color textPrimary}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Container(
                width: 3, height: 14,
                decoration: BoxDecoration(
                  color: _gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Islamic Hub',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        // 3 cards in a row
        Row(
          children: [
            Expanded(
              child: _buildHubTile(
                icon: Icons.menu_book_rounded,
                label: 'Quran',
                subtitle: '114 Surahs',
                color: _gold,
                bgColor: cardColor,
                textColor: textPrimary,
                subtitleColor: textPrimary.withValues(alpha: 0.45),
                onTap: () {
                  Navigator.push(context, SmoothForwardRoute(child: const _DeenSubScreen(title: 'Quran', child: SurahListScreen())));
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildHubTile(
                icon: Icons.library_books_rounded,
                label: 'Hadith',
                subtitle: '9 Books',
                color: _green,
                bgColor: cardColor,
                textColor: textPrimary,
                subtitleColor: textPrimary.withValues(alpha: 0.45),
                onTap: () {
                  Navigator.push(context, SmoothForwardRoute(child: _DeenSubScreen(title: 'Hadith', child: MinimalistHadithScreen())));
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildHubTile(
                icon: Icons.front_hand_rounded,
                label: 'Dua',
                subtitle: 'Adhkar',
                color: _goldDark,
                bgColor: cardColor,
                textColor: textPrimary,
                subtitleColor: textPrimary.withValues(alpha: 0.45),
                onTap: () {
                  Navigator.push(context, SmoothForwardRoute(child: const _DeenSubScreen(title: 'Dua & Adhkar', child: MinimalistDuaScreen())));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHubTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    Color? bgColor,
    Color? textColor,
    Color? subtitleColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor ?? _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: textColor ?? _brown,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: subtitleColor ?? _brownLight.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  // PHONE CALL ACCESS
  // ────────────────────────────────────────────────
  Widget _buildCallCard(BuildContext context, {required bool isDark, required Color cardColor, required Color borderColor, required Color textPrimary, required Color textSecondary}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.phone_rounded, color: _green, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phone Call',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Make or receive calls — always accessible',
                  style: TextStyle(
                    color: textSecondary.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              _openDialer();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _green.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.dialpad_rounded, color: _greenDark, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Dial',
                    style: TextStyle(
                      color: _greenDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDialer() async {
    final uri = Uri.parse('tel:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

// ── Progress Ring Painter ──
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;

  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final strokeWidth = 3.5;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Sub-screen wrapper for Islamic content ──
// Uses islamicThemeProvider so it respects the light/dark toggle set in DeenModeScreen.
class _DeenSubScreen extends ConsumerWidget {
  final String title;
  final Widget child;
  const _DeenSubScreen({required this.title, required this.child});

  static const _gold = Color(0xFFC2A366);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = ref.watch(islamicThemeColorsProvider);
    final isDark = ref.watch(islamicThemeProvider) == IslamicThemeMode.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: tc.background,
        statusBarIconBrightness: tc.statusBarBrightness,
        systemNavigationBarColor: tc.background,
        systemNavigationBarIconBrightness: tc.statusBarBrightness,
      ),
      child: Scaffold(
        backgroundColor: tc.background,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar: back + title + theme toggle ──
              Container(
                padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
                decoration: BoxDecoration(
                  color: tc.background,
                  border: Border(
                    bottom: BorderSide(
                      color: tc.border.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: tc.text.withValues(alpha: 0.6),
                        size: 22,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: tc.text.withValues(alpha: 0.85),
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Light / Dark toggle — same as DeenModeScreen header
                    GestureDetector(
                      onTap: () {
                        ref.read(islamicThemeProvider.notifier).toggle();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: _gold.withValues(
                              alpha: isDark ? 0.12 : 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _gold.withValues(
                                  alpha: isDark ? 0.25 : 0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDark
                                  ? Icons.dark_mode_rounded
                                  : Icons.light_mode_rounded,
                              color: _gold,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isDark ? 'Dark' : 'Light',
                              style: const TextStyle(
                                color: _gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Exit Button with countdown friction ─────────────────────────────────────
// The "Leave" button is disabled for 5 seconds, forcing a pause before exit.
class _ExitButton extends StatefulWidget {
  final VoidCallback onConfirm;
  final Color textColor;
  
  const _ExitButton({
    required this.onConfirm,
    required this.textColor,
  });

  @override
  State<_ExitButton> createState() => _ExitButtonState();
}

class _ExitButtonState extends State<_ExitButton> {
  static const _countdownSeconds = 5;
  int _remaining = _countdownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining > 1) {
        setState(() => _remaining--);
      } else {
        setState(() => _remaining = 0);
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _remaining == 0;
    final textColor = widget.textColor;
    final borderColor = textColor.withValues(alpha: 0.2);

    return GestureDetector(
      onTap: enabled ? widget.onConfirm : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: enabled
              ? borderColor.withValues(alpha: 0.5)
              : borderColor.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            enabled ? 'Leave Deen Mode' : 'Leave ($_remaining s)',
            style: TextStyle(
              color: enabled ? textColor : textColor.withValues(alpha: 0.5),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
