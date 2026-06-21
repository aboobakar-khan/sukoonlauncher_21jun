# Implementation Plan: Calm Watch UX Redesign

## Overview

Eight targeted improvements to the Calm Watch feature in Sukoon Launcher. Tasks are ordered so each builds on the previous: provider logic first, then player appearance, then overlay controls, then fullscreen handoff, then section visuals, then page-visibility integrity. No new dependencies are introduced.

---

## Tasks

- [x] 1. Fix title resolution in `CalmWatchNotifier` (provider layer)
  - [x] 1.1 Block save until oEmbed resolves — change `addFromUrl()` to `await` the oEmbed request before writing to Hive; remove the silent catch-and-continue pattern
    - Increase timeout from 5 s to 8 s per Requirement 1.3
    - If the response is non-200 or the request throws/times out, return an error string (`'Could not verify this video. Please try again.'`) and do **not** write to Hive
    - If the oEmbed title is an empty string, fall back to the video ID only (not the `"Video • {id}"` pattern) — store just the raw ID as the title
    - _Requirements: 1.1, 1.3, 1.4_
  - [x] 1.2 Add `retryTitle(String itemId)` method to `CalmWatchNotifier`
    - Re-fetch oEmbed with an 8-second timeout for the item matching `itemId`
    - On success: call `_updateItem` to persist the new title and update state
    - On failure: return an error string; leave stored title unchanged
    - _Requirements: 1.5_
  - [x] 1.3 Update `_VideoTile` in `calm_watch_screen.dart` to show retry affordance
    - Detect fallback pattern: title matches `RegExp(r'^[a-zA-Z0-9_-]{11}$')` for videos or is a raw playlist ID
    - When fallback detected: show a small `IconButton(icon: Icon(Icons.refresh_rounded))` trailing the title
    - On retry tap: call `ref.read(calmWatchProvider.notifier).retryTitle(item.id)`; show inline loading indicator while in-flight; on success hide the icon; on failure show a small red error label below the title
    - Ensure the tile never renders the string `"Video • {id}"` or `"Playlist • {id}"` — if such a string is found in stored data, display the raw ID portion only
    - _Requirements: 1.5, 1.6_

- [x] 2. Animated inline player appearance
  - [x] 2.1 Wrap the `SliverToBoxAdapter` that contains `_InlinePlayerCard` / `_PlayerPlaceholder` in an `AnimatedSize` widget
    - `duration: const Duration(milliseconds: 350)`, `curve: Curves.easeOutCubic`
    - `alignment: Alignment.topCenter` so the card grows downward
    - Keep the `ValueKey(_playingItem!.id)` on the inner child, not on the `AnimatedSize` wrapper, so switching videos does not re-trigger the height animation
    - _Requirements: 2.1, 2.5_
  - [x] 2.2 Ensure close animation completes before widget removal
    - Replace the direct `setState(() { _playerController = null; })` in `_stopInlinePlayer` with a two-step approach: first set a `_playerClosing` flag that renders an empty `SizedBox()` as the child (triggering the collapse animation), then remove the controller after the 350 ms animation completes via `Future.delayed`
    - _Requirements: 2.2_

- [x] 3. 16:9 aspect ratio enforcement for the inline player
  - [x] 3.1 Replace hardcoded `height: 210` in `_InlinePlayerCard` with `AspectRatio(aspectRatio: 16 / 9)`
    - Wrap the `AspectRatio` in a `LayoutBuilder` to read `constraints.maxWidth`
    - If `constraints.maxWidth * (9 / 16)` ≥ `MediaQuery.of(context).size.height * 0.6`, cap the height at 60% screen height using a `SizedBox(height: ...)` wrapper
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_
  - [x] 3.2 Apply the same `AspectRatio(aspectRatio: 16 / 9)` fix to `_PlayerPlaceholder`
    - Remove any fixed-height `Container` or `SizedBox` in the placeholder; use `AspectRatio` so placeholder and live player have identical rendered dimensions
    - _Requirements: 3.1, 7.4_
  - [x] 3.3 Fix card width formula in `curated_section.dart`
    - In `_CategoryBlock`, replace the hardcoded `height: 210` on the `SizedBox` wrapping the `ListView.builder` with a `LayoutBuilder`-derived height: `(availableWidth / 2).clamp(180.0, 220.0) * (9 / 16) + textAreaHeight`
    - Set `_VideoCard` width to `(availableWidth / 2).clamp(180.0, 220.0)` using a `LayoutBuilder` on the `SizedBox` parent
    - _Requirements: 5.8_

- [x] 4. Distraction-free player overlay in `_InlinePlayerCard`
  - [x] 4.1 Implement auto-hide overlay with `_controlsVisible` state and 3-second timer
    - Add `bool _controlsVisible = true` and `Timer? _hideTimer` to `_InlinePlayerCardState`
    - On mount: start the 3-second timer; on timer fire: `setState(() => _controlsVisible = false)`
    - On tap anywhere on the player surface: cancel existing timer, `setState(() => _controlsVisible = true)`, restart 3-second timer
    - Wrap all overlay widgets in `AnimatedOpacity(opacity: _controlsVisible ? 1.0 : 0.0, duration: Duration(milliseconds: 250))`
    - _Requirements: 4.1, 4.7_
  - [x] 4.2 Playing state overlay: title + close + fullscreen only
    - While `playerState == PlayerState.playing`: show title (1 line, ellipsis), close `IconButton`, and fullscreen `IconButton` — nothing else
    - Apply bottom-to-top gradient scrim: `LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.70)])` positioned at the bottom of the player
    - _Requirements: 4.2, 4.5_
  - [x] 4.3 Paused state overlay: same controls, no auto-hide
    - While `playerState == PlayerState.paused`: show same controls as playing state; cancel the auto-hide timer and do not restart it until the user taps
    - _Requirements: 4.3_
  - [x] 4.4 Buffering/loading state: hide all controls, show centered `CircularProgressIndicator`
    - While `playerState == PlayerState.buffering` or `!_playerStarted`: set `_controlsVisible = false` and cancel the hide timer; render a centered `CircularProgressIndicator(color: Colors.white, strokeWidth: 2)` over the player
    - _Requirements: 4.4_
  - [x] 4.5 Error state: replace player surface with inline error message
    - When `_controller.value.hasError`: replace the `YoutubePlayer` widget with a `Container` showing "This video can't be played here" (white 50% opacity, 14sp) and an "Open in YouTube" `TextButton` that calls `launchUrl(Uri.parse(item.originalUrl), mode: LaunchMode.externalApplication)`
    - _Requirements: 4.8_
  - [x] 4.6 Fullscreen button navigates to `CalmWatchPlayerScreen` with playback position
    - Read current position: `_controller.value.position.inMilliseconds`
    - Call `Navigator.of(context).push(...)` to `CalmWatchPlayerScreen`, passing `item` and `startPositionMs`
    - On return: receive the exit position from the route result and seek the inline controller to that position
    - _Requirements: 4.6, 8.1, 8.4_

- [x] 5. Curated category card visual hierarchy in `curated_section.dart`
  - [x] 5.1 Enforce 16:9 thumbnail `AspectRatio` and fix card width
    - The thumbnail `ClipRRect` already wraps an `AspectRatio(aspectRatio: 16/9)` — verify it is present and not overridden by a fixed height on the parent `SizedBox`
    - Set card `width` to `(MediaQuery.of(context).size.width / 2).clamp(180.0, 220.0)` — use `LayoutBuilder` on the `SizedBox` wrapping the `ListView.builder` to get `availableWidth`
    - _Requirements: 5.1, 5.8_
  - [x] 5.2 Title and channel text constraints
    - Title: `maxLines: 2`, `overflow: TextOverflow.ellipsis`, `fontSize: 12` (minimum), `height: 1.35`
    - Channel: `maxLines: 1`, `overflow: TextOverflow.ellipsis`, `color: cat.color.withValues(alpha: 0.75)`, leading dot `Container(width:4, height:4, decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle))`
    - _Requirements: 5.2, 5.3_
  - [x] 5.3 Press animation: scale 0.95 in 130 ms `easeOutCubic`, restore on release/cancel
    - The `_VideoCardState` already has `_pressed` + `AnimatedScale` — verify `curve: Curves.easeOutCubic` and `duration: const Duration(milliseconds: 130)` are set; add `onTapCancel` handler if missing
    - _Requirements: 5.4, 5.5_
  - [x] 5.4 Error placeholder: category icon on black 85% background
    - In the `errorBuilder` / `_thumbError` branch: render `Container(color: Colors.black.withValues(alpha: 0.85), child: Center(child: Icon(cat.icon, color: cat.color.withValues(alpha: 0.5), size: 32)))`
    - _Requirements: 5.6_
  - [x] 5.5 Shimmer: pulse 3%–8% white at 900 ms
    - The `_Shimmer` widget already implements this — verify `Tween(begin: 0.03, end: 0.08)` and `duration: Duration(milliseconds: 900)` are correct; no change needed if already correct
    - _Requirements: 5.7_
  - [x] 5.6 Category label row: icon + label (w600 uppercase) + sublabel (w400) + count right-aligned
    - The `_CategoryBlock` label row already has this structure — verify `fontWeight: FontWeight.w600` on the label and `fontWeight: FontWeight.w400` on the sublabel; ensure the row does not overflow on 320dp screens by wrapping the sublabel in `Flexible` with `overflow: TextOverflow.ellipsis`
    - _Requirements: 5.9_

- [x] 6. Work vs Play section distinction in `calm_watch_screen.dart`
  - [x] 6.1 Rename "Watch later" header to "YOUR LIBRARY" with subtitle
    - Replace the `Text('Watch later', ...)` widget with a `Column` containing:
      - `Text('YOUR LIBRARY', style: TextStyle(color: Colors.white.withValues(alpha: 0.22), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.4))`
      - `Text('Your personal saves', style: TextStyle(color: Colors.white.withValues(alpha: 0.18), fontSize: 11, fontWeight: FontWeight.w300))`
    - Add a white 20% opacity left-border bar (3dp wide, 16dp tall) before the text column, matching the existing accent bar pattern in `CuratedSection`
    - _Requirements: 6.2, 6.6_
  - [x] 6.2 Add subtitle to curated section header in `curated_section.dart`
    - Below the existing `'CURATED FOR YOU'` `Text` widget, add `Text('Handpicked Islamic content', style: TextStyle(color: Colors.white.withValues(alpha: 0.28), fontSize: 11, fontWeight: FontWeight.w300))`
    - The existing accent-colored left-border bar already uses `accent` color — no change needed there
    - _Requirements: 6.1, 6.6_
  - [x] 6.3 Add section divider between curated and library sections
    - In `calm_watch_screen.dart`, insert a `SliverToBoxAdapter` between the `CuratedSection` sliver and the "YOUR LIBRARY" header sliver:
      ```dart
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Container(height: 0.5, color: Colors.white.withValues(alpha: 0.06)),
        ),
      )
      ```
    - _Requirements: 6.3_
  - [x] 6.4 Update empty-state and filtered-empty-state messages
    - Replace `'Nothing saved yet.'` with `'Nothing saved yet — tap Add to save a video for later'` at 13sp, 30% white opacity
    - Add a second empty-state branch: when `all` (unfiltered) is non-empty but `filtered` (after tag filter) is empty, show `'No videos match this filter'` at 13sp, 30% white opacity
    - _Requirements: 6.4, 6.5_
  - [x] 6.5 Ensure tag filter applies only to YOUR LIBRARY, not curated section
    - Verify that `_activeTag` filtering is applied only to the `saved` and `completed` lists derived from `calmWatchProvider`, and that `CuratedSection` receives no filter prop — it should always render all categories
    - _Requirements: 6.7_

- [x] 7. Checkpoint — compile and smoke-test Tasks 1–6
  - Ensure all modified files compile without errors (`flutter analyze`). Fix any type errors or missing imports. Ask the user if any behaviour questions arise before proceeding.

- [x] 8. Page visibility pause/resume with `_pauseSource` tracking
  - [x] 8.1 Add `_PauseSource` enum and `_pauseSource` field to `_CalmWatchScreenState`
    - Define `enum _PauseSource { nav, user, none }` at file scope (or as a private top-level enum)
    - Replace the existing `bool _wasPausedByNav` field with `_PauseSource _pauseSource = _PauseSource.none`
    - _Requirements: 7.1, 7.2_
  - [x] 8.2 Update `_onShellPageChanged` to use `_pauseSource`
    - On leaving CalmWatch: if player is playing, pause it and set `_pauseSource = _PauseSource.nav`
    - On returning to CalmWatch: resume only if `_pauseSource == _PauseSource.nav`; if `_pauseSource == _PauseSource.user`, leave paused
    - After resuming, reset `_pauseSource = _PauseSource.none`
    - _Requirements: 7.1, 7.2_
  - [x] 8.3 Detect manual pause and set `_pauseSource = _PauseSource.user`
    - In `_onPlayerStateChange`, when `v.playerState == PlayerState.paused` and `_pauseSource == _PauseSource.none`, set `_pauseSource = _PauseSource.user`
    - When `v.playerState == PlayerState.playing`, reset `_pauseSource = _PauseSource.none`
    - _Requirements: 7.2_
  - [x] 8.4 Placeholder fade-out on return to visible
    - Wrap `_PlayerPlaceholder` in `AnimatedOpacity(opacity: _isVisible ? 0.0 : 1.0, duration: const Duration(milliseconds: 300))`
    - When `_isVisible` transitions back to `true`, the opacity animates from 1.0 → 0.0, revealing the live player beneath
    - _Requirements: 7.3_

- [x] 9. Fullscreen transition with playback position in `CalmWatchPlayerScreen`
  - [x] 9.1 Add `startPositionMs` parameter to `CalmWatchPlayerScreen`
    - Add `final int startPositionMs` field (default `0`) to the widget constructor
    - In `initState`, after controller creation, call `_controller.seekTo(Duration(milliseconds: widget.startPositionMs))` inside the `onReady` callback (or via a post-frame callback after `onReady` fires)
    - _Requirements: 8.1_
  - [x] 9.2 Lock orientation to landscape on entry, restore on exit
    - In `initState`: call `SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight])`
    - In `dispose`: call `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])` and restore `SystemUiMode.edgeToEdge`
    - _Requirements: 8.2, 8.3_
  - [x] 9.3 Return exit position to caller on pop
    - Replace `Navigator.of(context).pop()` calls (close button and back gesture) with `Navigator.of(context).pop(_controller.value.position.inMilliseconds)`
    - In `_InlinePlayerCard` (Task 4.6): after `await Navigator.push(...)`, receive the returned `int?` position and call `_controller.seekTo(Duration(milliseconds: returnedPosition ?? 0))`
    - _Requirements: 8.4_
  - [x] 9.4 Portrait fallback: 16:9 `AspectRatio` centered vertically
    - In the portrait branch of `CalmWatchPlayerScreen.build`, wrap the player in `Center(child: AspectRatio(aspectRatio: 16/9, child: _buildPlayer()))` instead of the current `Column(mainAxisAlignment: MainAxisAlignment.center, ...)`
    - _Requirements: 8.6_

- [x] 10. Final checkpoint — ensure all tests pass
  - Run `flutter analyze` and resolve any remaining warnings. Verify the inline player opens, animates, auto-hides controls, transitions to fullscreen, and returns position correctly. Ask the user if questions arise.

---

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Tasks 1–3 are independent and can be executed in parallel if desired; Tasks 4 and 9 have a dependency (9 requires the fullscreen button wired in 4.6)
- Task 7 (checkpoint) should be completed before Tasks 8–9 to catch compile errors early
- All changes are confined to the four files listed in the spec: `calm_watch_screen.dart`, `calm_watch_player_screen.dart`, `curated_section.dart`, and `calm_watch_provider.dart`
- No new packages are required; `dart:async` (for `Timer`) is already available
