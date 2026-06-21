import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final fridaySunnahProvider = StateNotifierProvider<FridaySunnahNotifier, Map<String, bool>>((ref) {
  return FridaySunnahNotifier();
});

class FridaySunnahNotifier extends StateNotifier<Map<String, bool>> {
  FridaySunnahNotifier() : super({}) {
    _load();
  }

  void _load() {
    final box = Hive.box('settings');
    final Map<dynamic, dynamic>? data = box.get('friday_sunnah_ticks');
    if (data != null) {
      state = Map<String, bool>.from(data);
    }
  }

  void toggleSunnah(String dateKey, String sunnahId) {
    final key = '${dateKey}_$sunnahId';
    final current = state[key] ?? false;
    final newState = {...state, key: !current};
    state = newState;
    Hive.box('settings').put('friday_sunnah_ticks', newState);
  }

  bool isCompleted(String dateKey, String sunnahId) {
    return state['${dateKey}_$sunnahId'] ?? false;
  }
}
