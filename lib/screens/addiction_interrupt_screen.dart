import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/usage_stats_provider.dart';
import '../utils/hive_box_manager.dart';

/// Addiction Interrupt System - THE KILLER FEATURE
/// 
/// When user tries to open Instagram/TikTok/etc., intercept with a 
/// beautiful "Pause Portal" offering:
/// - Breathing exercise
/// - Quick dhikr challenge (33 SubhanAllah to unlock)
/// - Time balance comparison
/// - Gentle escalation (1st = soft, 5th = harder)
/// 
/// Design Science:
/// - Friction Design: Add healthy friction to unhealthy choices
/// - Mindfulness Intervention: Break automatic behavior loops
/// - Choice Architecture: Make Islamic choice the easy choice
/// - Loss Aversion: Show what they're losing by scrolling
/// 
/// UI/UX Pro Max Guidelines:
/// - Dark Mode OLED optimized
/// - Smooth 300ms transitions
/// - Touch targets 44x44px minimum
/// - Loading states for async operations
class AddictionInterruptScreen extends ConsumerStatefulWidget {
  final String appName;
  final String packageName;
  final VoidCallback onProceed;
  final VoidCallback onCancel;

  const AddictionInterruptScreen({
    super.key,
    required this.appName,
    required this.packageName,
    required this.onProceed,
    required this.onCancel,
  });

  @override
  ConsumerState<AddictionInterruptScreen> createState() =>
      _AddictionInterruptScreenState();
}

class _AddictionInterruptScreenState
    extends ConsumerState<AddictionInterruptScreen>
    with TickerProviderStateMixin {
  // Professional color system
  static const Color _primaryGreen = Color(0xFFC2A366);
  static const Color _spiritualGold = Color(0xFFFFD93D);
  static const Color _warningRed = Color(0xFFDA3633);
  static const Color _calmTeal = Color(0xFF26A69A);
  static const Color _deepBlack = Color(0xFF0D1117);
  static const Color _cardBg = Color(0xFF161B22);
  static const Color _borderSubtle = Color(0xFF21262D);

  late AnimationController _breathController;
  late AnimationController _pulseController;
  late Animation<double> _breathAnimation;
  
  int _dhikrCount = 0;
  int _requiredDhikr = 33;
  bool _isBreathing = false;
  int _breathCycle = 0;
  int _todayInterrupts = 0;
  int _todayTimeWasted = 0;
  int _todayIslamicTime = 0;
  
  // Escalation levels
  InterruptLevel _level = InterruptLevel.gentle;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _breathAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _breathController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _breathController.reverse();
      } else if (status == AnimationStatus.dismissed && _isBreathing) {
        setState(() => _breathCycle++);
        if (_breathCycle < 3) {
          _breathController.forward();
        } else {
          setState(() => _isBreathing = false);
        }
      }
    });

    _loadInterruptData();
  }

  Future<void> _loadInterruptData() async {
    try {
      final box = await HiveBoxManager.get('addiction_interrupt');
      final today = DateTime.now().toIso8601String().substring(0, 10);
      
      setState(() {
        _todayInterrupts = box.get('interrupts_$today', defaultValue: 0);
        _level = _getInterruptLevel(_todayInterrupts);
        _requiredDhikr = _getRequiredDhikr(_level);
      });

      // Update interrupt count
      await box.put('interrupts_$today', _todayInterrupts + 1);

      // Load time data from usage stats
      final usageState = ref.read(usageStatsProvider);
      final summary = usageState.todaySummary;
      if (summary != null) {
        setState(() {
          _todayTimeWasted = summary.socialMinutes + summary.entertainmentMinutes;
          _todayIslamicTime = summary.islamicMinutes;
        });
      }
    } catch (e) {
      // Continue with defaults
    }
  }

  InterruptLevel _getInterruptLevel(int interrupts) {
    if (interrupts <= 2) return InterruptLevel.gentle;
    if (interrupts <= 5) return InterruptLevel.moderate;
    if (interrupts <= 10) return InterruptLevel.firm;
    return InterruptLevel.strong;
  }

  int _getRequiredDhikr(InterruptLevel level) {
    switch (level) {
      case InterruptLevel.gentle:
        return 11; // Quick check
      case InterruptLevel.moderate:
        return 33; // SubhanAllah x33
      case InterruptLevel.firm:
        return 66; // Two rounds
      case InterruptLevel.strong:
        return 100; // Full Istighfar
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _incrementDhikr() {
    setState(() {
      _dhikrCount++;
    });

    if (_dhikrCount >= _requiredDhikr) {
      _onDhikrComplete();
    }
  }

  Future<void> _onDhikrComplete() async {
    
    // Save dhikr to tasbih counter
    final box = await HiveBoxManager.get('tasbih_data');
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = box.get('lastDate', defaultValue: '');
    final currentTotal = (lastDate == today) 
        ? (box.get('todayCount', defaultValue: 0) as int)
        : 0;
    
    await box.put('todayCount', currentTotal + _dhikrCount);
    await box.put('lastDate', today);
    
    // Record that user earned access through dhikr
    final interruptBox = await HiveBoxManager.get('addiction_interrupt');
    await interruptBox.put('earned_through_dhikr_$today', true);
    
    // Show success and proceed
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _DhikrCompleteDialog(
          dhikrCount: _dhikrCount,
          onContinue: () {
            Navigator.pop(context);
            widget.onProceed();
          },
        ),
      );
    }
  }

  void _startBreathing() {
    setState(() {
      _isBreathing = true;
      _breathCycle = 0;
    });
    _breathController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _deepBlack,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Header with app info
              _buildHeader(),
              
              const SizedBox(height: 32),
              
              // Time comparison card
              _buildTimeComparisonCard(),
              
              const SizedBox(height: 24),
              
              // Dhikr challenge card
              _buildDhikrChallengeCard(),
              
              const SizedBox(height: 24),
              
              // Breathing exercise card
              if (_level != InterruptLevel.gentle)
                _buildBreathingCard(),
              
              const SizedBox(height: 32),
              
              // Action buttons
              _buildActionButtons(),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Pause icon with pulse
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.05),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _warningRed.withValues(alpha: 0.2),
                      _warningRed.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: _warningRed.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.pause_circle_outline,
                  color: _warningRed,
                  size: 40,
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 20),
        
        // Title
        Text(
          'Pause & Reflect',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // App being opened
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _warningRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _warningRed.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, 
                color: _warningRed.withValues(alpha: 0.7), size: 16),
              const SizedBox(width: 8),
              Text(
                'Opening ${widget.appName}',
                style: TextStyle(
                  color: _warningRed.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Interrupt level indicator
        Text(
          _getLevelMessage(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  String _getLevelMessage() {
    switch (_level) {
      case InterruptLevel.gentle:
        return 'Take a moment to reflect before you scroll.';
      case InterruptLevel.moderate:
        return 'This is your ${_todayInterrupts}th time today.\nLet\'s do some dhikr first.';
      case InterruptLevel.firm:
        return 'You\'ve been here $_todayInterrupts times today.\nYour time is precious.';
      case InterruptLevel.strong:
        return '$_todayInterrupts interrupts today.\nConsider if this aligns with your goals.';
    }
  }

  Widget _buildTimeComparisonCard() {
    final timeDiff = _todayIslamicTime - _todayTimeWasted;
    final isPositive = timeDiff >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderSubtle),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.balance, color: _calmTeal, size: 20),
              const SizedBox(width: 10),
              Text(
                'Today\'s Time Balance',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildTimeColumn(
                  icon: Icons.mosque,
                  label: 'Islamic',
                  minutes: _todayIslamicTime,
                  color: _primaryGreen,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: _borderSubtle,
              ),
              Expanded(
                child: _buildTimeColumn(
                  icon: Icons.phone_android,
                  label: 'Social',
                  minutes: _todayTimeWasted,
                  color: _warningRed,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Balance indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isPositive 
                  ? _primaryGreen.withValues(alpha: 0.1)
                  : _warningRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: isPositive ? _primaryGreen : _warningRed,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isPositive 
                      ? '+${timeDiff}m ahead on deen'
                      : '${timeDiff.abs()}m behind on deen',
                  style: TextStyle(
                    color: isPositive ? _primaryGreen : _warningRed,
                    fontSize: 13,
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

  Widget _buildTimeColumn({
    required IconData icon,
    required String label,
    required int minutes,
    required Color color,
  }) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final timeStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          timeStr,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildDhikrChallengeCard() {
    final progress = _dhikrCount / _requiredDhikr;
    final isComplete = _dhikrCount >= _requiredDhikr;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryGreen.withValues(alpha: isComplete ? 0.15 : 0.08),
            _cardBg,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete 
              ? _primaryGreen.withValues(alpha: 0.4)
              : _primaryGreen.withValues(alpha: 0.2),
          width: isComplete ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.favorite,
                  color: _primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dhikr to Unlock',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Tap to count SubhanAllah',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Progress badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isComplete 
                      ? _primaryGreen.withValues(alpha: 0.2)
                      : _spiritualGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_dhikrCount / $_requiredDhikr',
                  style: TextStyle(
                    color: isComplete ? _primaryGreen : _spiritualGold,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Tap area
          GestureDetector(
            onTap: isComplete ? null : _incrementDhikr,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isComplete
                      ? [_primaryGreen.withValues(alpha: 0.3), _primaryGreen.withValues(alpha: 0.1)]
                      : [_spiritualGold.withValues(alpha: 0.2), _spiritualGold.withValues(alpha: 0.05)],
                ),
                border: Border.all(
                  color: isComplete 
                      ? _primaryGreen.withValues(alpha: 0.5)
                      : _spiritualGold.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isComplete ? _primaryGreen : _spiritualGold).withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isComplete ? '✓' : 'سُبْحَانَ اللّٰهِ',
                    style: TextStyle(
                      fontSize: isComplete ? 36 : 18,
                      fontWeight: FontWeight.w600,
                      color: isComplete ? _primaryGreen : _spiritualGold,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  if (!isComplete) ...[
                    const SizedBox(height: 4),
                    Text(
                      'TAP',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.4),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Progress bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryGreen, _calmTeal],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryGreen.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          if (isComplete) ...[
            const SizedBox(height: 12),
            Text(
              'MashaAllah! You may proceed.',
              style: TextStyle(
                color: _primaryGreen,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreathingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderSubtle),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.air, color: _calmTeal, size: 20),
              const SizedBox(width: 10),
              Text(
                'Breathing Exercise',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (_isBreathing) ...[
            AnimatedBuilder(
              animation: _breathAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _breathAnimation.value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _calmTeal.withValues(alpha: 0.3),
                          _calmTeal.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _breathController.status == AnimationStatus.forward
                            ? 'Breathe In'
                            : 'Breathe Out',
                        style: TextStyle(
                          color: _calmTeal,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Cycle ${_breathCycle + 1} of 3',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ] else ...[
            GestureDetector(
              onTap: _startBreathing,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _calmTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: _calmTeal.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _breathCycle >= 3 ? 'Complete ✓' : 'Start Breathing',
                  style: TextStyle(
                    color: _calmTeal,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final canProceed = _dhikrCount >= _requiredDhikr;

    return Column(
      children: [
        // Go Back button (primary)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onCancel,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Return to Home',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Proceed button (secondary, requires dhikr)
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: canProceed ? widget.onProceed : null,
            style: TextButton.styleFrom(
              foregroundColor: canProceed 
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: canProceed 
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Text(
              canProceed 
                  ? 'Continue to ${widget.appName}'
                  : 'Complete dhikr to proceed',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}

/// Interrupt level enum
enum InterruptLevel {
  gentle,   // 1-2 interrupts: Soft reminder
  moderate, // 3-5 interrupts: Requires dhikr
  firm,     // 6-10 interrupts: More dhikr + breathing
  strong,   // 10+ interrupts: Maximum friction
}

/// Dialog shown when dhikr is complete
class _DhikrCompleteDialog extends StatelessWidget {
  final int dhikrCount;
  final VoidCallback onContinue;

  const _DhikrCompleteDialog({
    required this.dhikrCount,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFC2A366).withValues(alpha: 0.3),
                    const Color(0xFFC2A366).withValues(alpha: 0.1),
                  ],
                ),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFFC2A366),
                size: 48,
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Text(
              'MashaAllah!',
              style: TextStyle(
                color: Color(0xFFFFD93D),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'You completed $dhikrCount dhikr',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'You earned your access mindfully.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC2A366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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

/// Service to manage addiction interrupt settings
class AddictionInterruptService {
  static const String _boxName = 'addiction_interrupt';
  
  /// Apps that should trigger the interrupt screen
  static const Set<String> defaultBlockedApps = {
    'com.instagram.android',
    'com.twitter.android',
    'com.facebook.katana',
    'com.snapchat.android',
    'com.tiktok.android',
    'com.zhiliaoapp.musically',
    'com.pinterest',
    'com.reddit.frontpage',
    'com.google.android.youtube',
  };

  static Future<bool> shouldIntercept(String packageName) async {
    try {
      final box = await HiveBoxManager.get(_boxName);
      final isEnabled = box.get('enabled', defaultValue: true);
      if (!isEnabled) return false;

      final blockedApps = box.get('blocked_apps', defaultValue: defaultBlockedApps.toList());
      return (blockedApps as List).contains(packageName);
    } catch (e) {
      return defaultBlockedApps.contains(packageName);
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    final box = await HiveBoxManager.get(_boxName);
    await box.put('enabled', enabled);
  }

  static Future<bool> isEnabled() async {
    final box = await HiveBoxManager.get(_boxName);
    return box.get('enabled', defaultValue: true);
  }

  static Future<List<String>> getBlockedApps() async {
    final box = await HiveBoxManager.get(_boxName);
    return List<String>.from(
      box.get('blocked_apps', defaultValue: defaultBlockedApps.toList())
    );
  }

  static Future<void> setBlockedApps(List<String> apps) async {
    final box = await HiveBoxManager.get(_boxName);
    await box.put('blocked_apps', apps);
  }

  static Future<int> getTodayInterruptCount() async {
    final box = await HiveBoxManager.get(_boxName);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return box.get('interrupts_$today', defaultValue: 0);
  }

  static Future<int> getTotalSavesCount() async {
    final box = await HiveBoxManager.get(_boxName);
    return box.get('total_saves', defaultValue: 0);
  }

  static Future<void> recordSave() async {
    final box = await HiveBoxManager.get(_boxName);
    final current = box.get('total_saves', defaultValue: 0) as int;
    await box.put('total_saves', current + 1);
  }
}
