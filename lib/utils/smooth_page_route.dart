import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Apple-style page route with smooth iOS slide transitions.
///
/// Forward: new page slides in from the right while the old page slides left.
/// Back:    reversed slide — feels identical to iOS native swipe-back.
///
/// Uses [CupertinoPageRoute] under the hood so the interactive
/// edge-swipe-back gesture works automatically on both iOS and Android.
///
/// All navigation in the app should use this instead of [MaterialPageRoute]
/// or raw [PageRouteBuilder] so every transition is consistent and smooth.
class SmoothForwardRoute<T> extends CupertinoPageRoute<T> {
  SmoothForwardRoute({required Widget child, super.settings})
      : super(builder: (_) => child);

  /// True when the OS "reduce motion" accessibility setting is enabled.
  ///
  /// Read from the live navigator context (available once the route is pushed)
  /// so navigation collapses to a near-instant cut for motion-sensitive users
  /// instead of sliding. 1ms (not zero) keeps the route lifecycle intact.
  bool get _reducedMotion {
    final ctx = navigator?.context;
    if (ctx == null) return false;
    return MediaQuery.maybeOf(ctx)?.disableAnimations ?? false;
  }

  // Slightly faster than default Cupertino (400ms) for a snappier feel.
  @override
  Duration get transitionDuration => _reducedMotion
      ? const Duration(milliseconds: 1)
      : const Duration(milliseconds: 350);

  @override
  Duration get reverseTransitionDuration => _reducedMotion
      ? const Duration(milliseconds: 1)
      : const Duration(milliseconds: 300);
}
