import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/favorite_app.dart';
import '../utils/hive_box_manager.dart';

/// Provider for favorite apps stored permanently with app name
/// No cache, no expiration - instant minimalist performance
class FavoriteAppsNotifier extends StateNotifier<List<FavoriteApp>> {
  FavoriteAppsNotifier() : super([]) {
    _loadFavorites();
  }

  Box<FavoriteApp>? _box;

  Future<void> _loadFavorites() async {
    _box ??= await HiveBoxManager.get<FavoriteApp>('favorite_apps_v2');
    state = _box!.values.toList()
      ..sort((a, b) => a.addedAt.compareTo(b.addedAt));
  }

  Future<bool> toggleFavorite(String packageName, String appName) async {
    _box ??= await HiveBoxManager.get<FavoriteApp>('favorite_apps_v2');

    final existingIndex = state.indexWhere(
      (app) => app.packageName == packageName,
    );

    if (existingIndex != -1) {
      // Remove from favorites
      await _box!.deleteAt(existingIndex);
      state = state.where((app) => app.packageName != packageName).toList();
      return true;
    } else {
      // Check if already at maximum limit (7 apps)
      if (state.length >= 7) {
        return false; // Deny adding more than 7 favorites
      }

      // Add to favorites with app name stored permanently
      final favoriteApp = FavoriteApp(
        packageName: packageName,
        appName: appName,
      );
      await _box!.add(favoriteApp);
      state = [...state, favoriteApp];
      return true;
    }
  }

  bool isFavorite(String packageName) {
    return state.any((app) => app.packageName == packageName);
  }

  /// Get favorite app names for instant display - no API calls needed
  List<String> getFavoritePackages() {
    return state.map((app) => app.packageName).toList();
  }
}

final favoriteAppsProvider =
    StateNotifierProvider<FavoriteAppsNotifier, List<FavoriteApp>>(
      (ref) => FavoriteAppsNotifier(),
    );
