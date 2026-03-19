import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/hive_box_manager.dart';

/// ──────────────────────────────────────────────────────────
///  Calm Watch Enabled Provider
/// ──────────────────────────────────────────────────────────
/// Controls whether the Calm Watch page is visible in the
/// launcher PageView. Persisted in Hive 'settingsBox'.
/// ──────────────────────────────────────────────────────────

const _kKey = 'calm_watch_enabled';

final calmWatchEnabledProvider =
    StateNotifierProvider<CalmWatchEnabledNotifier, bool>((ref) {
  return CalmWatchEnabledNotifier();
});

class CalmWatchEnabledNotifier extends StateNotifier<bool> {
  CalmWatchEnabledNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final box = await HiveBoxManager.get('settingsBox');
    state = box.get(_kKey, defaultValue: true) as bool;
  }

  Future<void> toggle() async {
    state = !state;
    final box = await HiveBoxManager.get('settingsBox');
    await box.put(_kKey, state);
  }

  Future<void> set(bool value) async {
    state = value;
    final box = await HiveBoxManager.get('settingsBox');
    await box.put(_kKey, value);
  }
}
