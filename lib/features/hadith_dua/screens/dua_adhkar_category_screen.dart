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
//  CATEGORY DEFINITION (matches JSON categories exactly)
// ═══════════════════════════════════════════════════════════════════

class _Cat {
  final String name;
  final IconData icon;
  const _Cat(this.name, this.icon);
}

const _categories = <_Cat>[
  _Cat('Morning Adhkar', Icons.wb_sunny_rounded),
  _Cat('Evening Adhkar', Icons.nights_stay_rounded),
  _Cat('After Salah Adhkar', Icons.star_rounded),
  _Cat('Waking Up & Sleeping', Icons.bedtime_rounded),
  _Cat('Home & Family', Icons.home_rounded),
  _Cat('General Praise & Repentance', Icons.volunteer_activism_rounded),
  _Cat('Food & Drink', Icons.restaurant_rounded),
  _Cat('Traveling & Moving', Icons.flight_rounded),
  _Cat('Hardship & Anxiety', Icons.self_improvement_rounded),
  _Cat('Illness & Death', Icons.favorite_rounded),
  _Cat('Knowledge & Protection', Icons.shield_rounded),
  _Cat('Mosque & Prayer', Icons.mosque_rounded),
  _Cat('Social Interactions', Icons.group_rounded),
  _Cat('Dress & Appearance', Icons.checkroom_rounded),
  _Cat('Toilet & Cleanliness', Icons.water_drop_rounded),
];

// ═══════════════════════════════════════════════════════════════════
//  LIGHT THEME — warm beige + fresh green leaf
// ═══════════════════════════════════════════════════════════════════

class DuaTheme {
  final Color bg;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;        // primary — gold/beige
  final Color leafGreen;     // secondary — fresh green
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

  static const light = DuaTheme(
    bg: Color(0xFFF7F2E9),        // warm beige
    card: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1B3A2D),
    textSecondary: Color(0xFF6B7B6E),
    accent: Color(0xFFC9A84C),     // gold — PRIMARY
    leafGreen: Color(0xFF2D8A4E),  // fresh green — SECONDARY
    badgeBg: Color(0xFFFFF8EB),    // warm gold tint
    shadow: Color(0x12000000),
    divider: Color(0xFFE8E0D0),
  );

  static const dark = DuaTheme(
    bg: Color(0xFF0A0A0A),
    card: Color(0xFF161616),
    textPrimary: Color(0xFFE8E0D4),
    textSecondary: Color(0xFF8B9A8E),
    accent: Color(0xFFC2A366),     // gold — PRIMARY
    leafGreen: Color(0xFF4CAF50),  // green — SECONDARY
    badgeBg: Color(0xFF1E1A12),    // dark gold tint
    shadow: Color(0x00000000),
    divider: Color(0xFF1E1E1E),
  );
}

// ═══════════════════════════════════════════════════════════════════
//  SCREEN 1 — CATEGORY LIST
// ═══════════════════════════════════════════════════════════════════

class DuaAdhkarCategoryScreen extends ConsumerWidget {
  const DuaAdhkarCategoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(islamicThemeProvider) == IslamicThemeMode.dark;
    final t = isDark ? DuaTheme.dark : DuaTheme.light;
    final dataAsync = ref.watch(hisnulMuslimProvider);
    final bookmarks = ref.watch(duaBookmarkIdsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: dataAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: t.accent, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: Text('Failed to load data',
              style: GoogleFonts.poppins(color: t.textSecondary)),
        ),
        data: (allEntries) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            physics: const BouncingScrollPhysics(),
            itemCount: _categories.length + 1, // +1 for saved
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildSavedCard(context, t, bookmarks.length);
              }
              final cat = _categories[index - 1];
              final count = allEntries
                  .where((e) => e.category == cat.name)
                  .length;
              return _buildCategoryCard(context, t, cat, count);
            },
          );
        },
      ),
    );
  }

  Widget _buildSavedCard(BuildContext context, DuaTheme t, int count) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(blurRadius: 12, color: t.shadow)],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [t.accent, t.leafGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bookmark_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'My Saved Duas',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: t.textPrimary,
                ),
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: t.badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: t.accent,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: t.accent, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, DuaTheme t, _Cat cat, int count) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DuaAdhkarDetailScreen(categoryName: cat.name),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(blurRadius: 12, color: t.shadow)],
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: t.badgeBg,
              ),
              child: Icon(cat.icon, size: 20, color: t.accent),
            ),
            const SizedBox(width: 12),
            // Title
            Expanded(
              child: Text(
                cat.name,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: t.textPrimary,
                ),
              ),
            ),
            // Count pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: t.badgeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: t.accent,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: t.textSecondary.withValues(alpha: 0.4), size: 20),
          ],
        ),
      ),
    );
  }
}
