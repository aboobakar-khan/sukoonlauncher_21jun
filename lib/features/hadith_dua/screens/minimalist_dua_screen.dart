import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dua_adhkar_category_screen.dart';

/// Main entry point for Dua & Adhkar section
/// Routes to the redesigned category screen with warm cream palette
class MinimalistDuaScreen extends ConsumerWidget {
  const MinimalistDuaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DuaAdhkarCategoryScreen();
  }
}
