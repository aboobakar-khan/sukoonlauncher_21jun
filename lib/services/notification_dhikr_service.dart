import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/hive_box_manager.dart';

/// Notification Dhikr Counter Service
/// 
/// Provides a persistent notification that allows users to count dhikr
/// without opening the app. One-tap increment from notification.
/// 
/// Features:
/// - Persistent notification with current count
/// - Tap to increment without opening app
/// - Updates in real-time
/// - Syncs with main tasbih counter
/// 
/// Design Science:
/// - Removes all friction from dhikr
/// - Ambient Islamic consciousness
/// - Always available spiritual tool
class NotificationDhikrService {
  static const MethodChannel _channel = 
      MethodChannel('com.sukoon.launcher/dhikr_notification');
  
  static bool _isServiceRunning = false;
  static int _currentCount = 0;
  static const String _boxName = 'notification_dhikr';
  static Box? _cachedBox; // Cache Hive box to avoid repeated openBox calls

  /// Start the notification dhikr counter
  static Future<void> startService() async {
    if (_isServiceRunning) return;

    try {
      // Load current count (using cached box)
      _cachedBox = await HiveBoxManager.get(_boxName);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      _currentCount = _cachedBox!.get('count_$today', defaultValue: 0);

      // Start Android foreground service
      await _channel.invokeMethod('startDhikrNotification', {
        'count': _currentCount,
        'title': 'Dhikr Counter',
        'message': 'Tap to count SubhanAllah',
      });

      _isServiceRunning = true;

      // Listen for increment events from notification
      _channel.setMethodCallHandler(_handleMethodCall);
    } catch (e) {
      // Service not available on this platform
      debugPrint('Dhikr notification service not available: $e');
    }
  }

  /// Stop the notification service
  static Future<void> stopService() async {
    if (!_isServiceRunning) return;

    try {
      await _channel.invokeMethod('stopDhikrNotification');
      _isServiceRunning = false;
    } catch (e) {
      debugPrint('Error stopping dhikr notification: $e');
    }
  }

  /// Handle method calls from native side
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDhikrIncrement':
        await _handleIncrement();
        break;
      case 'onDhikrReset':
        await _handleReset();
        break;
      default:
        throw UnimplementedError('Method ${call.method} not implemented');
    }
  }

  /// Handle increment from notification tap
  static Future<void> _handleIncrement() async {
    _currentCount++;
    
    // Save to cached Hive box (no redundant openBox)
    _cachedBox ??= await HiveBoxManager.get(_boxName);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _cachedBox!.put('count_$today', _currentCount);

    // Also sync to main tasbih counter
    await _syncToMainCounter();

    // Update notification
    await _updateNotification();

    // Haptic feedback (if app is in foreground)
  }

  /// Handle reset action
  static Future<void> _handleReset() async {
    _currentCount = 0;
    
    _cachedBox ??= await HiveBoxManager.get(_boxName);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _cachedBox!.put('count_$today', 0);

    await _updateNotification();
  }

  /// Sync notification count to main tasbih counter
  static Future<void> _syncToMainCounter() async {
    try {
      final tasbihBox = await HiveBoxManager.get('tasbih_data');
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final lastDate = tasbihBox.get('lastDate', defaultValue: '');
      
      if (lastDate == today) {
        final currentTotal = tasbihBox.get('todayCount', defaultValue: 0) as int;
        await tasbihBox.put('todayCount', currentTotal + 1);
      } else {
        await tasbihBox.put('todayCount', 1);
        await tasbihBox.put('lastDate', today);
      }
      
      // Update total all time
      final totalAllTime = tasbihBox.get('totalAllTime', defaultValue: 0) as int;
      await tasbihBox.put('totalAllTime', totalAllTime + 1);
    } catch (e) {
      // Continue even if sync fails
    }
  }

  /// Update the notification with current count
  static Future<void> _updateNotification() async {
    try {
      await _channel.invokeMethod('updateDhikrNotification', {
        'count': _currentCount,
        'title': 'Dhikr Counter',
        'message': _getProgressMessage(),
      });
    } catch (e) {
      // Ignore update errors
    }
  }

  /// Get progress message based on count
  static String _getProgressMessage() {
    if (_currentCount == 0) {
      return 'Tap to start counting';
    } else if (_currentCount < 33) {
      return 'سُبْحَانَ اللّٰهِ • ${33 - _currentCount} to complete';
    } else if (_currentCount == 33) {
      return 'SubhanAllah complete! Continue for more';
    } else if (_currentCount < 66) {
      return 'الْحَمْدُ لِلّٰهِ • ${66 - _currentCount} to 66';
    } else if (_currentCount < 99) {
      return 'اللّٰهُ أَكْبَر • ${99 - _currentCount} to 99';
    } else if (_currentCount == 99) {
      return 'Tasbih Complete! MashaAllah ✨';
    } else {
      return '$_currentCount counted today 🌟';
    }
  }

  /// Get current count
  static int get currentCount => _currentCount;

  /// Check if service is running
  static bool get isRunning => _isServiceRunning;

  /// Get today's notification dhikr count
  static Future<int> getTodayCount() async {
    _cachedBox ??= await HiveBoxManager.get(_boxName);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _cachedBox!.get('count_$today', defaultValue: 0);
  }

  /// Enable/disable notification dhikr
  static Future<void> setEnabled(bool enabled) async {
    _cachedBox ??= await HiveBoxManager.get(_boxName);
    await _cachedBox!.put('enabled', enabled);
    
    if (enabled) {
      await startService();
    } else {
      await stopService();
    }
  }

  /// Check if notification dhikr is enabled
  static Future<bool> isEnabled() async {
    _cachedBox ??= await HiveBoxManager.get(_boxName);
    return _cachedBox!.get('enabled', defaultValue: false);
  }
}

/// Settings model for notification dhikr
class NotificationDhikrSettings {
  final bool enabled;
  final bool showArabic;
  final bool vibrateOnTap;
  final String selectedDhikr;

  NotificationDhikrSettings({
    this.enabled = false,
    this.showArabic = true,
    this.vibrateOnTap = true,
    this.selectedDhikr = 'SubhanAllah',
  });

  static Future<NotificationDhikrSettings> load() async {
    final box = await HiveBoxManager.get('notification_dhikr');
    return NotificationDhikrSettings(
      enabled: box.get('enabled', defaultValue: false),
      showArabic: box.get('showArabic', defaultValue: true),
      vibrateOnTap: box.get('vibrateOnTap', defaultValue: true),
      selectedDhikr: box.get('selectedDhikr', defaultValue: 'SubhanAllah'),
    );
  }

  Future<void> save() async {
    final box = await HiveBoxManager.get('notification_dhikr');
    await box.put('enabled', enabled);
    await box.put('showArabic', showArabic);
    await box.put('vibrateOnTap', vibrateOnTap);
    await box.put('selectedDhikr', selectedDhikr);
  }

  NotificationDhikrSettings copyWith({
    bool? enabled,
    bool? showArabic,
    bool? vibrateOnTap,
    String? selectedDhikr,
  }) {
    return NotificationDhikrSettings(
      enabled: enabled ?? this.enabled,
      showArabic: showArabic ?? this.showArabic,
      vibrateOnTap: vibrateOnTap ?? this.vibrateOnTap,
      selectedDhikr: selectedDhikr ?? this.selectedDhikr,
    );
  }
}
