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
import '../providers/widget_visibility_provider.dart';
import '../features/prayer_alarm/widgets/prayer_alarm_dashboard_card.dart';
import '../widgets/charity_log_widget.dart';
import '../widgets/edge_to_edge.dart';


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

    // Watch visibility state — rebuilds when user toggles widgets
    ref.watch(widgetVisibilityProvider);
    final visNotifier = ref.read(widgetVisibilityProvider.notifier);

    // Bottom inset so the last card / footer clears the gesture pill while the
    // scroll area itself still extends edge-to-edge behind it.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // SafeArea top keeps content below the status bar; bottom is handled
    // manually via [bottomInset] so the scroll view fills to the screen edge.
    return EdgeToEdge(
      bottom: false,
      child: Container(
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
                  const SizedBox(height: 12),

                  // ─── Prayer Alarm (Salah Wake) — TOP since it shows Ramadan times ──
                  if (visNotifier.isVisible(DashboardWidget.prayerAlarm)) ...[
                    const PrayerAlarmDashboardCard(),
                    _sectionGap(accent),
                  ],

                  // ─── Verse of the Moment ───────────────────────
                  if (visNotifier.isVisible(DashboardWidget.verseOfMoment)) ...[
                    _buildVerseCard(ref, arabicFont, accent),
                    _sectionGap(accent),
                  ],

                  // ─── Dhikr Summary — tap to open counter ──
                  if (visNotifier.isVisible(DashboardWidget.dhikrSummary)) ...[
                    const DhikrSummaryWidget(),
                    _sectionGap(accent),
                  ],

                  // ─── Prayer Tracker ─────────────────────────────
                  if (visNotifier.isVisible(DashboardWidget.prayerTracker)) ...[
                    const PrayerTrackerWidget(),
                    _sectionGap(accent),
                  ],


                  // ─── Deen Mode — Quick Entry (below Salah tracker) ──
                  if (visNotifier.isVisible(DashboardWidget.deenMode)) ...[
                    _buildDeenModeCard(context, ref, accent),
                    _sectionGap(accent),
                  ],

                  // ─── Charity Log ───────────────────────────────
                  if (visNotifier.isVisible(DashboardWidget.charityLog)) ...[
                    const CharityLogWidget(),
                    _sectionGap(accent),
                  ],

                  // ─── Calendar ──────────────────────────────────
                  if (visNotifier.isVisible(DashboardWidget.calendar)) ...[
                    CalendarWidget(onExpand: () {}),
                  ],

                  const SizedBox(height: 20),

                  // ─── Compact footer: Widgets · Donate · Rate · Settings ──
                  _buildFooter(context, accent),

                  SizedBox(height: 28 + bottomInset),
                ],
              ),
            ),     // closes RepaintBoundary child (SingleChildScrollView)
          ),       // closes RepaintBoundary
          ),       // closes Expanded child
        ],
      ),
      ),         // closes Container child of EdgeToEdge
    );
  }

  // ── Minimal footer: four icon-text pills in one row ──
  Widget _buildFooter(BuildContext context, Color accent) {
    final items = [
      (
        icon: Icons.dashboard_customize_outlined,
        label: 'Widgets',
        color: accent,
        onTap: () {
          _showEditWidgetsSheet(context, accent);
        },
      ),
      (
        icon: Icons.favorite_rounded,
        label: 'Donate',
        color: Colors.white,
        onTap: () => showDonationScreen(context),
      ),
      (
        icon: Icons.star_border_rounded,
        label: 'Rate',
        color: Colors.white,
        onTap: () async {
          await requestSukoonReview();
        },
      ),
      (
        icon: Icons.settings_outlined,
        label: 'Settings',
        color: Colors.white,
        onTap: () {
          Navigator.push(
            context,
            SmoothForwardRoute(child: const SettingsScreen()),
          );
        },
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 14,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          Expanded(
            child: GestureDetector(
              onTap: items[i].onTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      items[i].icon,
                      size: 16,
                      color: (i == 1 ? Colors.redAccent : items[i].color)
                          .withValues(alpha: (i == 0 || i == 1) ? 0.75 : 0.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items[i].label,
                      style: TextStyle(
                        color: items[i].color.withValues(alpha: (i == 0 || i == 1) ? 0.65 : 0.28),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Bottom sheet: toggle widget visibility ──
  void _showEditWidgetsSheet(BuildContext context, Color accent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _EditWidgetsSheet(accent: accent),
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
                        'Quran · Dhikr · Calls only',
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

  /// Try native in-app review first, fall back to Play Store URL
  // Replaced by shared requestSukoonReview() from review_helper.dart
}


// ═══════════════════════════════════════════════════════════════════
// EDIT WIDGETS BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════

class _EditWidgetsSheet extends ConsumerWidget {
  final Color accent;
  const _EditWidgetsSheet({required this.accent});

  // Map DashboardWidget → icon
  static IconData _iconFor(DashboardWidget w) {
    switch (w) {
      case DashboardWidget.prayerAlarm:
        return Icons.mosque_rounded;
      case DashboardWidget.verseOfMoment:
        return Icons.auto_awesome_rounded;
      case DashboardWidget.dhikrSummary:
        return Icons.radio_button_checked_rounded;
      case DashboardWidget.prayerTracker:
        return Icons.check_circle_outline_rounded;
      case DashboardWidget.qadhaTracker:
        return Icons.replay_rounded;
      case DashboardWidget.deenMode:
        return Icons.nights_stay_rounded;
      case DashboardWidget.charityLog:
        return Icons.volunteer_activism_rounded;
      case DashboardWidget.calendar:
        return Icons.calendar_month_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch visibility state so toggles reflect live
    ref.watch(widgetVisibilityProvider);
    final notifier = ref.read(widgetVisibilityProvider.notifier);
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.65,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: accent.withValues(alpha: 0.15)),
          left: BorderSide(color: accent.withValues(alpha: 0.08)),
          right: BorderSide(color: accent.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle bar ──
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Title ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.dashboard_customize_outlined,
                    size: 18, color: accent.withValues(alpha: 0.7)),
                const SizedBox(width: 10),
                Text(
                  'Edit Widgets',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 16, color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Toggle widgets to show or hide them on your dashboard',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Widget list ──
          Flexible(
            child: Builder(builder: (context) {
              // Filter out qadhaTracker — moved to Prayer Analytics page
              final widgets = DashboardWidget.values
                  .where((w) => w != DashboardWidget.qadhaTracker)
                  .toList();
              return ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 20),
                itemCount: widgets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final widget = widgets[index];
                final isVisible = notifier.isVisible(widget);

                return GestureDetector(
                  onTap: () {
                    notifier.toggle(widget);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isVisible
                          ? accent.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isVisible
                            ? accent.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Widget icon
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isVisible
                                ? accent.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _iconFor(widget),
                            size: 18,
                            color: isVisible
                                ? accent.withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Widget name
                        Expanded(
                          child: Text(
                            widget.label,
                            style: TextStyle(
                              color: isVisible
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : Colors.white.withValues(alpha: 0.35),
                              fontSize: 14,
                              fontWeight:
                                  isVisible ? FontWeight.w600 : FontWeight.w400,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        // Toggle switch
                        SizedBox(
                          height: 28,
                          child: FittedBox(
                            child: Switch.adaptive(
                              value: isVisible,
                              onChanged: (_) {
                                notifier.toggle(widget);
                              },
                              activeTrackColor: accent.withValues(alpha: 0.3),
                              thumbColor: WidgetStateProperty.resolveWith(
                                (states) => states.contains(WidgetState.selected)
                                    ? accent
                                    : Colors.white.withValues(alpha: 0.3),
                              ),
                              inactiveTrackColor:
                                  Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              );
            }),
          ),
        ],
      ),
    );
  }
}
