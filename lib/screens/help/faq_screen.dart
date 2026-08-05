import 'package:flutter/material.dart';

/// Starter FAQ content -- edit this list to add, remove, or reword entries.
const List<({String question, String answer})> _faqs = [
  (
    question: 'How do I save a post?',
    answer: 'Tap into a category from the home screen, then tap the + '
        "button. Type the text you want to reuse (a label is optional), "
        'and tap Save.',
  ),
  (
    question: 'Where is my data stored?',
    answer: 'Everything is saved locally on your device only -- there is '
        'no account and nothing is sent to the cloud.',
  ),
  (
    question: "Why can't I type freely with the AppPostIt keyboard?",
    answer: "The AppPostIt keyboard is designed to insert a saved post, "
        "not replace your regular keyboard for typing. Switch back to "
        "your normal keyboard when you're done inserting a post.",
  ),
  (
    question: 'How do I edit or delete a category or post?',
    answer: 'Tap the menu icon next to any category or post in the list '
        'to edit or delete it.',
  ),
  (
    question: 'Is my data backed up if I lose my phone?',
    answer: "Not yet -- backup and restore isn't available in this "
        'version.',
  ),
  (
    question: 'Does this work on iOS?',
    answer: 'Yes -- both the app and the AppPostIt keyboard work on iOS. '
        'On iOS, the keyboard needs "Allow Full Access" turned on '
        '(Settings > General > Keyboard > Keyboards > AppPostIt Keyboard) '
        'to track your free post limit and read your saved posts.',
  ),
];

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _faqs.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final faq = _faqs[index];
          return ExpansionTile(
            title: Text(
              faq.question,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                faq.answer,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}
