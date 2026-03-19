import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/calm_watch_item.dart';

class CalmWatchPlayerScreen extends StatefulWidget {
  final CalmWatchItem item;
  final VoidCallback? onMarkCompleted;

  const CalmWatchPlayerScreen({
    super.key,
    required this.item,
    this.onMarkCompleted,
  });

  @override
  State<CalmWatchPlayerScreen> createState() => _CalmWatchPlayerScreenState();
}

class _CalmWatchPlayerScreenState extends State<CalmWatchPlayerScreen> {
  late YoutubePlayerController _controller;
  bool _hasError = false;
  bool _controlsVisible = true;
  bool _playerStarted = false;
  bool _loadingTimedOut = false;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller = YoutubePlayerController(
      initialVideoId:
          widget.item.isPlaylist ? 'jNQXAC9IVRw' : widget.item.youtubeId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: false,
        loop: false,
        isLive: false,
        enableCaption: false,
        hideControls: false,
        hideThumbnail: false,
        forceHD: false,
      ),
    );
    _controller.addListener(_onStateChange);

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });

    Future.delayed(const Duration(seconds: 12), () {
      if (mounted && !_playerStarted) {
        setState(() {
          _loadingTimedOut = true;
          _hasError = true;
        });
      }
    });
  }

  void _onStateChange() {
    final v = _controller.value;
    if (v.hasError && mounted) {
      setState(() => _hasError = true);
      return;
    }
    if (!_playerStarted &&
        (v.playerState == PlayerState.playing ||
            v.playerState == PlayerState.buffering)) {
      if (mounted) setState(() => _playerStarted = true);
    }
    // Sync with the player's own fullscreen button
    if (v.isFullScreen && !_isFullScreen) {
      _goFullScreen();
    } else if (!v.isFullScreen && _isFullScreen) {
      _exitFullScreen();
    }
  }

  void _goFullScreen() {
    if (_isFullScreen) return;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    setState(() {
      _isFullScreen = true;
      _controlsVisible = false;
    });
  }

  void _exitFullScreen() {
    if (!_isFullScreen) return;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (_controller.value.isFullScreen) {
      _controller.toggleFullScreenMode();
    }
    setState(() {
      _isFullScreen = false;
      _controlsVisible = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    if (_isFullScreen) return;
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _controlsVisible = false);
      });
    }
  }

  void _loadPlaylist() {
    final wvc = _controller.value.webViewController;
    if (wvc == null) return;
    final listId = widget.item.youtubeId;
    wvc.evaluateJavascript(
      source:
          'player.loadPlaylist({listType:"playlist",list:"$listId",index:0,startSeconds:0});',
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChange);
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    super.dispose();
  }

  YoutubePlayer _buildPlayer() => YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.white70,
        progressColors: const ProgressBarColors(
          playedColor: Colors.white,
          handleColor: Colors.white,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white10,
        ),
        onReady: () {
          if (widget.item.isPlaylist) _loadPlaylist();
        },
      );

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    // ── FULLSCREEN ────────────────────────────────────────────────────
    // Landscape + immersive. Player fills 100% of screen.
    // Only the player's own controls (play/pause, seek, exit-fullscreen) show.
    if (_isFullScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _exitFullScreen();
          },
          child: SizedBox.expand(
            child: _hasError ? _buildErrorState() : _buildPlayer(),
          ),
        ),
      );
    }

    // ── PORTRAIT ─────────────────────────────────────────────────────
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Video centred vertically
            Positioned.fill(
              child: _hasError
                  ? _buildErrorState()
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [_buildPlayer()],
                    ),
            ),

            // Custom overlay
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Stack(
                  children: [
                    // Close + title
                    Positioned(
                      top: topPad + 8,
                      left: 12,
                      right: 12,
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white54, size: 20),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 13,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Mark as Completed
                    Positioned(
                      bottom: 32,
                      left: 24,
                      right: 24,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onMarkCompleted?.call();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'Mark as Completed',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final msg = _loadingTimedOut
        ? 'This video is taking too long to load.\nIt may be restricted or unavailable.'
        : 'This video cannot be played here.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 15,
                fontWeight: FontWeight.w300,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () async {
                final url = Uri.parse(widget.item.originalUrl);
                if (await canLaunchUrl(url)) {
                  launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Open in YouTube',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Go Back',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
