import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'category_edit_screen.dart';
import 'help/how_it_works_screen.dart';
import 'help/keyboard_setup_screen.dart';
import 'post_list_screen.dart';

class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1788F8),
        foregroundColor: Colors.white,
        flexibleSpace: Opacity(
          opacity: 0.5,
          child: Image.asset(
            'assets/icon/app_icon.png',
            fit: BoxFit.cover,
          ),
        ),
        title: const Text(
          'AppPostIt',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'User Management',
            onSelected: (value) {
              if (value == 'keyboard_setup') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const KeyboardSetupScreen(),
                  ),
                );
              } else if (value == 'how_it_works') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HowItWorksScreen()),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'keyboard_setup',
                child: Text('How to setup interactive keyboard'),
              ),
              PopupMenuItem(
                value: 'how_it_works',
                child: Text('App basic operation'),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.manage_accounts_outlined, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'User Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Create your first category to start saving posts.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Material(
                color: index.isEven
                    ? scheme.surface
                    : scheme.surfaceContainerHighest,
                child: ListTile(
                  title: Text(category.name),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PostListScreen(category: category),
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                CategoryEditScreen(category: category),
                          ),
                        );
                      } else if (value == 'delete') {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete category?'),
                            content: Text(
                              'Deleting "${category.name}" will also delete '
                              'all of its saved posts.',
                            ),
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
                              .read(categoryRepositoryProvider)
                              .delete(category.id);
                        }
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          );
        },
        error: (error, stack) => Center(child: Text('Error: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CategoryEditScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
