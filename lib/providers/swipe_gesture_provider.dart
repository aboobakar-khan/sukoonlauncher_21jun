import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/hive_box_manager.dart';

/// Actions that can be assigned to swipe gestures on the home screen.
enum SwipeAction {
  notifications('Notification Panel', 'Pull down system notifications', Icons.notifications_outlined),
  quickAccess('Quick Access', 'Samsung-style search & app grid', Icons.search_rounded),
  openApp('Open App', 'Launch a specific app', Icons.launch_rounded),
  none('Do Nothing', 'Disable this gesture', Icons.do_not_disturb_alt_rounded);

  final String label;
  final String description;
  final IconData icon;
  const SwipeAction(this.label, this.description, this.icon);
}

/// State for both swipe up and swipe down actions.
class SwipeGestureState {
  final SwipeAction swipeDown;
  final SwipeAction swipeUp;
  final String? swipeDownApp; // package name for openApp
  final String? swipeUpApp;   // package name for openApp

  const SwipeGestureState({
    this.swipeDown = SwipeAction.notifications,
    this.swipeUp = SwipeAction.quickAccess,
    this.swipeDownApp,
    this.swipeUpApp,
  });

  SwipeGestureState copyWith({
    SwipeAction? swipeDown,
    SwipeAction? swipeUp,
    String? swipeDownApp,
    String? swipeUpApp,
  }) {
    return SwipeGestureState(
      swipeDown: swipeDown ?? this.swipeDown,
      swipeUp: swipeUp ?? this.swipeUp,
      swipeDownApp: swipeDownApp ?? this.swipeDownApp,
      swipeUpApp: swipeUpApp ?? this.swipeUpApp,
    );
  }
}

class SwipeGestureNotifier extends StateNotifier<SwipeGestureState> {
  SwipeGestureNotifier() : super(const SwipeGestureState()) {
    _init();
  }

  static const _boxName = 'settings';
  static const _keyDown = 'swipe_down_action';
  static const _keyUp = 'swipe_up_action';
  static const _keyDownApp = 'swipe_down_app';
  static const _keyUpApp = 'swipe_up_app';
  Box? _box;

  Future<void> _init() async {
    try {
      _box = await HiveBoxManager.get(_boxName);
      final downStr = _box?.get(_keyDown, defaultValue: SwipeAction.notifications.name) as String?;
      final upStr = _box?.get(_keyUp, defaultValue: SwipeAction.quickAccess.name) as String?;
      final downApp = _box?.get(_keyDownApp) as String?;
      final upApp = _box?.get(_keyUpApp) as String?;
      state = SwipeGestureState(
        swipeDown: SwipeAction.values.firstWhere(
          (a) => a.name == downStr,
          orElse: () => SwipeAction.notifications,
        ),
        swipeUp: SwipeAction.values.firstWhere(
          (a) => a.name == upStr,
          orElse: () => SwipeAction.quickAccess,
        ),
        swipeDownApp: downApp,
        swipeUpApp: upApp,
      );
    } catch (e) {
      // Use defaults on error
      state = const SwipeGestureState();
    }
  }

  Future<void> setSwipeDown(SwipeAction action, {String? appPackage}) async {
    state = state.copyWith(swipeDown: action, swipeDownApp: appPackage);
    _box ??= await HiveBoxManager.get(_boxName);
    await _box?.put(_keyDown, action.name);
    if (appPackage != null) await _box?.put(_keyDownApp, appPackage);
  }

  Future<void> setSwipeUp(SwipeAction action, {String? appPackage}) async {
    state = state.copyWith(swipeUp: action, swipeUpApp: appPackage);
    _box ??= await HiveBoxManager.get(_boxName);
    await _box?.put(_keyUp, action.name);
    if (appPackage != null) await _box?.put(_keyUpApp, appPackage);
  }
}

final swipeGestureProvider =
    StateNotifierProvider<SwipeGestureNotifier, SwipeGestureState>(
        (ref) => SwipeGestureNotifier());
