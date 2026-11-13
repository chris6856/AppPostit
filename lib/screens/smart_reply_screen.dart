import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/reply_profiles.dart';
import '../providers/providers.dart';
import '../services/smart_reply_service.dart';
import '../widgets/reply_packs_sheet.dart';
import 'reply_profiles_screen.dart';

/// Most saved posts sent along as reference material per request. Keeps
/// the request (and its cost) bounded for large categories.
const int _maxExamplePosts = 15;

class SmartReplyScreen extends ConsumerStatefulWidget {
  const SmartReplyScreen({super.key});

  @override
  ConsumerState<SmartReplyScreen> createState() => _SmartReplyScreenState();
}

class _SmartReplyScreenState extends ConsumerState<SmartReplyScreen> {
  final _messageController = TextEditingController();
  final _replyController = TextEditingController();
  String _profileId = builtInReplyProfiles.first.id;
  ReplyTone _tone = ReplyTone.helpful;
  int? _referenceCategoryId;
  bool _loading = false;
  bool _hasReply = false;

  @override
  void dispose() {
    _messageController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  ReplyProfile _selectedProfile(List<ReplyProfile> profiles) =>
      profiles.firstWhere(
        (p) => p.id == _profileId,
        orElse: () => builtInReplyProfiles.first,
      );

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pasteMessage() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _showMessage('The clipboard has no text to paste.');
      return;
    }
    _messageController.text = text;
  }

  Future<bool> _ensureConsent() async {
    if (ref.read(smartReplyConsentProvider)) return true;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send text to our assistant?'),
        content: const Text(
          'To draft a reply, our assistant needs the message you paste, '
          'your chosen profile and tone, and any saved posts you pick as '
          "reference. These are sent to AppPostIt's server and processed by "
          'Claude, the AI service from Anthropic that powers our '
          'assistant.\n\n'
          "AppPostIt doesn't store this text. Avoid pasting passwords, "
          'payment details or other sensitive information.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Agree'),
          ),
        ],
      ),
    );
    if (agreed != true) return false;
    await grantSmartReplyConsent(ref);
    return true;
  }

  Future<void> _showOutOfReplies() => showReplyPacksSheet(
        context,
        title: ref.read(smartReplyCreditsProvider) == 0 &&
                ref.read(smartReplyCountProvider) >= kFreeSmartReplyLimit
            ? "You've used your $kFreeSmartReplyLimit free Smart Replies"
            : null,
      );

  Future<List<String>> _referencePosts() async {
    final categoryId = _referenceCategoryId;
    if (categoryId == null) return const [];
    final posts =
        await ref.read(postRepositoryProvider).watchByCategory(categoryId).first;
    return posts.take(_maxExamplePosts).map((p) => p.body).toList();
  }

  Future<void> _generate({bool shorten = false}) async {
    FocusScope.of(context).unfocus();
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _showMessage('Paste or type the message you want to reply to.');
      return;
    }
    if (shorten && _replyController.text.trim().isEmpty) return;

    if (!await _ensureConsent()) return;
    if (!mounted) return;
    if (ref.read(smartRepliesRemainingProvider) == 0) {
      await _showOutOfReplies();
      return;
    }

    setState(() => _loading = true);
    try {
      final profile = _selectedProfile(ref.read(allReplyProfilesProvider));
      final reply = await ref.read(smartReplyServiceProvider).generate(
            message: message,
            profileName: profile.name,
            profileInstructions: profile.instructions,
            tone: _tone,
            examples: await _referencePosts(),
            draftToShorten: shorten ? _replyController.text.trim() : null,
          );
      await recordSmartReplyUse(ref);
      if (!mounted) return;
      setState(() {
        _replyController.text = reply;
        _hasReply = true;
      });
    } on SmartReplyException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyReply() async {
    await Clipboard.setData(ClipboardData(text: _replyController.text));
    if (mounted) _showMessage('Reply copied. Paste it wherever you need it.');
  }

  Future<void> _saveAsPost() async {
    final body = _replyController.text.trim();
    if (body.isEmpty) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _SaveAsPostDialog(body: body),
    );
    if (saved == true && mounted) _showMessage('Saved as a post.');
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(allReplyProfilesProvider);
    final profile = _selectedProfile(profiles);
    final categories = ref.watch(categoriesStreamProvider).value ?? const [];
    final remaining = ref.watch(smartRepliesRemainingProvider);
    final freeLeft = ref.watch(freeSmartRepliesLeftProvider);
    final credits = ref.watch(smartReplyCreditsProvider);
    // Purchases complete asynchronously through the store, possibly after
    // the pack sheet has closed -- confirm when the credits land.
    ref.listen<int>(smartReplyCreditsProvider, (previous, next) {
      final added = next - (previous ?? 0);
      if (added > 0) _showMessage('Added $added replies. Thank you!');
    });
    final referenceId = categories.any((c) => c.id == _referenceCategoryId)
        ? _referenceCategoryId
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Smart Reply')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Paste a message you received, pick how to respond, and ask '
              'our assistant to draft a reply you can review, edit and copy.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              minLines: 4,
              maxLines: 10,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Incoming message',
                hintText: 'An email, post, comment, ticket or text message',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Paste',
                  icon: const Icon(Icons.content_paste),
                  onPressed: _pasteMessage,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('profile-${profile.id}-${profiles.length}'),
                    initialValue: profile.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Response profile',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final p in profiles)
                        DropdownMenuItem(value: p.id, child: Text(p.name)),
                    ],
                    onChanged: (id) {
                      if (id != null) setState(() => _profileId = id);
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Manage profiles',
                  icon: const Icon(Icons.tune),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ReplyProfilesScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Tone', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<ReplyTone>(
              segments: [
                for (final t in ReplyTone.values)
                  ButtonSegment(value: t, label: Text(t.label)),
              ],
              selected: {_tone},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _tone = s.first),
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                key: ValueKey('reference-$referenceId-${categories.length}'),
                initialValue: referenceId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Use saved posts as reference (optional)',
                  helperText: 'Facts, links and wording from these posts '
                      'can be reused in the reply.',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('None'),
                  ),
                  for (final c in categories)
                    DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (id) => setState(() => _referenceCategoryId = id),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading ? null : () => _generate(),
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _loading
                      ? 'Our assistant is writing...'
                      : 'Ask Our Assistant',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              remaining == 0
                  ? 'No replies left'
                  : credits == 0
                      ? '$freeLeft of $kFreeSmartReplyLimit free Smart '
                          'Replies left'
                      : '$remaining Smart '
                          '${remaining == 1 ? 'Reply' : 'Replies'} left',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Center(
              child: TextButton(
                onPressed: () => showReplyPacksSheet(context),
                child: const Text('Get more replies'),
              ),
            ),
            if (_hasReply) ...[
              const SizedBox(height: 24),
              TextField(
                controller: _replyController,
                minLines: 4,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Drafted reply (tap to edit)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI can make mistakes. Check names, prices and anything in '
                '[brackets] before sending.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _loading ? null : _copyReply,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : () => _generate(shorten: true),
                    icon: const Icon(Icons.short_text),
                    label: const Text('Shorten'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : () => _generate(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Regenerate'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _saveAsPost,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Save as post'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Saves the drafted reply as a regular post, so it can be inserted with
/// the keyboard later. Offers creating a category when none exist yet.
class _SaveAsPostDialog extends ConsumerStatefulWidget {
  const _SaveAsPostDialog({required this.body});

  final String body;

  @override
  ConsumerState<_SaveAsPostDialog> createState() => _SaveAsPostDialogState();
}

class _SaveAsPostDialogState extends ConsumerState<_SaveAsPostDialog> {
  final _labelController = TextEditingController();
  final _newCategoryController = TextEditingController();
  int? _categoryId;
  bool _saving = false;

  @override
  void dispose() {
    _labelController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _save(List<Category> categories) async {
    var categoryId = _categoryId ?? categories.firstOrNull?.id;
    if (categoryId == null) {
      final name = _newCategoryController.text.trim();
      if (name.isEmpty) return;
      setState(() => _saving = true);
      categoryId = await ref.read(categoryRepositoryProvider).create(name);
    }
    setState(() => _saving = true);
    final label = _labelController.text.trim();
    await ref.read(postRepositoryProvider).create(
          categoryId: categoryId,
          body: widget.body,
          label: label.isEmpty ? null : label,
        );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesStreamProvider).value ?? const [];
    final selectedId = _categoryId ?? categories.firstOrNull?.id;

    return AlertDialog(
      title: const Text('Save as post'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (categories.isEmpty)
            TextField(
              controller: _newCategoryController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'New category name',
              ),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: selectedId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in categories)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (id) => setState(() => _categoryId = id),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Label (optional)',
              hintText: 'Short title shown in lists',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(categories),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
