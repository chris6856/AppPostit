import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/post_repository.dart';

const hasSeenWelcomeKey = 'has_seen_welcome';

/// Overridden in main() with the SharedPreferences instance loaded before
/// runApp(), so it's available synchronously everywhere else.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with a loaded '
    'SharedPreferences instance before use.',
  );
});

final hasSeenWelcomeProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(hasSeenWelcomeKey) ?? false;
});

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(databaseProvider));
});

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(ref.watch(databaseProvider));
});

final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAll();
});

final postsStreamProvider =
    StreamProvider.family<List<Post>, int>((ref, categoryId) {
  return ref.watch(postRepositoryProvider).watchByCategory(categoryId);
});
