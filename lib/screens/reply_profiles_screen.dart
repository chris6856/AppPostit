import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reply_profiles.dart';
import '../providers/providers.dart';

/// Lists Smart Reply's built-in profiles (read-only) and the user's custom
/// ones, which can be added, edited and deleted.
class ReplyProfilesScreen extends ConsumerWidget {
  const ReplyProfilesScreen({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    ReplyProfile? profile,
  ]) async {
    final result = await showDialog<({String name, String instructions})>(
      context: context,
      builder: (_) => _ProfileDialog(profile: profile),
    );
    if (result == null) return;
    final notifier = ref.read(customReplyProfilesProvider.notifier);
    if (profile == null) {
      await notifier.add(result.name, result.instructions);
    } else {
      await notifier.edit(
        profile.copyWith(name: result.name, instructions: result.instructions),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = ref.watch(customReplyProfilesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Response Profiles')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Your profiles', style: theme.textTheme.titleSmall),
          ),
          if (custom.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Tap + to create a profile for the kinds of messages you '
                'answer often, for example "Automotive advice: answer as an '
                'experienced mechanic and help them decide whether to '
                'repair or replace."',
              ),
            ),
          for (final p in custom)
            ListTile(
              title: Text(p.name),
              subtitle: Text(
                p.instructions,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _edit(context, ref, p),
              trailing: IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Delete "${p.name}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref
                        .read(customReplyProfilesProvider.notifier)
                        .remove(p.id);
                  }
                },
              ),
            ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('Built-in profiles', style: theme.textTheme.titleSmall),
          ),
          for (final p in builtInReplyProfiles)
            ListTile(
              title: Text(p.name),
              subtitle: Text(p.instructions),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New profile',
        onPressed: () => _edit(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({this.profile});

  final ReplyProfile? profile;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final _nameController =
      TextEditingController(text: widget.profile?.name ?? '');
  late final _instructionsController =
      TextEditingController(text: widget.profile?.instructions ?? '');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.profile == null ? 'New profile' : 'Edit profile'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: widget.profile == null,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              TextFormField(
                controller: _instructionsController,
                minLines: 3,
                maxLines: 8,
                maxLength: 1500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Instructions',
                  hintText: 'Who you are, how to respond, what to always '
                      'or never include',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Instructions are required'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop((
              name: _nameController.text.trim(),
              instructions: _instructionsController.text.trim(),
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
