import 'package:flutter/material.dart';

import '../../widgets/step_tile.dart';

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How AppPostIt Works')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'AppPostIt saves reusable text so you can drop it into any '
            'app -- a Facebook comment, a group reply, anywhere you type.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          const StepTile(
            number: 1,
            title: 'Create categories',
            description: 'Group your saved posts by topic, like '
                '"Allergies" or "Product Promo".',
          ),
          const StepTile(
            number: 2,
            title: 'Add posts inside each category',
            description: 'Save the exact text you want to reuse, with '
                'an optional short label.',
          ),
          const StepTile(
            number: 3,
            title: 'Switch to the AppPostIt keyboard',
            description: 'While typing in any app, switch keyboards to '
                'AppPostIt.',
          ),
          const StepTile(
            number: 4,
            title: 'Tap a category, then a post',
            description: "Its text is inserted right where you're "
                'typing -- no copy-paste, no app-switching.',
          ),
          const SizedBox(height: 12),
          Text(
            'Tap the menu on any category or post to edit or delete it.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
