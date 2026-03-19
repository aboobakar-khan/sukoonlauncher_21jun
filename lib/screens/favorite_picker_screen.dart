import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/favorite_apps_provider.dart';
import '../providers/installed_apps_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/swipe_back_wrapper.dart';

/// Favorite Picker Screen — Select up to 7 favorite apps
class FavoritePickerScreen extends ConsumerStatefulWidget {
  const FavoritePickerScreen({super.key});

  @override
  ConsumerState<FavoritePickerScreen> createState() => _FavoritePickerScreenState();
}

class _FavoritePickerScreenState extends ConsumerState<FavoritePickerScreen> {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  static const Color _sandGold = Color(0xFFC2A366);
  static const Color _warmBrown = Color(0xFFA67B5B);
  static const Color _desertSunset = Color(0xFFE8915A);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final isLight = themeColor.isLight;
    final bgColor = isLight ? const Color(0xFFF5F5F5) : Colors.black;
    final primaryText = isLight ? const Color(0xFF0D0D0D) : Colors.white;
    final allApps = ref.watch(installedAppsProvider);
    final favorites = ref.watch(favoriteAppsProvider);
    final favPackages = favorites.map((f) => f.packageName).toSet();
    final favCount = favorites.length;

    // Filter apps by search
    final filteredApps = _searchQuery.isEmpty
        ? allApps
        : allApps
            .where((app) =>
                app.appName.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return SwipeBackWrapper(
      child: Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: themeColor.color, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Favorites',
              style: TextStyle(
                color: primaryText.withValues(alpha: 0.9),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$favCount / 10 selected',
              style: TextStyle(
                color: favCount >= 10
                    ? _desertSunset.withValues(alpha: 0.8)
                    : _sandGold.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _sandGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(color: _sandGold, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            height: 3,
            decoration: BoxDecoration(
              color: primaryText.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (favCount / 10).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_sandGold, favCount >= 10 ? _desertSunset : _warmBrown],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(
                color: themeColor.color.withValues(alpha: 0.9),
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Search apps...',
                hintStyle: TextStyle(color: primaryText.withValues(alpha: 0.25)),
                filled: true,
                fillColor: primaryText.withValues(alpha: 0.06),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.search_rounded, color: primaryText.withValues(alpha: 0.3), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: primaryText.withValues(alpha: 0.4), size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // App list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredApps.length,
              itemBuilder: (context, index) {
                final app = filteredApps[index];
                final isFav = favPackages.contains(app.packageName);
                final isMaxReached = favCount >= 10 && !isFav;

                return GestureDetector(
                  onTap: () async {
                    if (isMaxReached) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Max 10 apps reached — remove one first'),
                          backgroundColor: _desertSunset,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    HapticFeedback.selectionClick();
                    await ref
                        .read(favoriteAppsProvider.notifier)
                        .toggleFavorite(app.packageName, app.appName);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isFav
                          ? _sandGold.withValues(alpha: 0.06)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        // App name
                        Expanded(
                          child: Text(
                            app.appName,
                            style: TextStyle(
                              color: isFav
                                  ? primaryText.withValues(alpha: 0.95)
                                  : isMaxReached
                                      ? primaryText.withValues(alpha: 0.25)
                                      : primaryText.withValues(alpha: 0.7),
                              fontSize: 15,
                              fontWeight: isFav ? FontWeight.w500 : FontWeight.w300,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        // Checkbox
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            color: isFav
                                ? _sandGold.withValues(alpha: 0.2)
                                : primaryText.withValues(alpha: 0.06),
                            border: Border.all(
                              color: isFav
                                  ? _sandGold.withValues(alpha: 0.5)
                                  : primaryText.withValues(alpha: 0.12),
                              width: 1.5,
                            ),
                          ),
                          child: isFav
                              ? const Icon(Icons.check_rounded, color: _sandGold, size: 16)
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
    );
  }
}
