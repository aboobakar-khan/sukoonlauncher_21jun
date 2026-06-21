import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/theme_provider.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Donation Screen — Support Sukoon Launcher
/// ═══════════════════════════════════════════════════════════════════════
/// 
/// Professional, theme-consistent donation page with Razorpay.
/// All features are free — donations are voluntary acts of sadaqah.
/// ═══════════════════════════════════════════════════════════════════════

class DonationScreen extends ConsumerStatefulWidget {
  const DonationScreen({super.key});

  @override
  ConsumerState<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends ConsumerState<DonationScreen>
    with SingleTickerProviderStateMixin {

  late final AnimationController _animController;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(themeColorProvider).color;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: _buildDonationView(accent, bottomInset),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DONATION VIEW
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDonationView(Color accent, double bottomInset) {
    return Column(
      children: [
        // Header
        _buildHeader(accent),
        
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset > 0 ? bottomInset + 20 : 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Story section
                _buildStorySection(accent),

                const SizedBox(height: 28),

                // Where your support goes
                _buildWhyItMatters(accent),

                const SizedBox(height: 28),

                // Sadaqah Jariyah note
                _buildSadaqahNote(accent),

                const SizedBox(height: 24),

                // UPI direct button
                _buildUpiButton(accent),

                // Ko-fi button (with its own "or" divider)
                _buildKofiButton(accent),

                const SizedBox(height: 24),

                // Disclaimer
                _buildDisclaimer(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new_rounded, 
              color: Colors.white.withValues(alpha: 0.6), size: 20),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_open_rounded, size: 12, 
                  color: Colors.green.withValues(alpha: 0.8)),
                const SizedBox(width: 4),
                Text('All Features Free',
                  style: TextStyle(
                    color: Colors.green.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorySection(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon + Title
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.12),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/app_icon.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Support Sukoon',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Every contribution matters',
                    style: TextStyle(
                      color: accent.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 20),

        // The story
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ٱلسَّلَامُ عَلَيْكُمْ وَرَحْمَةُ ٱللَّٰهِ وَبَرَكَاتُهُ',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent.withValues(alpha: 0.7),
                  fontSize: 18,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'I had one problem — ten different apps, most of them paid. And the Muslim who couldn\'t afford it? Just left out.\n\n'
                
                'That didn\'t feel right.\n\n'
                
                'So I built Sukoon. Quran, hadith, dua, dhikr, salah tracker, app blocker — everything in one place. Free. Always. InshāAllah.\n\n'
                
                'Other launchers charge monthly (2-3 dollars/month). I chose not to. Because deen is not a luxury — every Muslim deserves access, whether they have money or not.\n\n'
                
                'Allah is the best rewarder. That is enough for me.\n\n'
                
                'Now it\'s in your hands.\n\n'
                
                'Your support keeps this app running, updated, and reaching Muslims who need it. Every rupee you give becomes sadaqah jariyah — continuous reward, long after this moment passes.\n\n'
                
                'Donate. Share. Make du\'a. Every action counts.\n\n'
                
                'May Allah make your sadaqah a light on your path — in this world and the next. 🤲',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13.5,
                  height: 1.65,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '— Abu Bakar · Made with love, for the Ummah ❤️',
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWhyItMatters(Color accent) {
    final items = [
      (Icons.code_rounded,        'Development',       'New features & bug fixes'),
      (Icons.cloud_outlined,      'Infrastructure',    'Prayer times, Quran & updates'),
      (Icons.people_outline_rounded, 'Growing the Ummah', 'Reaching Muslims who need this'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where your support goes',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(item.$1, color: accent.withValues(alpha: 0.5), size: 15),
              const SizedBox(width: 10),
              Text(
                item.$2,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '·  ${item.$3}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildUpiButton(Color accent) {
    const upiId = '8171114186@ibl';
    // upi://pay scheme — supported by GPay, PhonePe, Paytm, BHIM, etc.
    final upiUri = Uri.parse(
      'upi://pay?pa=$upiId&pn=Abu%20Bakar&cu=INR&tn=Donation%20for%20Sukoon%20Launcher',
    );
    // Fallback: open a web search if no UPI app is installed
    const webFallback = 'https://upi.sbi.co.in/';

    return GestureDetector(
      onTap: () async {
        try {
          final launched = await launchUrl(
            upiUri,
            mode: LaunchMode.externalApplication,
          );
          if (!launched) throw Exception('No UPI app');
        } catch (_) {
          await launchUrl(
            Uri.parse(webFallback),
            mode: LaunchMode.externalApplication,
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF6C63FF).withValues(alpha: 0.18),
              const Color(0xFF6C63FF).withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.currency_rupee_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Donate via UPI',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.bolt_rounded,
                  size: 15,
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.8),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // UPI ID — shown so user can copy manually
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 10,
                  color: Colors.white.withValues(alpha: 0.20),
                ),
                const SizedBox(width: 5),
                Text(
                  upiId,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.30),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKofiButton(Color accent) {
    const kofiUrl = 'https://ko-fi.com/aboobakar';

    return GestureDetector(
      onTap: () async {
        try {
          await launchUrl(
            Uri.parse(kofiUrl),
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {}
      },
      child: Column(
        children: [
          // "or" divider
          Row(
            children: [
              Expanded(
                  child: Divider(
                      color: Colors.white.withValues(alpha: 0.06), height: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'or',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.18),
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(
                  child: Divider(
                      color: Colors.white.withValues(alpha: 0.06), height: 1)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4ADE80).withValues(alpha: 0.15),
                  const Color(0xFF4ADE80).withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF4ADE80).withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4ADE80).withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4ADE80).withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_cafe_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Donate via Ko-fi',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.favorite_rounded,
                  size: 14,
                  color: const Color(0xFF4ADE80).withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSadaqahNote(Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.green.withValues(alpha: 0.5), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Sadaqah Jariyah: ',
                    style: TextStyle(
                      color: Colors.green.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  TextSpan(
                    text: 'Supporting an app that helps people pray, '
                        'remember Allah, and live mindfully — '
                        'the reward continues for as long as people benefit, '
                        'in shā Allāh.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        'All features are free forever. Donations are voluntary and '
        'non-refundable. No personal data is stored.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.15),
          fontSize: 10,
          height: 1.4,
        ),
      ),
    );
  }



}



/// Helper function to show donation screen from anywhere
void showDonationScreen(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, _, _) => const DonationScreen(),
      transitionsBuilder: (context, anim, _, child) {
        return FadeTransition(opacity: anim, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    ),
  );
}
