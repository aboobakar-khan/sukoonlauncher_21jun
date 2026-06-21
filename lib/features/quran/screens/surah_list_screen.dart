import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/quran_provider.dart';
import '../providers/quran_settings_provider.dart';
import '../models/surah.dart';
import 'surah_reader_screen.dart';
import 'quran_settings_screen.dart';
import '../../../providers/islamic_theme_provider.dart';
import '../../../widgets/swipe_back_wrapper.dart';

class SurahListScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  
  const SurahListScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends ConsumerState<SurahListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Surah> _filteredSurahs = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _filterSurahs(List<Surah> allSurahs, String query) {
    if (query.isEmpty) {
      _filteredSurahs = allSurahs;
    } else {
      _filteredSurahs = allSurahs.where((surah) {
        final searchLower = query.toLowerCase();
        return surah.name.toLowerCase().contains(searchLower) ||
            surah.transliteration.toLowerCase().contains(searchLower) ||
            surah.id.toString().contains(searchLower);
      }).toList();
    }
  }

  void _navigateToSurah(Surah surah, {int? scrollToAyah}) {
    ref.read(selectedSurahProvider.notifier).state = surah;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SurahReaderScreen(
          surah: surah,
          initialAyah: scrollToAyah,
        ),
      ),
    );
  }

  Future<void> _resumeReading(LastReadPosition position, List<Surah> surahs) async {
    
    // Find the surah
    final surah = surahs.firstWhere(
      (s) => s.id == position.surahId,
      orElse: () => surahs.first,
    );
    
    _navigateToSurah(surah, scrollToAyah: position.ayahNumber);
  }

  @override
  Widget build(BuildContext context) {
    final surahsAsync = ref.watch(surahsProvider);
    final readingProgress = ref.watch(readingProgressProvider);
    final tc = ref.watch(islamicThemeColorsProvider);

    return SwipeBackWrapper(
      child: Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        child: Column(
          children: [
          // ── Header with settings ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
            child: Row(
              children: [
                Text('Al-Quran',
                  style: TextStyle(color: tc.text, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Consumer(
                  builder: (context, ref, _) {
                    final settings = ref.watch(quranSettingsProvider);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: tc.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        settings.translationName,
                        style: TextStyle(color: tc.green.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    );
                  },
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuranSettingsScreen()),
                    );
                  },
                  icon: Icon(Icons.tune_rounded, color: tc.textSecondary.withValues(alpha: 0.5), size: 22),
                ),
              ],
            ),
          ),
          // Resume Reading Card
          if (!readingProgress.isLoading && readingProgress.lastPosition != null)
            surahsAsync.when(
              data: (surahs) => _buildResumeReadingCard(readingProgress.lastPosition!, surahs, tc),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: tc.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isSearching
                      ? tc.accent.withValues(alpha: 0.3)
                      : tc.surface.withValues(alpha: 0.6),
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: TextStyle(color: tc.text.withValues(alpha: 0.85), fontSize: 14),
                onTap: () => setState(() => _isSearching = true),
                decoration: InputDecoration(
                  hintText: 'Search surah by name or number...',
                  hintStyle: TextStyle(
                    color: tc.textSecondary.withValues(alpha: 0.3),
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: _isSearching
                        ? tc.accent.withValues(alpha: 0.7)
                        : tc.textSecondary.withValues(alpha: 0.3),
                    size: 18,
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 44),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            setState(() {
                              _searchController.clear();
                              _isSearching = false;
                              _searchFocusNode.unfocus();
                            });
                          },
                          child: Icon(
                            Icons.close_rounded,
                            color: tc.textSecondary.withValues(alpha: 0.35),
                            size: 16,
                          ),
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),
          ),

          // Surah List
          Expanded(
            child: surahsAsync.when(
              data: (surahs) {
                _filterSurahs(surahs, _searchController.text);

                if (_filteredSurahs.isEmpty) {
                  return Center(
                    child: Text(
                      'No Surah found',
                      style: TextStyle(
                        color: tc.textSecondary.withValues(alpha: 0.4),
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  physics: const ClampingScrollPhysics(),
                  cacheExtent: 500,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _filteredSurahs.length,
                  itemBuilder: (context, index) {
                    final surah = _filteredSurahs[index];
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: tc.surface.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: tc.surface.withValues(alpha: 0.5)),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: tc.green.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${surah.id}',
                              style: TextStyle(
                                color: tc.green.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                surah.name,
                                style: TextStyle(
                                  color: tc.text.withValues(alpha: 0.85),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Amiri',
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              surah.transliteration,
                              style: TextStyle(
                                color: tc.textSecondary.withValues(alpha: 0.65),
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              surah.type == 'meccan' ? 'Meccan' : 'Medinan',
                              style: TextStyle(
                                color: tc.textSecondary.withValues(alpha: 0.35),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${surah.totalVerses} verses',
                              style: TextStyle(
                                color: tc.textSecondary.withValues(alpha: 0.35),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          color: tc.accent.withValues(alpha: 0.35),
                          size: 14,
                        ),
                        onTap: () {
                          _navigateToSurah(surah);
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(color: tc.green.withValues(alpha: 0.5)),
              ),
              error: (error, stack) => Center(
                child: Text(
                  'Error loading Quran: $error',
                  style: TextStyle(color: Colors.red.withValues(alpha: 0.7)),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    ),  // SwipeBackWrapper
    );
  }

  Widget _buildResumeReadingCard(LastReadPosition position, List<Surah> surahs, IslamicThemeColors tc) {
    // Use the islamicThemeColorsProvider background brightness instead of Flutter's Material theme.
    final isDark = tc.statusBarBrightness == Brightness.light;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        color: tc.green.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tc.green.withValues(alpha: isDark ? 0.25 : 0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _resumeReading(position, surahs),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Book icon - minimal and clean
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tc.green.withValues(alpha: isDark ? 0.2 : 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: tc.green.withValues(alpha: 0.8),
                    size: 22,
                  ),
                ),
                
                const SizedBox(width: 14),
                
                // Text content - clean typography
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // "Last Read" label
                      Text(
                        'Last Read',
                        style: TextStyle(
                          color: tc.textSecondary.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Surah name and ayah
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: tc.text.withValues(alpha: 0.9),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                          children: [
                            TextSpan(text: position.surahTransliteration),
                            TextSpan(
                              text: '  •  ${position.ayahNumber}/${position.totalVerses}',
                              style: TextStyle(
                                color: tc.textSecondary.withValues(alpha: 0.5),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Simple arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: tc.green.withValues(alpha: 0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
