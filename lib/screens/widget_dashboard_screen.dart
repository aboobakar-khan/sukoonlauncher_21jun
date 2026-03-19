import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/review_helper.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/prayer_tracker_widget.dart';
import '../widgets/dhikr_summary_widget.dart';
import 'deen_mode_screen.dart';
import 'donation_screen.dart';
import 'premium_paywall_screen.dart';
import 'saved_verses_screen.dart';
import 'settings_screen.dart';
import '../utils/smooth_page_route.dart';
import '../features/quran/providers/quran_provider.dart';
import '../features/quran/widgets/tafseer_bottom_sheet.dart';
import '../providers/arabic_font_provider.dart';
import '../providers/saved_verses_provider.dart';
import '../providers/premium_provider.dart';
import '../providers/theme_provider.dart';
import '../features/prayer_alarm/widgets/prayer_alarm_dashboard_card.dart';
import '../widgets/charity_log_widget.dart';



/// Widget Dashboard — Minimalist Redesign
/// Clean vertical flow with subtle section dividers.
/// Removed redundant DhikrAnalytics / PrayerAnalytics widgets
/// (both dashboards are already accessible from their parent widgets).
class WidgetDashboardScreen extends ConsumerStatefulWidget {
  const WidgetDashboardScreen({super.key});

  @override
  ConsumerState<WidgetDashboardScreen> createState() => _WidgetDashboardScreenState();
}

class _WidgetDashboardScreenState extends ConsumerState<WidgetDashboardScreen>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true; // Keep state alive during PageView scrolling

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    final arabicFont = ref.watch(arabicFontProvider);
    final currentTheme = ref.watch(themeColorProvider);
    final accent = currentTheme.color;

    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          Expanded(
            // RepaintBoundary isolates the scrollable content into its own
            // compositing layer. Any repaint triggered by scroll position
            // changes (child widgets listening to providers) stays within
            // this boundary and does not propagate up to the PageView's
            // Stack — preventing the layout thrash that causes card bouncing.
            child: RepaintBoundary(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                children: [
                  const SizedBox(height: 48),

                  // ─── Prayer Alarm (Salah Wake) — TOP since it shows Ramadan times ──
                  const PrayerAlarmDashboardCard(),

                  _sectionGap(accent),

                  // ─── Verse of the Moment ───────────────────────
                  _buildVerseCard(ref, arabicFont, accent),

                  _sectionGap(accent),

                  // ─── Dhikr Summary — tap to open counter ──
                  const DhikrSummaryWidget(),

                  _sectionGap(accent),

                  // ─── Prayer Tracker ─────────────────────────────
                  const PrayerTrackerWidget(),

                  _sectionGap(accent),

                  // ─── Deen Mode — Quick Entry (below Salah tracker) ──
                  _buildDeenModeCard(context, ref, accent),

                  _sectionGap(accent),

                  // ─── Charity Log ───────────────────────────────
                  const CharityLogWidget(),

                  _sectionGap(accent),

                  // ─── Calendar ──────────────────────────────────
                  CalendarWidget(onExpand: () {}),

                  const SizedBox(height: 24),

                  // ─── Support Sukoon — subtle donation CTA ────────────────
                  _buildSupportRow(context, accent),

                  const SizedBox(height: 12),

                  // ─── Rate us on Play Store ────────────────
                  _buildRateUsRow(context, accent),

                  const SizedBox(height: 32),
                ],
              ),
            ),     // closes RepaintBoundary child (SingleChildScrollView)
          ),       // closes RepaintBoundary
          ),       // closes Expanded child
        ],
      ),
    );
  }

  // ── Consistent section gap with faint divider ──
  Widget _sectionGap(Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          width: 36,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              accent.withValues(alpha: 0.12),
              accent.withValues(alpha: 0.03),
            ]),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }

  // ── Deen Mode — entry card on dashboard ──
  Widget _buildDeenModeCard(BuildContext context, WidgetRef ref, Color accent) {
    final isPremium = ref.watch(hasFeatureProvider(PremiumFeature.deenMode));

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (!isPremium) {
          showPremiumPaywall(context, triggerFeature: 'Deen Mode');
          return;
        }
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const DeenModeScreen()),
        );
      },
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.nights_stay_rounded, size: 20, color: accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deen Mode',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Quran · Dhikr · Calls only — distraction free',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_forward_ios_rounded, color: accent.withValues(alpha: 0.5), size: 14),
                ),
              ],
            ),
          ),
          if (!isPremium)
            Positioned(
              top: 10,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFC2A366).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC2A366).withValues(alpha: 0.30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 9, color: const Color(0xFFC2A366).withValues(alpha: 0.8)),
                    const SizedBox(width: 4),
                    Text(
                      'PRO',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFC2A366).withValues(alpha: 0.8),
                        letterSpacing: 0.5,
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

  // ── Verse of the Moment — streamlined ──
  Widget _buildVerseCard(WidgetRef ref, dynamic arabicFont, Color accent) {
    return Consumer(
      builder: (context, ref, child) {
        final verseAsync = ref.watch(randomVerseProvider);
        return verseAsync.when(
          data: (verse) {
            if (verse == null) return const SizedBox.shrink();
            final verseKey = '${verse['surahId']}:${verse['verseNumber']}';
            final isSaved = ref.watch(isVerseSavedProvider(verseKey));
            return GestureDetector(
              onTap: () => ref.invalidate(randomVerseProvider),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.025),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: accent.withValues(alpha: 0.6), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Verse of the Moment',
                          style: TextStyle(
                            color: accent.withValues(alpha: 0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        // Bookmark icon
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (isSaved) {
                              ref.read(savedVersesProvider.notifier).removeVerse(verseKey);
                            } else {
                              ref.read(savedVersesProvider.notifier).saveVerse(verse);
                            }
                          },
                          child: Icon(
                            isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: isSaved
                                ? accent.withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.18),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.refresh_rounded, color: Colors.white.withValues(alpha: 0.12), size: 14),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Arabic text
                    Text(
                      verse['arabic'] as String,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
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
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                          height: 1.55,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Footer: surah ref + saved + tafseer
                    Row(
                      children: [
                        Text(
                          '${verse['surahTransliteration']} ${verse['verseNumber']}',
                          style: TextStyle(
                            color: accent.withValues(alpha: 0.45),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              SmoothForwardRoute(child: const SavedVersesScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.collections_bookmark_outlined, size: 12, color: accent.withValues(alpha: 0.6)),
                                const SizedBox(width: 4),
                                Text(
                                  'Saved',
                                  style: TextStyle(
                                    color: accent.withValues(alpha: 0.6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.menu_book_outlined, size: 12, color: accent.withValues(alpha: 0.6)),
                                const SizedBox(width: 4),
                                Text(
                                  'Tafseer',
                                  style: TextStyle(
                                    color: accent.withValues(alpha: 0.6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
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

  // ── Support Sukoon — donation CTA ──
  Widget _buildSupportRow(BuildContext context, Color accent) {
    return GestureDetector(
      onTap: () => showDonationScreen(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accent.withValues(alpha: 0.20),
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Brand icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.15)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.asset(
                  'assets/app_icon.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Support Sukoon',
                    style: TextStyle(
                      color: accent.withValues(alpha: 0.90),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Free forever · Donate as sadaqah jariyah',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withValues(alpha: 0.25)),
              ),
              child: Text(
                'Donate',
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Compact bottom row: Rate Sukoon + Settings ──
  Widget _buildRateUsRow(BuildContext context, Color accent) {
    return Row(
      children: [
        // Rate Sukoon
        Expanded(
          child: GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              await requestSukoonReview();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_rounded,
                      size: 16, color: Colors.amber.withValues(alpha: 0.7)),
                  const SizedBox(width: 7),
                  Text(
                    'Rate Sukoon',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Settings
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                SmoothForwardRoute(child: const SettingsScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.settings_outlined,
                      size: 15, color: Colors.white.withValues(alpha: 0.45)),
                  const SizedBox(width: 7),
                  Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Try native in-app review first, fall back to Play Store URL
  // Replaced by shared requestSukoonReview() from review_helper.dart
}
