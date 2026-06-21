import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/note.dart';
import 'models/favorite_app.dart';
import 'models/installed_app.dart';
import 'models/prayer_record.dart';
import 'models/qadha_record.dart';
import 'models/productivity_models.dart';
import 'features/prayer_alarm/models/prayer_alarm_config.dart';
import 'features/prayer_alarm/services/prayer_alarm_service.dart';
import 'screens/launcher_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/notification_feed_screen.dart';
import 'providers/font_provider.dart';
import 'providers/font_size_provider.dart';
import 'utils/hive_box_manager.dart';
import 'utils/smooth_page_route.dart';
import 'widgets/edge_to_edge.dart';

/// Global navigator key so notification taps can push routes from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Load environment variables ──
  await dotenv.load(fileName: '.env');

  // ── Global error handler — catch framework errors ──
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('🔴 FlutterError: ${details.exceptionAsString()}');
    // TODO: Send to Sentry / Firebase Crashlytics when integrated
  };

  // Initialize Hive
  await Hive.initFlutter();

  Hive.registerAdapter(NoteAdapter());
  Hive.registerAdapter(FavoriteAppAdapter());
  Hive.registerAdapter(InstalledAppAdapter());
  Hive.registerAdapter(PrayerRecordAdapter()); // Prayer tracking
  Hive.registerAdapter(QadhaRecordAdapter()); // Qadha prayer tracking

  // Prayer Alarm adapters
  Hive.registerAdapter(PrayerAlarmConfigAdapter());
  Hive.registerAdapter(DailyPrayerTimesAdapter());
  Hive.registerAdapter(PrayerReminderSettingsAdapter());

  // Productivity Hub adapters
  Hive.registerAdapter(TodoItemAdapter());
  Hive.registerAdapter(PomodoroSessionAdapter());
  Hive.registerAdapter(AcademicDoubtAdapter());
  Hive.registerAdapter(ProductivityEventAdapter());
  Hive.registerAdapter(AppBlockRuleAdapter());
  Hive.registerAdapter(PomodoroSettingsAdapter());

  // ── Modern edge-to-edge system UI ──
  // Transparent status + navigation bars so the dark background draws fully
  // behind them; content respects the insets via the shared [EdgeToEdge]
  // wrapper. Light icons sit on the dark surface.
  SystemChrome.setSystemUIOverlayStyle(edgeToEdgeOverlayStyle());
  final prefs = await SharedPreferences.getInstance();
  final showStatusBar = prefs.getBool('display_show_status_bar') ?? false;

  // Draw content behind the system bars (edge-to-edge). When the user opts to
  // hide the status bar, immersiveSticky keeps the same edge-to-edge canvas
  // while hiding the bars until swiped.
  SystemChrome.setEnabledSystemUIMode(
    showStatusBar ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
  );
  // Lock entire app to portrait.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Pre-open ALL frequently used Hive boxes in parallel (avoids repeated I/O)
  // This eliminates ~40+ redundant Hive.openBox() calls during first render
  await Future.wait([
    HiveBoxManager.get('wallpaperBox'),
    HiveBoxManager.get('settingsBox'),
    HiveBoxManager.get('zen_mode_box'),
    HiveBoxManager.get('tasbih_data'),
    HiveBoxManager.get('settings'),
    HiveBoxManager.get<TodoItem>('productivity_todos'),
    HiveBoxManager.get<PomodoroSettings>('pomodoro_settings'),
    HiveBoxManager.get('pomodoro_daily_stats'),
    HiveBoxManager.get<InstalledApp>('installed_apps'),
    HiveBoxManager.get<AppBlockRule>('app_block_rules'),
    HiveBoxManager.get<AcademicDoubt>('academic_doubts'),
    HiveBoxManager.get<ProductivityEvent>('productivity_events'),
    HiveBoxManager.get('focus_streak'),
    HiveBoxManager.get<String>('recently_installed_apps'),
    HiveBoxManager.get('prayer_records'),
    HiveBoxManager.get<QadhaRecord>('qadha_records'),
    HiveBoxManager.get<String>('qadha_meta'),
    HiveBoxManager.get('prayer_alarm_config'),
    HiveBoxManager.get<DailyPrayerTimes>('prayer_alarm_times'),
    HiveBoxManager.get('prayer_reminder_settings'),
  ]);

  // Initialize prayer alarm service (exact alarms + notifications)
  await PrayerAlarmService.initialize();


  // Listen for native "open notification feed" intent (from hint notification tap)
  const notifChannel = MethodChannel('com.sukoon.launcher/notification_filter');
  notifChannel.setMethodCallHandler((call) async {
    if (call.method == 'openNotificationFeed') {
      // Delay briefly to let the navigator finish attaching
      await Future.delayed(const Duration(milliseconds: 500));
      navigatorKey.currentState?.push(
        SmoothForwardRoute(child: const NotificationFeedScreen()),
      );
    }
  });

  // NOTE: checkNativeAlarmPending() is NOT called here because navigatorKey
  // is not yet attached to the widget tree at this point. It runs instead in
  // _LauncherEntryPointState.initState() via addPostFrameCallback so the
  // navigator is guaranteed to be ready.

  runApp(const ProviderScope(child: SukoonLauncherApp()));
}

/// Global scroll behavior: removes ALL overscroll stretch and glow indicators.
///
/// On Android with Material 3, the default [MaterialScrollBehavior] wraps every
/// [Scrollable] in a [StretchingOverscrollIndicator]. This causes:
///   - Visible elastic "stretching" at the first and last pages of [PageView].
///   - Subtle content shift/resize between pages during fast swipes.
///   - A spring-back visual on inner scrollables (lists, grids).
///
/// By overriding [buildOverscrollIndicator] to return [child] directly, we
/// strip the stretch from every scrollable in the app — making page transitions
/// feel rigid and mechanical, like Pixel Launcher / AOSP Launcher3.
class _NoStretchScrollBehavior extends ScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child; // No stretch, no glow — just the raw scrollable content.
}

class SukoonLauncherApp extends ConsumerWidget {
  const SukoonLauncherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appFont = ref.watch(fontProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final bgColor = Colors.black.withValues(alpha: 0.5);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Sukoon Launcher',
      debugShowCheckedModeBanner: false,
      // ── Global scroll behavior: kill ALL overscroll stretch/glow ──
      //
      // On Android with Material 3 the default MaterialScrollBehavior wraps
      // every Scrollable in a StretchingOverscrollIndicator.  This applies
      // to the PageView itself, producing the elastic "page stretching"
      // effect at the first/last page, and a subtle stretch between any
      // two pages when the user drags past the settling point.
      //
      // By returning `child` unmodified from buildOverscrollIndicator we
      // strip the stretch from every scrollable in the widget tree — the
      // PageView, inner ScrollViews, ListViews, GridViews, etc. — globally.
      scrollBehavior: const _NoStretchScrollBehavior(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(fontSize)),
          child: child!,
        );
      },
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgColor,
        primarySwatch: Colors.grey,
        useMaterial3: true,
        fontFamily: appFont.fontFamily,
        // ── Global iOS-style page transitions for ALL MaterialPageRoutes ──
        // This gives every push/pop the smooth Apple slide animation with
        // interactive swipe-back on both Android and iOS — no more janky
        // Android zoom transitions.
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          },
        ),
        // 2-font hierarchy: headings use heading font, body uses body font
        textTheme: TextTheme(
          // Display styles — large headings
          displayLarge: TextStyle(fontFamily: appFont.headingFamily, decoration: TextDecoration.none),
          displayMedium: TextStyle(fontFamily: appFont.headingFamily, decoration: TextDecoration.none),
          displaySmall: TextStyle(fontFamily: appFont.headingFamily, decoration: TextDecoration.none),
          // Headline styles — section headings
          headlineLarge: TextStyle(fontFamily: appFont.headingFamily, decoration: TextDecoration.none),
          headlineMedium: TextStyle(fontFamily: appFont.headingFamily, decoration: TextDecoration.none),
          headlineSmall: TextStyle(fontFamily: appFont.headingFamily, decoration: TextDecoration.none),
          // Title styles — card / appbar titles
          titleLarge: TextStyle(fontFamily: appFont.headingFamily, decoration: TextDecoration.none),
          titleMedium: TextStyle(fontFamily: appFont.fontFamily, decoration: TextDecoration.none),
          titleSmall: TextStyle(fontFamily: appFont.fontFamily, decoration: TextDecoration.none),
          // Body styles — paragraphs, content
          bodyLarge: TextStyle(fontFamily: appFont.fontFamily, decoration: TextDecoration.none),
          bodyMedium: TextStyle(fontFamily: appFont.fontFamily, decoration: TextDecoration.none),
          bodySmall: TextStyle(fontFamily: appFont.fontFamily, decoration: TextDecoration.none),
          // Label styles — buttons, chips
          labelLarge: TextStyle(fontFamily: appFont.fontFamily, decoration: TextDecoration.none),
          labelMedium: TextStyle(fontFamily: appFont.fontFamily, decoration: TextDecoration.none),
          labelSmall: TextStyle(fontFamily: appFont.fontFamily, decoration: TextDecoration.none),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        dividerTheme: const DividerThemeData(
          color: Colors.transparent,
        ),
      ),
      home: const _LauncherEntryPoint(),
    );
  }
}

/// Entry point that checks onboarding + manages app lifecycle
class _LauncherEntryPoint extends StatefulWidget {
  const _LauncherEntryPoint();

  @override
  State<_LauncherEntryPoint> createState() => _LauncherEntryPointState();
}

class _LauncherEntryPointState extends State<_LauncherEntryPoint>
    with WidgetsBindingObserver {
  DateTime? _lastCompactTime;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
        // Compact Hive only on full pause (not inactive — inactive fires
        // for permission dialogs, notification shade, etc. and running
        // disk I/O there can compete with the UI thread on resume).
        final now = DateTime.now();
        if (_lastCompactTime == null || 
            now.difference(_lastCompactTime!).inMinutes >= 5) {
          _lastCompactTime = now;
          HiveBoxManager.compactAll();
        }
        break;
      case AppLifecycleState.resumed:
        // No special handling needed — alarm is handled natively.
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Synchronous read — settingsBox is already pre-opened in main()
    final box = Hive.box('settingsBox');
    final onboardingCompleted = box.get('onboarding_completed', defaultValue: false) as bool;
    return onboardingCompleted 
        ? const LauncherShell() 
        : const OnboardingScreen();
  }
}
