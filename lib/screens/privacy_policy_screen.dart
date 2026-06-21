import 'package:flutter/material.dart';
import '../widgets/swipe_back_wrapper.dart';

/// Privacy Policy Screen - Full privacy policy for Play Store & Razorpay compliance
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
                child: _buildPrivacyPolicyContent(context),
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
          const Expanded(
            child: Text(
              'Privacy Policy',
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

  Widget _buildPrivacyPolicyContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          title: 'Last updated: 2 April 2026',
          content:
              'Sukoon Launcher ("we", "our", or "the app") is a peaceful Islamic launcher application designed for a focused, mindful digital life. Your privacy is very important to us. This Privacy Policy explains how we handle information when you use our application.\n\nBy using this app, you agree to the practices described in this policy.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '1. Information We Collect',
          content:
              '• We do not collect, store, or sell any personal data.\n\n'
              '• All user preferences — including wallpaper selection, favorites, hidden apps, prayer records, dhikr counts, Pomodoro history, app block rules, fasting logs, charity logs, Calm Watch saved videos, and settings — are stored locally on your device only using Hive local storage.\n\n'
              '• We do not require you to create an account.\n\n'
              '• No analytics, tracking, or telemetry data is collected or transmitted.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '2. Location Access',
          content:
              '• The app requests location permission (GPS and network) solely to calculate accurate prayer times (Salah times) and Qibla direction based on your geographic coordinates.\n\n'
              '• Location data is processed on-device only and is never transmitted, stored on any server, or shared with third parties.\n\n'
              '• Granting location permission is optional — you can manually set your location in settings if preferred.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '3. App Usage Access Permission',
          content:
              '• If you enable the App Timer or App Blocker features, the app may request Usage Access permission.\n\n'
              '• Usage data is processed only on your device to show you how long you spend in each app and to enforce time limits you set.\n\n'
              '• We do not collect, store, or transmit app usage information to any server.\n\n'
              '• Granting this permission is entirely optional.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '4. Notification Access',
          content:
              '• If you enable the Notification Filter feature, the app requests Notification Listener permission to capture and display your notifications inside the launcher.\n\n'
              '• Notification data is cached locally on your device and never transmitted externally.\n\n'
              '• This feature allows you to manage, filter, and dismiss notifications without leaving the launcher.\n\n'
              '• Granting this permission is entirely optional.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '5. Installed Apps Information',
          content:
              '• As a launcher application, Sukoon reads the list of installed applications that have a launcher activity, in order to display, search, and launch apps on your home screen and app drawer.\n\n'
              '• This information is processed entirely on your device and is never transmitted, uploaded, or shared with any server or third party.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '6. Alarms, Notifications & Background Services',
          content:
              '• The app uses exact alarm scheduling (SCHEDULE_EXACT_ALARM) to deliver Prayer Alarms (Salah Wake) at precise prayer times.\n\n'
              '• The app uses a foreground service for the App Blocker feature to monitor and enforce app time limits you configure.\n\n'
              '• The app may show notifications for prayer reminders, Pomodoro timer completion, and app time-limit alerts.\n\n'
              '• Wake Lock permission is used to ensure alarm sounds play reliably even when the screen is off.\n\n'
              '• Boot Completed permission is used to restart the App Blocker service after device reboot.\n\n'
              '• All alarm and notification data is stored and processed locally.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '7. Overlay & Do Not Disturb',
          content:
              '• The app uses System Alert Window (overlay) permission for the Kahf Mode feature, which displays a full-screen focus overlay and blocks notification bar pull-down during focus sessions.\n\n'
              '• Do Not Disturb (DND) access is requested to silence notifications during Kahf Mode sessions.\n\n'
              '• These permissions are only used when you actively start a Kahf Mode session.\n\n'
              '• Granting these permissions is entirely optional.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '8. Device Admin',
          content:
              '• The app optionally requests Device Admin privilege solely for the double-tap-to-lock-screen feature.\n\n'
              '• This permission is never used to control, wipe, or modify your device in any other way.\n\n'
              '• You can revoke Device Admin at any time in Android Settings.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '9. Qur\'an & Islamic Content',
          content:
              '• The app displays Qur\'an verses, Hadith, Duas, and Adhkar for inspiration and reading purposes.\n\n'
              '• All Islamic content is stored locally for offline use.\n\n'
              '• Translation sources are credited in the app\'s Credits section.\n\n'
              '• We do not track or collect reading activity.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '10. Voluntary Donations & Payment Processing',
          content:
              '• The app offers optional voluntary donations to support development. Donating is completely optional and does not unlock or restrict any features — the entire app is free.\n\n'
              '• Donations may be processed through the following trusted third-party payment processors:\n\n'
              '  – Razorpay (razorpay.com) — a PCI-DSS compliant payment gateway regulated by the Reserve Bank of India (RBI).\n'
              '  – PayPal (paypal.com) — a globally trusted payment platform.\n'
              '  – Ko-fi (ko-fi.com) — a voluntary support platform.\n\n'
              '• We do not store, access, or process any payment card details, bank account information, UPI IDs, or billing information. All payment data is handled entirely by the respective payment processor.\n\n'
              '• Razorpay may collect certain information (name, email, phone number, payment instrument details) as required to process transactions. This data is governed by Razorpay\'s own Privacy Policy (https://razorpay.com/privacy/).\n\n'
              '• We only receive transaction confirmation (success/failure status and transaction ID) — no sensitive financial data is shared with us.\n\n'
              '• All donations are voluntary, and by proceeding with payment, you agree to the terms of the respective payment processor.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '11. Refund & Cancellation Policy',
          content:
              '• All donations made through the app are voluntary contributions (sadaqah) to support the development and maintenance of Sukoon Launcher.\n\n'
              '• Since donations are not payments for goods or services, they are generally non-refundable.\n\n'
              '• However, if a transaction was made in error (e.g., duplicate payment, unauthorized transaction, or technical glitch), you may request a refund by contacting us within 7 days of the transaction.\n\n'
              '• To request a refund, please email us at mewatxpro2@gmail.com with your transaction ID, payment method, date of transaction, and reason for the refund request.\n\n'
              '• Refund requests will be reviewed within 5–7 business days. If approved, the refund will be processed to the original payment method within 7–10 business days.\n\n'
              '• Cancellation: Since donations are one-time voluntary payments (not subscriptions), there is no recurring billing to cancel. Each donation is a single, standalone transaction.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '12. Terms of Service',
          content:
              '• By using Sukoon Launcher, you agree to the following terms:\n\n'
              '• License: You are granted a non-exclusive, non-transferable license to use the app on your personal Android device.\n\n'
              '• Free to Use: All features of the app are provided free of charge. No purchases are required to access any functionality.\n\n'
              '• Voluntary Donations: Any donations you make are entirely voluntary and are used to support development, server infrastructure, and community growth. Donations do not constitute a purchase and do not entitle you to any additional features or services beyond what is already freely available.\n\n'
              '• Content Accuracy: While we strive to provide accurate Islamic content (prayer times, Qur\'an text, Hadith, Duas), we do not guarantee absolute accuracy. Users should verify with qualified scholars for religious rulings.\n\n'
              '• No Warranty: The app is provided "as is" without warranties of any kind, express or implied.\n\n'
              '• Limitation of Liability: We shall not be liable for any direct, indirect, incidental, or consequential damages arising from the use of this app.\n\n'
              '• Modifications: We reserve the right to modify, update, or discontinue any feature of the app at any time.\n\n'
              '• Governing Law: These terms shall be governed by and construed in accordance with the laws of India.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '13. Internet Access',
          content:
              '• Internet permission is used for:\n\n'
              '  – Fetching prayer times from the Aladhan API.\n\n'
              '  – Processing voluntary donations via Razorpay, PayPal, or Ko-fi.\n\n'
              '  – Downloading Hadith content for offline access from hadithapi.com.\n\n'
              '  – Fetching video titles from YouTube\'s public oEmbed API when you save a link to Calm Watch.\n\n'
              '• Calm Watch uses the YouTube IFrame Player API (YouTube\'s official embedding method) to play videos inside the app. No personal data is sent to YouTube.\n\n'
              '• No other personal data is ever transmitted over the network.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '14. Storage & Media Access',
          content:
              '• The app may request storage/media access to let you select custom alarm sounds from your device.\n\n'
              '• Files are read locally and never uploaded or transmitted.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '15. Third-Party Services',
          content:
              'The app uses trusted third-party services including:\n\n'
              '• Aladhan API (for prayer time calculation)\n\n'
              '• Razorpay (for voluntary donation processing — razorpay.com/privacy)\n\n'
              '• PayPal (for voluntary donation processing — paypal.com/privacy)\n\n'
              '• Ko-fi (for voluntary support — ko-fi.com/privacy)\n\n'
              '• hadithapi.com (for Hadith content)\n\n'
              '• YouTube IFrame Player API (for Calm Watch in-app video playback)\n\n'
              '• YouTube oEmbed API (for fetching video titles in Calm Watch)\n\n'
              'These services operate under their own privacy policies. No personal data is shared with any third-party service except as required for payment processing.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '16. Children\'s Privacy',
          content:
              'This app does not knowingly collect any personal information from children under the age of 13.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '17. Data Security',
          content:
              'All user data and settings are stored locally on the device using encrypted local storage. No data is transmitted to external servers. We take reasonable steps to protect the app from unauthorized access.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '18. Changes to This Policy',
          content:
              'We may update this Privacy Policy from time to time. Any changes will be reflected on this page with an updated date.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '19. Merchant / Developer Information',
          content:
              'App Name: Sukoon Launcher\n\n'
              'Developer: Abu Bakar (Sukoon Foundation)\n\n'
              'Registered Address: India\n\n'
              'Email: mewatxpro2@gmail.com\n\n'
              'Website: https://sukoon-launcher.web.app (if applicable)\n\n'
              'This information is provided as required by payment processors (Razorpay, PayPal) for merchant verification.',
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: '20. Contact Us',
          content:
              'If you have any questions, concerns, or refund requests regarding this Privacy Policy, you may contact us at:\n\n'
              '📧 mewatxpro2@gmail.com\n\n'
              '💬 WhatsApp: +91 81711 14186\n\n'
              'We aim to respond to all inquiries within 48 hours.',
        ),
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
            fontSize: 16,
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
}
