import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/providers.dart';
import 'screens/category_list_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const AppPostItApp(),
    ),
  );
}

class AppPostItApp extends ConsumerWidget {
  const AppPostItApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSeenWelcome = ref.watch(hasSeenWelcomeProvider);
    final isLocked = ref.watch(isLockedProvider);
    // Kick off purchase-service init (product details, restore purchases)
    // once; nothing in the UI needs to await this directly.
    ref.watch(purchaseInitProvider);

    return MaterialApp(
      title: 'AppPostIt',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // Runs for every route regardless of navigation depth, so hitting the
      // free-post limit mid-session immediately replaces whatever's on
      // screen with the paywall -- not just what a fresh `home:` swap would
      // cover.
      builder: (context, child) {
        if (isLocked) return const PaywallScreen();
        return child ?? const SizedBox.shrink();
      },
      home:
          hasSeenWelcome ? const CategoryListScreen() : const WelcomeScreen(),
    );
  }
}
