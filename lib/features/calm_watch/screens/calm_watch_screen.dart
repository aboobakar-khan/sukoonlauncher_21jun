import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/calm_watch_item.dart';
import '../providers/calm_watch_provider.dart';
import 'calm_watch_player_screen.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/wallpaper_provider.dart';
import '../../../providers/amoled_provider.dart';
import '../../../providers/launcher_page_provider.dart';

class CalmWatchScreen extends ConsumerStatefulWidget {
  const CalmWatchScreen({super.key});

  /// Global key so LauncherShell can trigger inline playback from share intents.
  static final playItemKey = GlobalKey<_CalmWatchScreenState>();

  @override
  ConsumerState<CalmWatchScreen> createState() => _CalmWatchScreenState();
}

class _CalmWatchScreenState extends ConsumerState<CalmWatchScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// Public method for external callers (e.g. share intent handler)
  void playItem(CalmWatchItem item) => _playItemInline(item);

  // ── Filter ─────────────────────────────────────────────
  String? _activeTag;

  // ── Inline player ──────────────────────────────────────
  YoutubePlayerController? _playerController;
  CalmWatchItem? _playingItem;

  /// For playlists: the video ID currently playing inside the iframe.
  String? _currentPlaylistVideoId;
  /// For playlists: index reported by the player.
  int _currentPlaylistIndex = 0;

  bool _playerStarted = false;

  // ── Page visibility — pause player when off-screen ──
  PageController? _shellPageController;
  bool _isVisible = true;
  bool _wasPausedByNav = false;

  void _disposePlayer() {
    _playerController?.removeListener(_onPlayerStateChange);
    _playerController?.pause();
    _playerController?.dispose();
    _playerController = null;
    _playingItem = null;
    _playerStarted = false;
    _currentPlaylistVideoId = null;
    _currentPlaylistIndex = 0;
    _wasPausedByNav = false;
  }

  void _onPlayerStateChange() {
    if (_playerController == null) return;
    final v = _playerController!.value;
    if (!_playerStarted &&
        (v.playerState == PlayerState.playing ||
            v.playerState == PlayerState.buffering)) {
      if (mounted) setState(() => _playerStarted = true);
    }
    // Track which video inside a playlist is now active.
    if (_playingItem != null && _playingItem!.isPlaylist) {
      final vid = v.metaData.videoId;
      if (vid.isNotEmpty && vid != _currentPlaylistVideoId) {
        if (mounted) setState(() => _currentPlaylistVideoId = vid);
      }
    }
  }

  void _playItemInline(CalmWatchItem item) {
    // Same item — toggle pause/play
    if (_playingItem?.id == item.id && _playerController != null) {
      _playerController!.value.isPlaying
          ? _playerController!.pause()
          : _playerController!.play();
      return;
    }

    // Build new controller FIRST, then dispose old one, then setState once.
    final controller = YoutubePlayerController(
      // For playlists: use a valid placeholder ID so the player initialises
      // without Error Code 2 ("invalid parameter"). The onReady callback
      // immediately calls loadPlaylist() via JS to load the real playlist,
      // so this placeholder video is never actually shown to the user.
      initialVideoId: item.isPlaylist ? 'jNQXAC9IVRw' : item.youtubeId,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: false,
        loop: false,
        isLive: false,
        enableCaption: false,
        hideControls: false,
        hideThumbnail: false,
        forceHD: false,
        // For playlists, startMuted=false; video will be loaded via JS onReady
        startAt: 0,
      ),
    );
    controller.addListener(_onPlayerStateChange);

    // Tear down old (no setState yet)
    _playerController?.removeListener(_onPlayerStateChange);
    _playerController?.pause();
    _playerController?.dispose();

    _playerController = controller;
    _playingItem = item;
    _playerStarted = false;
    _currentPlaylistVideoId = null;
    _currentPlaylistIndex = 0;

    setState(() {});
  }

  void _stopInlinePlayer() {
    _disposePlayer();
    setState(() {});
  }

  @override
  void dispose() {
    _shellPageController?.removeListener(_onShellPageChanged);
    _disposePlayer();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Attach the page controller listener once it becomes available.
    if (_shellPageController == null) {
      final pc = ref.read(launcherPageControllerProvider);
      if (pc != null && pc.hasClients) {
        _shellPageController = pc;
        _shellPageController!.addListener(_onShellPageChanged);
      } else {
        // Retry after next frame (controller may not be attached yet)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final pc2 = ref.read(launcherPageControllerProvider);
          if (pc2 != null && _shellPageController == null) {
            _shellPageController = pc2;
            _shellPageController!.addListener(_onShellPageChanged);
          }
        });
      }
    }
  }

  /// Pause the YouTube player when the user swipes away from CalmWatch
  /// (page 0) to any other page. Resume when they return. This eliminates
  /// the navigation lag caused by the WebView rendering continuously
  /// in the background during page transitions.
  void _onShellPageChanged() {
    final page = _shellPageController?.page;
    if (page == null) return;

    final nowVisible = page < 0.5; // CalmWatch is page 0

    if (nowVisible && !_isVisible) {
      // Returned to CalmWatch — resume if we paused it
      _isVisible = true;
      if (_wasPausedByNav && _playerController != null) {
        _playerController!.play();
        _wasPausedByNav = false;
      }
    } else if (!nowVisible && _isVisible) {
      // Left CalmWatch — pause the player to free GPU/CPU
      _isVisible = false;
      if (_playerController != null && (_playerController!.value.isPlaying)) {
        _playerController!.pause();
        _wasPausedByNav = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final all = ref.watch(calmWatchProvider);
    final tags = ref.read(calmWatchProvider.notifier).existingTags;

    // Filter by active tag (null = show all)
    // Reset filter if the tag no longer exists (e.g. all items deleted)
    if (_activeTag != null && !tags.contains(_activeTag)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _activeTag = null);
      });
    }
    final filtered = _activeTag == null
        ? all
        : all.where((v) => v.tag == _activeTag).toList();

    final saved = filtered.where((v) => !v.isCompleted).toList();
    final completed = filtered.where((v) => v.isCompleted).toList();
    final topPad = MediaQuery.of(context).padding.top;

    // ── Theme integration ─────────────────────────────────
    final accent = ref.watch(themeColorProvider).color;
    // Determine if wallpaper is purely black-based (no image / gradient)
    final wallpaper = ref.watch(wallpaperProvider);
    final isAmoled = ref.watch(amoledProvider);
    final hasImageWallpaper = !isAmoled &&
        (wallpaperAssetPath(wallpaper) != null ||
            wallpaper == WallpaperType.customImage);
    // Over image wallpapers add a subtle scrim so text stays legible
    final scrimOpacity = hasImageWallpaper ? 0.55 : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Scrim over wallpaper for text legibility
          if (hasImageWallpaper)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: scrimOpacity),
                  ),
                ),
              ),
            ),
          CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Header + category chips ─────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, topPad + 16, 24, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Calm Watch',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 0.3,
                        ),
                      ),
                      GestureDetector(
                        onTap: _showAddSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            '+ Add',
                            style: TextStyle(
                              color: accent.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (tags.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: Row(
                        children: [
                          _CategoryChip(
                            label: 'All',
                            selected: _activeTag == null,
                            accent: accent,
                            onTap: () => setState(() => _activeTag = null),
                          ),
                          ...tags.map((t) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _CategoryChip(
                                label: t,
                                selected: _activeTag == t,
                                accent: accent,
                                onTap: () => setState(() => _activeTag = t),
                              ),
                            )),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Inline player (appears when user taps Watch)
          if (_playerController != null && _playingItem != null)
            SliverToBoxAdapter(
              key: ValueKey(_playingItem!.id),
              // When the page is not fully visible (mid-transition or on
              // another page), replace the heavy WebView player with a
              // lightweight static placeholder. This prevents the GPU from
              // compositing the platform view during swipe animations —
              // the root cause of the navigation lag.
              child: _isVisible
                  ? _InlinePlayerCard(
                      controller: _playerController!,
                      item: _playingItem!,
                      accent: accent,
                      currentVideoId: _currentPlaylistVideoId,
                      currentIndex: _currentPlaylistIndex,
                      onClose: _stopInlinePlayer,
                      onPlaylistVideoTap: (index) {
                        final wvc = _playerController?.value.webViewController;
                        if (wvc != null) {
                          wvc.evaluateJavascript(
                              source: 'player.playVideoAt($index);');
                          setState(() => _currentPlaylistIndex = index);
                        }
                      },
                      onReady: () {
                        if (_playingItem!.isPlaylist) {
                          final wvc = _playerController?.value.webViewController;
                          if (wvc != null) {
                            final listId = _playingItem!.youtubeId;
                            wvc.evaluateJavascript(
                                source:
                                    'player.loadPlaylist({listType:"playlist",list:"$listId",index:0,startSeconds:0});');
                          }
                        }
                      },
                    )
                  : _PlayerPlaceholder(
                      item: _playingItem!,
                      accent: accent,
                      onTap: () {
                        // User tapped placeholder while off-screen — navigate back
                        // and resume
                        if (_shellPageController?.hasClients == true) {
                          _shellPageController!.animateToPage(
                            0,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      },
                    ),
            ),

          // ── Saved section ────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
              child: Row(
                children: [
                  Text(
                    'Watch later',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.22),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.4,
                    ),
                  ),
                  if (saved.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${saved.length}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (saved.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: Text(
                  'Tap + Add to save a YouTube link.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.12),
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _VideoTile(
                    item: saved[i],
                    isPlaying: _playingItem?.id == saved[i].id,
                    onTap: () => _playItemInline(saved[i]),
                    onLongPress: () => _showItemSheet(saved[i], completed: false),
                  ),
                  childCount: saved.length,
                ),
              ),
            ),

          // ── Completed section ─────────────────────────────
          if (completed.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
                child: Row(
                  children: [
                    Text(
                      'Watched',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.22),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${completed.length}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _VideoTile(
                    item: completed[i],
                    isPlaying: _playingItem?.id == completed[i].id,
                    isCompleted: true,
                    onTap: () => _playItemInline(completed[i]),
                    onLongPress: () =>
                        _showItemSheet(completed[i], completed: true),
                  ),
                  childCount: completed.length,
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
        ],
      ),
    );
  }

  /// Fullscreen player fallback (retained for programmatic use).
  // ignore: unused_element
  void _openPlayer(CalmWatchItem item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CalmWatchPlayerScreen(
        item: item,
        onMarkCompleted: () => _showItemSheet(item, completed: false),
      ),
    ));
  }

  /// Long-press context sheet — all actions for a tile in one place.
  void _showItemSheet(CalmWatchItem item, {required bool completed}) {
    final accent = ref.read(themeColorProvider).color;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131313),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 56,
                        height: 32,
                        child: item.isPlaylist
                            ? Container(
                                color: Colors.white.withValues(alpha: 0.04),
                                child: Icon(Icons.playlist_play_rounded,
                                    color:
                                        Colors.white.withValues(alpha: 0.2),
                                    size: 18),
                              )
                            : Image.network(
                                item.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.white.withValues(alpha: 0.04),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF252525), height: 1),
              const SizedBox(height: 4),
              // Reflection block — shown for completed items that have one
              if (completed && item.reflection.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: accent.withValues(alpha: 0.12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded,
                                size: 13,
                                color: accent.withValues(alpha: 0.5)),
                            const SizedBox(width: 6),
                            Text(
                              'Your reflection',
                              style: TextStyle(
                                color: accent.withValues(alpha: 0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.reflection,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Divider(color: Color(0xFF252525), height: 1),
                const SizedBox(height: 4),
              ],
              // Play
              _SheetAction(
                icon: Icons.play_arrow_rounded,
                label: 'Play now',
                onTap: () {
                  Navigator.pop(ctx);
                  _playItemInline(item);
                },
              ),
              if (!completed)
                _SheetAction(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Mark as watched',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showReflectionSheet(item);
                  },
                ),
              if (completed)
                _SheetAction(
                  icon: Icons.replay_rounded,
                  label: 'Move back to Watch Later',
                  onTap: () {
                    Navigator.pop(ctx);
                    ref
                        .read(calmWatchProvider.notifier)
                        .markSaved(item.id);
                  },
                ),
              _SheetAction(
                icon: Icons.delete_outline_rounded,
                label: 'Remove',
                destructive: true,
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(calmWatchProvider.notifier).remove(item.id);
                },
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  void _showReflectionSheet(CalmWatchItem item) {
    final accent = ref.read(themeColorProvider).color;
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131313),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Reflection',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 17,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'What did you take away? (optional)',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Key insight, dua, or note…',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.15),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      ref
                          .read(calmWatchProvider.notifier)
                          .markCompleted(item.id);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Skip',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () {
                      ref
                          .read(calmWatchProvider.notifier)
                          .markCompleted(item.id,
                              reflection: ctrl.text.trim());
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text('Mark watched',
                          style: TextStyle(
                              color: accent.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131313),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddLinkSheet(
        existingTags: ref.read(calmWatchProvider.notifier).existingTags,
        onSave: (url, tag) async {
          final error = await ref
              .read(calmWatchProvider.notifier)
              .addFromUrl(url, tag: tag);
          if (!ctx.mounted) return;
          Navigator.pop(ctx);
          if (error != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(error),
              backgroundColor: const Color(0xFF1F1F1F),
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
      ),
    );
  }
}

// ─── Unified video tile ───────────────────────────────────────────────────────
/// Single tile used for both saved and completed items.
/// Tap = play. Long-press = context sheet with all actions.

class _VideoTile extends StatelessWidget {
  final CalmWatchItem item;
  final bool isPlaying;
  final bool isCompleted;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _VideoTile({
    required this.item,
    required this.onTap,
    required this.onLongPress,
    this.isPlaying = false,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleOpacity = isCompleted ? 0.35 : 0.82;
    final thumbOpacity = isCompleted ? 0.35 : 1.0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Thumbnail ─────────────────────────────────
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 120,
                    height: 68,
                    child: Opacity(
                      opacity: thumbOpacity,
                      child: item.isPlaylist
                          ? Container(
                              color: Colors.white.withValues(alpha: 0.04),
                              child: Icon(Icons.playlist_play_rounded,
                                  color: Colors.white.withValues(alpha: 0.2),
                                  size: 30),
                            )
                          : Image.network(
                              item.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.white.withValues(alpha: 0.04),
                                child: Icon(Icons.play_circle_outline_rounded,
                                    color: Colors.white.withValues(alpha: 0.15),
                                    size: 24),
                              ),
                            ),
                    ),
                  ),
                ),
                // Playing indicator
                if (isPlaying)
                  Container(
                    width: 120,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.graphic_eq_rounded,
                        color: Colors.white.withValues(alpha: 0.9), size: 22),
                  ),
                // Watched checkmark badge
                if (isCompleted && !isPlaying)
                  Positioned(
                    top: 5,
                    left: 5,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Icon(Icons.check_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 10),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 12),

            // ── Text ──────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: titleOpacity),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (item.isPlaylist)
                        Icon(Icons.queue_music_rounded,
                            size: 11,
                            color: Colors.white.withValues(alpha: 0.2)),
                      if (item.isPlaylist) const SizedBox(width: 3),
                      if (item.tag.isNotEmpty)
                        Text(
                          item.tag,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.22),
                            fontSize: 11,
                          ),
                        ),
                      if (item.reflection.isNotEmpty) ...[
                        if (item.tag.isNotEmpty)
                          Text(' · ',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  fontSize: 11)),
                        Expanded(
                          child: Text(
                            '"${item.reflection}"',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ── More indicator ────────────────────────────
            GestureDetector(
              onTap: onLongPress,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                child: Icon(Icons.more_vert_rounded,
                    color: Colors.white.withValues(alpha: 0.3), size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sheet action row ─────────────────────────────────────────────────────────

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Colors.redAccent.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.65);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 16),
            Text(label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                )),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  const _CategoryChip({
    required this.label,
    required this.onTap,
    required this.accent,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? accent.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.4),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─── Player Placeholder ──────────────────────────────────────────────────────
/// Lightweight static stand-in for the YouTube player WebView.
/// Rendered when the CalmWatch page is mid-transition or off-screen.
/// Prevents the platform WebView from being composited during swipe animations
/// — the single biggest source of page transition lag.

class _PlayerPlaceholder extends StatelessWidget {
  final CalmWatchItem item;
  final Color accent;
  final VoidCallback onTap;

  const _PlayerPlaceholder({
    required this.item,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 210,
            color: const Color(0xFF111111),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Thumbnail or playlist icon
                if (!item.isPlaylist)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.4,
                      child: Image.network(
                        item.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                // Play icon overlay
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white70,
                    size: 28,
                  ),
                ),
                // Title label at bottom
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                // Playlist badge
                if (item.isPlaylist)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.queue_music_rounded,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 13),
                          const SizedBox(width: 4),
                          Text(
                            'Playlist',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Inline Player Card ──────────────────────────────────────────────────────
/// Shows the YouTube player + (for playlists) a collapsible queue panel below.

class _InlinePlayerCard extends StatefulWidget {
  final YoutubePlayerController controller;
  final CalmWatchItem item;
  final Color accent;
  final String? currentVideoId;
  final int currentIndex;
  final VoidCallback onClose;
  final VoidCallback onReady;
  final void Function(int index) onPlaylistVideoTap;

  const _InlinePlayerCard({
    required this.controller,
    required this.item,
    required this.accent,
    required this.currentVideoId,
    required this.currentIndex,
    required this.onClose,
    required this.onReady,
    required this.onPlaylistVideoTap,
  });

  @override
  State<_InlinePlayerCard> createState() => _InlinePlayerCardState();
}

class _InlinePlayerCardState extends State<_InlinePlayerCard> {
  bool _queueExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isPlaylist = widget.item.isPlaylist;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Video player ────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: YoutubePlayerBuilder(
              player: YoutubePlayer(
                controller: widget.controller,
                showVideoProgressIndicator: true,
                progressIndicatorColor: widget.accent,
                progressColors: ProgressBarColors(
                  playedColor: widget.accent,
                  handleColor: widget.accent,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
                onReady: widget.onReady,
              ),
              builder: (ctx, player) => SizedBox(
                height: 210,
                child: Stack(
                  children: [
                    Positioned.fill(child: player),
                    // Close button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: widget.onClose,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white70, size: 17),
                        ),
                      ),
                    ),
                    // Playlist badge bottom-left
                    if (isPlaylist)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.queue_music_rounded,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  size: 13),
                              const SizedBox(width: 4),
                              Text(
                                'Playlist',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Now-playing title bar (always shown) ────────
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: isPlaylist
                  ? BorderRadius.zero
                  : const BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ValueListenableBuilder<YoutubePlayerValue>(
                        valueListenable: widget.controller,
                        builder: (_, v, __) {
                          final title = v.metaData.title.isNotEmpty
                              ? v.metaData.title
                              : widget.item.title;
                          return Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          );
                        },
                      ),
                      if (isPlaylist)
                        Text(
                          widget.item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.28),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                // Queue toggle for playlists
                if (isPlaylist) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _queueExpanded = !_queueExpanded),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _queueExpanded
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _queueExpanded
                                ? Icons.expand_less_rounded
                                : Icons.queue_rounded,
                            color: Colors.white.withValues(alpha: 0.55),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _queueExpanded ? 'Hide' : 'Queue',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Playlist queue panel ─────────────────────────
          if (isPlaylist && _queueExpanded)
            _PlaylistQueuePanel(
              controller: widget.controller,
              playlistId: widget.item.youtubeId,
              currentVideoId: widget.currentVideoId,
              currentIndex: widget.currentIndex,
              onVideoTap: widget.onPlaylistVideoTap,
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Playlist Queue Panel ────────────────────────────────────────────────────
/// Fetches all videos in the playlist via yt.lemnoslife.com (no API key)
/// and shows a scrollable list so the user can jump to any video.

class _PlaylistQueuePanel extends StatefulWidget {
  final YoutubePlayerController controller;
  final String playlistId;
  final String? currentVideoId;
  final int currentIndex;
  final void Function(int index) onVideoTap;

  const _PlaylistQueuePanel({
    required this.controller,
    required this.playlistId,
    required this.currentVideoId,
    required this.currentIndex,
    required this.onVideoTap,
  });

  @override
  State<_PlaylistQueuePanel> createState() => _PlaylistQueuePanelState();
}

class _PlaylistQueuePanelState extends State<_PlaylistQueuePanel> {
  List<_PlaylistEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPlaylist();
  }

  @override
  void didUpdateWidget(_PlaylistQueuePanel old) {
    super.didUpdateWidget(old);
    if (old.playlistId != widget.playlistId) {
      _entries = [];
      _loading = true;
      _error = null;
      _fetchPlaylist();
    }
  }

  Future<void> _fetchPlaylist() async {
    // inv.nadeko.net — confirmed working, no API key
    if (await _tryInvidious('https://inv.nadeko.net')) return;
    // Second Invidious instance as fallback
    if (await _tryInvidious('https://invidious.privacyredirect.com')) return;
    // Both failed — show prev/next controls only
    if (mounted) setState(() { _loading = false; _error = 'unavailable'; });
  }

  Future<bool> _tryInvidious(String base) async {
    try {
      final url = Uri.parse(
          '$base/api/v1/playlists/${widget.playlistId}?fields=videos&page=1');
      final res = await http.get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return false;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (data['videos'] as List?) ?? [];
      final entries = <_PlaylistEntry>[];
      for (final item in items) {
        final videoId = item['videoId'] as String? ?? '';
        if (videoId.isEmpty) continue;
        final title = item['title'] as String? ?? 'Untitled';
        entries.add(_PlaylistEntry(videoId: videoId, title: title));
      }
      if (entries.isEmpty) return false;
      if (mounted) setState(() { _entries = entries; _loading = false; _error = null; });
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: Row(
              children: [
                Icon(Icons.playlist_play_rounded,
                    color: Colors.white.withValues(alpha: 0.3), size: 18),
                const SizedBox(width: 8),
                Text(
                  'QUEUE',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
                if (_entries.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${_entries.length} videos',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.18),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (_loading)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
            )
          else if (_error != null)
            // API failed — show current video from player metadata + controls
            ValueListenableBuilder<YoutubePlayerValue>(
              valueListenable: widget.controller,
              builder: (_, v, __) {
                final nowId = v.metaData.videoId;
                final nowTitle = v.metaData.title;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show current playing video if known
                      if (nowId.isNotEmpty)
                        _QueueVideoRow(
                          videoId: nowId,
                          title: nowTitle.isNotEmpty ? nowTitle : 'Now playing',
                          subtitle: '',
                          isPlaying: true,
                          index: widget.currentIndex,
                          onTap: () {},
                        ),
                      const SizedBox(height: 10),
                      // Prev / Next + Retry
                      Row(
                        children: [
                          _QueueControlBtn(
                            icon: Icons.skip_previous_rounded,
                            label: 'Prev',
                            onTap: () {
                              final prev = widget.currentIndex > 0
                                  ? widget.currentIndex - 1
                                  : 0;
                              widget.onVideoTap(prev);
                            },
                          ),
                          const SizedBox(width: 10),
                          _QueueControlBtn(
                            icon: Icons.skip_next_rounded,
                            label: 'Next',
                            onTap: () =>
                                widget.onVideoTap(widget.currentIndex + 1),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _loading = true;
                                _error = null;
                              });
                              _fetchPlaylist();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.07)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh_rounded,
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                      size: 14),
                                  const SizedBox(width: 4),
                                  Text('Retry',
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.35),
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            )
          else
            // Full scrollable list
            ValueListenableBuilder<YoutubePlayerValue>(
              valueListenable: widget.controller,
              builder: (_, v, __) {
                final nowId = v.metaData.videoId;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _entries.length,
                  itemBuilder: (_, i) {
                    final e = _entries[i];
                    final isPlaying = e.videoId == nowId ||
                        (nowId.isEmpty && i == widget.currentIndex);
                    return _QueueVideoRow(
                      videoId: e.videoId,
                      title: e.title,
                      subtitle: '',
                      isPlaying: isPlaying,
                      index: i,
                      onTap: () => widget.onVideoTap(i),
                    );
                  },
                );
              },
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Simple data holder for a playlist entry.
class _PlaylistEntry {
  final String videoId;
  final String title;
  const _PlaylistEntry({required this.videoId, required this.title});
}


class _QueueVideoRow extends StatelessWidget {
  final String videoId;
  final String title;
  final String subtitle;
  final bool isPlaying;
  final int index;
  final VoidCallback onTap;

  const _QueueVideoRow({
    required this.videoId,
    required this.title,
    required this.subtitle,
    required this.isPlaying,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.network(
                    'https://i.ytimg.com/vi/$videoId/mqdefault.jpg',
                    width: 72,
                    height: 42,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 72,
                      height: 42,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  if (isPlaying)
                    Container(
                      width: 72,
                      height: 42,
                      color: Colors.black.withValues(alpha: 0.35),
                      child: Icon(Icons.graphic_eq_rounded,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 20),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPlaying
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (isPlaying)
              Icon(Icons.equalizer_rounded,
                  color: Colors.white.withValues(alpha: 0.4), size: 16),
          ],
        ),
      ),
    );
  }
}

class _QueueControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QueueControlBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                )),
          ],
        ),
      ),
    );
  }
}

// ─── Add Link Sheet (two-step: URL → collection) ────────────────────────────

class _AddLinkSheet extends StatefulWidget {
  final List<String> existingTags;
  final Future<void> Function(String url, String tag) onSave;

  const _AddLinkSheet({required this.existingTags, required this.onSave});

  @override
  State<_AddLinkSheet> createState() => _AddLinkSheetState();
}

class _AddLinkSheetState extends State<_AddLinkSheet> {
  final _urlCtrl = TextEditingController();
  final _newTagCtrl = TextEditingController();

  // Step 1 = enter URL, Step 2 = pick collection
  int _step = 1;
  bool _saving = false;
  String? _selectedTag; // null = no tag / "New…" = create new
  bool _creatingNew = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _newTagCtrl.dispose();
    super.dispose();
  }

  void _goToStep2() {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _step = 2);
  }

  Future<void> _save() async {
    final url = _urlCtrl.text.trim();
    final tag = _creatingNew
        ? _newTagCtrl.text.trim()
        : (_selectedTag ?? '');
    setState(() => _saving = true);
    await widget.onSave(url, tag);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 28, 24, bottom + 28),
        child: _step == 1 ? _buildStep1() : _buildStep2(),
      ),
    );
  }

  // ── Step 1: Enter URL ──────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add YouTube Link',
          style: TextStyle(color: Colors.white, fontSize: 18,
              fontWeight: FontWeight.w400),
        ),
        const SizedBox(height: 6),
        Text(
          'Paste a video or playlist URL',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.3),
              fontSize: 13),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _urlCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onSubmitted: (_) => _goToStep2(),
          decoration: InputDecoration(
            hintText: 'https://youtube.com/watch?v=...',
            hintStyle:
                TextStyle(color: Colors.white.withValues(alpha: 0.15)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
            suffixIcon: IconButton(
              icon: Icon(Icons.content_paste_rounded,
                  color: Colors.white.withValues(alpha: 0.3), size: 20),
              onPressed: () async {
                final d =
                    await Clipboard.getData(Clipboard.kTextPlain);
                if (d?.text != null && mounted) {
                  _urlCtrl.text = d!.text!;
                  _urlCtrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: _urlCtrl.text.length));
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _goToStep2,
            child: const Text('Next'),
          ),
        ),
      ],
    );
  }

  // ── Step 2: Pick or create collection ─────────────────────────────────
  Widget _buildStep2() {
    final tags = widget.existingTags;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back arrow + title
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() {
                _step = 1;
                _creatingNew = false;
                _selectedTag = null;
              }),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white.withValues(alpha: 0.4), size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              'Add to collection',
              style: TextStyle(color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w400),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Optional — organise your Calm Watch',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
        ),
        const SizedBox(height: 20),

        // "No collection" option
        _CollectionTile(
          label: 'No collection',
          subtitle: 'Save directly to Calm Watch',
          selected: _selectedTag == null && !_creatingNew,
          onTap: () => setState(() {
            _selectedTag = null;
            _creatingNew = false;
          }),
        ),
        const SizedBox(height: 8),

        // Existing tags
        if (tags.isNotEmpty) ...[
          ...tags.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CollectionTile(
                  label: t,
                  selected: _selectedTag == t && !_creatingNew,
                  onTap: () => setState(() {
                    _selectedTag = t;
                    _creatingNew = false;
                  }),
                ),
              )),
        ],

        // Create new collection
        _CollectionTile(
          label: 'New collection…',
          icon: Icons.add_rounded,
          selected: _creatingNew,
          onTap: () => setState(() {
            _creatingNew = true;
            _selectedTag = null;
          }),
        ),
        if (_creatingNew) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _newTagCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g. Quran Recitations',
              hintStyle:
                  TextStyle(color: Colors.white.withValues(alpha: 0.15)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: Colors.white))
                : const Text('Save'),
          ),
        ),
      ],
    );
  }
}

class _CollectionTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _CollectionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon ?? Icons.folder_outlined,
              color: selected
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.25),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.85)
                              : Colors.white.withValues(alpha: 0.45),
                          fontSize: 14,
                          fontWeight: FontWeight.w400)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 11)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded,
                  color: Colors.white.withValues(alpha: 0.5), size: 16),
          ],
        ),
      ),
    );
  }
}
