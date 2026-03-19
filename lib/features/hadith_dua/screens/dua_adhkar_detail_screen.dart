import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../providers/islamic_theme_provider.dart';
import 'dua_adhkar_category_screen.dart'; // HisnulEntry, providers, DuaTheme

// ═══════════════════════════════════════════════════════════════════
//  SCREEN 2 — DUA DETAIL LIST
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

    // Get base list
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

    // Type filter
    if (_filter == 'adhkar') {
      entries = entries.where((e) => e.type == 'Adhkar').toList();
    } else if (_filter == 'dua') {
      entries = entries.where((e) => e.type == 'Dua').toList();
    }

    // Search
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
    final isDark = ref.watch(islamicThemeProvider) == IslamicThemeMode.dark;
    final t = isDark ? DuaTheme.dark : DuaTheme.light;
    final dataAsync = ref.watch(hisnulMuslimProvider);
    final bookmarks = ref.watch(duaBookmarkIdsProvider);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: t.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.categoryName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: t.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showSearch ? Icons.close_rounded : Icons.search_rounded,
              color: t.textPrimary,
              size: 22,
            ),
            onPressed: () {
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
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: t.accent, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: Text('Error loading data',
              style: GoogleFonts.poppins(color: t.textSecondary)),
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
              // ── Search bar ──
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                height: _showSearch ? 56 : 0,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: GoogleFonts.poppins(fontSize: 14, color: t.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: GoogleFonts.poppins(fontSize: 14, color: t.textSecondary),
                      filled: true,
                      fillColor: t.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.search, color: t.textSecondary, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, size: 18, color: t.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),

              // ── Filter pills ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _FilterPill(
                      label: 'All (${baseEntries.length})',
                      active: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all'),
                      theme: t,
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'Adhkar ($adhkarCount)',
                      active: _filter == 'adhkar',
                      onTap: () => setState(() => _filter = 'adhkar'),
                      theme: t,
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'Dua ($duaCount)',
                      active: _filter == 'dua',
                      onTap: () => setState(() => _filter = 'dua'),
                      theme: t,
                    ),
                  ],
                ),
              ),

              // ── Entry list ──
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
                              color: t.textSecondary.withValues(alpha: 0.3),
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No results found'
                                  : widget.isSaved
                                      ? 'No saved duas yet'
                                      : 'No entries',
                              style: GoogleFonts.poppins(
                                fontSize: 14, color: t.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final e = entries[index];
                          final key = e.id.toString();
                          return _DuaEntryCard(
                            entry: e,
                            theme: t,
                            isBookmarked: bookmarks.contains(key),
                            countProgress: _countProgress[key] ?? 0,
                            onBookmarkToggle: () {
                              HapticFeedback.lightImpact();
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
//  FILTER PILL
// ═══════════════════════════════════════════════════════════════════

class _FilterPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final DuaTheme theme;

  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? theme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? theme.accent : theme.textSecondary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : theme.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  DUA ENTRY CARD
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
  bool get _isComplete => _hasCount && widget.countProgress >= e.count!;

  // Theme-specific badge colors — gold primary for Adhkar, green for Dua
  Color get _typeBadgeBg => _isAdhkar
      ? t.accent.withValues(alpha: 0.12)
      : t.leafGreen.withValues(alpha: 0.10);
  Color get _typeBadgeText => _isAdhkar ? t.accent : t.leafGreen;
  Color get _arabicBg => t.bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: _isComplete
            ? Border.all(color: t.accent.withValues(alpha: 0.4), width: 1.5)
            : null,
        boxShadow: [BoxShadow(blurRadius: 12, color: t.shadow)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. TOP ROW ─────────────────────────────────────
          Row(
            children: [
              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _typeBadgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  e.type,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _typeBadgeText,
                  ),
                ),
              ),
              const Spacer(),
              // Count badge
              if (_hasCount)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.leafGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '× ${e.count}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: t.leafGreen,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              // Bookmark
              GestureDetector(
                onTap: widget.onBookmarkToggle,
                child: Icon(
                  widget.isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: widget.isBookmarked ? t.accent : t.textSecondary,
                  size: 22,
                ),
              ),
            ],
          ),

          // ── 2. TITLE ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              e.title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: t.textPrimary,
              ),
            ),
          ),

          // ── 3. ARABIC BLOCK ────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: _arabicBg,
              borderRadius: BorderRadius.circular(14),
              border: Border(left: BorderSide(color: t.accent, width: 3)),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      e.arabic,
                      style: GoogleFonts.amiri(
                        fontSize: 24,
                        color: t.textPrimary,
                        height: 2.0,
                      ),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      softWrap: true,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: e.arabic));
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Arabic text copied ✓',
                            style: GoogleFonts.poppins(fontSize: 13)),
                        backgroundColor: t.accent,
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ));
                    },
                    child: Icon(Icons.copy_rounded, size: 16,
                        color: t.textSecondary.withValues(alpha: 0.5)),
                  ),
                ),
              ],
            ),
          ),

          // ── 4. TRANSLITERATION (collapsible) ───────────────
          if (e.transliteration.isNotEmpty) ...[
            GestureDetector(
              onTap: () =>
                  setState(() => _translitExpanded = !_translitExpanded),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(Icons.translate_rounded, size: 14, color: t.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Transliteration',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: t.textSecondary),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _translitExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18, color: t.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _translitExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  e.transliteration,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: t.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],

          // ── 5. TRANSLATION ─────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: t.leafGreen, width: 2)),
            ),
            child: Text(
              e.translation,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                color: t.textPrimary.withValues(alpha: 0.85),
                height: 1.6,
              ),
            ),
          ),

          // ── 6. REFERENCE ───────────────────────────────────
          if (e.reference.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Icon(Icons.menu_book_rounded, size: 13, color: t.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      e.reference,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: t.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── 7. REWARD (collapsible) ────────────────────────
          if (_hasReward) ...[
            GestureDetector(
              onTap: () => setState(() => _rewardExpanded = !_rewardExpanded),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(color: t.accent, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            size: 16, color: t.accent),
                        const SizedBox(width: 6),
                        Text(
                          'Reward & Virtue',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: t.accent,
                          ),
                        ),
                        const Spacer(),
                        AnimatedRotation(
                          turns: _rewardExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: t.accent,
                          ),
                        ),
                      ],
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      crossFadeState: _rewardExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          e.reward!,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: t.textPrimary.withValues(alpha: 0.75),
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── 8. COUNT TRACKER (only if count exists) ────────
          if (_hasCount) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(height: 1, color: t.divider),
            ),
            const SizedBox(height: 12),
            _isComplete
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: t.accent, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Complete!',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: t.accent,
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          widget.onCountChange(0);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Text(
                            'Reset',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: t.textSecondary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Minus
                      _CounterBtn(
                        icon: Icons.remove,
                        filled: false,
                        color: t.accent,
                        onTap: () {
                          if (widget.countProgress > 0) {
                            HapticFeedback.lightImpact();
                            widget.onCountChange(widget.countProgress - 1);
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      // Progress circle
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: widget.countProgress / e.count!,
                              strokeWidth: 3,
                              backgroundColor: t.divider,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(t.accent),
                            ),
                            Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                  text: '${widget.countProgress}\n',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: t.textPrimary,
                                    height: 1.2,
                                  ),
                                ),
                                TextSpan(
                                  text: '/${e.count}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: t.textSecondary,
                                    height: 1.0,
                                  ),
                                ),
                              ]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Plus
                      _CounterBtn(
                        icon: Icons.add,
                        filled: true,
                        color: t.accent,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          final next = widget.countProgress + 1;
                          widget.onCountChange(next);
                          if (next >= e.count!) HapticFeedback.heavyImpact();
                        },
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          widget.onCountChange(0);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Text(
                            'Reset',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: t.textSecondary,
                            ),
                          ),
                        ),
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
//  COUNTER BUTTON
// ═══════════════════════════════════════════════════════════════════

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final Color color;
  final VoidCallback onTap;

  const _CounterBtn({
    required this.icon,
    required this.filled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : Colors.transparent,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Icon(icon, size: 18, color: filled ? Colors.white : color),
      ),
    );
  }
}
