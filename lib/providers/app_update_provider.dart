import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lightweight state for inline "Update available" indicator on home screen.
///
/// WHY a provider instead of widget props?
/// - HomeClockScreen is `const` inside a PageView  (changing it to non-const
///   would rebuild the entire page tree on every update check).
/// - A StateProvider lets only the tiny update label rebuild, zero cost.
class AppUpdateState {
  final bool updateAvailable;
  final bool updateReady; // downloaded, needs restart

  const AppUpdateState({
    this.updateAvailable = false,
    this.updateReady = false,
  });

  AppUpdateState copyWith({bool? updateAvailable, bool? updateReady}) {
    return AppUpdateState(
      updateAvailable: updateAvailable ?? this.updateAvailable,
      updateReady: updateReady ?? this.updateReady,
    );
  }
}

final appUpdateStateProvider =
    StateProvider<AppUpdateState>((_) => const AppUpdateState());
