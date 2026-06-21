# Requirements Document

## Introduction

This document defines the requirements for the Calm Watch UX Redesign — a set of targeted improvements to the existing Calm Watch feature in the Sukoon Launcher (v1.2.2+36). Calm Watch is a distraction-free Islamic media player embedded as a page in the launcher's PageView. The redesign addresses six specific UX problems: raw URL/ID display in video tiles, abrupt inline player appearance, incorrect 16:9 aspect ratio enforcement, weak category card visual hierarchy, a non-premium player overlay experience, and the "Work and Play" category distinction lacking clarity. No new dependencies are introduced; all changes use packages already present in pubspec.yaml.

## Glossary

- **CalmWatch_Screen**: The main `CalmWatchScreen` widget (`calm_watch_screen.dart`) that hosts the inline player, curated section, and saved/watched lists.
- **Inline_Player**: The `YoutubePlayerBuilder`/`YoutubePlayerController`-based player card that appears inside the `CustomScrollView` when a video is selected.
- **Player_Card**: The `SliverToBoxAdapter` container that wraps the `Inline_Player` within the `CalmWatch_Screen`.
- **Video_Tile**: The `_VideoTile` widget that represents a single saved or watched item in the Watch Later / Watched lists.
- **Curated_Card**: The `_VideoCard` widget inside `CuratedSection` that represents a single curated video or playlist.
- **Curated_Section**: The `CuratedSection` widget (`curated_section.dart`) that renders the horizontal-scroll category rows.
- **Category_Block**: The `_CategoryBlock` widget that renders one category label row plus its horizontal `ListView` of `Curated_Card`s.
- **oEmbed_Service**: YouTube's public oEmbed endpoint (`https://www.youtube.com/oembed`) used to resolve video titles without an API key.
- **Title_Resolver**: The title-fetching logic inside `CalmWatchNotifier.addFromUrl()` in `calm_watch_provider.dart`.
- **Fallback_Title**: The video ID extracted from the submitted URL, used as a last-resort display string when the oEmbed_Service returns an empty title.
- **Player_Controller**: The `YoutubePlayerController` instance (`_playerController`) held in `_CalmWatchScreenState`.
- **Page_Visibility**: The boolean `_isVisible` flag in `_CalmWatchScreenState` that tracks whether CalmWatch is the active launcher page.
- **Accent_Color**: The theme color sourced from `themeColorProvider`, used as the primary accent throughout the UI.
- **Work_Category**: Curated Islamic content categories (Tafseer, Seerah, Recitation, Reminders, Motivation, Dua & Dhikr) pre-seeded in `kCuratedCategories`.
- **Play_Category**: User-saved personal videos and playlists stored in the Hive `calm_watch_items` box.
- **Section_Divider**: The visual separator between the Work_Category section and the Play_Category section on the CalmWatch_Screen.
- **Pause_Source**: A state variable tracking whether the Player_Controller was paused by page navigation (value: `nav`) or by the user manually (value: `user`), used to determine resume eligibility.

---

## Requirements

### Requirement 1: Reliable Title Resolution Before Display

**User Story:** As a user, I want every video tile to show a real title instead of a raw YouTube ID or URL, so that my Watch Later list is readable and meaningful.

#### Acceptance Criteria

1. WHEN a user submits a YouTube URL via the add sheet, THE Title_Resolver SHALL attempt to fetch the video title from the oEmbed_Service before saving the item to Hive.
2. WHILE the oEmbed_Service request is in progress, THE CalmWatch_Screen SHALL display a loading indicator in place of the title text within the add sheet.
3. IF the oEmbed_Service returns a non-200 status code or times out after 8 seconds, THEN THE Title_Resolver SHALL reject the submission, discard the item without saving it to Hive, and return an error message to the add sheet indicating that the video could not be verified.
4. IF the oEmbed_Service returns a title that is an empty string, THEN THE Title_Resolver SHALL use the Fallback_Title (the video ID extracted from the submitted URL) as the stored title instead of the empty string.
5. WHEN a saved item has a Fallback_Title, THE Video_Tile SHALL display a retry icon button that, when tapped, re-attempts title resolution from the oEmbed_Service with an 8-second timeout; IF the retry succeeds, THE Video_Tile SHALL update the stored title and hide the retry icon; IF the retry fails or times out, THE Video_Tile SHALL keep the retry icon visible and display an inline error message below the title.
6. THE Video_Tile SHALL never display a string matching the pattern `"Video • [a-zA-Z0-9_-]{11}"` or `"Playlist • [a-zA-Z0-9_-]+"` to the user.

---

### Requirement 2: Smooth Inline Player Appearance Animation

**User Story:** As a user, I want the inline player to animate smoothly into view when I tap a video, so that the transition feels premium and intentional rather than jarring.

#### Acceptance Criteria

1. WHEN the `Player_Controller` transitions from null to a non-null value, THE Player_Card SHALL animate its height from 0 to its natural height using an `AnimatedSize` widget with a duration of 350 milliseconds and a `Curves.easeOutCubic` curve.
2. WHEN the `Player_Controller` transitions from a non-null value back to null (player closed), THE Player_Card SHALL animate its height from its natural height back to 0 using the same `AnimatedSize` widget and curve before being removed from the widget tree.
3. WHEN the Player_Card height animation is in progress, THE vertical position of any `SliverList` item below the Player_Card SHALL NOT shift by more than 2 logical pixels per frame relative to its final settled position.
4. THE CalmWatch_Screen SHALL remain scrollable and interactive at all times, regardless of whether a Player_Card height animation is in progress or not.
5. WHEN a different video is selected while the Player_Card is already visible, THE Player_Card height SHALL remain unchanged in the same animation frame that the new Player_Controller is assigned — only the player content inside SHALL update.

---

### Requirement 3: Correct 16:9 Aspect Ratio for the Inline Player

**User Story:** As a user, I want the inline player to always display at the correct 16:9 aspect ratio regardless of my device's screen width, so that there is no letterboxing, cropping, or overflow.

#### Acceptance Criteria

1. THE Inline_Player height SHALL be derived from its rendered width using the formula `height = width × (9 / 16)`, not from a fixed pixel constant.
2. WHEN the device screen width changes (e.g. orientation change or split-screen), THE Inline_Player SHALL automatically recompute its height to maintain the 16:9 ratio without requiring a hot reload.
3. THE Inline_Player width SHALL equal the total width of the `CalmWatch_Screen` minus the sum of all horizontal padding values applied to the Player_Card and its ancestors.
4. IF the computed player height equals or exceeds 60% of the device screen height, THEN THE Inline_Player height SHALL be capped at exactly 60% of the device screen height.
5. WHEN the Inline_Player height is capped per criterion 4, THE video content SHALL fit within the capped height without cropping or letterboxing.
6. THE Inline_Player SHALL not overflow its parent container on any screen width between 320dp and 1280dp.

---

### Requirement 4: Authentic, Distraction-Free Player Overlay

**User Story:** As a user, I want the inline player to feel like a minimal, intentional YouTube experience — not a generic WebView embed — so that I can focus on the content without visual noise.

#### Acceptance Criteria

1. THE Inline_Player SHALL display the video title and a close button as an overlay above the player; these controls SHALL be visible by default and SHALL auto-hide after 3 seconds of no tap on the player surface.
2. WHILE the player is in an actively playing state, THE Inline_Player overlay SHALL show only: the video title (truncated to one line with ellipsis), a close/dismiss button, and a fullscreen button — no other controls or branding.
3. WHILE the player is in a paused state, THE Inline_Player overlay SHALL show the same controls as criterion 2 and SHALL remain visible without auto-hiding until the user taps elsewhere on the player surface.
4. WHILE the player is in a buffering or loading state, THE Inline_Player overlay SHALL hide all overlay controls (title, close button, and fullscreen button) and display only a centered loading indicator styled to match the app's dark theme (white circular progress indicator, no YouTube branding visible).
5. THE Inline_Player title overlay SHALL use a bottom-to-top gradient scrim (black at 70% opacity at the bottom edge, transitioning to transparent at the top edge) so the title text remains legible over any video thumbnail or frame.
6. WHEN the user taps the fullscreen button in the overlay, THE CalmWatch_Screen SHALL navigate to `CalmWatchPlayerScreen` passing the current `CalmWatchItem` and the current playback position in milliseconds.
7. THE Inline_Player overlay SHALL re-show all controls on a single tap anywhere on the player surface, and SHALL restart the 3-second auto-hide timer from that tap event.
8. WHEN the player has an error (e.g. video unavailable), THE Inline_Player SHALL replace the player surface with an error state showing the message "This video can't be played here", and an "Open in YouTube" button that, when tapped, opens the item's `originalUrl` in an external browser application.

---

### Requirement 5: Curated Category Cards — Visual Hierarchy and Interaction

**User Story:** As a user, I want the curated category cards to have clear visual hierarchy and smooth interaction feedback, so that I can quickly scan, understand, and tap into content without confusion.

#### Acceptance Criteria

1. THE Curated_Card SHALL display the video thumbnail at a 16:9 aspect ratio at the top of the card, with the title and channel name below in a dedicated text area that is visually separated from the thumbnail.
2. THE Curated_Card title text SHALL be limited to 2 lines maximum with ellipsis overflow, using a font size of at least 12sp and a line height of 1.35.
3. THE Curated_Card channel name SHALL be displayed on a single line below the title with ellipsis overflow, using the category's accent color at 75% opacity, with a leading dot indicator matching the category color.
4. WHEN a user presses a Curated_Card, THE Curated_Card SHALL scale down to 0.95 within a duration not exceeding 130 milliseconds using `Curves.easeOutCubic`; WHEN the press is released or cancelled, THE Curated_Card SHALL scale back to 1.0 using the same curve and duration.
5. THE Curated_Card SHALL have a minimum tappable area of 48×48dp as per Material accessibility guidelines.
6. WHEN a Curated_Card thumbnail fails to load, THE Curated_Card SHALL display a category-colored icon placeholder (playlist icon for playlists, play-circle icon for videos) centered on a background of black at 85% opacity — never a broken image widget.
7. WHILE a Curated_Card thumbnail is loading, THE Curated_Card SHALL display an animated shimmer placeholder that pulses between 3% and 8% white opacity at 900ms intervals.
8. THE Category_Block horizontal scroll list card width SHALL be calculated as `(availableScreenWidth / 2).clamp(180.0, 220.0)` logical pixels, where `availableScreenWidth` is the screen width minus any horizontal padding applied to the Category_Block.
9. THE Category_Block label row SHALL display: the category icon, the category label in font weight w600 uppercase, the sublabel in font weight w400, and the item count right-aligned — all on a single row without overflow on screens 320dp wide or wider.

---

### Requirement 6: Work and Play Section Distinction

**User Story:** As a user, I want a clear visual distinction between the curated Islamic content ("Work") and my personal saved videos ("Play"), so that I understand the purpose of each section at a glance.

#### Acceptance Criteria

1. THE CalmWatch_Screen SHALL display the curated categories under a section header labelled "CURATED FOR YOU" with a supporting subtitle "Handpicked Islamic content".
2. THE CalmWatch_Screen SHALL display the user's saved Watch Later list under a section header labelled "YOUR LIBRARY" with a supporting subtitle "Your personal saves".
3. THE Section_Divider between the curated section and the personal library section SHALL be a full-width horizontal rule at 0.5dp height with 6% white opacity, preceded by 24dp of vertical spacing.
4. WHERE the user has no saved items in the Watch Later list, THE CalmWatch_Screen SHALL display an empty-state message: "Nothing saved yet — tap Add to save a video for later" styled at 13sp, 30% white opacity.
5. WHERE the user has saved items but none match the active tag filter, THE CalmWatch_Screen SHALL display a filtered-empty-state message: "No videos match this filter" styled at 13sp, 30% white opacity, in place of the Watch Later list.
6. THE section header for "CURATED FOR YOU" SHALL use the Accent_Color as the left-border accent bar, and the section header for "YOUR LIBRARY" SHALL use white at 20% opacity as the left-border accent bar, visually distinguishing the two sections.
7. WHEN the user applies a tag filter chip, THE filter SHALL apply only to the "YOUR LIBRARY" section and SHALL NOT hide or filter the "CURATED FOR YOU" section.

---

### Requirement 7: Page Visibility — Player Pause and Resume Integrity

**User Story:** As a user, I want the inline player to pause automatically when I swipe away from Calm Watch and resume when I return, so that audio does not bleed into other launcher pages.

#### Acceptance Criteria

1. WHEN the launcher `PageController` page value moves beyond 0.5 (away from CalmWatch), THE Player_Controller SHALL pause playback and THE Pause_Source SHALL be set to `nav`.
2. WHEN the launcher `PageController` page value returns to below 0.5 (back to CalmWatch), THE Player_Controller SHALL resume playback only if Pause_Source equals `nav`; IF Pause_Source equals `user`, THE Player_Controller SHALL remain paused.
3. WHILE `Page_Visibility` is false, THE CalmWatch_Screen SHALL render a static `_PlayerPlaceholder` widget visually in front of the live `Inline_Player` WebView to eliminate GPU compositing overhead during page transitions; WHEN `Page_Visibility` returns to true, THE CalmWatch_Screen SHALL fade out the placeholder over 300 milliseconds before revealing the live player.
4. THE `_PlayerPlaceholder` SHALL display the video thumbnail, title, and a "Tap to resume" label, and SHALL have the same rendered dimensions as the `Inline_Player` so no layout shift occurs when switching between the two.
5. IF the `Player_Controller` is null when page visibility changes, THEN THE CalmWatch_Screen SHALL take no action and SHALL NOT throw an exception.

---

### Requirement 8: Player Aspect Ratio Preserved in Fullscreen Transition

**User Story:** As a user, I want the transition from inline player to fullscreen to be seamless, so that the video does not stutter, resize awkwardly, or lose its aspect ratio during the transition.

#### Acceptance Criteria

1. WHEN the user taps the fullscreen button, THE CalmWatch_Screen SHALL navigate to `CalmWatchPlayerScreen` passing the current `CalmWatchItem` and the current playback position in milliseconds; THE `CalmWatchPlayerScreen` SHALL begin playback from that position within 500 milliseconds of mounting.
2. THE `CalmWatchPlayerScreen` SHALL lock device orientation to landscape (`landscapeLeft` and `landscapeRight`) upon entry.
3. WHEN the user exits `CalmWatchPlayerScreen` via the back gesture or close button, THE device orientation SHALL be restored to portrait-only.
4. WHEN the user exits fullscreen, THE CalmWatch_Screen SHALL resume the inline player at the playback position the fullscreen player was at when dismissed, within a tolerance of 500 milliseconds.
5. THE fullscreen player in `CalmWatchPlayerScreen` SHALL fill 100% of the screen width and height in landscape orientation with no letterboxing or pillarboxing.
6. IF the device does not support landscape orientation (e.g. orientation lock is enabled by the user), THEN THE `CalmWatchPlayerScreen` SHALL display the player in portrait at 16:9 aspect ratio centered vertically on the screen.
