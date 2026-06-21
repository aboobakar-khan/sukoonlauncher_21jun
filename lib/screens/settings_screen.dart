import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/review_helper.dart';
import '../providers/theme_provider.dart';
import '../providers/font_provider.dart';
import '../providers/font_size_provider.dart';
import '../providers/clock_style_provider.dart';
import '../providers/time_format_provider.dart';
import '../providers/wallpaper_provider.dart';
import '../providers/page_indicator_provider.dart';
import '../providers/swipe_gesture_provider.dart';
import '../providers/double_tap_provider.dart';
import '../providers/installed_apps_provider.dart';
import '../providers/keyboard_auto_open_provider.dart';
import 'theme_color_picker_screen.dart';
import 'font_picker_screen.dart';
import 'clock_style_picker_screen.dart';
import 'wallpaper_picker_screen.dart';
import 'donation_screen.dart';
import 'favorite_picker_screen.dart';
import 'privacy_policy_screen.dart';
import 'credits_screen.dart';

import '../widgets/swipe_back_wrapper.dart';
import 'screen_time_settings_screen.dart';
import 'notification_feed_screen.dart';
import 'app_permissions_screen.dart';
import '../providers/notification_filter_provider.dart';
import '../providers/tasbih_provider.dart';
import '../providers/prayer_provider.dart';
import '../providers/note_provider.dart';
import '../providers/saved_verses_provider.dart';
import '../providers/dhikr_history_provider.dart';
import '../providers/ramadan_provider.dart';
import '../providers/display_settings_provider.dart';
import '../providers/productivity_provider.dart';
import '../providers/zen_mode_provider.dart';
import '../providers/screen_time_provider.dart';
import '../providers/fasting_provider.dart';
import '../services/backup_restore_service.dart';
import '../utils/smooth_page_route.dart';
import '../services/offline_content_manager.dart';
import '../features/hadith_dua/models/hadith_dua_models.dart';

/// Settings Screen - Customization options
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeColorProvider);
    final currentFont = ref.watch(fontProvider);
    final currentFontSize = ref.watch(fontSizeProvider);
    final currentClockStyle = ref.watch(clockStyleProvider);
    final currentTimeFormat = ref.watch(timeFormatProvider);
    final currentWallpaper = ref.watch(wallpaperProvider);
    final isLight = currentTheme.isLight;
    final bgColor = isLight ? const Color(0xFFF5F5F5) : Colors.black;
    final primaryText = isLight ? const Color(0xFF0D0D0D) : Colors.white;

    // Find current font size preset name
    final fontSizePreset = fontSizePresets.firstWhere(
      (preset) => preset.scale == currentFontSize,
      orElse: () => fontSizePresets[1], // Default to Normal
    );

    return SwipeBackWrapper(
      child: Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, isLight: isLight, primaryText: primaryText),

            // Settings list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Support Sukoon banner — gentle donation encouragement
                  _buildSupportBanner(context, currentTheme),
                  const SizedBox(height: 10),

                  // Rate Sukoon — in-app review
                  _buildRateUsBanner(currentTheme.color, isLight: isLight),
                  const SizedBox(height: 24),

                  _buildSettingsSection(
                    title: 'APPEARANCE',
                    accentColor: currentTheme.color,
                    items: [
                      _buildSettingsItem(
                        icon: Icons.palette,
                        title: 'Theme Color',
                        subtitle: currentTheme.name,
                        accentColor: currentTheme.color,
                        onTap: () {
                          Navigator.of(context).push(
                            SmoothForwardRoute(
                              child: const ThemeColorPickerScreen(),
                            ),
                          );
                        },
                      
                        isLight: isLight,
                      ),
                      _buildSettingsItem(
                        icon: Icons.wallpaper,
                        title: 'Wallpaper',
                        subtitle: currentWallpaper.name,
                        accentColor: currentTheme.color,
                        onTap: () {
                          Navigator.of(context).push(
                            SmoothForwardRoute(
                              child: const WallpaperPickerScreen(),
                            ),
                          );
                        },
                      
                        isLight: isLight,
                      ),
                      _buildSettingsItem(
                        icon: Icons.font_download,
                        title: 'Font Style',
                        subtitle: '${currentFont.name} · ${AppFonts.categoryName(currentFont.category)}',
                        accentColor: currentTheme.color,
                        onTap: () {
                          Navigator.of(context).push(
                            SmoothForwardRoute(
                              child: const FontPickerScreen(),
                            ),
                          );
                        },
                      
                        isLight: isLight,
                      ),
                      _buildSettingsItem(
                        icon: Icons.format_size,
                        title: 'Font Size',
                        subtitle: fontSizePreset.name,
                        accentColor: currentTheme.color,
                        onTap: () {
                          _showFontSizeDialog(context, ref);
                        },
                      
                        isLight: isLight,
                      ),
                      _buildSettingsItem(
                        icon: Icons.access_time,
                        title: 'Clock Style',
                        subtitle: currentClockStyle.name,
                        accentColor: currentTheme.color,
                        onTap: () {
                          Navigator.of(context).push(
                            SmoothForwardRoute(
                              child: const ClockStylePickerScreen(),
                            ),
                          );
                        },
                      
                        isLight: isLight,
                      ),
                      _buildSettingsItem(
                        icon: Icons.schedule,
                        title: 'Time Format',
                        subtitle: currentTimeFormat.name,
                        accentColor: currentTheme.color,
                        onTap: () {
                          _showTimeFormatDialog(
                            context,
                            ref,
                            currentTimeFormat,
                          );
                        },
                      
                        isLight: isLight,
                      ),
                      _buildPageIndicatorToggle(context, ref),
                      _buildStatusBarToggle(context, ref),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildGesturesSection(context, ref),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    title: 'WIDGETS',
                    accentColor: currentTheme.color,
                    items: [
                      _buildSettingsItem(
                        icon: Icons.star_rounded,
                        title: 'Manage Favorites',
                        subtitle: 'Choose up to 7 favorite apps',
                        accentColor: currentTheme.color,
                        onTap: () {
                          Navigator.push(
                            context,
                            SmoothForwardRoute(
                              child: const FavoritePickerScreen(),
                            ),
                          );
                        },
                      
                        isLight: isLight,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    title: 'DIGITAL WELLBEING',
                    accentColor: currentTheme.color,
                    items: [
                      _buildSettingsItem(
                        icon: Icons.timer_outlined,
                        title: 'In-app time reminder',
                        subtitle: 'Set in-app time reminders for apps',
                        accentColor: currentTheme.color,
                        onTap: () {
                          Navigator.push(
                            context,
                            SmoothForwardRoute(
                              child: const ScreenTimeSettingsScreen(),
                            ),
                          );
                        },
                      
                        isLight: isLight,
                      ),
                      _buildSettingsItem(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        subtitle: 'Filter & view app notifications',
                        accentColor: currentTheme.color,
                        badge: ref.watch(notificationFilterProvider).totalCount,
                        onTap: () {
                          Navigator.push(
                            context,
                            SmoothForwardRoute(
                              child: const NotificationFeedScreen(),
                            ),
                          );
                        },
                      
                        isLight: isLight,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    title: 'SYSTEM',
                    accentColor: currentTheme.color,
                    items: [
                      _buildSettingsItem(
                        icon: Icons.home,
                        title: 'Change Default Launcher',
                        subtitle: 'Set as default home app',
                        accentColor: currentTheme.color,
                        onTap: () {
                          _openHomeLauncherSettings(context);
                        },
                      
                        isLight: isLight,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    title: 'SUPPORT',
                    accentColor: currentTheme.color,
                    items: [
                      _buildSettingsItem(
                        icon: Icons.chat_rounded,
                        title: 'Request Feature / Contact Admin',
                        subtitle: 'Chat with us on WhatsApp',
                        accentColor: currentTheme.color,
                        onTap: () => _openWhatsAppContact(context),
                      
                        isLight: isLight,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsSection(
                    title: 'DATA',
                    accentColor: currentTheme.color,
                    items: [
                      _buildSettingsItem(
                        icon: Icons.download_for_offline_rounded,
                        title: 'Export All Data',
                        subtitle: 'Save backup file to Downloads folder',
                        accentColor: currentTheme.color,
                        onTap: () => _exportData(context),
                      
                        isLight: isLight,
                      ),
                      _buildSettingsItem(
                        icon: Icons.download_rounded,
                        title: 'Import Data',
                        subtitle: 'Restore from a backup file',
                        accentColor: currentTheme.color,
                        onTap: () => _importData(context, ref),
                      
                        isLight: isLight,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildSettingsSection(
                    title: 'HADITH OFFLINE',
                    accentColor: currentTheme.color,
                    items: [
                      _buildSettingsItem(
                        icon: Icons.cloud_download_rounded,
                        title: 'Download Books',
                        subtitle: 'Save complete collections for offline use',
                        accentColor: currentTheme.color,
                        onTap: () => _showHadithDownloadDialog(context, ref, currentTheme.color),
                      
                        isLight: isLight,
                      ),
                      _buildSettingsItem(
                        icon: Icons.delete_sweep_rounded,
                        title: 'Clear Offline Hadiths',
                        subtitle: '${ref.watch(offlineContentProvider).hadithsDownloaded} saved offline',
                        accentColor: Colors.red.shade400,
                        onTap: () => _confirmClearHadithCache(context, ref),
                      
                        isLight: isLight,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildSettingsSection(
                    title: 'ABOUT',
                    accentColor: currentTheme.color,
                    items: [
                      _buildSettingsItem(
                        icon: Icons.info_outline,
                        title: 'Version',
                        subtitle: '1.2.3',
                        accentColor: currentTheme.color,
                        onTap: null,
                      
                        isLight: isLight,
                      ),
                      _buildSettingsItem(
                        icon: Icons.security_outlined,
                        title: 'App Permissions',
                        subtitle: 'See why each permission is used',
                        accentColor: currentTheme.color,
                        onTap: () {
                          Navigator.of(context).push(
                            SmoothForwardRoute(
                              child: const AppPermissionsScreen(),
                            ),
                          );
                        },
                        isLight: isLight,
                      ),
                      _buildSettingsItem(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        subtitle: 'How we handle your data',
                        accentColor: currentTheme.color,
                        onTap: () {
                          Navigator.of(context).push(
                            SmoothForwardRoute(
                              child: const PrivacyPolicyScreen(),
                            ),
                          );
                        },
                      
                        isLight: isLight,
                      ),
                      _buildSettingsItem(
                        icon: Icons.menu_book,
                        title: 'Credits & Licenses',
                        subtitle: 'Qur\'an sources and attributions',
                        accentColor: currentTheme.color,
                        onTap: () {
                          Navigator.of(context).push(
                            SmoothForwardRoute(
                              child: const CreditsScreen(),
                            ),
                          );
                        },
                      
                        isLight: isLight,
                      ),
                      _buildSettingsItem(
                        icon: Icons.source_outlined,
                        title: 'Open-Source Licenses',
                        subtitle: 'Third-party package licenses',
                        accentColor: currentTheme.color,
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'Sukoon Launcher',
                            applicationVersion: '1.2.3',
                            applicationIcon: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Image.asset(
                                'assets/app_icon.png',
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                              ),
                            ),
                            applicationLegalese: '© 2026 Sukoon Launcher. All rights reserved.',
                            children: [
                              const SizedBox(height: 12),
                              Text(
                                "Sukoon Launcher - AI focus & Minimalist\nCreated by Sukoon Foundation.\n\nThank you for choosing simplicity.",
                                style: TextStyle(
                                  color: (!isLight) ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          );
                        },
                      
                        isLight: isLight,
                      ),
                    ],
                  ),

                  // ── Bottom branding footer ──────────────────────
                  const SizedBox(height: 36),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/app_icon.png',
                            width: 22,
                            height: 22,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sukoon Launcher',
                          style: TextStyle(
                            color: primaryText.withValues(alpha: 0.3),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· v1.2.3',
                          style: TextStyle(
                            color: primaryText.withValues(alpha: 0.18),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  void _openHomeLauncherSettings(BuildContext context) async {
    try {
      // Open Android home screen settings using platform channel
      const platform = MethodChannel('com.sukoon.launcher/launcher');
      await platform.invokeMethod('openHomeLauncherSettings');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open launcher settings: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _openWhatsAppContact(BuildContext context) async {
    const phone = '918171114186';
    const message = 'Hi! I\'m using Sukoon Launcher and I have a feature request / feedback:';
    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not open WhatsApp. Please install WhatsApp first.'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _exportData(BuildContext context) async {
    // Show data summary first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return FutureBuilder<Map<String, int>>(
          future: BackupRestoreService.getDataSummary(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return AlertDialog(
                backgroundColor: const Color(0xFF1A1A1A),
                title: const Text('Preparing Export...', style: TextStyle(color: Colors.white)),
                content: const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator(color: Colors.white70)),
                ),
              );
            }

            final summary = snapshot.data!;
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Export Data', style: TextStyle(color: Colors.white, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your data to export:',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ...summary.entries.where((e) => e.value > 0).map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                        Text('${e.value}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
                  if (summary.values.every((v) => v == 0))
                    const Text('No data found yet.', style: TextStyle(color: Colors.white38, fontSize: 13)),
                  const SizedBox(height: 12),
                  const Text(
                    'All settings, preferences, and history will be included.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    // Show progress
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Saving backup to Downloads...'),
                        duration: Duration(seconds: 3),
                        backgroundColor: Color(0xFF2A2A2A),
                      ),
                    );

                    final savedPath = await BackupRestoreService.exportData();

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).clearSnackBars();

                    final success = savedPath.isNotEmpty;
                    final isDownloads = savedPath.contains('/Download');
                    final location = isDownloads
                        ? 'Saved to Downloads folder'
                        : 'Saved to app storage';

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? '$location\n$savedPath'
                            : 'Export failed. Please try again.'),
                        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  },
                  child: const Text('Save to Downloads', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _importData(BuildContext context, WidgetRef ref) async {
    // Confirm before import
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Import Data', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text(
          'This will replace ALL current data with the backup.\n\n'
          'Your existing data will be overwritten.\n\n'
          'The app will need to be restarted after import.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Choose File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Importing data...'),
        duration: Duration(seconds: 10),
        backgroundColor: Color(0xFF2A2A2A),
      ),
    );

    final result = await BackupRestoreService.importData();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();

    if (result == 'cancelled') return;

    final isError = result.startsWith('Error');

    if (!isError) {
      // ── Invalidate ALL providers so UI refreshes immediately ──
      ref.invalidate(tasbihProvider);
      ref.invalidate(prayerRecordListProvider);
      ref.invalidate(noteBoxProvider);
      ref.invalidate(noteListProvider);
      ref.invalidate(savedVersesProvider);
      ref.invalidate(dhikrHistoryProvider);
      ref.invalidate(ramadanProvider);
      ref.invalidate(displaySettingsProvider);
      ref.invalidate(todoProvider);
      ref.invalidate(productivityEventProvider);
      ref.invalidate(academicDoubtProvider);
      ref.invalidate(appBlockRuleProvider);
      ref.invalidate(focusCategoryProvider);
      ref.invalidate(focusStreakProvider);
      ref.invalidate(zenModeProvider);
      ref.invalidate(screenTimeProvider);
      ref.invalidate(notificationFilterProvider);
      ref.invalidate(fastingProvider);
      ref.invalidate(themeColorProvider);
      ref.invalidate(wallpaperProvider);
      ref.invalidate(clockStyleProvider);
      ref.invalidate(fontProvider);
      ref.invalidate(fontSizeProvider);
      ref.invalidate(timeFormatProvider);
      ref.invalidate(keyboardAutoOpenProvider);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isError ? 'Import Failed' : 'Import Complete',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Text(
          isError ? result : '${result.replaceAll('ok:', '')}\n\nAll data has been refreshed.',
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, {required bool isLight, required Color primaryText}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryText.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: primaryText.withValues(alpha: 0.5),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: primaryText.withValues(alpha: 0.9),
                ),
              ),
              Text(
                'Customize your experience',
                style: TextStyle(
                  fontSize: 11,
                  color: primaryText.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> items,
    Color? accentColor,
  }) {
    final accent = accentColor ?? const Color(0xFFC2A366);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  color: accent.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        ...items,
      ],
    );
  }

  void _showFontSizeDialog(BuildContext context, WidgetRef ref) {
    final accent = ref.read(themeColorProvider).color;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: accent.withValues(alpha: 0.15),
          ),
        ),
        title: const Text(
          'Font Size',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: fontSizePresets.map((preset) {
            final isSelected = ref.watch(fontSizeProvider) == preset.scale;
            return ListTile(
              title: Text(
                preset.name,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                  fontSize: 14 * preset.scale,
                ),
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      color: accent,
                    )
                  : null,
              onTap: () {
                ref.read(fontSizeProvider.notifier).setFontSize(preset.scale);
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Gestures section ──

  Widget _buildGesturesSection(BuildContext context, WidgetRef ref) {
    final swipeConfig = ref.watch(swipeGestureProvider);
    final doubleTapConfig = ref.watch(doubleTapProvider);
    final allApps = ref.watch(installedAppsProvider);
    final themeColor = ref.read(themeColorProvider);
    final accent = themeColor.color;
    final isLight = themeColor.isLight;

    // Helper to get app name from package
    String subtitleFor(SwipeAction action, String? pkg) {
      if (action == SwipeAction.openApp && pkg != null) {
        final match = allApps.where((a) => a.packageName == pkg);
        if (match.isNotEmpty) return '${action.label} · ${match.first.appName}';
      }
      return action.label;
    }

    String doubleTapSubtitle() {
      if (doubleTapConfig.action == DoubleTapAction.openApp && doubleTapConfig.appPackage != null) {
        final match = allApps.where((a) => a.packageName == doubleTapConfig.appPackage);
        if (match.isNotEmpty) return '${doubleTapConfig.action.label} · ${match.first.appName}';
      }
      return doubleTapConfig.action.label;
    }

    return _buildSettingsSection(
      title: 'GESTURES',
      accentColor: accent,
      items: [
        _buildSettingsItem(
          icon: Icons.arrow_downward_rounded,
          title: 'Swipe Down',
          subtitle: subtitleFor(swipeConfig.swipeDown, swipeConfig.swipeDownApp),
          accentColor: accent,
          onTap: () => _showSwipeActionPicker(
            context, ref,
            direction: 'Swipe Down',
            current: swipeConfig.swipeDown,
            onSelect: (a, {String? appPackage}) =>
                ref.read(swipeGestureProvider.notifier).setSwipeDown(a, appPackage: appPackage),
          ),
        
          isLight: isLight,
        ),
        _buildSettingsItem(
          icon: Icons.arrow_upward_rounded,
          title: 'Swipe Up',
          subtitle: subtitleFor(swipeConfig.swipeUp, swipeConfig.swipeUpApp),
          accentColor: accent,
          onTap: () => _showSwipeActionPicker(
            context, ref,
            direction: 'Swipe Up',
            current: swipeConfig.swipeUp,
            onSelect: (a, {String? appPackage}) =>
                ref.read(swipeGestureProvider.notifier).setSwipeUp(a, appPackage: appPackage),
          ),
        
          isLight: isLight,
        ),
        _buildSettingsItem(
          icon: Icons.touch_app_rounded,
          title: 'Double Tap',
          subtitle: doubleTapSubtitle(),
          accentColor: accent,
          onTap: () => _showDoubleTapActionPicker(context, ref),
        
          isLight: isLight,
        ),
        _buildKeyboardAutoOpenToggle(context, ref, accent),
      ],
    );
  }

  void _showSwipeActionPicker(
    BuildContext context,
    WidgetRef ref, {
    required String direction,
    required SwipeAction current,
    required void Function(SwipeAction, {String? appPackage}) onSelect,
  }) {
    final gold = ref.read(themeColorProvider).color;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottomPad = MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 16;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPad),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              direction,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose what happens when you $direction on the home screen',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            // Options
            ...SwipeAction.values.map((action) {
              final selected = action == current;
              return GestureDetector(
                onTap: () {
                  if (action == SwipeAction.openApp) {
                    Navigator.pop(ctx);
                    _showAppPickerForSwipe(context, ref, onSelect: onSelect);
                  } else {
                    onSelect(action);
                    Navigator.pop(ctx);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? gold.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? gold.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected
                              ? gold.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(action.icon, size: 18,
                            color: selected ? gold : Colors.white.withValues(alpha: 0.55)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              action.label,
                              style: TextStyle(
                                color: selected ? gold : Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              action.description,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle_rounded,
                            color: gold.withValues(alpha: 0.8), size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
        );
      },
    );
  }

  void _showAppPickerForSwipe(
    BuildContext context,
    WidgetRef ref, {
    required void Function(SwipeAction, {String? appPackage}) onSelect,
  }) {
    final allApps = ref.read(installedAppsProvider);
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final query = searchController.text.toLowerCase();
            final filtered = query.isEmpty
                ? allApps
                : allApps.where((a) => a.appName.toLowerCase().contains(query)).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.85,
              expand: false,
              builder: (_, scrollController) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    // Title
                    Text(
                      'Choose App',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select which app to open on swipe',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Search field
                    TextField(
                      controller: searchController,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search apps...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                        prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.3), size: 20),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // App list
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final app = filtered[i];
                          return GestureDetector(
                            onTap: () {
                              onSelect(SwipeAction.openApp, appPackage: app.packageName);
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                app.appName,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Double Tap picker ──

  void _showDoubleTapActionPicker(BuildContext context, WidgetRef ref) {
    final gold = ref.read(themeColorProvider).color;
    final current = ref.read(doubleTapProvider).action;

    final emojiMap = <DoubleTapAction, IconData>{
      DoubleTapAction.lockScreen: Icons.lock_outline_rounded,
      DoubleTapAction.flashlight: Icons.flashlight_on_rounded,
      DoubleTapAction.openCamera: Icons.camera_alt_outlined,
      DoubleTapAction.openApp: Icons.launch_rounded,
      DoubleTapAction.expandNotifications: Icons.notifications_outlined,
      DoubleTapAction.quickAccess: Icons.bolt_rounded,
      DoubleTapAction.none: Icons.do_not_disturb_alt_rounded,
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottomPad = MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 16;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPad),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Double Tap',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose what happens when you double-tap on the home screen',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            ...DoubleTapAction.values.map((action) {
              final selected = action == current;
              return GestureDetector(
                onTap: () {
                  if (action == DoubleTapAction.openApp) {
                    Navigator.pop(ctx);
                    _showAppPickerForDoubleTap(context, ref);
                  } else {
                    ref.read(doubleTapProvider.notifier).setAction(action);
                    Navigator.pop(ctx);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? gold.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? gold.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected
                              ? gold.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(emojiMap[action] ?? Icons.touch_app_rounded,
                            size: 18,
                            color: selected ? gold : Colors.white.withValues(alpha: 0.55)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              action.label,
                              style: TextStyle(
                                color: selected ? gold : Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              action.description,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle_rounded,
                            color: gold.withValues(alpha: 0.8), size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
        );
      },
    );
  }

  void _showAppPickerForDoubleTap(BuildContext context, WidgetRef ref) {
    final allApps = ref.read(installedAppsProvider);
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final query = searchController.text.toLowerCase();
            final filtered = query.isEmpty
                ? allApps
                : allApps.where((a) => a.appName.toLowerCase().contains(query)).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.85,
              expand: false,
              builder: (_, scrollController) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    Text(
                      'Choose App',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select which app to open on double-tap',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: searchController,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search apps...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                        prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.3), size: 20),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final app = filtered[i];
                          return GestureDetector(
                            onTap: () {
                              ref.read(doubleTapProvider.notifier).setAction(
                                DoubleTapAction.openApp,
                                appPackage: app.packageName,
                              );
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                app.appName,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsItem({
    IconData? icon,
    Widget? iconWidget,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color? accentColor,
    int badge = 0,
    bool isLight = false,
  }) {
    final accent = accentColor ?? const Color(0xFFC2A366);
    final primaryText = isLight ? const Color(0xFF0D0D0D) : Colors.white;
    final itemBg = isLight
        ? Colors.black.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.03);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: itemBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Icon with optional badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: iconWidget != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: iconWidget,
                        )
                      : Icon(icon ?? Icons.circle_outlined,
                          color: accent.withValues(alpha: 0.6), size: 18),
                ),
                if (badge > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Center(
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: primaryText.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: primaryText.withValues(alpha: 0.35),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: primaryText.withValues(alpha: 0.2),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicatorToggle(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(pageIndicatorProvider);
    final themeColor = ref.watch(themeColorProvider);
    final accent = themeColor.color;
    final isLight = themeColor.isLight;
    final primaryText = isLight ? const Color(0xFF0D0D0D) : Colors.white;
    final itemBg = isLight
        ? Colors.black.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.03);
    final toggleTrackOff = isLight
        ? Colors.black.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.1);
    final toggleThumbOff = isLight ? Colors.black.withValues(alpha: 0.3) : Colors.white38;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: itemBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.more_horiz_rounded,
                color: accent.withValues(alpha: 0.6), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Page Indicator',
                  style: TextStyle(
                    color: primaryText.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  isEnabled ? 'Dots visible on all pages' : 'Hidden',
                  style: TextStyle(
                    color: primaryText.withValues(alpha: 0.35),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              ref.read(pageIndicatorProvider.notifier).toggle();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 24,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isEnabled
                    ? accent.withValues(alpha: 0.3)
                    : toggleTrackOff,
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: isEnabled ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isEnabled ? accent : toggleThumbOff,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBarToggle(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(displaySettingsProvider);
    final isEnabled = settings.showStatusBar;
    final themeColor = ref.watch(themeColorProvider);
    final accent = themeColor.color;
    final isLight = themeColor.isLight;
    final primaryText = isLight ? const Color(0xFF0D0D0D) : Colors.white;
    final itemBg = isLight
        ? Colors.black.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.03);
    final toggleTrackOff = isLight
        ? Colors.black.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.1);
    final toggleThumbOff = isLight ? Colors.black.withValues(alpha: 0.3) : Colors.white38;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: itemBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.signal_cellular_alt_rounded,
                color: accent.withValues(alpha: 0.6), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Bar',
                  style: TextStyle(
                    color: primaryText.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  isEnabled ? 'Visible on home screen' : 'Hidden for minimalism',
                  style: TextStyle(
                    color: primaryText.withValues(alpha: 0.35),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              ref.read(displaySettingsProvider.notifier).setShowStatusBar(!isEnabled);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 24,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isEnabled
                    ? accent.withValues(alpha: 0.3)
                    : toggleTrackOff,
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: isEnabled ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isEnabled ? accent : toggleThumbOff,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardAutoOpenToggle(BuildContext context, WidgetRef ref, Color accent) {

    final isEnabled = ref.watch(keyboardAutoOpenProvider);
    final isLight = ref.watch(themeColorProvider).isLight;
    final primaryText = isLight ? const Color(0xFF0D0D0D) : Colors.white;
    final itemBg = isLight
        ? Colors.black.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.03);
    final toggleTrackOff = isLight
        ? Colors.black.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.1);
    final toggleThumbOff = isLight ? Colors.black.withValues(alpha: 0.3) : Colors.white38;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: itemBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.keyboard_rounded,
                color: accent.withValues(alpha: 0.6), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-Open Keyboard',
                  style: TextStyle(
                    color: primaryText.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  isEnabled ? 'Opens when App List appears' : 'Tap search bar to type',
                  style: TextStyle(
                    color: primaryText.withValues(alpha: 0.35),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              ref.read(keyboardAutoOpenProvider.notifier).toggle();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 24,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isEnabled
                    ? accent.withValues(alpha: 0.3)
                    : toggleTrackOff,
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: isEnabled ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isEnabled ? accent : toggleThumbOff,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTimeFormatDialog(
    BuildContext context,
    WidgetRef ref,
    TimeFormat currentFormat,
  ) {
    final accent = ref.read(themeColorProvider).color;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141414),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: accent.withValues(alpha: 0.15),
            ),
          ),
          title: const Text(
            'Time Format',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTimeFormatOption(
                context,
                ref,
                '12-Hour (AM/PM)',
                TimeFormat.hour12,
                currentFormat,
              ),
              const SizedBox(height: 8),
              _buildTimeFormatOption(
                context,
                ref,
                '24-Hour',
                TimeFormat.hour24,
                currentFormat,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeFormatOption(
    BuildContext context,
    WidgetRef ref,
    String label,
    TimeFormat format,
    TimeFormat currentFormat,
  ) {
    final isSelected = format == currentFormat;
    final gold = ref.read(themeColorProvider).color;
    return InkWell(
      onTap: () {
        ref.read(timeFormatProvider.notifier).setTimeFormat(format);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? gold.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? gold.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected
                  ? gold
                  : Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateUsBanner(Color accent, {required bool isLight}) {
    final primaryText = isLight ? const Color(0xFF0D0D0D) : Colors.white;
    final bannerBg = isLight
        ? Colors.black.withValues(alpha: 0.02)
        : Colors.white.withValues(alpha: 0.02);
    return InkWell(
      onTap: () async {
        await requestSukoonReview();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bannerBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.amber.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
              ),
              child: Icon(
                Icons.star_rounded,
                size: 22,
                color: Colors.amber.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rate Sukoon',
                    style: TextStyle(
                      color: primaryText.withValues(alpha: 0.9),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Your review helps other Muslims find us',
                    style: TextStyle(
                      color: primaryText.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // 3 mini stars
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (_) => Padding(
                padding: const EdgeInsets.only(left: 1),
                child: Icon(Icons.star_rounded,
                    size: 14, color: Colors.amber.withValues(alpha: 0.5)),
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportBanner(BuildContext context, AppThemeColor currentTheme) {
    final accent = currentTheme.color;
    final isLight = currentTheme.isLight;
    final primaryText = isLight ? const Color(0xFF0D0D0D) : Colors.white;
    final bannerBg = isLight
        ? Colors.black.withValues(alpha: 0.02)
        : Colors.white.withValues(alpha: 0.02);
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DonationScreen()),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bannerBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accent.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(
                  'assets/app_icon.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Support Sukoon',
                    style: TextStyle(
                      color: primaryText.withValues(alpha: 0.9),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'All features free — donate as sadaqah jariyah',
                    style: TextStyle(
                      color: primaryText.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: accent.withValues(alpha: 0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showHadithDownloadDialog(BuildContext context, WidgetRef ref, Color accent) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final stats = ref.watch(offlineContentProvider);
          return AlertDialog(
            backgroundColor: const Color(0xFF141414),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: accent.withValues(alpha: 0.1)),
            ),
            title: Row(
              children: [
                Icon(Icons.cloud_download_rounded, color: accent, size: 24),
                const SizedBox(width: 12),
                const Text('Offline Hadith',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   if (stats.isDownloading) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      color: accent,
                      backgroundColor: accent.withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      stats.currentItem ?? 'Downloading...',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    const Text(
                      'Select a collection to download for offline reading.',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: HadithCollection.collections.length,
                        itemBuilder: (context, i) {
                          final c = HadithCollection.collections[i];
                          final isDownloaded = stats.downloadedCollections[c.id] ?? false;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(c.name,
                                style: const TextStyle(color: Colors.white, fontSize: 14)),
                            subtitle: Text('${c.totalHadiths} hadiths',
                                style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            trailing: isDownloaded 
                                ? Icon(Icons.check_circle_rounded, color: accent, size: 18)
                                : Icon(Icons.download_rounded,
                                    color: accent.withValues(alpha: 0.5), size: 18),
                            onTap: isDownloaded ? null : () {
                              ref.read(offlineContentProvider.notifier).downloadBook(c);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(stats.isDownloading ? 'Run in Background' : 'Close',
                    style: TextStyle(color: accent)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmClearHadithCache(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.red, width: 0.5),
        ),
        title: const Text('Clear Cache?',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text(
          'This will delete all offline hadith data from your device storage.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              ref.read(offlineContentProvider.notifier).clearHadithCache();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Offline hadiths cleared'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Clear All',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
