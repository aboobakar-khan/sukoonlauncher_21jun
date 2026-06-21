import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/hadith_dua_provider.dart';
import '../models/hadith_dua_models.dart';

/// Hadith & Dua Screen - Displays daily hadith and dua with search and bookmarks
class HadithDuaScreen extends ConsumerStatefulWidget {
  const HadithDuaScreen({super.key});

  @override
  ConsumerState<HadithDuaScreen> createState() => _HadithDuaScreenState();
}

class _HadithDuaScreenState extends ConsumerState<HadithDuaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(hadithDuaTabProvider.notifier).state = _tabController.index;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchStateProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            _buildSearchBar(searchState),

            // Content
            Expanded(
              child: searchState.isSearching
                  ? _buildSearchResults(searchState)
                  : _buildMainContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(SearchState searchState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: searchState.isSearching
                ? const Color(0xFFC2A366)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                Icons.search,
                color: searchState.isSearching
                    ? const Color(0xFFC2A366)
                    : Colors.grey[500],
                size: 20,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search hadith or dua...',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onTap: () {
                  ref.read(searchStateProvider.notifier).startSearch();
                },
                onChanged: (query) {
                  ref.read(searchStateProvider.notifier).search(query);
                },
              ),
            ),
            if (searchState.isSearching)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                onPressed: () {
                  _searchController.clear();
                  _searchFocusNode.unfocus();
                  ref.read(searchStateProvider.notifier).endSearch();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Tab bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF21262D),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: const Color(0xFFA67B5B),
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.all(4),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[500],
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            dividerColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            tabs: const [
              Tab(text: 'Hadith', height: 40),
              Tab(text: 'Dua', height: 40),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Tab content - swipe disabled so main page navigation works
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(), // Disable swipe - tap to switch tabs
            children: [
              _buildHadithTab(),
              _buildDuaTab(),
            ],
          ),
        ),
      ],
    );
  }

  /* REMOVED: Old "Today" tab with Daily Inspiration UI
   * This tab has been removed. Users can access Hadith and Dua directly
   * from the daily challenges card which navigates to the proper tabs.
   */

  // Helper methods still used by Dua tab and search results
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFA67B5B).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: const Color(0xFFC2A366), size: 14),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDuaCard(Dua dua, {bool isDaily = false}) {
    final isBookmarked = ref.read(bookmarksProvider.notifier).isDuaBookmarked(dua);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDaily
              ? const Color(0xFFC2A366).withAlpha(40)
              : Colors.white.withAlpha(5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  dua.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (dua.category != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    dua.category!,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 10,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  ref.read(bookmarksProvider.notifier).toggleDuaBookmark(dua);
                },
                child: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: isBookmarked ? const Color(0xFFC2A366) : Colors.grey[500],
                  size: 20,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Arabic text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFC2A366).withAlpha(15),
                  Colors.white.withAlpha(5),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC2A366).withAlpha(15)),
            ),
            child: Text(
              dua.arabicText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                height: 1.8,
                fontWeight: FontWeight.w500,
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 12),

          // Transliteration
          Text(
            dua.transliteration,
            style: TextStyle(
              color: const Color(0xFFC2A366).withValues(alpha: 0.9),
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 8),

          // Translation
          Text(
            dua.translation,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 13,
              height: 1.5,
            ),
          ),

          if (dua.source != null) ...[
            const SizedBox(height: 8),
            Text(
              '— ${dua.source}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Actions
          Row(
            children: [
              _buildActionButton(Icons.copy, 'Copy', () {
                Clipboard.setData(ClipboardData(
                  text: '${dua.arabicText}\n\n${dua.transliteration}\n\n${dua.translation}',
                ));
                _showSnackBar('Copied to clipboard');
              }),
              const SizedBox(width: 8),
              _buildActionButton(Icons.share, 'Share', () {
                Share.share(dua.shareableText);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.grey[500], size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHadithTab() {
    final hadithsAsync = ref.watch(collectionHadithsProvider);
    final selectedCollection = ref.watch(selectedCollectionProvider);
    final selectedGrade = ref.watch(selectedGradeFilterProvider);

    return Column(
      children: [
        // Collection dropdown and filters
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Collection dropdown
              Expanded(
                child: _buildCollectionDropdown(selectedCollection),
              ),
              const SizedBox(width: 8),
              // Grade filter
              _buildGradeFilterButton(selectedGrade),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Hadiths list
        Expanded(
          child: hadithsAsync.when(
            data: (hadiths) {
              if (hadiths.isEmpty) {
                return _buildEmptyState('No hadiths found');
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const ClampingScrollPhysics(),
                itemCount: hadiths.length.clamp(0, 100),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: EnhancedHadithCard(hadith: hadiths[index]),
                  );
                },
              );
            },
            loading: () => _buildEmptyState('Loading hadiths...'),
            error: (_, _) => _buildEmptyState('Failed to load hadiths'),
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionDropdown(String selectedCollection) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCollection,
          isDense: true,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[500], size: 20),
          dropdownColor: const Color(0xFF21262D),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: HadithCollection.collections.map((c) {
            return DropdownMenuItem(
              value: c.id,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.defaultGrade == HadithGrade.sahih
                          ? const Color(0xFFC2A366).withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      c.shortName,
                      style: TextStyle(
                        color: c.defaultGrade == HadithGrade.sahih
                            ? const Color(0xFFC2A366)
                            : Colors.grey[400],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.name,
                      style: TextStyle(color: Colors.grey[300], fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              ref.read(selectedCollectionProvider.notifier).state = value;
            }
          },
        ),
      ),
    );
  }

  Widget _buildGradeFilterButton(HadithGrade? selectedGrade) {
    return PopupMenuButton<HadithGrade?>(
      onSelected: (grade) {
        ref.read(selectedGradeFilterProvider.notifier).state = grade;
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: null,
          child: Text('All Grades', style: TextStyle(fontSize: 13)),
        ),
        PopupMenuItem(
          value: HadithGrade.sahih,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Color(HadithGrade.sahih.colorValue),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Sahih', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: HadithGrade.hasan,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Color(HadithGrade.hasan.colorValue),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Hasan', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: HadithGrade.daif,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Color(HadithGrade.daif.colorValue),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text("Da'if", style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selectedGrade != null
              ? Color(selectedGrade.colorValue).withValues(alpha: 0.2)
              : const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selectedGrade != null
                ? Color(selectedGrade.colorValue).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Icon(
          Icons.filter_list,
          color: selectedGrade != null
              ? Color(selectedGrade.colorValue)
              : Colors.grey[500],
          size: 18,
        ),
      ),
    );
  }

  Widget _buildDuaTab() {
    final categories = ref.watch(duaCategoriesProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const ClampingScrollPhysics(),
      children: [
        for (final category in categories) ...[
          _buildCategorySection(category),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildCategorySection(String category) {
    final duas = ref.watch(duasByCategoryProvider(category));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...duas.map((dua) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildDuaCard(dua),
        )),
      ],
    );
  }

  Widget _buildSearchResults(SearchState searchState) {
    if (searchState.query.isEmpty) {
      return _buildEmptyState('Type to search...');
    }

    if (searchState.isLoading && searchState.hadithResults.isEmpty && searchState.duaResults.isEmpty) {
      return _buildEmptyState('Searching...');
    }

    final hasResults = searchState.hadithResults.isNotEmpty || searchState.duaResults.isNotEmpty;

    if (!hasResults) {
      return _buildEmptyState('No results found');
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const ClampingScrollPhysics(),
      children: [
        if (searchState.duaResults.isNotEmpty) ...[
          _buildSectionHeader('Duas (${searchState.duaResults.length})', Icons.favorite_outline),
          const SizedBox(height: 8),
          ...searchState.duaResults.map((dua) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildDuaCard(dua),
          )),
          const SizedBox(height: 16),
        ],
        if (searchState.hadithResults.isNotEmpty) ...[
          _buildSectionHeader('Hadiths (${searchState.hadithResults.length})', Icons.menu_book),
          const SizedBox(height: 8),
          ...searchState.hadithResults.map((hadith) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: EnhancedHadithCard(hadith: hadith),
          )),
        ],
        if (searchState.isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFC2A366)),
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, color: Colors.grey[600], size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF21262D),
      ),
    );
  }
}

/// Enhanced Hadith Card with expandable sections
class EnhancedHadithCard extends ConsumerStatefulWidget {
  final Hadith hadith;
  final bool isDaily;

  const EnhancedHadithCard({
    super.key,
    required this.hadith,
    this.isDaily = false,
  });

  @override
  ConsumerState<EnhancedHadithCard> createState() => _EnhancedHadithCardState();
}

class _EnhancedHadithCardState extends ConsumerState<EnhancedHadithCard> {
  bool _showArabic = false;
  bool _showNarrator = false;
  bool _showTranslation = true;

  @override
  Widget build(BuildContext context) {
    ref.watch(bookmarksProvider);
    final isBookmarked = ref.read(bookmarksProvider.notifier).isHadithBookmarked(widget.hadith);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: widget.isDaily
              ? const Color(0xFFC2A366).withAlpha(40)
              : Colors.white.withAlpha(5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with grade badge
          _buildHeader(isBookmarked),
          
          // Reference info
          _buildReferenceInfo(),
          
          // Category tags
          if (widget.hadith.categories.isNotEmpty)
            _buildCategoryTags(),
          
          // Narrator chain (expandable)
          if (widget.hadith.extractedNarrator != null)
            _buildNarratorSection(),
          
          // Arabic section (expandable)
          if (widget.hadith.arabicText != null && widget.hadith.arabicText!.isNotEmpty)
            _buildArabicSection(),
          
          // Translation section (expandable)
          _buildTranslationSection(),
          
          // Actions
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isBookmarked) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          // Collection badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFA67B5B).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.hadith.collection.split(' ').last, // Short name
              style: const TextStyle(
                color: Color(0xFFC2A366),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Grade badge
          _buildGradeBadge(),
          
          const Spacer(),
          
          // Hadith number
          Text(
            '#${widget.hadith.hadithNumber}',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Bookmark button
          GestureDetector(
            onTap: () => _showBookmarkOptions(),
            child: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: isBookmarked ? const Color(0xFFC2A366) : Colors.grey[500],
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeBadge() {
    final grade = widget.hadith.grade;
    if (grade == HadithGrade.unknown) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color(grade.colorValue).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Color(grade.colorValue).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Color(grade.colorValue),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            grade.displayName,
            style: TextStyle(
              color: Color(grade.colorValue),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceInfo() {
    final scholarGrades = widget.hadith.scholarGrades;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full reference
          Text(
            widget.hadith.formattedReference,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
            ),
          ),
          
          // Scholar grading
          if (scholarGrades.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              scholarGrades.first.displayText,
              style: TextStyle(
                color: Color(scholarGrades.first.grade.colorValue).withValues(alpha: 0.8),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryTags() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: widget.hadith.categories.take(3).map((category) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF21262D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${category.emoji} ${category.displayName}',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 10,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNarratorSection() {
    return _buildExpandableSection(
      title: 'Narrator',
      icon: Icons.person_outline,
      isExpanded: _showNarrator,
      onToggle: () => setState(() => _showNarrator = !_showNarrator),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.hadith.extractedNarrator ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.hadith.narratorChain != null) ...[
            const SizedBox(height: 8),
            Text(
              'Chain: ${widget.hadith.narratorChain}',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArabicSection() {
    return _buildExpandableSection(
      title: 'Arabic Text',
      icon: Icons.translate,
      isExpanded: _showArabic,
      onToggle: () => setState(() => _showArabic = !_showArabic),
      content: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFC2A366).withAlpha(15),
              Colors.white.withAlpha(5),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC2A366).withAlpha(15)),
        ),
        child: Column(
          children: [
            Text(
              widget.hadith.arabicText!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                height: 1.8,
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.hadith.arabicText!));
                  _showSnackBar('Arabic text copied');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, color: Colors.grey[500], size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Copy Arabic',
                        style: TextStyle(color: Colors.grey[500], fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationSection() {
    return _buildExpandableSection(
      title: 'Translation',
      icon: Icons.article_outlined,
      isExpanded: _showTranslation,
      onToggle: () => setState(() => _showTranslation = !_showTranslation),
      alwaysShowFirst: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.hadith.text,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.hadith.text));
              _showSnackBar('Translation copied');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy, color: Colors.grey[500], size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'Copy Translation',
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget content,
    bool alwaysShowFirst = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Icon(icon, color: Colors.grey[500], size: 14),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey[500],
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        
        // Content
        AnimatedCrossFade(
          firstChild: alwaysShowFirst
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: content,
                )
              : const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: content,
          ),
          crossFadeState: isExpanded || alwaysShowFirst
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Row(
        children: [
          // Copy all
          _buildActionButton(Icons.copy_all, 'Copy All', () {
            Clipboard.setData(ClipboardData(text: widget.hadith.shareableText));
            _showSnackBar('Copied to clipboard');
          }),
          
          const SizedBox(width: 8),
          
          // Share
          _buildActionButton(Icons.share, 'Share', () {
            Share.share(widget.hadith.shareableText);
          }),
          
          const Spacer(),
          
          // More options
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz, color: Colors.grey[500], size: 20),
            onSelected: (value) {
              switch (value) {
                case 'copy_arabic':
                  if (widget.hadith.arabicText != null) {
                    Clipboard.setData(ClipboardData(text: widget.hadith.arabicText!));
                    _showSnackBar('Arabic copied');
                  }
                  break;
                case 'copy_translation':
                  Clipboard.setData(ClipboardData(text: widget.hadith.text));
                  _showSnackBar('Translation copied');
                  break;
                case 'copy_reference':
                  Clipboard.setData(ClipboardData(text: widget.hadith.formattedReference));
                  _showSnackBar('Reference copied');
                  break;
              }
            },
            itemBuilder: (context) => [
              if (widget.hadith.arabicText != null)
                const PopupMenuItem(
                  value: 'copy_arabic',
                  child: Row(
                    children: [
                      Icon(Icons.translate, size: 16),
                      SizedBox(width: 8),
                      Text('Copy Arabic', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'copy_translation',
                child: Row(
                  children: [
                    Icon(Icons.text_fields, size: 16),
                    SizedBox(width: 8),
                    Text('Copy Translation', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy_reference',
                child: Row(
                  children: [
                    Icon(Icons.tag, size: 16),
                    SizedBox(width: 8),
                    Text('Copy Reference', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.grey[500], size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookmarkOptions() {
    final bookmarks = ref.read(bookmarksProvider);
    final isBookmarked = ref.read(bookmarksProvider.notifier).isHadithBookmarked(widget.hadith);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bookmark, color: Color(0xFFC2A366), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Save to Collection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (isBookmarked)
                  TextButton(
                    onPressed: () {
                      ref.read(bookmarksProvider.notifier).toggleHadithBookmark(widget.hadith);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Remove',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...bookmarks.collections.map((collection) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.folder_outlined,
                color: Colors.grey[400],
              ),
              title: Text(
                collection,
                style: TextStyle(color: Colors.grey[300], fontSize: 14),
              ),
              trailing: Icon(
                Icons.add_circle_outline,
                color: Colors.grey[500],
              ),
              onTap: () {
                ref.read(bookmarksProvider.notifier).toggleHadithBookmark(
                  widget.hadith,
                  collectionName: collection,
                );
                Navigator.pop(context);
                _showSnackBar('Saved to $collection');
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF21262D),
      ),
    );
  }
}
