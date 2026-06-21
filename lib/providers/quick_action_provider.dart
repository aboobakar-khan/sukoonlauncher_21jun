import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:flutter/services.dart';
import '../utils/hive_box_manager.dart';

/// Provider for storing quick action app selections (phone, camera, etc.)
final quickActionProvider =
    StateNotifierProvider<QuickActionNotifier, QuickActions>((ref) {
      return QuickActionNotifier();
    });

class QuickActions {
  final String? phoneApp;
  final String? cameraApp;

  QuickActions({this.phoneApp, this.cameraApp});

  QuickActions copyWith({String? phoneApp, String? cameraApp}) {
    return QuickActions(
      phoneApp: phoneApp ?? this.phoneApp,
      cameraApp: cameraApp ?? this.cameraApp,
    );
  }
}

class QuickActionNotifier extends StateNotifier<QuickActions> {
  static const String _boxName = 'quickActions';
  Box? _box;

  // Common phone dialer package names (ordered by popularity)
  static const _commonDialers = [
    'com.google.android.dialer',
    'com.samsung.android.dialer',
    'com.android.dialer',
    'com.android.phone',
    'com.samsung.android.contacts',
    'com.oneplus.dialer',
    'com.miui.calls',
    'com.asus.contacts',
    'com.huawei.contacts',
  ];

  // Common camera package names (ordered by popularity)
  static const _commonCameras = [
    'com.google.android.GoogleCamera',       // Google Pixel (GCam)
    'com.google.android.GoogleCameraGo',     // Google Camera Go (budget Pixels)
    'com.samsung.android.camera',            // Samsung
    'com.android.camera',                    // AOSP / stock
    'com.android.camera2',                   // AOSP Camera2
    'com.oneplus.camera',                    // OnePlus
    'com.miui.camera',                       // Xiaomi / MIUI
    'com.huawei.camera',                     // Huawei
    'com.asus.camera',                       // Asus
    'com.sec.android.app.camera',            // Samsung (older)
    'com.motorola.camera3',                  // Motorola
    'com.motorola.camera2',                  // Motorola (older)
    'com.sonyericsson.android.camera',       // Sony
    'org.codeaurora.snapcam',                // Qualcomm SnapCam
    'com.oppo.camera',                       // Oppo
    'com.coloros.camera',                    // Oppo ColorOS camera
    'com.coloros.camera2',                   // Oppo ColorOS camera2
    'com.vivo.camera',                       // Vivo
    'com.realme.camera',                     // Realme
    'com.hmd.camera',                        // Nokia / HMD
    'com.lava.camera',                       // Lava
    'com.lava.camera2',                      // Lava (alt)
    'com.transsion.camera',                  // Tecno / Infinix / itel (Transsion)
    'com.mediatek.camera',                   // MediaTek stock camera
    'com.lenovo.camera',                     // Lenovo
    'com.nothing.camera',                    // Nothing Phone
    'com.tcl.camera',                        // TCL
    'com.zte.camera',                        // ZTE
  ];

  QuickActionNotifier() : super(QuickActions()) {
    _init();
  }

  Future<void> _init() async {
    _box = await HiveBoxManager.get(_boxName);
    _loadFromHive();

    // Auto-detect if no apps are saved yet
    if (state.phoneApp == null || state.cameraApp == null) {
      await _autoDetectDefaults();
    }
  }

  void _loadFromHive() {
    final phoneApp = _box?.get('phoneApp') as String?;
    final cameraApp = _box?.get('cameraApp') as String?;
    state = QuickActions(phoneApp: phoneApp, cameraApp: cameraApp);
  }

  /// Auto-detect common phone and camera apps from installed apps
  Future<void> _autoDetectDefaults() async {
    try {
      final channel = const MethodChannel('com.sukoon.launcher/apps');
      final raw = await channel.invokeMethod<List<dynamic>>('getLauncherApps');
      final installedPackages = (raw ?? [])
          .cast<Map<dynamic, dynamic>>()
          .map((m) => (m['package'] as String?) ?? '')
          .toSet();

      // Auto-detect phone app
      if (state.phoneApp == null) {
        for (final dialer in _commonDialers) {
          if (installedPackages.contains(dialer)) {
            debugPrint('QuickAction: Auto-detected phone app: $dialer');
            await setPhoneApp(dialer);
            break;
          }
        }
      }

      // Auto-detect camera app
      if (state.cameraApp == null) {
        for (final camera in _commonCameras) {
          if (installedPackages.contains(camera)) {
            debugPrint('QuickAction: Auto-detected camera app: $camera');
            await setCameraApp(camera);
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('QuickAction: Auto-detect error: $e');
    }
  }

  Future<void> setPhoneApp(String packageName) async {
    if (_box == null) return;
    await _box?.put('phoneApp', packageName);
    state = state.copyWith(phoneApp: packageName);
  }

  Future<void> setCameraApp(String packageName) async {
    if (_box == null) return;
    await _box?.put('cameraApp', packageName);
    state = state.copyWith(cameraApp: packageName);
  }

  /// Public helper: re-run camera auto-detect (useful after a native-intent
  /// fallback so the next tap can use the fast _launchApp path).
  Future<void> autoDetectCamera() async {
    if (state.cameraApp != null) return; // already set
    try {
      final channel = const MethodChannel('com.sukoon.launcher/apps');
      final raw = await channel.invokeMethod<List<dynamic>>('getLauncherApps');
      final installed = (raw ?? [])
          .cast<Map<dynamic, dynamic>>()
          .map((m) => (m['package'] as String?) ?? '')
          .toSet();
      for (final camera in _commonCameras) {
        if (installed.contains(camera)) {
          debugPrint('QuickAction: Auto-detected camera app: $camera');
          await setCameraApp(camera);
          return;
        }
      }
    } catch (e) {
      debugPrint('QuickAction: autoDetectCamera error: $e');
    }
  }

  void clearPhoneApp() {
    _box?.delete('phoneApp');
    state = state.copyWith(phoneApp: null);
  }

  void clearCameraApp() {
    _box?.delete('cameraApp');
    state = state.copyWith(cameraApp: null);
  }
}
