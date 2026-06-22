import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../screens/donation_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Charity Log — Data model
// ─────────────────────────────────────────────────────────────────────────────

class CharityEntry {
  final String id;
  final String description;
  final double amount;
  final String currency;
  final String category;
  final DateTime date;

  const CharityEntry({
    required this.id,
    required this.description,
    required this.amount,
    required this.currency,
    required this.category,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'amount': amount,
        'currency': currency,
        'category': category,
        'date': date.toIso8601String(),
      };

  factory CharityEntry.fromJson(Map<String, dynamic> j) => CharityEntry(
        id: j['id'] as String,
        description: j['description'] as String,
        amount: (j['amount'] as num).toDouble(),
        currency: (j['currency'] as String?) ?? 'USD',
        category: (j['category'] as String?) ?? 'Sadaqah',
        date: DateTime.parse(j['date'] as String),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

class CharityLogNotifier extends StateNotifier<List<CharityEntry>> {
  static const _key = 'charity_log_entries';

  CharityLogNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        state = list
            .map((e) => CharityEntry.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  Future<void> addEntry(CharityEntry entry) async {
    state = [entry, ...state];
    await _save();
  }

  Future<void> removeEntry(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _save();
  }

  double get totalThisMonth {
    final now = DateTime.now();
    return state
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get totalAllTime => state.fold(0.0, (sum, e) => sum + e.amount);
}

final charityLogProvider =
    StateNotifierProvider<CharityLogNotifier, List<CharityEntry>>(
  (ref) => CharityLogNotifier(),
);

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

class CharityLogWidget extends ConsumerWidget {
  const CharityLogWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(themeColorProvider).color;
    final entries = ref.watch(charityLogProvider);
    final notifier = ref.read(charityLogProvider.notifier);

    final recentEntries = entries.take(3).toList();
    final allTimeTotal = notifier.totalAllTime;
    // Use the currency of the most recent entry, fallback to empty
    final lastCurrency = entries.isNotEmpty ? entries.first.currency : '';
    final currencySymbol = _currencySymbol(lastCurrency);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.volunteer_activism_rounded, size: 18, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CHARITY LOG',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: accent.withValues(alpha: 0.9),
                        ),
                      ),
                      Text(
                        'الصدقة تطفئ الخطيئة',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.25),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                // Add button
                GestureDetector(
                  onTap: () => _showAddEntrySheet(context, ref, accent),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withValues(alpha: 0.2)),
                    ),
                    child: Icon(Icons.add_rounded, size: 18, color: accent),
                  ),
                ),
              ],
            ),
          ),

          // ── Stats row ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildStat(
                  label: 'Total Charity',
                  value: entries.isEmpty
                      ? '—'
                      : '$currencySymbol${allTimeTotal.toStringAsFixed(allTimeTotal % 1 == 0 ? 0 : 2)}',
                  accent: accent,
                ),
                const SizedBox(width: 12),
                _buildStat(
                  label: 'Entries',
                  value: '${entries.length}',
                  accent: accent,
                  dim: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Recent entries ──
          if (recentEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(
                children: [
                  Icon(Icons.spa_rounded, size: 12, color: accent.withValues(alpha: 0.25)),
                  const SizedBox(width: 6),
                  Text(
                    'Tap + to record your sadaqah',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ...recentEntries.map((entry) => _buildEntryRow(entry, accent, ref)),
            if (entries.length > 3)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: GestureDetector(
                  onTap: () => _showAllEntriesSheet(context, ref, accent),
                  child: Text(
                    '+ ${entries.length - 3} more entries',
                    style: TextStyle(
                      fontSize: 11,
                      color: accent.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 6),
          ],

          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildStat({
    required String label,
    required String value,
    required Color accent,
    bool dim = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: dim ? 0.04 : 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: dim
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.9),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: Colors.white.withValues(alpha: 0.3),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryRow(CharityEntry entry, Color accent, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                _categoryIcon(entry.category),
                size: 15,
                color: accent.withValues(alpha: 0.65),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${entry.category} · ${_formatDate(entry.date)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${entry.currency} ${entry.amount.toStringAsFixed(entry.amount % 1 == 0 ? 0 : 2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accent.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  String _currencySymbol(String code) {
    switch (code) {
      case 'USD': return '\$';
      case 'GBP': return '£';
      case 'EUR': return '€';
      case 'PKR': return '₨';
      case 'INR': return '₹';
      case 'SAR': return '﷼';
      case 'AED': return 'د.إ';
      default:    return code.isNotEmpty ? '$code ' : '';
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Zakat':
        return Icons.water_drop_rounded;
      case 'Kaffarah':
        return Icons.spa_rounded;
      case 'Fidyah':
        return Icons.brightness_3_rounded;
      case 'Lillah':
        return Icons.mosque_rounded;
      case 'Hadith Gift':
        return Icons.menu_book_rounded;
      default:
        return Icons.volunteer_activism_rounded;
    }
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  void _showAddEntrySheet(BuildContext context, WidgetRef ref, Color accent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddCharitySheet(accent: accent, ref: ref),
    );
  }

  void _showAllEntriesSheet(BuildContext context, WidgetRef ref, Color accent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllEntriesSheet(accent: accent, ref: ref),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Charity Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AddCharitySheet extends StatefulWidget {
  final Color accent;
  final WidgetRef ref;
  const _AddCharitySheet({required this.accent, required this.ref});

  @override
  State<_AddCharitySheet> createState() => _AddCharitySheetState();
}

class _AddCharitySheetState extends State<_AddCharitySheet> {
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _selectedCategory = 'Sadaqah';
  String _currency = 'USD';

  static const _categories = [
    'Sadaqah', 'Zakat', 'Kaffarah', 'Fidyah', 'Lillah', 'Hadith Gift', 'Other',
  ];
  static const _currencies = ['USD', 'GBP', 'EUR', 'PKR', 'INR', 'SAR', 'AED'];

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Log Charity',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'الصدقة تطفئ غضب الرب',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 20),

            // Description
            _buildTextField(
              controller: _descCtrl,
              hint: 'What did you give? (e.g. Masjid donation)',
              accent: accent,
            ),
            const SizedBox(height: 12),

            // Amount + Currency row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTextField(
                    controller: _amountCtrl,
                    hint: 'Amount',
                    accent: accent,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _buildDropdown<String>(
                    value: _currency,
                    items: _currencies,
                    accent: accent,
                    onChanged: (v) => setState(() => _currency = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Category chips
            Text(
              'CATEGORY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _categories.map((cat) {
                final isSelected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accent.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? accent.withValues(alpha: 0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? accent.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.4),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Support Developer CTA
            GestureDetector(
              onTap: () => showDonationScreen(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.favorite_rounded, color: accent.withValues(alpha: 0.45), size: 15),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Support Sukoon — donate as sadaqah jariyah',
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.55),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: accent.withValues(alpha: 0.3), size: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Save button
            GestureDetector(
              onTap: _save,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Center(
                  child: Text(
                    'Save Entry',
                    style: TextStyle(
                      color: accent,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final desc = _descCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (desc.isEmpty || amount <= 0) {
      return;
    }
    final entry = CharityEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      description: desc,
      amount: amount,
      currency: _currency,
      category: _selectedCategory,
      date: DateTime.now(),
    );
    widget.ref.read(charityLogProvider.notifier).addEntry(entry);
    Navigator.pop(context);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required Color accent,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
      cursorColor: accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.4)),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required Color accent,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: const Color(0xFF1A1A1A),
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              fontWeight: FontWeight.w500),
          icon:
              Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withValues(alpha: 0.3), size: 18),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(item.toString()),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// All Entries Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AllEntriesSheet extends ConsumerWidget {
  final Color accent;
  final WidgetRef ref;
  const _AllEntriesSheet({required this.accent, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef innerRef) {
    final entries = innerRef.watch(charityLogProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.volunteer_activism_rounded,
                          color: accent, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'All Charity Entries',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${entries.length} total',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: entries.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                itemBuilder: (_, i) {
                  final entry = entries[i];
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          _categoryIcon(entry.category),
                          size: 18,
                          color: accent.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    title: Text(
                      entry.description,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${entry.category} · ${entry.date.day}/${entry.date.month}/${entry.date.year}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${entry.currency} ${entry.amount.toStringAsFixed(entry.amount % 1 == 0 ? 0 : 2)}',
                          style: TextStyle(
                            color: accent.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            innerRef
                                .read(charityLogProvider.notifier)
                                .removeEntry(entry.id);
                          },
                          child: Icon(Icons.delete_outline_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.2)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Zakat':
        return Icons.water_drop_rounded;
      case 'Kaffarah':
        return Icons.spa_rounded;
      case 'Fidyah':
        return Icons.brightness_3_rounded;
      case 'Lillah':
        return Icons.mosque_rounded;
      case 'Hadith Gift':
        return Icons.menu_book_rounded;
      default:
        return Icons.volunteer_activism_rounded;
    }
  }
}
