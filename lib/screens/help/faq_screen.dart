import 'package:flutter/material.dart';

import '../../providers/providers.dart' show kFreeSmartReplyLimit;

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
    answer: 'Your categories and posts are saved locally on your device '
        'only -- there is no account. The one exception is Smart Reply: '
        'when you ask our assistant for a reply, the message you pasted '
        '(and any saved posts you chose as reference) is sent to it to '
        "draft the reply. AppPostIt doesn't store it. Our assistant is "
        'powered by Claude, an AI service from Anthropic.',
  ),
  (
    question: 'What is Smart Reply?',
    answer: 'Tap Smart Reply on the home screen, paste a message you '
        'received (an email, post, comment or text), pick a response '
        'profile and tone, and tap Ask Our Assistant. You can edit the draft, '
        'shorten it, regenerate it, copy it, or save it as a post. Create '
        'your own profiles with the tune button next to the profile list. '
        'You get $kFreeSmartReplyLimit free replies to try it.',
  ),
  (
    question: 'How do I get more Smart Replies?',
    answer: 'Tap "Get more replies" on the Smart Reply screen (or Buy '
        'Smart Replies under User Management) and pick a pack of 50 or '
        '125 replies. You pay through your Apple or Google account. '
        'Generate, Shorten and Regenerate each use one reply. Packs never '
        'expire, but they are stored on your device and are not restored '
        'if you delete and reinstall the app. Smart Replies are separate '
        'from the one-time unlimited posts unlock.',
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
        'to track your free insert limit and read your saved posts.',
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
