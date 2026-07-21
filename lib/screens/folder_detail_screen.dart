import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_folder_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/installed_apps_provider.dart';

class FolderDetailScreen extends ConsumerStatefulWidget {
  final String folderName;

  const FolderDetailScreen({super.key, required this.folderName});

  @override
  ConsumerState<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends ConsumerState<FolderDetailScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final accent = themeColor.color;
    final allApps = ref.watch(installedAppsProvider);
    final folderNotifier = ref.read(appFolderProvider.notifier);

    // Filter apps based on search
    final filteredApps = allApps.where((app) {
      if (_searchQuery.isEmpty) return true;
      final name = app.customName ?? app.appName;
      return name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.folderName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // ── Search Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Search apps...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    border: InputBorder.none,
                    icon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ),

            // ── Apps List ──
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filteredApps.length,
                itemBuilder: (context, index) {
                  final app = filteredApps[index];
                  // Watch provider to get current category reactively
                  final folderState = ref.watch(appFolderProvider);
                  // We need to determine category manually since getCategoryFor doesn't take state
                  // Wait, getCategoryFor uses state internally inside notifier. 
                  // So we just call notifier.getCategoryFor(). Since we watched folderState, this rebuilds on changes.
                  final currentCategory = folderNotifier.getCategoryFor(app.packageName);
                  final isInFolder = currentCategory == widget.folderName;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      app.customName ?? app.appName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                    ),
                    subtitle: currentCategory != null && !isInFolder
                        ? Text(
                            'Currently in: $currentCategory',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                            ),
                          )
                        : null,
                    trailing: Checkbox(
                      value: isInFolder,
                      activeColor: accent,
                      checkColor: Colors.black,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (val) {
                        if (val == true) {
                          folderNotifier.moveAppToFolder(app.packageName, widget.folderName);
                        } else {
                          // Remove from this folder (reverts to auto-category, which might be this folder if default)
                          folderNotifier.removeAppFromFolder(app.packageName);
                        }
                      },
                    ),
                    onTap: () {
                      if (!isInFolder) {
                        folderNotifier.moveAppToFolder(app.packageName, widget.folderName);
                      } else {
                        folderNotifier.removeAppFromFolder(app.packageName);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
