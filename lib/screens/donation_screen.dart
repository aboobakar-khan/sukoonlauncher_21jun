import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/theme_provider.dart';
import '../utils/review_helper.dart';

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
    with TickerProviderStateMixin, WidgetsBindingObserver {

  // Razorpay live key — repo is private, key is safe here
  static const String _razorpayKey = 'rzp_live_SLKDKAometXIBI';

  /// Static flag survives activity recreation (Razorpay opens external
  /// checkout which may kill the Flutter activity on low-memory devices).
  static bool _pendingSuccess = false;

  late final Razorpay _razorpay;
  late final AnimationController _animController;
  late final Animation<double> _fadeIn;
  late final AnimationController _thankYouController;
  late final Animation<double> _thankYouFade;

  int? _selectedAmountIndex;
  final _customController = TextEditingController();
  // Retained for when Razorpay card payments are re-enabled
  // ignore: unused_field
  bool _isProcessing = false;
  bool _showThankYou = false;
  final FocusNode _customFocusNode = FocusNode();

  // 3 clean presets — USD shown, INR charged via Razorpay.
  // International cards (Visa/MC/Amex) from any country work — 
  // the donor's bank does the currency conversion automatically.
  static const List<_DonationPreset> _presets = [
    _DonationPreset(
      amountInr: 249,
      displayUsd: 3,
      label: 'Bārakah',
      impact: 'A cup of chai. Keeps this deen-first app alive.',
    ),
    _DonationPreset(
      amountInr: 749,
      displayUsd: 9,
      label: 'Sadaqah',
      impact: 'Your salah reminder reached someone today because of this.',
    ),
    _DonationPreset(
      amountInr: 1249,
      displayUsd: 15,
      label: 'Jazākallāh',
      impact: 'Funds a month of building tools that bring us closer to Allah.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    _thankYouController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _thankYouFade = CurvedAnimation(
        parent: _thankYouController, curve: Curves.easeOut);

    // If a previous success was pending (activity recreated), show thank you
    if (_pendingSuccess) {
      _pendingSuccess = false;
      _showThankYou = true;
      _thankYouController.forward(from: 0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingSuccess) {
      _pendingSuccess = false;
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _showThankYou = true;
        });
        HapticFeedback.heavyImpact();
        _thankYouController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _razorpay.clear();
    _animController.dispose();
    _thankYouController.dispose();
    _customController.dispose();
    _customFocusNode.dispose();
    super.dispose();
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    _pendingSuccess = true; // persist across potential activity recreation
    if (!mounted) return;
    _pendingSuccess = false;
    setState(() {
      _isProcessing = false;
      _showThankYou = true;
    });
    HapticFeedback.heavyImpact();
    _thankYouController.forward(from: 0);
  }

  void _onPaymentError(PaymentFailureResponse response) {
    setState(() => _isProcessing = false);
    if (!mounted) return;
    
    final code = response.code ?? 0;
    // Don't show error for user-cancelled payments
    if (code == 2) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Something went wrong. Please try again.',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    setState(() => _isProcessing = false);
  }

  int _getAmount() {
    if (_selectedAmountIndex != null && _selectedAmountIndex! < _presets.length) {
      return _presets[_selectedAmountIndex!].amountInr;
    }
    // Custom amount — user enters their own INR value
    final text = _customController.text.trim();
    if (text.isNotEmpty) {
      final parsed = int.tryParse(text);
      if (parsed != null && parsed > 0) return parsed;
    }
    return 0;
  }

  // Retained for when Razorpay card payments are re-enabled
  // ignore: unused_element
  void _startPayment() {
    final amount = _getAmount();
    if (amount <= 0 || amount > 50000) return; // cap at ₹50,000 (~$600)

    setState(() => _isProcessing = true);
    _customFocusNode.unfocus();

    final options = {
      'key': _razorpayKey,
      'amount': amount * 100,   // Razorpay uses paise (1 INR = 100 paise)
      'currency': 'INR',        // Razorpay Indian merchants process in INR
      'name': 'Sukoon Launcher',
      'description': 'Sadaqah — Support Sukoon',
      'theme': {
        'color': '#1A1A1A',
      },
      'modal': {
        'confirm_close': true,
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() => _isProcessing = false);
      debugPrint('Razorpay error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(themeColorProvider).color;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _showThankYou
            ? FadeTransition(
                opacity: _thankYouFade,
                child: _buildThankYouView(accent),
              )
            : FadeTransition(
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

                // Donation tiers
                _buildDonationTiers(accent),

                const SizedBox(height: 20),

                // Custom amount
                _buildCustomAmount(accent),

                const SizedBox(height: 28),

                // Donate button
                _buildDonateButton(accent),

                // PayPal alternative (contains its own "or" divider)
                _buildPayPalButton(accent),

                const SizedBox(height: 20),

                // Sadaqah Jariyah note
                _buildSadaqahNote(accent),

                const SizedBox(height: 20),

                // Rate Sukoon — in-app review
                _buildRateUsCard(accent),

                const SizedBox(height: 12),

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
                '2am. Isha unprayed. 3 hours gone to a screen.\n\n'

'"When did I become someone who chooses this over Allah ﷻ?"\n\n'

'That one question changed everything.\n\n'

'I wanted a phone that blocked the noise.\n'
'That protected salah like it mattered.\n'
'That made Qur\'an, dhikr and prayer easy to reach.\n\n'

'So I built Sukoon. Nights of code. Months of du\'a.\n\n'

'You\'ve used it. You know the difference —\n'
'a phone that serves your deen, not steals it.\n\n'

'No investors. No company behind this.\n'
'Just one person making sure it stays free. Always.\n\n'

'Because the second it becomes about money —\n'
'it becomes like everything else.\n\n'

'If this app has helped you —\n'
'support it as sadaqah jariyah.\n'
'Every Muslim it guides back,\n'
'that reward is yours too.\n\n'

'Can\'t give? Share it. Rate us on the Play Store.\n'
'Seconds of your time.\n'
'Possibly a lifetime of reward.\n\n'

'Imagine that on your scale of deeds.\n\n'

'JazākAllāhu Khayran.\n'
'May Allah ﷻ accept from us all. 🤲',
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
                  '— Abu Bakar, Developer',
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

  Widget _buildDonationTiers(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHOOSE AN AMOUNT',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.30),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(_presets.length, (i) {
          final preset = _presets[i];
          final isSelected = _selectedAmountIndex == i;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedAmountIndex = i;
                _customController.clear();
                _customFocusNode.unfocus();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? accent.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.07),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  // Selection indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? accent : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? accent
                            : Colors.white.withValues(alpha: 0.18),
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 12)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  // Label + impact
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset.label,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.95)
                                : Colors.white.withValues(alpha: 0.65),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          preset.impact,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.45)
                                : Colors.white.withValues(alpha: 0.25),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${preset.displayUsd}',
                        style: TextStyle(
                          color: isSelected
                              ? accent
                              : Colors.white.withValues(alpha: 0.80),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${preset.amountInr}',
                        style: TextStyle(
                          color: isSelected
                              ? accent.withValues(alpha: 0.45)
                              : Colors.white.withValues(alpha: 0.20),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCustomAmount(Color accent) {
    final isCustomActive = _selectedAmountIndex == null &&
        _customController.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "or" divider
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.07), height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'or enter your own',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.22),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.07), height: 1)),
          ],
        ),
        const SizedBox(height: 14),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          decoration: BoxDecoration(
            color: isCustomActive
                ? accent.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCustomActive
                  ? accent.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.07),
              width: isCustomActive ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Text(
                '₹',
                style: TextStyle(
                  color: isCustomActive
                      ? accent.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.25),
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _customController,
                  focusNode: _customFocusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Any amount',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.15),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onTap: () => setState(() => _selectedAmountIndex = null),
                  onChanged: (_) => setState(() {
                    if (_selectedAmountIndex != null) _selectedAmountIndex = null;
                  }),
                ),
              ),
              if (isCustomActive)
                Icon(Icons.check_circle_rounded,
                    color: accent.withValues(alpha: 0.55), size: 18),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            'International donors: \$1 ≈ ₹83  ·  Enter ₹ equivalent',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.18),
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDonateButton(Color accent) {
    final amount = _getAmount();
    final hasAmount = amount > 0;
    final isLightAccent = hasAmount && accent.computeLuminance() > 0.4;
    final onAccentColor = isLightAccent
        ? Colors.black.withValues(alpha: 0.80)
        : Colors.white;

    return Column(
      children: [
        // Primary CTA — Razorpay temporarily disabled, shows alternative sheet
        GestureDetector(
          onTap: hasAmount ? () => _showPaymentDownSheet(accent) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 17),
            decoration: BoxDecoration(
              gradient: hasAmount
                  ? LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.80)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: hasAmount ? null : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasAmount) ...[
                    Icon(Icons.favorite_rounded,
                        size: 13,
                        color: onAccentColor.withValues(alpha: 0.7)),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    hasAmount
                        ? (_selectedAmountIndex != null
                            ? 'Donate \$${_presets[_selectedAmountIndex!].displayUsd}  ·  ₹$amount'
                            : 'Donate ₹$amount')
                        : 'Select an amount to continue',
                    style: TextStyle(
                      color: hasAmount
                          ? onAccentColor
                          : Colors.white.withValues(alpha: 0.22),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasAmount) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 11,
                  color: Colors.white.withValues(alpha: 0.18)),
              const SizedBox(width: 5),
              Text(
                'Card payments temporarily unavailable — see alternatives',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.18),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Shows a bottom sheet explaining Razorpay is down and offering
  /// PayPal + UPI as immediate alternatives.
  void _showPaymentDownSheet(Color accent) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          24, 20, 24,
          24 + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Icon + title row
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.construction_rounded,
                      color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Card payments are temporarily down',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'We\'re updating our payment key. Use one of the options below.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // UPI option
            _paymentOptionTile(
              context: ctx,
              icon: Icons.phone_android_rounded,
              title: 'Pay via UPI',
              subtitle: '8171114186@kotak811',
              accentColor: accent,
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(
                  const ClipboardData(text: '8171114186@kotak811'),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('UPI ID copied to clipboard'),
                    backgroundColor: const Color(0xFF1A1A1A),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // PayPal option
            _paymentOptionTile(
              context: ctx,
              icon: Icons.open_in_new_rounded,
              title: 'Pay via PayPal',
              subtitle: 'paypal.me/khnnabubakar786',
              accentColor: accent,
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await launchUrl(
                    Uri.parse('https://www.paypal.com/webapps/shoppingcart?flowlogging_id=f897778242485&mfid=1773517838347_f897778242485#/checkout/openButton'),
                    mode: LaunchMode.externalApplication,
                  );
                } catch (_) {
                  await launchUrl(
                    Uri.parse('https://paypal.me/khnnabubakar786'),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
            ),

            const SizedBox(height: 20),

            Center(
              child: Text(
                'JazākAllāh Khayr for your patience 🤍',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentOptionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: accentColor.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w400)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.2), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPayPalButton(Color accent) {
    // Direct checkout link — opens PayPal cart/checkout page.
    // paypal.me/<username> kept as fallback.
    const paypalUrl = 'https://www.paypal.com/webapps/shoppingcart?flowlogging_id=f897778422485&mfid=1773517838347_f897778242485#/checkout/openButton';
    const paypalFallback = 'https://paypal.me/khnnabubakar786';
    const paypalEmail = 'khnnabubakar786@gmail.com'; // shown for manual send

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(paypalUrl);
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {
          // Fallback: open PayPal.me profile
          await launchUrl(
            Uri.parse(paypalFallback),
            mode: LaunchMode.externalApplication,
          );
        }
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
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF003087),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Text(
                          'P',
                          style: TextStyle(
                            color: Color(0xFF009CDE),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'Pay with PayPal',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(Icons.open_in_new_rounded,
                        size: 11,
                        color: Colors.white.withValues(alpha: 0.20)),
                  ],
                ),
                const SizedBox(height: 8),
                // PayPal ID — visible so users can send manually if link fails
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.alternate_email_rounded,
                        size: 10,
                        color: Colors.white.withValues(alpha: 0.18)),
                    const SizedBox(width: 5),
                    Text(
                      paypalEmail,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.28),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
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
        'non-refundable. Payments are processed securely via Razorpay. '
        'No personal data is stored.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.15),
          fontSize: 10,
          height: 1.4,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // RATE SUKOON — IN-APP REVIEW
  // ═══════════════════════════════════════════════════════════════

  Widget _buildRateUsCard(Color accent) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        await requestSukoonReview();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            // 5 stars row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(
                    Icons.star_rounded,
                    size: 30,
                    color: Colors.amber.withValues(alpha: 0.9),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),

            Text(
              'Rate Sukoon on Play Store',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),

            Text(
              'Can\'t donate? A review is just as valuable.\n'
              'It helps other Muslims discover Sukoon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // Tap to rate button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.20)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.rate_review_rounded,
                      size: 16, color: Colors.amber.withValues(alpha: 0.8)),
                  const SizedBox(width: 8),
                  Text(
                    'Tap to Rate',
                    style: TextStyle(
                      color: Colors.amber.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // THANK YOU VIEW
  // ═══════════════════════════════════════════════════════════════

  Widget _buildThankYouView(Color accent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Green checkmark
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green.withValues(alpha: 0.25), width: 2),
              ),
              child: Icon(Icons.check_rounded, color: Colors.green.withValues(alpha: 0.8), size: 40),
            ),
            const SizedBox(height: 24),

            Text(
              'جَزَاكَ ٱللَّٰهُ خَيْرًا',
              style: TextStyle(
                color: accent.withValues(alpha: 0.8),
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'May Allah reward you abundantly',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.025),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  Text(
                    '"Whoever guides someone to goodness will have '
                    'a reward like the one who does it."',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '— Prophet Muhammad ﷺ (Sahih Muslim)',
                    style: TextStyle(
                      color: accent.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Text(
              'Your support helps keep Sukoon free for everyone.\n'
              'May it be sadaqah jariyah for you and your family. 🤲',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                ),
                child: Text('Return to Sukoon',
                  style: TextStyle(
                    color: accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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

/// Data class for donation preset
class _DonationPreset {
  final int amountInr;     // charged via Razorpay (INR)
  final int displayUsd;    // shown to user (USD)
  final String label;
  final String impact;
  const _DonationPreset({
    required this.amountInr,
    required this.displayUsd,
    required this.label,
    required this.impact,
  });
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
