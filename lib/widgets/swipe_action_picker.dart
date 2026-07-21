import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../providers/swipe_gesture_provider.dart';
import '../providers/installed_apps_provider.dart';

void showSwipeActionPicker(
  BuildContext context,
  WidgetRef ref, {
  required String direction,
  required SwipeAction current,
  required void Function(SwipeAction, {String? appPackage}) onSelect,
}) {
  final gold = ref.read(themeColorProvider).color;
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF121212),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final bottomPad = MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 16;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              direction,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose what happens when you $direction on the home screen',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            // Options
            ...SwipeAction.values.map((action) {
              final selected = action == current;
              return GestureDetector(
                onTap: () {
                  if (action == SwipeAction.openApp) {
                    Navigator.pop(ctx);
                    _showAppPickerForSwipe(context, ref, onSelect: onSelect);
                  } else {
                    onSelect(action);
                    Navigator.pop(ctx);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? gold.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? gold.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected
                              ? gold.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(action.icon, size: 18,
                            color: selected ? gold : Colors.white.withValues(alpha: 0.55)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              action.label,
                              style: TextStyle(
                                color: selected ? gold : Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              action.description,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle_rounded,
                            color: gold.withValues(alpha: 0.8), size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      );
    },
  );
}

void _showAppPickerForSwipe(
  BuildContext context,
  WidgetRef ref, {
  required void Function(SwipeAction, {String? appPackage}) onSelect,
}) {
  final allApps = ref.read(installedAppsProvider);
  final searchController = TextEditingController();

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF121212),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final query = searchController.text.toLowerCase();
          final filtered = query.isEmpty
              ? allApps
              : allApps.where((a) => a.appName.toLowerCase().contains(query)).toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, scrollController) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: [
                  // Title
                  Text(
                    'Choose App',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select which app to open on swipe',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search field
                  TextField(
                    controller: searchController,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search apps...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                      prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.3), size: 20),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // App list
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final app = filtered[i];
                        return GestureDetector(
                          onTap: () {
                            onSelect(SwipeAction.openApp, appPackage: app.packageName);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.app_shortcut_rounded, size: 18, color: Colors.white.withValues(alpha: 0.5)),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    app.appName,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
