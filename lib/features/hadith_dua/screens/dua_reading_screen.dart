import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../models/hadith_dua_models.dart';
import '../../../providers/islamic_theme_provider.dart';

/// Enhanced immersive reading screen with toggles and progress
class DuaReadingScreen extends ConsumerStatefulWidget {
  final Dua initialDua;
  final List<Dua> allDuas;
  final int initialIndex;

  const DuaReadingScreen({
    super.key,
    required this.initialDua,
    required this.allDuas,
    required this.initialIndex,
  });

  @override
  ConsumerState<DuaReadingScreen> createState() => _DuaReadingScreenState();
}

class _DuaReadingScreenState extends ConsumerState<DuaReadingScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showTransliteration = true;
  bool _showTranslation = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = ref.watch(islamicThemeColorsProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: tc.background,
        statusBarIconBrightness: tc.statusBarBrightness,
        systemNavigationBarColor: tc.background,
        systemNavigationBarIconBrightness: tc.statusBarBrightness,
      ),
      child: Scaffold(
        backgroundColor: tc.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, tc),
              _buildProgressIndicator(tc),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.allDuas.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemBuilder: (_, index) => _buildDuaPage(
                    widget.allDuas[index],
                    tc,
                  ),
                ),
              ),
              _buildBottomControls(tc),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, IslamicThemeColors tc) {
    final currentDua = widget.allDuas[_currentIndex];
    
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      decoration: BoxDecoration(
        color: tc.background,
        border: Border(
          bottom: BorderSide(
            color: tc.surface.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.close,
              color: tc.text.withValues(alpha: 0.6),
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentDua.title,
                  style: TextStyle(
                    color: tc.text.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (currentDua.category != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    currentDua.category!.toUpperCase(),
                    style: TextStyle(
                      color: tc.textSecondary.withValues(alpha: 0.35),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _buildShareButton(tc, currentDua),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(IslamicThemeColors tc) {
    final progress = widget.allDuas.length > 1
        ? (_currentIndex + 1) / widget.allDuas.length
        : 1.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_currentIndex + 1}',
                style: TextStyle(
                  color: tc.green.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                ' / ${widget.allDuas.length}',
                style: TextStyle(
                  color: tc.textSecondary.withValues(alpha: 0.4),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: tc.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(1),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: tc.green.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDuaPage(Dua dua, IslamicThemeColors tc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ornamental top divider
          _buildOrnamentalDivider(tc),
          const SizedBox(height: 28),

          // Large Arabic text (centered)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
            decoration: BoxDecoration(
              color: tc.surface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              dua.arabicText,
              style: TextStyle(
                color: tc.arabicText.withValues(alpha: 0.95),
                fontSize: 28,
                height: 2.2,
                fontFamily: 'Amiri',
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 24),

          // Divider
          _buildOrnamentalDivider(tc),

          const SizedBox(height: 24),

          // Transliteration (toggleable)
          if (_showTransliteration && dua.transliteration.isNotEmpty) ...[
            _buildSectionLabel('Transliteration', tc),
            const SizedBox(height: 10),
            Text(
              dua.transliteration,
              style: TextStyle(
                color: tc.textSecondary.withValues(alpha: 0.6),
                fontSize: 16,
                fontStyle: FontStyle.italic,
                height: 1.8,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],

          // Translation (toggleable)
          if (_showTranslation) ...[
            _buildSectionLabel('Translation', tc),
            const SizedBox(height: 10),
            Text(
              dua.translation,
              style: TextStyle(
                color: tc.text.withValues(alpha: 0.85),
                fontSize: 17,
                height: 1.9,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Source
          if (dua.source != null && dua.source!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tc.surface.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: tc.surface.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 16,
                    color: tc.textSecondary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Source: ',
                    style: TextStyle(
                      color: tc.textSecondary.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      dua.source!,
                      style: TextStyle(
                        color: tc.textSecondary.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Repeat Count
          if (dua.repeatCount != null && dua.repeatCount! > 1) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tc.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: tc.accent.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.repeat_rounded,
                    size: 18,
                    color: tc.accent.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Recite ${dua.repeatCount} times',
                    style: TextStyle(
                      color: tc.accent.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Benefit/Reward
          if (dua.benefit != null && dua.benefit!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tc.surface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: tc.accent.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.stars_rounded,
                        size: 16,
                        color: tc.accent.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Benefit & Reward',
                        style: TextStyle(
                          color: tc.accent.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    dua.benefit!,
                    style: TextStyle(
                      color: tc.textSecondary.withValues(alpha: 0.75),
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          const SizedBox(height: 32),

          // Swipe hint
          Center(
            child: Text(
              '← swipe for more →',
              style: TextStyle(
                color: tc.textSecondary.withValues(alpha: 0.2),
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildOrnamentalDivider(IslamicThemeColors tc) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  tc.accent.withValues(alpha: 0.3),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '✦',
              style: TextStyle(
                fontSize: 8,
                color: tc.accent.withValues(alpha: 0.3),
              ),
            ),
          ),
          Container(
            width: 40,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  tc.accent.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, IslamicThemeColors tc) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: tc.green.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: tc.textSecondary.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(IslamicThemeColors tc) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: tc.background,
        border: Border(
          top: BorderSide(
            color: tc.surface.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toggle buttons row
          Row(
            children: [
              Expanded(
                child: _buildToggleButton(
                  label: 'Transliteration',
                  isActive: _showTransliteration,
                  onTap: () {
                    setState(() => _showTransliteration = !_showTransliteration);
                  },
                  tc: tc,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildToggleButton(
                  label: 'Translation',
                  isActive: _showTranslation,
                  onTap: () {
                    setState(() => _showTranslation = !_showTranslation);
                  },
                  tc: tc,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Navigation row
          Row(
            children: [
              _buildNavButton(
                icon: Icons.chevron_left,
                enabled: _currentIndex > 0,
                onTap: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                },
                tc: tc,
              ),
              const Spacer(),
              _buildCopyButton(tc),
              const Spacer(),
              _buildNavButton(
                icon: Icons.chevron_right,
                enabled: _currentIndex < widget.allDuas.length - 1,
                onTap: () {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                },
                tc: tc,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required IslamicThemeColors tc,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? tc.green.withValues(alpha: 0.12)
              : tc.surface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? tc.green.withValues(alpha: 0.3)
                : tc.surface.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.visibility : Icons.visibility_off,
              size: 14,
              color: isActive
                  ? tc.green.withValues(alpha: 0.7)
                  : tc.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? tc.green.withValues(alpha: 0.8)
                    : tc.textSecondary.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    required IslamicThemeColors tc,
  }) {
    return GestureDetector(
      onTap: enabled
          ? () {
              onTap();
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: enabled
              ? tc.surface.withValues(alpha: 0.5)
              : tc.surface.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: enabled
              ? tc.text.withValues(alpha: 0.6)
              : tc.textSecondary.withValues(alpha: 0.2),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildCopyButton(IslamicThemeColors tc) {
    final currentDua = widget.allDuas[_currentIndex];
    
    return GestureDetector(
      onTap: () {
        final text = '${currentDua.arabicText}\n\n'
            '${currentDua.transliteration}\n\n'
            '${currentDua.translation}\n\n'
            '— ${currentDua.source ?? "Islamic Dua"}';
        
        Clipboard.setData(ClipboardData(text: text));
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Copied to clipboard',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: tc.green,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tc.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.copy_rounded,
          color: tc.textSecondary.withValues(alpha: 0.5),
          size: 18,
        ),
      ),
    );
  }

  Widget _buildShareButton(IslamicThemeColors tc, Dua dua) {
    return GestureDetector(
      onTap: () {
        final text = '${dua.title}\n\n'
            '${dua.arabicText}\n\n'
            '${dua.transliteration}\n\n'
            '${dua.translation}\n\n'
            '— ${dua.source ?? "Islamic Dua"}';
        
        Share.share(text);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: tc.surface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.share_rounded,
          color: tc.textSecondary.withValues(alpha: 0.5),
          size: 18,
        ),
      ),
    );
  }
}
