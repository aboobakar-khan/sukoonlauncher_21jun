import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hadith_dua_provider.dart';
import '../models/hadith_dua_models.dart';
import '../../../providers/islamic_theme_provider.dart';
import 'dua_reading_screen.dart';

/// List screen showing duas within a selected category
class DuaListScreen extends ConsumerWidget {
  final String categoryId;
  final String categoryName;
  final IconData categoryIcon;

  const DuaListScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = ref.watch(islamicThemeColorsProvider);
    final allDuas = ref.watch(allDuasProvider);
    final filteredDuas = _filterDuas(allDuas);

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
              _buildHeader(context, tc, filteredDuas.length),
              Expanded(
                child: filteredDuas.isEmpty
                    ? _buildEmptyState(tc)
                    : _buildDuaList(context, tc, filteredDuas),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Dua> _filterDuas(List<Dua> allDuas) {
    if (categoryId == 'General') {
      // Show duas that don't belong to specific categories
      const specificCategories = [
        'Morning & Evening',
        'Protection',
        'After Salah',
        'Ramadan',
        'Darood & Salawat',
      ];
      return allDuas.where((d) {
        final cat = d.category ?? '';
        return !specificCategories.any((sc) => cat.contains(sc));
      }).toList();
    }
    
    return allDuas.where((d) {
      final cat = d.category ?? '';
      return cat.contains(categoryId);
    }).toList();
  }

  Widget _buildHeader(BuildContext context, IslamicThemeColors tc, int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 16),
      decoration: BoxDecoration(
        color: tc.background,
        border: Border(
          bottom: BorderSide(
            color: tc.surface.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back,
              color: tc.text.withValues(alpha: 0.7),
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tc.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              categoryIcon,
              color: tc.green.withValues(alpha: 0.7),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryName,
                  style: TextStyle(
                    color: tc.text.withValues(alpha: 0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count supplications',
                  style: TextStyle(
                    color: tc.textSecondary.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuaList(BuildContext context, IslamicThemeColors tc, List<Dua> duas) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      physics: const ClampingScrollPhysics(),
      itemCount: duas.length,
      itemBuilder: (context, index) {
        return _DuaListItem(
          dua: duas[index],
          index: index,
          tc: tc,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DuaReadingScreen(
                  initialDua: duas[index],
                  allDuas: duas,
                  initialIndex: index,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(IslamicThemeColors tc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: tc.surface.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_outlined,
              color: tc.textSecondary.withValues(alpha: 0.3),
              size: 28,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No duas found',
            style: TextStyle(
              color: tc.textSecondary.withValues(alpha: 0.5),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try another category',
            style: TextStyle(
              color: tc.textSecondary.withValues(alpha: 0.3),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual dua list item - Clean and minimal
class _DuaListItem extends StatelessWidget {
  final Dua dua;
  final int index;
  final IslamicThemeColors tc;
  final VoidCallback onTap;

  const _DuaListItem({
    required this.dua,
    required this.index,
    required this.tc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Extract first line of Arabic for preview
    final arabicPreview = dua.arabicText.split('\n').first;
    final shortPreview = arabicPreview.length > 60
        ? '${arabicPreview.substring(0, 60)}...'
        : arabicPreview;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.surface.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: tc.surface.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Number indicator
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tc.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: tc.green.withValues(alpha: 0.65),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    dua.title,
                    style: TextStyle(
                      color: tc.text.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Arabic preview (faded)
                  Text(
                    shortPreview,
                    style: TextStyle(
                      color: tc.arabicText.withValues(alpha: 0.35),
                      fontSize: 13,
                      fontFamily: 'Amiri',
                      height: 1.6,
                    ),
                    textDirection: TextDirection.rtl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Arrow indicator
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: tc.textSecondary.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }
}
