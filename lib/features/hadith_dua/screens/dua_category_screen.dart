import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hadith_dua_provider.dart';
import '../../../providers/islamic_theme_provider.dart';
import 'dua_list_screen.dart';

/// Category model for organized dua categories
class DuaCategory {
  final String id;
  final String name;
  final IconData icon;
  final String description;

  const DuaCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
  });
}

/// Main category screen - Clean card-based navigation
class DuaCategoryScreen extends ConsumerWidget {
  const DuaCategoryScreen({super.key});

  static const List<DuaCategory> categories = [
    DuaCategory(
      id: 'Morning & Evening',
      name: 'Morning & Evening',
      icon: Icons.wb_sunny_outlined,
      description: 'Daily morning and evening remembrance',
    ),
    DuaCategory(
      id: 'Protection',
      name: 'Protection',
      icon: Icons.shield_outlined,
      description: 'Seeking Allah\'s protection',
    ),
    DuaCategory(
      id: 'After Salah',
      name: 'After Salah',
      icon: Icons.mosque_outlined,
      description: 'Supplications after prayer',
    ),
    DuaCategory(
      id: 'Ramadan',
      name: 'Ramadan',
      icon: Icons.nightlight_outlined,
      description: 'Fasting, Suhoor, Iftar, Laylatul Qadr',
    ),
    DuaCategory(
      id: 'Darood & Salawat',
      name: 'Darood & Salawat',
      icon: Icons.favorite_outline,
      description: 'Blessings upon Prophet Muhammad ﷺ',
    ),
    DuaCategory(
      id: 'General',
      name: 'General',
      icon: Icons.auto_awesome_outlined,
      description: 'Other beneficial supplications',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = ref.watch(islamicThemeColorsProvider);
    final allDuas = ref.watch(allDuasProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(tc, allDuas.length),
            Expanded(
              child: _buildCategoryGrid(context, tc, allDuas),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(IslamicThemeColors tc, int totalCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tc.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.favorite_outline,
                  color: tc.green.withValues(alpha: 0.7),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duas & Adhkar',
                      style: TextStyle(
                        color: tc.text.withValues(alpha: 0.9),
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Supplications from Quran & Sunnah',
                      style: TextStyle(
                        color: tc.textSecondary.withValues(alpha: 0.45),
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: tc.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: tc.green.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$totalCount',
                  style: TextStyle(
                    color: tc.green.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Select a category',
            style: TextStyle(
              color: tc.textSecondary.withValues(alpha: 0.35),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(BuildContext context, IslamicThemeColors tc, List<dynamic> allDuas) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      physics: const ClampingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.88,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final count = _getCountForCategory(category.id, allDuas);
        return _CategoryCard(
          category: category,
          count: count,
          tc: tc,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DuaListScreen(
                  categoryId: category.id,
                  categoryName: category.name,
                  categoryIcon: category.icon,
                ),
              ),
            );
          },
        );
      },
    );
  }

  int _getCountForCategory(String categoryId, List<dynamic> allDuas) {
    if (categoryId == 'General') {
      // Include all categories that don't match specific ones
      final specificCategories = categories
          .where((c) => c.id != 'General')
          .map((c) => c.id)
          .toList();
      return allDuas.where((d) {
        final cat = d.category ?? '';
        return !specificCategories.any((sc) => cat.contains(sc));
      }).length;
    }
    
    return allDuas.where((d) {
      final cat = d.category ?? '';
      return cat.contains(categoryId);
    }).length;
  }
}

/// Category Card Widget
class _CategoryCard extends StatelessWidget {
  final DuaCategory category;
  final int count;
  final IslamicThemeColors tc;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.count,
    required this.tc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tc.surface.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: tc.surface.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            // Icon container
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: tc.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                category.icon,
                size: 32,
                color: tc.green.withValues(alpha: 0.65),
              ),
            ),
            const Spacer(flex: 2),
            // Title
            Text(
              category.name,
              style: TextStyle(
                color: tc.text.withValues(alpha: 0.85),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                category.description,
                style: TextStyle(
                  color: tc.textSecondary.withValues(alpha: 0.4),
                  fontSize: 10,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(flex: 1),
            // Count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tc.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count duas',
                style: TextStyle(
                  color: tc.green.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}
