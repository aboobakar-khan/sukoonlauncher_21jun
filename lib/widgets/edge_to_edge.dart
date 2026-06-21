import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Builds the transparent, edge-to-edge system-bar style.
///
/// Both the status bar and navigation bar are transparent so the app's dark
/// background extends fully behind them for a seamless look. [iconBrightness]
/// controls the status/nav icon colour — use [Brightness.light] over dark
/// surfaces (the app's default) and [Brightness.dark] over light surfaces.
SystemUiOverlayStyle edgeToEdgeOverlayStyle({
  Brightness iconBrightness = Brightness.light,
}) {
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: iconBrightness,
    // iOS uses the inverse semantic — brightness of the bar *background*.
    statusBarBrightness:
        iconBrightness == Brightness.light ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: iconBrightness,
  );
}

/// Shared edge-to-edge content wrapper.
///
/// Reasserts the transparent system-bar style for the wrapped route and insets
/// its [child] with a [SafeArea] so real content never collides with the status
/// bar (clock, battery, signal) or the bottom gesture pill — while the dark
/// background behind it still extends fully edge-to-edge.
///
/// Use this instead of a bare [SafeArea] so every screen shares one consistent
/// system-UI treatment. The individual [SafeArea] edges are configurable for
/// screens that manage part of their own insets (e.g. a scroll view that pads
/// its own bottom, or a header that already adds `MediaQuery.padding.top`).
class EdgeToEdge extends StatelessWidget {
  final Widget child;
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;
  final Brightness iconBrightness;

  const EdgeToEdge({
    super.key,
    required this.child,
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
    this.iconBrightness = Brightness.light,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: edgeToEdgeOverlayStyle(iconBrightness: iconBrightness),
      child: SafeArea(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: child,
      ),
    );
  }
}
