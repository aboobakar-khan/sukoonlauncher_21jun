import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../providers/islamic_theme_provider.dart';
import 'dua_adhkar_detail_screen.dart';

// ═══════════════════════════════════════════════════════════════════
//  HISNUL MUSLIM DATA PROVIDER
// ═══════════════════════════════════════════════════════════════════

/// Raw JSON entry from hisnul_muslim.json
class HisnulEntry {
  final int id;
  final String type;       // "Adhkar" or "Dua"
  final String category;
  final String title;
  final String arabic;
  final String transliteration;
  final String translation;
  final String reference;
  final String? reward;
  final int? count;

  const HisnulEntry({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.reference,
    this.reward,
    this.count,
  });

  factory HisnulEntry.fromJson(Map<String, dynamic> j) => HisnulEntry(
        id: j['id'] as int,
        type: j['type'] as String? ?? 'Dua',
        category: j['category'] as String? ?? '',
        title: j['title'] as String? ?? '',
        arabic: j['arabic'] as String? ?? '',
        transliteration: j['transliteration'] as String? ?? '',
        translation: j['translation'] as String? ?? '',
        reference: j['reference'] as String? ?? '',
        reward: j.containsKey('reward') ? j['reward'] as String? : null,
        count: j.containsKey('count') ? j['count'] as int? : null,
      );
}

/// Riverpod provider: loads hisnul_muslim.json once
final hisnulMuslimProvider = FutureProvider<List<HisnulEntry>>((ref) async {
  final raw = await rootBundle.loadString('assets/hisnul_muslim.json');
  final List<dynamic> list = jsonDecode(raw);
  return list.map((e) => HisnulEntry.fromJson(e as Map<String, dynamic>)).toList();
});

/// Bookmarked IDs persisted via SharedPreferences
final duaBookmarkIdsProvider =
    StateNotifierProvider<_BookmarkNotifier, Set<String>>((ref) => _BookmarkNotifier());

class _BookmarkNotifier extends StateNotifier<Set<String>> {
  _BookmarkNotifier() : super({}) {
    _load();
  }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('hisnul_bookmarked_ids');
    if (raw != null) state = Set<String>.from(jsonDecode(raw));
  }

  Future<void> toggle(int id) async {
    final key = id.toString();
    state = state.contains(key) ? ({...state}..remove(key)) : {...state, key};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hisnul_bookmarked_ids', jsonEncode(state.toList()));
  }
}

// ═══════════════════════════════════════════════════════════════════
//  CATEGORY DEFINITION
// ═══════════════════════════════════════════════════════════════════

class _Cat {
  final String name;
  final IconData icon;
  const _Cat(this.name, this.icon);
}

const _categories = <_Cat>[
  _Cat('Morning Adhkar',               Icons.wb_sunny_rounded),
  _Cat('Evening Adhkar',               Icons.nights_stay_rounded),
  _Cat('After Salah Adhkar',           Icons.star_rounded),
  _Cat('Waking Up & Sleeping',         Icons.bedtime_rounded),
  _Cat('Home & Family',                Icons.home_rounded),
  _Cat('General Praise & Repentance',  Icons.volunteer_activism_rounded),
  _Cat('Food & Drink',                 Icons.restaurant_rounded),
  _Cat('Traveling & Moving',           Icons.flight_rounded),
  _Cat('Hardship & Anxiety',           Icons.self_improvement_rounded),
  _Cat('Illness & Death',              Icons.favorite_rounded),
  _Cat('Knowledge & Protection',       Icons.shield_rounded),
  _Cat('Mosque & Prayer',              Icons.mosque_rounded),
  _Cat('Social Interactions',          Icons.group_rounded),
  _Cat('Dress & Appearance',           Icons.checkroom_rounded),
  _Cat('Toilet & Cleanliness',         Icons.water_drop_rounded),
];

// ═══════════════════════════════════════════════════════════════════
//  DESIGN TOKENS — Cream + Fresh Green Leaf
// ═══════════════════════════════════════════════════════════════════

class DuaTheme {
  final Color bg;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;        // gold/warm
  final Color leafGreen;     // fresh leaf green
  final Color badgeBg;
  final Color shadow;
  final Color divider;

  const DuaTheme({
    required this.bg,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.leafGreen,
    required this.badgeBg,
    required this.shadow,
    required this.divider,
  });

  // ── Light: warm cream + fresh green ───────────────────────────────
  static const light = DuaTheme(
    bg:            Color(0xFFF5EFE4),  // warm parchment — softer than before
    card:          Color(0xFFFFFBF4),  // slightly warm white
    textPrimary:   Color(0xFF1A2E22),  // deep forest
    textSecondary: Color(0xFF6B7F6E),  // muted sage
    accent:        Color(0xFFC9A84C),  // warm gold
    leafGreen:     Color(0xFF2A7A44),  // fresh leaf green — deeper, richer
    badgeBg:       Color(0xFFECF5EC),  // pale green wash
    shadow:        Color(0x00000000),  // no shadows
    divider:       Color(0xFFE0D8C8),  // subtle parchment divider
  );

  // ── Dark variant (kept for toggle support) ─────────────────────────
  static const dark = DuaTheme(
    bg:            Color(0xFF0A0A0A),
    card:          Color(0xFF161616),
    textPrimary:   Color(0xFFE8E0D4),
    textSecondary: Color(0xFF8B9A8E),
    accent:        Color(0xFFC2A366),
    leafGreen:     Color(0xFF4CAF50),
    badgeBg:       Color(0xFF1E1A12),
    shadow:        Color(0x00000000),
    divider:       Color(0xFF1E1E1E),
  );
}

// ═══════════════════════════════════════════════════════════════════
//  SCREEN 1 — CATEGORY LIST  (magazine-clean, separator-based)
// ═══════════════════════════════════════════════════════════════════

class DuaAdhkarCategoryScreen extends ConsumerWidget {
  const DuaAdhkarCategoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(islamicThemeProvider) == IslamicThemeMode.dark;
    final t = isDark ? DuaTheme.dark : DuaTheme.light;
    final dataAsync = ref.watch(hisnulMuslimProvider);
    final bookmarks = ref.watch(duaBookmarkIdsProvider);
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      body: dataAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
              color: t.leafGreen.withValues(alpha: 0.5), strokeWidth: 1.5),
        ),
        error: (e, _) => Center(
          child: Text('Failed to load data',
              style: GoogleFonts.inter(color: t.textSecondary)),
        ),
        data: (allEntries) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // ── Header ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, mq.padding.top + 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dua & Adhkar',
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w300,
                          color: t.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hisnul Muslim — Fortress of the Muslim',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: t.leafGreen.withValues(alpha: 0.55),
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Thin gold divider under header ────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Container(
                    height: 0.5,
                    color: t.accent.withValues(alpha: 0.25),
                  ),
                ),
              ),

              // ── Saved row (first item, prominent) ─────────────
              SliverToBoxAdapter(
                child: _buildSavedRow(context, t, bookmarks.length),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    height: 0.5,
                    color: t.divider,
                  ),
                ),
              ),

              // ── Section label ─────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    'CATEGORIES',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.8,
                      color: t.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),

              // ── Category rows ─────────────────────────────────
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final cat = _categories[index];
                    final count = allEntries
                        .where((e) => e.category == cat.name)
                        .length;
                    return _buildCategoryRow(context, t, cat, count, index);
                  },
                  childCount: _categories.length,
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: mq.padding.bottom + 40)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSavedRow(BuildContext context, DuaTheme t, int count) {
    return _RowTap(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const DuaAdhkarDetailScreen(
              categoryName: 'My Saved Duas',
              isSaved: true,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Row(
          children: [
            // Leaf icon — no container box
            Icon(Icons.bookmark_rounded, size: 18, color: t.leafGreen),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'My Saved Duas',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: t.textPrimary,
                ),
              ),
            ),
            if (count > 0) ...[
              Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: t.leafGreen.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Icon(Icons.chevron_right_rounded,
                size: 16,
                color: t.textSecondary.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow(
      BuildContext context, DuaTheme t, _Cat cat, int count, int index) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RowTap(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DuaAdhkarDetailScreen(categoryName: cat.name),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                // Bare icon — no container, just the glyph
                Icon(cat.icon,
                    size: 16,
                    color: t.accent.withValues(alpha: 0.65)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    cat.name,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w400,
                      fontSize: 15,
                      color: t.textPrimary.withValues(alpha: 0.88),
                    ),
                  ),
                ),
                // Count — plain number, no pill
                Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: t.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.chevron_right_rounded,
                    size: 16,
                    color: t.textSecondary.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
        // Hairline divider (skip after last)
        if (index < _categories.length - 1)
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Container(height: 0.5, color: t.divider),
          ),
      ],
    );
  }
}

// ─── Tap wrapper with opacity feedback ───────────────────────────────────────
class _RowTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _RowTap({required this.child, required this.onTap});

  @override
  State<_RowTap> createState() => _RowTapState();
}

class _RowTapState extends State<_RowTap> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: widget.child,
      ),
    );
  }
}
