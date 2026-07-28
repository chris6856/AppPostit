import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants.dart';
import '../providers/providers.dart';
import '../widgets/step_tile.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: brandGradient),
        child: _WelcomeContent(),
      ),
    );
  }
}

class _WelcomeContent extends ConsumerWidget {
  const _WelcomeContent();

  Future<void> _getStarted(WidgetRef ref) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(hasSeenWelcomeKey, true);
    ref.read(hasSeenWelcomeProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 12),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 120,
                height: 120,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thanks for downloading AppPostIt!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Here's a suggested way to get set up:",
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  const StepTile(
                    number: 1,
                    title: 'Build your categories and posts',
                    description:
                        'Start on the home screen -- create a '
                        'category, then add the posts you want to reuse.',
                  ),
                  const StepTile(
                    number: 2,
                    title: 'Then check out User Management',
                    description:
                        'Tap User Management in the top bar for '
                        'keyboard setup instructions, how the app works, '
                        'FAQs, and how-to videos.',
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _getStarted(ref),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Get Started'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
