import 'package:flutter/material.dart';
import '../widgets/swipe_back_wrapper.dart';

/// Credits & Licenses Screen - Attribution for Qur'an and other resources
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SwipeBackWrapper(
      child: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildCreditsContent(context),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/app_icon.png',
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Credits & Licenses',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Qur'an ─────────────────────────────────────────────
        _buildSection(
          title: '📖 Qur\'an Text & Translation',
          content:
              'This application includes Qur\'an text and translations for reading and reflection.',
        ),
        const SizedBox(height: 20),
        _buildLicenseCard(
          title: 'Arabic Qur\'an Text',
          description:
              'The Arabic Qur\'an text is sourced from public domain datasets based on the Uthmanic script.',
          license: 'Public Domain',
        ),
        const SizedBox(height: 16),
        _buildLicenseCard(
          title: 'English Translation',
          description:
              'English translation of the Qur\'an meanings provided by public domain sources.\n\n'
              'The translation is used for educational and spiritual purposes.\n\n'
              'Note: This is a translation of the meanings and is not a substitute for the original Arabic text.',
          license: 'Public Domain / Open License',
        ),
        const SizedBox(height: 16),
        _buildLicenseCard(
          title: 'Qur\'an Data Source',
          description:
              'Qur\'an data structure and organization inspired by open-source Islamic resources.\n\n'
              'We acknowledge the contributions of the global Muslim open-source community in making Qur\'an data accessible.',
          license: 'Various Open Licenses',
        ),
        const SizedBox(height: 32),
        const Divider(color: Colors.white24, thickness: 1),
        const SizedBox(height: 32),

        // ── Prayer Times ───────────────────────────────────────
        _buildSection(
          title: '🕌 Prayer Times',
          content: 'Accurate prayer time calculation is powered by an external API service.',
        ),
        const SizedBox(height: 20),
        _buildLicenseCard(
          title: 'Aladhan Prayer Times API',
          description:
              'Prayer times are fetched from the Aladhan API (api.aladhan.com).\n\n'
              'This free public API provides prayer times based on multiple calculation methods '
              '(ISNA, MWL, Egyptian, Umm Al-Qura, etc.).',
          license: 'Free Public API',
        ),
        const SizedBox(height: 32),
        const Divider(color: Colors.white24, thickness: 1),
        const SizedBox(height: 32),

        // ── Audio ──────────────────────────────────────────────
        _buildSection(
          title: '🔊 Audio & Sounds',
          content: 'Ambient sounds and audio used in the app:',
        ),
        const SizedBox(height: 20),
        _buildLicenseCard(
          title: 'Ambient Sounds',
          description:
              'Waterfall and nature ambient sounds sourced from Chosic.com and other royalty-free sound libraries.\n\n'
              'Used for Kahf Mode and Pomodoro focus sessions.',
          license: 'Royalty-Free / Creative Commons',
        ),
        const SizedBox(height: 32),
        const Divider(color: Colors.white24, thickness: 1),
        const SizedBox(height: 32),

        // ── Design & Icons ─────────────────────────────────────
        _buildSection(
          title: '🎨 Design & Icons',
          content: 'This application uses carefully selected resources:',
        ),
        const SizedBox(height: 20),
        _buildLicenseCard(
          title: 'Material Design Icons',
          description: 'Icons provided by Google\'s Material Design.',
          license: 'Apache License 2.0',
        ),
        const SizedBox(height: 16),
        _buildLicenseCard(
          title: 'Google Fonts',
          description: 'Typography powered by Google Fonts — fonts are downloaded on-demand and cached locally.',
          license: 'Apache License 2.0 / SIL Open Font License',
        ),
        const SizedBox(height: 16),
        _buildLicenseCard(
          title: 'Lottie Animations',
          description: 'Animated backgrounds using Lottie by Airbnb.',
          license: 'Apache License 2.0',
        ),
        const SizedBox(height: 32),
        const Divider(color: Colors.white24, thickness: 1),
        const SizedBox(height: 32),

        // ── Payment ────────────────────────────────────────────
        _buildSection(
          title: '💳 Payment Processing',
          content: 'Donation payments are handled securely:',
        ),
        const SizedBox(height: 20),
        _buildLicenseCard(
          title: 'Razorpay',
          description:
              'Voluntary donation payments are processed via Razorpay.\n\n'
              'We do not store any payment or card information. '
              'All transactions are handled securely by Razorpay.',
          license: 'Razorpay SDK License',
        ),
        const SizedBox(height: 32),
        const Divider(color: Colors.white24, thickness: 1),
        const SizedBox(height: 32),

        // ── Open-Source Packages ────────────────────────────────
        _buildSection(
          title: '📦 Open-Source Packages',
          content:
              'This app is built with Flutter and relies on the following open-source packages:',
        ),
        const SizedBox(height: 20),
        _buildLicenseCard(
          title: 'Flutter & Dart',
          description: 'Cross-platform UI toolkit by Google.',
          license: 'BSD 3-Clause License',
        ),
        const SizedBox(height: 12),
        _buildLicenseCard(
          title: 'flutter_riverpod',
          description: 'Reactive state management for Flutter.',
          license: 'MIT License',
        ),
        const SizedBox(height: 12),
        _buildLicenseCard(
          title: 'Hive & hive_flutter',
          description: 'Lightweight, fast key-value database for local storage.',
          license: 'Apache License 2.0',
        ),
        const SizedBox(height: 12),
        _buildLicenseCard(
          title: 'geolocator',
          description: 'GPS location access for prayer time calculation.',
          license: 'MIT License',
        ),
        const SizedBox(height: 12),
        _buildLicenseCard(
          title: 'flutter_local_notifications',
          description: 'Local notification scheduling for prayer alarms.',
          license: 'BSD 3-Clause License',
        ),
        const SizedBox(height: 12),
        _buildLicenseCard(
          title: 'android_alarm_manager_plus',
          description: 'Background alarm scheduling for precise prayer times.',
          license: 'BSD 3-Clause License',
        ),
        const SizedBox(height: 12),
        _buildLicenseCard(
          title: 'audioplayers',
          description: 'Audio playback for ambient sounds and alarm tones.',
          license: 'MIT License',
        ),
        const SizedBox(height: 12),
        _buildLicenseCard(
          title: 'Other packages',
          description:
              'intl, hijri, table_calendar, uuid, http, share_plus, connectivity_plus, '
              'image_picker, file_picker, in_app_update, installed_apps, '
              'shared_preferences, permission_handler, url_launcher, timezone.',
          license: 'Various (BSD / MIT / Apache)',
        ),
        const SizedBox(height: 12),
        // Link to Flutter's built-in license page
        GestureDetector(
          onTap: () {
            showLicensePage(
              context: context,
              applicationName: 'Sukoon Launcher',
              applicationVersion: '1.2.1',
              applicationLegalese: '© 2026 Sukoon Launcher. All rights reserved.',
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.open_in_new, color: Colors.white.withValues(alpha: 0.6), size: 16),
                const SizedBox(width: 8),
                Text(
                  'View All Open-Source Licenses',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 32),
        const Divider(color: Colors.white24, thickness: 1),
        const SizedBox(height: 32),

        // ── Acknowledgments ────────────────────────────────────
        _buildSection(
          title: '💙 Acknowledgments',
          content:
              'We are deeply grateful to:\n\n'
              '• The global Muslim community for preserving and sharing the Qur\'an\n\n'
              '• Open-source contributors who make Islamic resources accessible\n\n'
              '• The Flutter community for building amazing tools\n\n'
              '• Aladhan.com for providing free prayer time data\n\n'
              '• All users who support this project through donations',
        ),
        const SizedBox(height: 32),
        _buildDisclaimerCard(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            height: 1.6,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildLicenseCard({
    required String title,
    required String description,
    required String license,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.5,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'License: $license',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade300, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Important Note',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'While we strive for accuracy, the English translation is a translation of meanings and should not replace reading the original Arabic Qur\'an.\n\n'
            'For religious study, please consult qualified scholars and authentic sources.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
