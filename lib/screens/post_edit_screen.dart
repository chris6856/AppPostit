import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/providers.dart';

class PostEditScreen extends ConsumerStatefulWidget {
  const PostEditScreen({super.key, required this.categoryId, this.post});

  final int categoryId;
  final Post? post;

  @override
  ConsumerState<PostEditScreen> createState() => _PostEditScreenState();
}

class _PostEditScreenState extends ConsumerState<PostEditScreen> {
  late final TextEditingController _labelController;
  late final TextEditingController _bodyController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.post?.label ?? '');
    _bodyController = TextEditingController(text: widget.post?.body ?? '');
  }

  @override
  void dispose() {
    _labelController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(postRepositoryProvider);
    final label = _labelController.text.trim();
    final body = _bodyController.text.trim();
    if (widget.post == null) {
      await repo.create(
        categoryId: widget.categoryId,
        body: body,
        label: label.isEmpty ? null : label,
      );
    } else {
      await repo.update(
        widget.post!.id,
        body: body,
        label: label.isEmpty ? null : label,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.post != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Post' : 'New Post')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Label (optional)',
                  hintText: 'Short title shown in lists',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Post text',
                  alignLabelWithHint: true,
                ),
                maxLines: 8,
                autofocus: !isEditing,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Post text is required'
                    : null,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
  }
}
