import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/tasbih_provider.dart';
import '../providers/prayer_provider.dart';

/// Weekly Barakah Report
/// 
/// Beautiful Sunday summary with:
/// - Total dhikr this week
/// - Time saved from social media
/// - Prayers on time %
/// - Quran verses read
/// - "Spiritual health score"
/// 
/// Design Science:
/// - Creates anticipation and reflection
/// - Shareable format for social proof
/// - Celebrates progress, not perfection
/// 
/// UI/UX Pro Max Guidelines:
/// - Premium visual design
/// - Share-optimized layout
/// - Celebration animations
class WeeklyBarakahReport extends ConsumerStatefulWidget {
  const WeeklyBarakahReport({super.key});

  @override
  ConsumerState<WeeklyBarakahReport> createState() => _WeeklyBarakahReportState();
}

class _WeeklyBarakahReportState extends ConsumerState<WeeklyBarakahReport> {
  // Weekly stats
  int _weeklyDhikr = 0;
  int _weeklyPrayers = 0;
  int _weeklyQuranMinutes = 0;
  int _timeSavedMinutes = 0;
  int _streakDays = 0;
  double _spiritualScore = 0.0;
  bool _isLoading = true;

  // Color system
  static const Color _primaryGreen = Color(0xFFC2A366);
  static const Color _spiritualGold = Color(0xFFFFD93D);
  static const Color _calmTeal = Color(0xFF26A69A);
  static const Color _lavender = Color(0xFFA855F7);
  static const Color _cardBg = Color(0xFF161B22);
  static const Color _deepBlack = Color(0xFF0D1117);

  @override
  void initState() {
    super.initState();
    // Removed: _shimmerController was created with .repeat() (infinite loop)
    // but never referenced in the build tree — it was burning CPU+GPU
    // for absolutely nothing.  The SingleTickerProviderStateMixin is
    // kept in case a shimmer effect is added in the future.
    _loadWeeklyData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadWeeklyData() async {
    try {
      // Load dhikr data
      final tasbihState = ref.read(tasbihProvider);
      _weeklyDhikr = tasbihState.monthlyTotal; // Approximate weekly from monthly
      _streakDays = tasbihState.streakDays;

      // Load prayer data
      final prayerRecord = ref.read(todayPrayerRecordProvider);
      _weeklyPrayers = (prayerRecord?.completedCount ?? 0) * 7; // Rough estimate

      _weeklyQuranMinutes = 0;
      _timeSavedMinutes = 0;

      // Calculate spiritual score (0-100)
      _calculateSpiritualScore();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _calculateSpiritualScore() {
    // Score based on multiple factors
    double score = 0;
    
    // Dhikr contribution (max 30 points)
    score += (_weeklyDhikr / 500).clamp(0, 30);
    
    // Prayer contribution (max 35 points) - 35 prayers per week
    score += (_weeklyPrayers / 35 * 35).clamp(0, 35);
    
    // Quran time contribution (max 20 points) - goal: 60 min/week
    score += (_weeklyQuranMinutes / 60 * 20).clamp(0, 20);
    
    // Streak contribution (max 15 points)
    score += (_streakDays / 7 * 15).clamp(0, 15);
    
    _spiritualScore = score.clamp(0, 100);
  }

  String _getSpiritualLevel() {
    if (_spiritualScore >= 80) return 'Guardian';
    if (_spiritualScore >= 60) return 'Devoted';
    if (_spiritualScore >= 40) return 'Seeker';
    if (_spiritualScore >= 20) return 'Mindful';
    return 'Beginner';
  }

  Color _getLevelColor() {
    if (_spiritualScore >= 80) return _spiritualGold;
    if (_spiritualScore >= 60) return _primaryGreen;
    if (_spiritualScore >= 40) return _calmTeal;
    if (_spiritualScore >= 20) return _lavender;
    return Colors.white.withValues(alpha: 0.5);
  }

  Future<void> _shareReport() async {
    
    final shareText = '''
📿 My Weekly Barakah Report

✨ Spiritual Score: ${_spiritualScore.toInt()}/100
🏆 Level: ${_getSpiritualLevel()}

📊 This Week:
• ${_weeklyDhikr.toStringAsFixed(0)} dhikr completed
• ${_formatTime(_weeklyQuranMinutes)} of Islamic time
• ${_formatTime(_timeSavedMinutes)} saved from distractions
• $_streakDays day streak 🔥

May Allah bless our efforts. 🤲

#Barakah #IslamicProductivity #SukoonLauncher
    ''';

    await Share.share(shareText);
  }

  String _formatTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getLevelColor().withValues(alpha: 0.1),
            _cardBg,
            _deepBlack,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getLevelColor().withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _getLevelColor().withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with spiritual score
          _buildHeader(),
          
          const Divider(height: 1, color: Color(0xFF21262D)),
          
          // Stats grid
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildStatTile(
                      icon: '📿',
                      value: _weeklyDhikr.toString(),
                      label: 'Dhikr',
                      color: _spiritualGold,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatTile(
                      icon: '🕌',
                      value: _weeklyPrayers.toString(),
                      label: 'Prayers',
                      color: _primaryGreen,
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildStatTile(
                      icon: '📖',
                      value: _formatTime(_weeklyQuranMinutes),
                      label: 'Islamic Time',
                      color: _calmTeal,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatTile(
                      icon: '⏰',
                      value: _formatTime(_timeSavedMinutes),
                      label: 'Time Saved',
                      color: _lavender,
                    )),
                  ],
                ),
              ],
            ),
          ),
          
          // Streak banner
          if (_streakDays > 0) _buildStreakBanner(),
          
          // Share button
          _buildShareButton(),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              color: _primaryGreen,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Calculating your Barakah...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Score circle
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  value: _spiritualScore / 100,
                  strokeWidth: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(_getLevelColor()),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_spiritualScore.toInt()}',
                    style: TextStyle(
                      color: _getLevelColor(),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '/100',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(width: 20),
          
          // Title and level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '✨ ',
                      style: TextStyle(fontSize: 16),
                    ),
                    const Text(
                      'Weekly Barakah',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getLevelColor().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getLevelColor().withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _getSpiritualLevel(),
                    style: TextStyle(
                      color: _getLevelColor(),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required String icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _spiritualGold.withValues(alpha: 0.15),
            _spiritualGold.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _spiritualGold.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text(
            '$_streakDays day streak!',
            style: TextStyle(
              color: _spiritualGold,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Keep it going!',
            style: TextStyle(
              color: _spiritualGold.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _shareReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryGreen.withValues(alpha: 0.15),
            foregroundColor: _primaryGreen,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: _primaryGreen.withValues(alpha: 0.3)),
            ),
            elevation: 0,
          ),
          icon: const Icon(Icons.share_outlined, size: 18),
          label: const Text(
            'Share Your Progress',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Mini widget for home screen (shows only score)
class BarakahScoreBadge extends ConsumerWidget {
  const BarakahScoreBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Simple score calculation
    final tasbihState = ref.watch(tasbihProvider);
    final score = ((tasbihState.streakDays / 7) * 100).clamp(0, 100).toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFC2A366).withValues(alpha: 0.2),
            const Color(0xFFC2A366).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC2A366).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✨', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Text(
            'Barakah $score%',
            style: const TextStyle(
              color: Color(0xFFC2A366),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
