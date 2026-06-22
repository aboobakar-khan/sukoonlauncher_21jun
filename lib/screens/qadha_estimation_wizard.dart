import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/qadha_provider.dart';
import '../providers/theme_provider.dart';

/// Qadha Estimation Wizard — calm, one-question-per-screen guided flow
/// to help users estimate their lifetime missed prayers.
class QadhaEstimationWizard extends ConsumerStatefulWidget {
  const QadhaEstimationWizard({super.key});

  @override
  ConsumerState<QadhaEstimationWizard> createState() =>
      _QadhaEstimationWizardState();
}

class _QadhaEstimationWizardState
    extends ConsumerState<QadhaEstimationWizard> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Wizard answers
  int? _yearsNotPraying;
  String? _missFrequency;
  String? _estimationStyle;
  int? _estimatedTotal;

  // Custom year input
  final _customYearController = TextEditingController();
  bool _showCustomYear = false;

  @override
  void dispose() {
    _pageController.dispose();
    _customYearController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(themeColorProvider).color;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with back + progress
            _buildTopBar(accent),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildStep1(accent),
                  _buildStep2(accent),
                  _buildStep3(accent),
                  _buildResultPage(accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: _prevPage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back_ios_new,
                  color: Colors.white.withValues(alpha: 0.7), size: 18),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Qadha Estimation',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (_currentPage + 1) / 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation(accent.withValues(alpha: 0.6)),
                    minHeight: 3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 1: When did you start praying regularly?
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStep1(Color accent) {
    final options = [
      {'label': 'Always prayed', 'years': 0, 'sub': 'AlHamdulillah'},
      {'label': 'Last 1 year', 'years': 1, 'sub': 'Started recently'},
      {'label': 'Last 2–3 years', 'years': 3, 'sub': 'A few years ago'},
      {'label': 'Last 5 years', 'years': 5, 'sub': 'Half a decade'},
      {'label': 'More than 5 years', 'years': 10, 'sub': 'A long time'},
      {'label': 'Custom', 'years': -1, 'sub': 'Enter exact years'},
    ];

    return _buildQuestionPage(
      icon: Icons.calendar_today_rounded,
      question: 'When did you start\npraying regularly?',
      subtitle: 'Think about when you became consistent with 5 daily prayers.',
      accent: accent,
      child: Column(
        children: [
          ...options.map((opt) {
            final years = opt['years'] as int;
            final isSelected = !_showCustomYear && _yearsNotPraying == years;
            final isCustom = years == -1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  if (isCustom) {
                    setState(() => _showCustomYear = true);
                  } else {
                    setState(() {
                      _yearsNotPraying = years;
                      _showCustomYear = false;
                    });
                    if (years == 0) {
                      // No qadha needed
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('MashaAllah! No qadha needed.'),
                          backgroundColor: accent.withValues(alpha: 0.8),
                        ),
                      );
                      return;
                    }
                    Future.delayed(const Duration(milliseconds: 300), _nextPage);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accent.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? accent.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt['label'] as String,
                              style: TextStyle(
                                color: isSelected
                                    ? accent
                                    : Colors.white.withValues(alpha: 0.85),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              opt['sub'] as String,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded,
                            color: accent, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
          // Custom year input
          if (_showCustomYear) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customYearController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Years not praying',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: accent.withValues(alpha: 0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: accent.withValues(alpha: 0.5)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    final years =
                        int.tryParse(_customYearController.text) ?? 0;
                    if (years > 0) {
                      setState(() {
                        _yearsNotPraying = years;
                      });
                      _nextPage();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.arrow_forward_rounded,
                        color: accent, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 2: How often did you miss?
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStep2(Color accent) {
    final options = [
      {
        'label': 'Rarely',
        'value': 'rarely',
        'sub': 'Missed a few here and there',
        'icon': Icons.spa_outlined,
      },
      {
        'label': 'Sometimes',
        'value': 'sometimes',
        'sub': 'Missed regularly but not daily',
        'icon': Icons.cloud_outlined,
      },
      {
        'label': 'Often',
        'value': 'often',
        'sub': 'Missed most prayers',
        'icon': Icons.nights_stay_outlined,
      },
      {
        'label': 'Almost all',
        'value': 'almost_all',
        'sub': 'Rarely prayed during that time',
        'icon': Icons.dark_mode_outlined,
      },
    ];

    return _buildQuestionPage(
      icon: Icons.timeline_rounded,
      question: 'Before that, how often\ndid you miss salah?',
      subtitle: "Be honest with yourself. There's no judgment here.",
      accent: accent,
      child: Column(
        children: options.map((opt) {
          final isSelected = _missFrequency == opt['value'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () {
                setState(() => _missFrequency = opt['value'] as String);
                Future.delayed(const Duration(milliseconds: 300), _nextPage);
              },
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? accent.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      opt['icon'] as IconData,
                      color: isSelected
                          ? accent
                          : Colors.white.withValues(alpha: 0.4),
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt['label'] as String,
                            style: TextStyle(
                              color: isSelected
                                  ? accent
                                  : Colors.white.withValues(alpha: 0.85),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            opt['sub'] as String,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded,
                          color: accent, size: 20),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 3: Choose estimation style
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStep3(Color accent) {
    final options = [
      {
        'label': 'Conservative',
        'value': 'conservative',
        'sub': 'Lower estimate — start lighter',
        'icon': Icons.shield_outlined,
      },
      {
        'label': 'Balanced',
        'value': 'balanced',
        'sub': 'Recommended — middle ground',
        'icon': Icons.balance_rounded,
      },
      {
        'label': 'Strict',
        'value': 'strict',
        'sub': 'Higher estimate — be thorough',
        'icon': Icons.gavel_rounded,
      },
    ];

    return _buildQuestionPage(
      icon: Icons.tune_rounded,
      question: 'Choose your\nestimation style',
      subtitle: 'This adjusts how many prayers are estimated. You can always change it later.',
      accent: accent,
      child: Column(
        children: options.map((opt) {
          final isSelected = _estimationStyle == opt['value'];
          final isBalanced = opt['value'] == 'balanced';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _estimationStyle = opt['value'] as String;
                  _estimatedTotal = QadhaEstimation.calculate(
                    yearsNotPraying: _yearsNotPraying ?? 0,
                    missFrequency: _missFrequency ?? 'sometimes',
                    estimationStyle: _estimationStyle!,
                  );
                });
                Future.delayed(const Duration(milliseconds: 300), _nextPage);
              },
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? accent.withValues(alpha: 0.4)
                        : isBalanced
                            ? accent.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      opt['icon'] as IconData,
                      color: isSelected
                          ? accent
                          : Colors.white.withValues(alpha: 0.4),
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                opt['label'] as String,
                                style: TextStyle(
                                  color: isSelected
                                      ? accent
                                      : Colors.white.withValues(alpha: 0.85),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (isBalanced) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Recommended',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: accent,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            opt['sub'] as String,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded,
                          color: accent, size: 20),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESULT PAGE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildResultPage(Color accent) {
    final total = _estimatedTotal ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: [
          const Spacer(),

          // Glowing circle with number
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.06),
              border: Border.all(color: accent.withValues(alpha: 0.15), width: 2),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.08),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '~${_formatNumber(total)}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  'prayers',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'Estimated Qadha',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          // Breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBreakdownItem(
                    '${_yearsNotPraying ?? 0}', 'Years', accent),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                _buildBreakdownItem(
                    _missFrequency?.replaceAll('_', ' ').toUpperCase() ?? '',
                    'Frequency',
                    accent),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                _buildBreakdownItem(
                    _estimationStyle?.substring(0, 3).toUpperCase() ?? '',
                    'Style',
                    accent),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Note
          Text(
            'This is only an estimate.\nYour sincere intention matters most.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 13,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),

          const Spacer(),

          // Accept button
          GestureDetector(
            onTap: () {
              final estimation = QadhaEstimation(
                yearsNotPraying: _yearsNotPraying ?? 0,
                missFrequency: _missFrequency ?? 'sometimes',
                estimationStyle: _estimationStyle ?? 'balanced',
                estimatedTotal: total,
              );
              ref
                  .read(qadhaRecordProvider.notifier)
                  .applyEstimation(estimation);
              Navigator.pop(context);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_rounded, color: accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Accept Estimate',
                    style: TextStyle(
                      color: accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Edit manually
          GestureDetector(
            onTap: () {
              // Close wizard, go back so the manual setup shows
              Navigator.pop(context, 'manual');
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  'Edit Manually',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(String value, String label, Color accent) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: accent,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED QUESTION LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildQuestionPage({
    required IconData icon,
    required String question,
    required String subtitle,
    required Color accent,
    required Widget child,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(height: 24),
          Text(
            question,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k'.replaceAll('.0k', 'k');
    }
    return '$n';
  }
}
