import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../utils/hive_box_manager.dart';

/// Page Indicator Provider
/// Controls whether the 6-dot page indicator is shown at the top
/// of every non-home page. Defaults to ON.

final pageIndicatorProvider = StateNotifierProvider<PageIndicatorNotifier, bool>(
  (ref) => PageIndicatorNotifier(),
);

class PageIndicatorNotifier extends StateNotifier<bool> {
  PageIndicatorNotifier() : super(true) {
    _load();
  }

  static const _boxName = 'settingsBox';
  static const _key = 'showPageIndicator';
  Box? _box;

  Future<void> _load() async {
    _box = await HiveBoxManager.get(_boxName);
    state = _box!.get(_key, defaultValue: true) as bool;
  }

  Future<void> toggle() async {
    state = !state;
    _box ??= await HiveBoxManager.get(_boxName);
    _box!.put(_key, state);
  }

  Future<void> set(bool value) async {
    state = value;
    _box ??= await HiveBoxManager.get(_boxName);
    _box!.put(_key, value);
  }
}
