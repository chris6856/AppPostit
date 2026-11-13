import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/purchase_service.dart';

/// Bottom sheet offering the Smart Reply packs. Tapping a pack opens the
/// store's own checkout (Face ID / fingerprint with the card already on
/// the user's Apple or Google account); the replies are credited when the
/// store confirms the purchase.
Future<void> showReplyPacksSheet(BuildContext context, {String? title}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ReplyPacksSheet(title: title),
  );
}

class _ReplyPacksSheet extends ConsumerWidget {
  const _ReplyPacksSheet({this.title});

  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(purchaseServiceProvider);
    final remaining = ref.watch(smartRepliesRemainingProvider);
    final theme = Theme.of(context);

    Future<void> buy(String productId) async {
      final messenger = ScaffoldMessenger.of(context);
      final started = await service.buyReplyPack(productId);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      if (!started) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              "Purchases aren't available right now. Please try again "
              'later.',
            ),
          ),
        );
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title ?? 'Get more Smart Replies',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              remaining == 0
                  ? "You're out of replies. Pick a pack to keep going."
                  : 'You have $remaining '
                      '${remaining == 1 ? 'reply' : 'replies'} left.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            for (final entry in kReplyPackCredits.entries) ...[
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const Icon(Icons.auto_awesome),
                  title: Text(
                    '${entry.value} replies',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('One-time purchase, never expires'),
                  trailing: FilledButton(
                    onPressed: () => buy(entry.key),
                    child: Text(service.priceFor(entry.key)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            Text(
              'Paid through your ${Theme.of(context).platform == TargetPlatform.iOS ? 'Apple' : 'Google'} '
              'account. Generate, Shorten and Regenerate each use one '
              'reply. Replies are stored on this device and are not '
              'restored if you reinstall the app.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
