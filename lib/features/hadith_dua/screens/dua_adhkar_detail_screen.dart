import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../providers/islamic_theme_provider.dart';
import 'dua_adhkar_category_screen.dart'; // HisnulEntry, providers, DuaTheme

// ═══════════════════════════════════════════════════════════════════
//  SCREEN 2 — DUA DETAIL LIST  (clean reading view, parchment)
// ═══════════════════════════════════════════════════════════════════

class DuaAdhkarDetailScreen extends ConsumerStatefulWidget {
  final String categoryName;
  final bool isSaved;

  const DuaAdhkarDetailScreen({
    super.key,
    required this.categoryName,
    this.isSaved = false,
  });

  @override
  ConsumerState<DuaAdhkarDetailScreen> createState() =>
      _DuaAdhkarDetailScreenState();
}

class _DuaAdhkarDetailScreenState
    extends ConsumerState<DuaAdhkarDetailScreen> {
  String _filter = 'all'; // 'all', 'adhkar', 'dua'
  String _searchQuery = '';
  bool _showSearch = false;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Map<String, int> _countProgress = {};

  @override
  void initState() {
    super.initState();
    _loadCountProgress();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCountProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('hisnul_count_progress');
    if (raw != null && mounted) {
      setState(() => _countProgress = Map<String, int>.from(jsonDecode(raw)));
    }
  }

  Future<void> _saveCountProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hisnul_count_progress', jsonEncode(_countProgress));
  }

  List<HisnulEntry> _filter_(List<HisnulEntry> allEntries) {
    final bookmarks = ref.read(duaBookmarkIdsProvider);

    List<HisnulEntry> entries;
    if (widget.isSaved) {
      entries = allEntries
          .where((e) => bookmarks.contains(e.id.toString()))
          .toList();
    } else {
      entries = allEntries
          .where((e) => e.category == widget.categoryName)
          .toList();
    }

    if (_filter == 'adhkar') {
      entries = entries.where((e) => e.type == 'Adhkar').toList();
    } else if (_filter == 'dua') {
      entries = entries.where((e) => e.type == 'Dua').toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      entries = entries.where((e) =>
          e.title.toLowerCase().contains(q) ||
          e.translation.toLowerCase().contains(q) ||
          e.transliteration.toLowerCase().contains(q) ||
          e.arabic.contains(q)).toList();
    }

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final t = DuaTheme.from(ref.watch(islamicThemeColorsProvider));
    final dataAsync = ref.watch(hisnulMuslimProvider);
    final bookmarks = ref.watch(duaBookmarkIdsProvider);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: t.textPrimary.withValues(alpha: 0.6)),
          ),
        ),
        title: Text(
          widget.categoryName,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 15,
            color: t.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
              if (_showSearch) {
                Future.delayed(const Duration(milliseconds: 200),
                    () => _searchFocus.requestFocus());
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
              child: Icon(
                _showSearch ? Icons.close_rounded : Icons.search_rounded,
                color: t.textPrimary.withValues(alpha: 0.5),
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
              color: t.leafGreen.withValues(alpha: 0.5), strokeWidth: 1.5),
        ),
        error: (e, _) => Center(
          child: Text('Error loading data',
              style: GoogleFonts.inter(color: t.textSecondary)),
        ),
        data: (allEntries) {
          final entries = _filter_(allEntries);
          final baseEntries = widget.isSaved
              ? allEntries.where((e) => bookmarks.contains(e.id.toString())).toList()
              : allEntries.where((e) => e.category == widget.categoryName).toList();
          final adhkarCount = baseEntries.where((e) => e.type == 'Adhkar').length;
          final duaCount = baseEntries.where((e) => e.type == 'Dua').length;

          return Column(
            children: [
              // ── Search bar (slide-down) ──────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: _showSearch ? 52 : 0,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: GoogleFonts.inter(fontSize: 14, color: t.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search…',
                      isDense: true,
                      hintStyle: GoogleFonts.inter(
                          fontSize: 14, color: t.textSecondary.withValues(alpha: 0.5)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      prefixIcon: Icon(Icons.search, color: t.textSecondary, size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),

              // Thin divider under search
              Container(height: 0.5, color: t.divider),

              // ── Filter pills ─────────────────────────────────
              Container(
                color: t.bg,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    _FilterPill(
                      label: 'All',
                      count: baseEntries.length,
                      active: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all'),
                      theme: t,
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'Adhkar',
                      count: adhkarCount,
                      active: _filter == 'adhkar',
                      onTap: () => setState(() => _filter = 'adhkar'),
                      theme: t,
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'Dua',
                      count: duaCount,
                      active: _filter == 'dua',
                      onTap: () => setState(() => _filter = 'dua'),
                      theme: t,
                    ),
                  ],
                ),
              ),

              Container(height: 0.5, color: t.divider),

              // ── Entry list ───────────────────────────────────
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty
                                  ? Icons.search_off_rounded
                                  : Icons.bookmark_border_rounded,
                              color: t.textSecondary.withValues(alpha: 0.2),
                              size: 36,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No results found'
                                  : widget.isSaved
                                      ? 'No saved duas yet'
                                      : 'No entries',
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: t.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).padding.bottom + 40),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => Container(
                          margin: const EdgeInsets.only(left: 20),
                          height: 0.5,
                          color: t.divider,
                        ),
                        itemBuilder: (context, index) {
                          final e = entries[index];
                          final key = e.id.toString();
                          return _DuaEntryCard(
                            entry: e,
                            theme: t,
                            isBookmarked: bookmarks.contains(key),
                            countProgress: _countProgress[key] ?? 0,
                            onBookmarkToggle: () {
                              ref.read(duaBookmarkIdsProvider.notifier).toggle(e.id);
                            },
                            onCountChange: (v) {
                              setState(() {
                                _countProgress = {..._countProgress, key: v};
                              });
                              _saveCountProgress();
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  FILTER PILL  — refined, minimal
// ═══════════════════════════════════════════════════════════════════

class _FilterPill extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  final DuaTheme theme;

  const _FilterPill({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? theme.leafGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? theme.leafGreen
                : theme.textSecondary.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : theme.textPrimary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: active
                    ? Colors.white.withValues(alpha: 0.7)
                    : theme.textSecondary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  DUA ENTRY CARD  — parchment reading view, no heavy white card
// ═══════════════════════════════════════════════════════════════════

class _DuaEntryCard extends StatefulWidget {
  final HisnulEntry entry;
  final DuaTheme theme;
  final bool isBookmarked;
  final int countProgress;
  final VoidCallback onBookmarkToggle;
  final ValueChanged<int> onCountChange;

  const _DuaEntryCard({
    required this.entry,
    required this.theme,
    required this.isBookmarked,
    required this.countProgress,
    required this.onBookmarkToggle,
    required this.onCountChange,
  });

  @override
  State<_DuaEntryCard> createState() => _DuaEntryCardState();
}

class _DuaEntryCardState extends State<_DuaEntryCard> {
  bool _translitExpanded = false;
  bool _rewardExpanded = false;

  HisnulEntry get e => widget.entry;
  DuaTheme get t => widget.theme;
  bool get _isAdhkar => e.type == 'Adhkar';
  bool get _hasCount => e.count != null;
  bool get _hasReward => e.reward != null && e.reward!.isNotEmpty;
  Color get _typeColor => _isAdhkar ? t.accent : t.leafGreen;

  void _copyArabic() {
    Clipboard.setData(ClipboardData(text: e.arabic));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Copied ✓', style: GoogleFonts.inter(fontSize: 13)),
      backgroundColor: t.leafGreen,
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    ));
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icon, size: 19, color: color),
      ),
    );
  }

  /// A quiet, low-chrome expand toggle (no leading icon box, just label + caret).
  Widget _quietToggle({
    required String label,
    required bool expanded,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color.withValues(alpha: 0.7),
                    letterSpacing: 0.1)),
            const SizedBox(width: 3),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16, color: color.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expandable(bool expanded, Widget child) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 200),
      crossFadeState:
          expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild: const SizedBox(width: double.infinity),
      secondChild: Padding(padding: const EdgeInsets.only(top: 8), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── HEADER: title · copy · bookmark ──────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  e.title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 15.5,
                    color: t.textPrimary,
                    letterSpacing: -0.2,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _iconBtn(Icons.copy_rounded,
                  t.textSecondary.withValues(alpha: 0.4), _copyArabic),
              _iconBtn(
                widget.isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                widget.isBookmarked
                    ? t.accent
                    : t.textSecondary.withValues(alpha: 0.4),
                widget.onBookmarkToggle,
              ),
            ],
          ),

          // ── ARABIC — single type-colored accent bar ──────────
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                    color: _typeColor.withValues(alpha: 0.45), width: 2.5),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                e.arabic,
                style: GoogleFonts.amiri(
                  fontSize: 24,
                  color: t.textPrimary.withValues(alpha: 0.95),
                  height: 2.0,
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                softWrap: true,
              ),
            ),
          ),

          // ── TRANSLITERATION (quiet toggle) ───────────────────
          if (e.transliteration.isNotEmpty) ...[
            _quietToggle(
              label: 'Transliteration',
              expanded: _translitExpanded,
              color: t.textSecondary,
              onTap: () =>
                  setState(() => _translitExpanded = !_translitExpanded),
            ),
            _expandable(
              _translitExpanded,
              Text(
                e.transliteration,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: t.textSecondary.withValues(alpha: 0.8),
                  height: 1.6,
                ),
              ),
            ),
          ],

          // ── TRANSLATION (always visible, plain) ──────────────
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              e.translation,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: t.textPrimary.withValues(alpha: 0.82),
                height: 1.7,
              ),
            ),
          ),

          // ── REFERENCE ────────────────────────────────────────
          if (e.reference.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                e.reference,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: t.textSecondary.withValues(alpha: 0.5),
                  letterSpacing: 0.1,
                ),
              ),
            ),

          // ── REWARD (quiet toggle) ────────────────────────────
          if (_hasReward) ...[
            _quietToggle(
              label: 'Reward & virtue',
              expanded: _rewardExpanded,
              color: t.accent,
              onTap: () => setState(() => _rewardExpanded = !_rewardExpanded),
            ),
            _expandable(
              _rewardExpanded,
              Text(
                e.reward!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: t.textPrimary.withValues(alpha: 0.68),
                  height: 1.65,
                ),
              ),
            ),
          ],

          // ── COUNTER — minimal tap-to-count pill ──────────────
          if (_hasCount) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                const Spacer(),
                _CountPill(
                  progress: widget.countProgress,
                  total: e.count!,
                  accent: t.leafGreen,
                  theme: t,
                  onTap: () {
                    if (widget.countProgress < e.count!) {
                      widget.onCountChange(widget.countProgress + 1);
                    }
                  },
                  onReset: () => widget.onCountChange(0),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  COUNT PILL — one tap-to-count control (replaces −/ring/+/Reset)
//
//  • Not started / counting: outlined "progress / total" pill, tap = +1.
//  • A subtle ↺ reset appears to its left once counting begins.
//  • Complete: fills with the accent colour and shows ✓ Done.
// ═══════════════════════════════════════════════════════════════════

class _CountPill extends StatelessWidget {
  final int progress;
  final int total;
  final Color accent;
  final DuaTheme theme;
  final VoidCallback onTap;
  final VoidCallback onReset;

  const _CountPill({
    required this.progress,
    required this.total,
    required this.accent,
    required this.theme,
    required this.onTap,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final complete = progress >= total;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (progress > 0)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onReset,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
              child: Icon(Icons.refresh_rounded,
                  size: 18, color: theme.textSecondary.withValues(alpha: 0.45)),
            ),
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: complete ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: complete ? accent : accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: complete ? accent : accent.withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: complete
                  ? [
                      const Icon(Icons.check_rounded,
                          size: 17, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('Done',
                          style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ]
                  : [
                      Text('$progress',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: accent)),
                      Text(' / $total',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: accent.withValues(alpha: 0.6))),
                      const SizedBox(width: 8),
                      Icon(Icons.add_rounded,
                          size: 16, color: accent.withValues(alpha: 0.85)),
                    ],
            ),
          ),
        ),
      ],
    );
  }
}
