import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../providers/providers.dart';
import '../widgets/theme_mode_dialog.dart';
import 'category_edit_screen.dart';
import 'help/faq_screen.dart';
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
          child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.cover),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'User Management',
            onSelected: (value) async {
              switch (value) {
                case 'keyboard_setup':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const KeyboardSetupScreen(),
                    ),
                  );
                case 'how_it_works':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HowItWorksScreen()),
                  );
                case 'faq':
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const FaqScreen()));
                case 'how_to_videos':
                  final launched = await launchUrl(
                    howToVideosUri,
                    mode: LaunchMode.inAppWebView,
                  );
                  if (!launched && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Couldn't open the how-to videos link."),
                      ),
                    );
                  }
                case 'theme':
                  showThemeModeDialog(context);
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
              PopupMenuItem(value: 'faq', child: Text('FAQ')),
              PopupMenuItem(
                value: 'how_to_videos',
                child: Text('How-to videos'),
              ),
              PopupMenuDivider(),
              PopupMenuItem(value: 'theme', child: Text('Theme')),
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
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: brandGradient),
        child: categoriesAsync.when(
          data: (categories) {
            if (categories.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Create your first category to start saving posts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CategoryEditScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}
