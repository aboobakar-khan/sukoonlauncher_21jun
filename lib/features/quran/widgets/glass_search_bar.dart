import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../providers/islamic_theme_provider.dart';

/// Frosted-glass search bar shared between the Quran home (tap-to-open) and the
/// search screen (live field). Both wrap it in a [Hero] with the same tag, so
/// tapping it on the home morphs smoothly into the search screen — an iOS-style
/// expanding-search feel. A neutral static shuttle is used during the flight to
/// avoid building a focused TextField inside the overlay.
class GlassSearchBar extends StatelessWidget {
  static const heroTag = 'quran-glass-search';

  final IslamicThemeColors tc;
  final bool editable;
  final String hint;
  final bool focused;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool showClear;

  const GlassSearchBar({
    super.key,
    required this.tc,
    this.editable = false,
    this.hint = 'Search surah name or 2:188',
    this.focused = false,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onClear,
    this.showClear = false,
  });

  BoxDecoration _decoration() => BoxDecoration(
        color: tc.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: focused
              ? tc.green.withValues(alpha: 0.55)
              : tc.border.withValues(alpha: 0.7),
          width: focused ? 1.4 : 1,
        ),
      );

  Widget _glass({required Widget child}) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: _decoration(),
            child: child,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final iconColor = focused
        ? tc.green.withValues(alpha: 0.8)
        : tc.textSecondary.withValues(alpha: 0.45);

    final Widget field = editable
        ? TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction: TextInputAction.search,
            cursorColor: tc.green,
            style: TextStyle(
                color: tc.text.withValues(alpha: 0.9),
                fontSize: 16,
                fontWeight: FontWeight.w400),
            decoration: InputDecoration(
              isCollapsed: true,
              hintText: hint,
              hintStyle: TextStyle(
                  color: tc.textSecondary.withValues(alpha: 0.4),
                  fontSize: 16,
                  fontWeight: FontWeight.w400),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          )
        : Text(
            hint,
            style: TextStyle(
                color: tc.textSecondary.withValues(alpha: 0.45),
                fontSize: 16,
                fontWeight: FontWeight.w400),
          );

    final content = Row(
      children: [
        Icon(Icons.search_rounded, size: 20, color: iconColor),
        const SizedBox(width: 12),
        Expanded(child: field),
        if (showClear)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClear,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.close_rounded,
                  size: 18, color: tc.textSecondary.withValues(alpha: 0.5)),
            ),
          ),
      ],
    );

    final bar = Material(
      type: MaterialType.transparency,
      child: editable
          ? _glass(child: content)
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: _glass(child: content),
            ),
    );

    return Hero(
      tag: heroTag,
      // Neutral, non-blurred placeholder while the bar is flying between screens.
      flightShuttleBuilder: (_, __, ___, ____, _____) => Material(
        type: MaterialType.transparency,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: _decoration(),
          alignment: Alignment.centerLeft,
          child: Row(children: [
            Icon(Icons.search_rounded,
                size: 20, color: tc.textSecondary.withValues(alpha: 0.45)),
          ]),
        ),
      ),
      child: bar,
    );
  }
}

/// iOS-style fade+scale route used to open the search screen so the Hero bar
/// glides while the rest of the content cross-fades in.
class SearchFadeRoute<T> extends PageRouteBuilder<T> {
  SearchFadeRoute({required Widget page})
      : super(
          opaque: false,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
                parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: child,
            );
          },
        );
}
