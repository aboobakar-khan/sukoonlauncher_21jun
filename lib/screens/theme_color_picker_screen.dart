import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../widgets/swipe_back_wrapper.dart';

/// Theme Color Picker Screen — all colors unlocked
class ThemeColorPickerScreen extends ConsumerWidget {
  const ThemeColorPickerScreen({super.key});

  // ── Grouped color sections ────────────────────────────────────────────────
  static final _brandSection = [ThemeColors.sukoon];

  static final _neutralSection = [ThemeColors.white, ThemeColors.slate];

  static final _warmSection = [
    ThemeColors.gold,
    ThemeColors.amber,
    ThemeColors.orange,
    ThemeColors.peach,
    ThemeColors.rose,
    ThemeColors.warmRed,
    ThemeColors.coral,
    ThemeColors.crimson,
  ];

  static final _coolSection = [
    ThemeColors.blue,
    ThemeColors.skyBlue,
    ThemeColors.cyan,
    ThemeColors.aqua,
    ThemeColors.teal,
    ThemeColors.indigo,
  ];

  static final _natureSection = [
    ThemeColors.green,
    ThemeColors.emerald,
    ThemeColors.mint,
    ThemeColors.sage,
    ThemeColors.lavender,
    ThemeColors.lilac,
    ThemeColors.purple,
    ThemeColors.pink,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeColorProvider);
    final isLight = currentTheme.isLight;
    final bgColor = isLight ? const Color(0xFFF5F5F5) : Colors.black;
    final primaryText = isLight ? const Color(0xFF0D0D0D) : Colors.white;

    return SwipeBackWrapper(
      child: Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(child: _buildHeader(context, isLight: isLight, primaryText: primaryText)),

            // Brand
            _buildSectionHeader('BRAND', primaryText: primaryText),
            _buildColorGrid(context, ref, _brandSection, currentTheme, primaryText: primaryText),

            // Neutral
            _buildSectionHeader('NEUTRAL', primaryText: primaryText),
            _buildColorGrid(context, ref, _neutralSection, currentTheme, primaryText: primaryText),

            // Warm
            _buildSectionHeader('WARM', primaryText: primaryText),
            _buildColorGrid(context, ref, _warmSection, currentTheme, primaryText: primaryText),

            // Cool
            _buildSectionHeader('COOL', primaryText: primaryText),
            _buildColorGrid(context, ref, _coolSection, currentTheme, primaryText: primaryText),

            // Nature
            _buildSectionHeader('NATURE', primaryText: primaryText),
            _buildColorGrid(context, ref, _natureSection, currentTheme, primaryText: primaryText),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    ),
    );
  }

  SliverToBoxAdapter _buildSectionHeader(String label, {required Color primaryText}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.5,
            color: primaryText.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }

  SliverPadding _buildColorGrid(
    BuildContext context,
    WidgetRef ref,
    List<AppThemeColor> colors,
    AppThemeColor currentTheme, {
    required Color primaryText,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final theme = colors[index];
            final isSelected = theme.name == currentTheme.name;
            return _buildColorOption(context, ref, theme, isSelected, primaryText: primaryText);
          },
          childCount: colors.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, {required bool isLight, required Color primaryText}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryText.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: primaryText.withValues(alpha: 0.7),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme Color',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${ThemeColors.all.length} beautiful colors',
                style: TextStyle(
                  fontSize: 12,
                  color: primaryText.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorOption(
    BuildContext context,
    WidgetRef ref,
    AppThemeColor theme,
    bool isSelected, {
    required Color primaryText,
  }) {
    final isLight = ref.read(themeColorProvider).isLight;
    return GestureDetector(
      onTap: () {
        ref.read(themeColorProvider.notifier).setThemeColor(theme);
        Navigator.of(context).pop();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.color
                : (isLight ? Colors.black : Colors.white).withValues(alpha: 0.08),
            width: isSelected ? 2.5 : 1,
          ),
          gradient: LinearGradient(
            colors: [
              theme.color.withValues(alpha: 0.25),
              theme.accentColor.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Color name and circle
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.color.withValues(alpha: 0.4),
                          blurRadius: isSelected ? 12 : 6,
                          spreadRadius: isSelected ? 2 : 0,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    theme.name,
                    style: TextStyle(
                      color: primaryText.withValues(alpha: isSelected ? 0.9 : 0.65),
                      fontSize: 11,
                      letterSpacing: 0.5,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Selected indicator
            if (isSelected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: theme.color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.black, size: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
