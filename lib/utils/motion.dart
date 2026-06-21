import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ════════════════════════════════════════════════════════════════════════
/// MOTION & GESTURE TUNING — single source of truth
/// ════════════════════════════════════════════════════════════════════════
///
/// Centralises swipe thresholds, reduced-motion handling, and gesture haptics
/// so every swipe and transition in the app feels consistent and respects the
/// user's OS-level "reduce motion" accessibility setting.

/// Standardised swipe gesture thresholds.
///
/// Previously each swipe wrapper hard-coded its own velocity (-500 / -400 /
/// -300 / ±400 px/s), so the *same* flick felt responsive on one screen and
/// dead on another. Two clearly-defined, semantic tiers replace that:
///   • [commitVelocity] — a deliberate, confident flick. Used for full-screen
///     navigational swipes (back-to-home, page-turn) where an accidental
///     trigger is costly, so the bar is deliberately higher.
///   • [quickVelocity]  — a lighter flick. Used for edge / discovery swipes
///     where a low activation barrier improves discoverability.
class SwipeTuning {
  SwipeTuning._();

  /// px/s — a deliberate flick that should always commit the gesture.
  static const double commitVelocity = 450.0;

  /// px/s — a lighter flick for edge swipes where discoverability matters.
  static const double quickVelocity = 350.0;

  /// px — minimum travel for a distance-based (low-velocity) swipe to count.
  static const double minDistance = 50.0;

  /// Max off-axis drift as a fraction of on-axis travel for a gesture to still
  /// count as a clean directional swipe. Keeps diagonal drags from triggering.
  static const double directionRatio = 0.7;
}

/// Reduced-motion helpers.
///
/// The Flutter framework does NOT automatically collapse custom
/// [AnimationController]s or route transitions when the OS "reduce motion"
/// setting is on — each call site must opt in. These helpers make that a
/// one-liner so motion-sensitive users get a calm, near-instant experience.
class Motion {
  Motion._();

  /// Whether the user has enabled "reduce motion" in OS accessibility settings.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Collapse [full] to a near-instant duration when reduced motion is on.
  ///
  /// We use 1ms rather than [Duration.zero] so [AnimationController]s still
  /// run a tick and fire their status/listeners (avoids "stuck at 0" states).
  static Duration duration(BuildContext context, Duration full) =>
      reduced(context) ? const Duration(milliseconds: 1) : full;
}

/// Gesture haptics — thin, semantic wrappers over [HapticFeedback] so swipe
/// completions feel tactile and consistent everywhere. Centralising the intent
/// (not the raw impact level) means the whole app can be re-tuned in one place.
class GestureHaptics {
  GestureHaptics._();

  /// A committed navigational swipe (back, home, page-turn, drawer open).
  static void swipeCommit() => HapticFeedback.lightImpact();

  /// A discrete selection or toggle.
  static void select() => HapticFeedback.selectionClick();
}
