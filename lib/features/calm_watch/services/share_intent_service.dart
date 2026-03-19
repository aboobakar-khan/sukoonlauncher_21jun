import 'dart:async';
import 'package:flutter/services.dart';

/// ──────────────────────────────────────────────────────────
///  Share Intent Service — Calm Watch
/// ──────────────────────────────────────────────────────────
/// Listens for YouTube URLs shared from other apps via
/// Android's share sheet (ACTION_SEND) or deep links (ACTION_VIEW).
///
/// The native side (MainActivity.kt) extracts the URL and
/// forwards it to Flutter via the "com.sukoon.launcher/share"
/// MethodChannel. This service manages the stream of incoming
/// URLs so any listener (e.g. LauncherShell) can react.
/// ──────────────────────────────────────────────────────────

class ShareIntentService {
  ShareIntentService._();
  static final ShareIntentService _instance = ShareIntentService._();
  static ShareIntentService get instance => _instance;

  static const _channel = MethodChannel('com.sukoon.launcher/share');

  final _controller = StreamController<String>.broadcast();

  /// Stream of YouTube URLs received from share intents.
  Stream<String> get sharedUrls => _controller.stream;

  bool _initialized = false;

  /// Call once from main.dart to start listening for shared URLs.
  void initialize() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedUrl') {
        final url = call.arguments as String?;
        if (url != null && url.isNotEmpty) {
          _controller.add(url);
        }
      }
    });
  }

  /// Query native for any URL that arrived before Flutter was ready (cold start).
  Future<String?> getInitialSharedUrl() async {
    try {
      final url = await _channel.invokeMethod<String>('getInitialSharedUrl');
      return (url != null && url.isNotEmpty) ? url : null;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _controller.close();
  }
}
