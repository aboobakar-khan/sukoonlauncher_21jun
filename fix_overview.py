import re

with open('lib/screens/prayer_history_dashboard_redesigned.dart', 'r') as f:
    text = f.read()

# find _buildNamazHistory from git head since it's clean
import subprocess
git_old = subprocess.check_output(['git', 'show', 'HEAD:lib/screens/prayer_history_dashboard_redesigned.dart']).decode('utf-8')
match = re.search(r'(  Widget _buildNamazHistory\(\) \{.*?\n  \}\n)', git_old, re.DOTALL)
build_namaz = match.group(1) if match else ''

build_nafil = """  Widget _buildNafilSection() {
    final recordsList = records;
    final totalTahajjud = recordsList.where((r) => r.tahajjud).length;
    final totalIshraq = recordsList.where((r) => r.ishraq).length;
    final totalChasht = recordsList.where((r) => r.chasht).length;
    final totalAwwabin = recordsList.where((r) => r.awwabin).length;

    final nafils = [
      {'name': 'Tahajjud', 'icon': Icons.bedtime_rounded, 'count': totalTahajjud},
      {'name': 'Ishraq', 'icon': Icons.wb_twilight_rounded, 'count': totalIshraq},
      {'name': 'Chasht', 'icon': Icons.light_mode_rounded, 'count': totalChasht},
      {'name': 'Awwabin', 'icon': Icons.nights_stay_rounded, 'count': totalAwwabin},
    ];
    final total = totalTahajjud + totalIshraq + totalChasht + totalAwwabin;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'NAFIL PRAYERS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.40),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFC2A366).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$total total',
                  style: TextStyle(
                    color: const Color(0xFFC2A366).withValues(alpha: 0.65),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: nafils.map((n) {
              final count = n['count'] as int;
              final maxCount = nafils.map((x) => x['count'] as int).fold<int>(0, (a, b) => a > b ? a : b);
              final frac = maxCount > 0 ? count / maxCount : 0.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Column(
                    children: [
                      Icon(n['icon'] as IconData,
                          size: 16,
                          color: count > 0
                              ? const Color(0xFFC2A366).withValues(alpha: 0.70)
                              : Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(height: 8),
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.bottomCenter,
                        clipBehavior: Clip.hardEdge,
                        child: FractionallySizedBox(
                          heightFactor: frac.clamp(0.05, 1.0),
                          widthFactor: 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: count > 0
                                  ? const Color(0xFFC2A366).withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$count',
                        style: TextStyle(
                          color: count > 0
                              ? const Color(0xFFC2A366).withValues(alpha: 0.80)
                              : Colors.white.withValues(alpha: 0.20),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        n['name'] as String,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }"""

# Insert _buildNamazHistory and _buildNafilSection before the end of _OverviewTab
new_text = text.replace('  }\n}\n// ═══════════════════════════════════════════════════════════════════════════════\n// CALENDAR TAB',
    '  }\n\n' + build_namaz + '\n' + build_nafil + '\n}\n// ═══════════════════════════════════════════════════════════════════════════════\n// CALENDAR TAB')

# Update build to add these sections
old_build = '''        _buildSectionLabel('WEEKLY ACTIVITY'),
        const SizedBox(height: 12),
        _buildWeeklyChart(stats),
      ],'''
new_build = '''        _buildSectionLabel('WEEKLY ACTIVITY'),
        const SizedBox(height: 12),
        _buildWeeklyChart(stats),
        const SizedBox(height: 24),
        _buildSectionLabel('RECENT PRAYERS'),
        const Size    '  }\n\n' + build_namaz + '\n' + build_nafil + '\n}\n// ═izedBox(height: 24),
        _buildNafilSection(),
      ],'''
new_text = new_text.replace(old_build, new_build)

# Ensure _buildMetricsGrid includes "TOTAL NIFL SALAH" instead of "GOALS MET"
# We just replace 'GOALS MET' with 'TOTAL NAFIL' and pass the count
old_metric = "              _buildMetric('${stats['perfectDays']}', 'GOALS MET', Icons.task_alt_rounded),"
new_metric = """              _buildMetric('${records.where((r) => r.tahajjud).length + records.where((r) => r.ishraq).length + records.where((r) => r.chasht).length + records.where((r) => r.awwabin).length}', 'TOTAL NAFIL', Icons.auto_awesome_rounded),"""
new_text = new_text.replace(old_metric, new_metric)

with open('lib/screens/prayer_history_dashboard_redesigned.dart', 'w') as f:
    f.write(new_text)

print('Done applying Task 1 and 2 patches.')
