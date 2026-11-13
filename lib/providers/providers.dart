import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';
import '../data/repositories/category_repository.dart';
import '../data/reply_profiles.dart';
import '../data/repositories/post_repository.dart';
import '../services/purchase_service.dart';
import '../services/shared_storage.dart';
import '../services/smart_reply_service.dart';

const hasSeenWelcomeKey = 'has_seen_welcome';

const themeModeKey = 'theme_mode';

ThemeMode themeModeFromPrefsString(String? value) => switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

String themeModeToPrefsString(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };

/// Insertions beyond this many (a saved post actually typed into another
/// app via the keyboard -- not how many posts are saved) require the
/// unlock purchase. Keep in sync with the Android keyboard's own copy of
/// this limit (android/.../ime/AppPostItInputMethodService.kt), since the
/// keyboard enforces the same gate natively -- it's also the only place
/// that increments the counter, via UsageTracker.kt.
const int kFreeInsertLimit = 8;

const String insertCountKey = 'insert_count';

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

/// Purely a UI preference, local to this device -- no cross-process
/// sharing with the keyboard involved, so a plain StateProvider backed by
/// SharedPreferences is enough (unlike insertCountProvider/
/// isPremiumProvider above).
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return themeModeFromPrefsString(prefs.getString(themeModeKey));
});

Future<void> setThemeMode(WidgetRef ref, ThemeMode mode) async {
  final prefs = ref.read(sharedPreferencesProvider);
  await prefs.setString(themeModeKey, themeModeToPrefsString(mode));
  ref.read(themeModeProvider.notifier).state = mode;
}

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

final sharedStorageProvider = Provider<SharedStorage>((ref) {
  return SharedStorage(ref.watch(sharedPreferencesProvider));
});

/// The keyboard (UsageTracker.kt on Android, the equivalent iOS extension
/// code) is the only thing that increments this. The initial value here is
/// a same-platform-instant guess (correct on Android via the shared
/// SharedPreferences file; a stale default on iOS, which has no
/// synchronous access to the App Group store) -- AppPostItApp corrects it
/// via SharedStorage right after first frame and again on every resume,
/// since the write always happens from a native code path outside this
/// instance's awareness.
final insertCountProvider = StateProvider<int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getInt(insertCountKey) ?? 0;
});

final isPremiumProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(kIsPremiumKey) ?? false;
});

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final storage = ref.watch(sharedStorageProvider);
  final service = PurchaseService(
    storage,
    onPremiumUnlocked: () => ref.read(isPremiumProvider.notifier).state = true,
    onRepliesPurchased: (purchaseKey, replies) =>
        grantPurchasedReplies(ref, purchaseKey, replies),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Kicks off PurchaseService.init() (querying product details, restoring
/// past purchases) once, the first time anything watches it.
final purchaseInitProvider = FutureProvider<void>((ref) async {
  await ref.watch(purchaseServiceProvider).init();
});

/// True once the free insert limit is reached without a purchase -- gates
/// the entire app behind PaywallScreen when true.
final isLockedProvider = Provider<bool>((ref) {
  if (ref.watch(isPremiumProvider)) return false;
  final count = ref.watch(insertCountProvider);
  return count >= kFreeInsertLimit;
});

// ---- Smart Reply -------------------------------------------------------

/// Free Smart Reply generations (Generate, Regenerate and Shorten each
/// count) every install gets as a trial. After that, replies come from
/// purchased packs (kReplyPackCredits) -- the one-time posts unlock does
/// not include Smart Reply, since every generation costs real API fees.
/// Everyone is also capped at 25 per day by the server (smart-reply.php,
/// SMART_REPLY_DEVICE_DAILY_LIMIT in anthropic-config.php).
const int kFreeSmartReplyLimit = 3;

/// Free trial generations used so far.
const String smartReplyCountKey = 'smart_reply_count';

/// Purchased replies not yet used. Kept on this device only: consumable
/// purchases aren't restorable from the stores, so a reinstall loses them.
const String smartReplyCreditsKey = 'smart_reply_credits';

/// Recent pack transaction IDs already credited, so a store redelivering
/// an unfinished transaction doesn't credit it twice.
const String creditedPackPurchasesKey = 'smart_reply_credited_purchases';

const String smartReplyConsentKey = 'smart_reply_consent';

final smartReplyCountProvider = StateProvider<int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getInt(smartReplyCountKey) ?? 0;
});

final smartReplyCreditsProvider = StateProvider<int>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getInt(smartReplyCreditsKey) ?? 0;
});

final freeSmartRepliesLeftProvider = Provider<int>((ref) {
  final used = ref.watch(smartReplyCountProvider);
  return (kFreeSmartReplyLimit - used).clamp(0, kFreeSmartReplyLimit);
});

/// Everything the user can still generate: free trial plus purchased.
final smartRepliesRemainingProvider = Provider<int>((ref) =>
    ref.watch(freeSmartRepliesLeftProvider) +
    ref.watch(smartReplyCreditsProvider));

/// Uses one reply after a successful generation: free trial first, then
/// purchased credits.
Future<void> recordSmartReplyUse(WidgetRef ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  if (ref.read(freeSmartRepliesLeftProvider) > 0) {
    final next = ref.read(smartReplyCountProvider) + 1;
    await prefs.setInt(smartReplyCountKey, next);
    ref.read(smartReplyCountProvider.notifier).state = next;
    return;
  }
  final credits = ref.read(smartReplyCreditsProvider);
  final next = credits > 0 ? credits - 1 : 0;
  await prefs.setInt(smartReplyCreditsKey, next);
  ref.read(smartReplyCreditsProvider.notifier).state = next;
}

/// Credits a purchased pack once per store transaction.
Future<void> grantPurchasedReplies(
  Ref ref,
  String purchaseKey,
  int replies,
) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final credited = prefs.getStringList(creditedPackPurchasesKey) ?? [];
  if (credited.contains(purchaseKey)) return;

  final next = ref.read(smartReplyCreditsProvider) + replies;
  await prefs.setInt(smartReplyCreditsKey, next);
  final recent = [...credited, purchaseKey];
  await prefs.setStringList(
    creditedPackPurchasesKey,
    recent.length > 100 ? recent.sublist(recent.length - 100) : recent,
  );
  ref.read(smartReplyCreditsProvider.notifier).state = next;
}

/// Whether the user has agreed to their pasted text being sent to the AI
/// service (required by App Store Guideline 5.1.2(i) before sharing data
/// with a third-party AI).
final smartReplyConsentProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(smartReplyConsentKey) ?? false;
});

Future<void> grantSmartReplyConsent(WidgetRef ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  await prefs.setBool(smartReplyConsentKey, true);
  ref.read(smartReplyConsentProvider.notifier).state = true;
}

final smartReplyServiceProvider = Provider<SmartReplyService>((ref) {
  final service = SmartReplyService(ref.watch(sharedPreferencesProvider));
  ref.onDispose(service.dispose);
  return service;
});

class CustomReplyProfiles extends Notifier<List<ReplyProfile>> {
  @override
  List<ReplyProfile> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return decodeCustomProfiles(prefs.getString(customReplyProfilesKey));
  }

  Future<void> _save(List<ReplyProfile> profiles) async {
    state = profiles;
    await ref
        .read(sharedPreferencesProvider)
        .setString(customReplyProfilesKey, encodeCustomProfiles(profiles));
  }

  Future<ReplyProfile> add(String name, String instructions) async {
    final profile = ReplyProfile(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      instructions: instructions,
    );
    await _save([...state, profile]);
    return profile;
  }

  Future<void> edit(ReplyProfile updated) => _save([
        for (final p in state) p.id == updated.id ? updated : p,
      ]);

  Future<void> remove(String id) =>
      _save(state.where((p) => p.id != id).toList());
}

final customReplyProfilesProvider =
    NotifierProvider<CustomReplyProfiles, List<ReplyProfile>>(
  CustomReplyProfiles.new,
);

final allReplyProfilesProvider = Provider<List<ReplyProfile>>((ref) => [
      ...builtInReplyProfiles,
      ...ref.watch(customReplyProfilesProvider),
    ]);
