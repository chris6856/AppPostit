import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/category_list_screen.dart';

void main() {
  runApp(const ProviderScope(child: AppPostItApp()));
}

class AppPostItApp extends StatelessWidget {
  const AppPostItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppPostIt',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const CategoryListScreen(),
    );
  }
}
