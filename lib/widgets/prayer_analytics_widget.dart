import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/prayer_provider.dart';
import '../screens/prayer_history_dashboard_redesigned.dart';

/// Prayer Analytics Dashboard Widget - Compact card for main dashboard
class PrayerAnalyticsWidget extends ConsumerWidget {
  const PrayerAnalyticsWidget({super.key});

  static const Color _gold = Color(0xFFC2A366);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsMap = ref.watch(prayerRecordsMapProvider);

    // Calculate this week's data
    final now = DateTime.now();
    final weekDaysData = <int>[];
    final dayLetters = <String>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final record = recordsMap[key];
      final count = record?.completedCount ?? 0;
      weekDaysData.add(count);
      
      final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      dayLetters.add(days[date.weekday - 1]);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PrayerHistoryDashboard()),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF161616), // Dark background matching the image
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WEEKLY ACTIVITY',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
              )),
            const SizedBox(height: 36),
            // Mini week bar chart
            SizedBox(
              height: 100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final count = weekDaysData[i];
                  final isToday = i == 6;
                  final double barHeight = count > 0 ? (count / 5 * 60).clamp(10.0, 60.0) : 3.0;
                  
                  return SizedBox(
                    width: 36,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (count > 0)
                          Text('$count', style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          )),
                        if (count > 0)
                          const SizedBox(height: 6),
                          
                        Container(
                          width: double.infinity,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: count > 0 
                                ? (isToday ? _gold : const Color(0xFF7D5F23)) 
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: count > 0 
                                ? BorderRadius.circular(6) 
                                : BorderRadius.circular(1.5),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          dayLetters[i],
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.15),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          )
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
