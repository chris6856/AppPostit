import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/providers.dart';
import 'screens/category_list_screen.dart';
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

    return MaterialApp(
      title: 'AppPostIt',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home:
          hasSeenWelcome ? const CategoryListScreen() : const WelcomeScreen(),
    );
  }
}
