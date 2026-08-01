import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/post_repository.dart';
import '../services/purchase_service.dart';

const hasSeenWelcomeKey = 'has_seen_welcome';

/// Posts beyond this many (across all categories) require the unlock
/// purchase. Keep in sync with the Android keyboard's own copy of this
/// limit (android/.../ime/AppPostItInputMethodService.kt), since the
/// keyboard enforces the same gate natively against the same database.
const int kFreePostLimit = 8;

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

final totalPostCountProvider = StreamProvider<int>((ref) {
  return ref.watch(postRepositoryProvider).watchTotalCount();
});

final isPremiumProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(kIsPremiumKey) ?? false;
});

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = PurchaseService(
    prefs,
    onPremiumUnlocked: () => ref.read(isPremiumProvider.notifier).state = true,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Kicks off PurchaseService.init() (querying product details, restoring
/// past purchases) once, the first time anything watches it.
final purchaseInitProvider = FutureProvider<void>((ref) async {
  await ref.watch(purchaseServiceProvider).init();
});

/// True once the free post limit is reached without a purchase -- gates
/// the entire app behind PaywallScreen when true.
final isLockedProvider = Provider<bool>((ref) {
  if (ref.watch(isPremiumProvider)) return false;
  final count = ref.watch(totalPostCountProvider).value ?? 0;
  return count >= kFreePostLimit;
});
