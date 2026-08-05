import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'platform/app_group_path_channel.dart';
import 'providers/providers.dart';
import 'screens/category_list_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/purchase_service.dart' show kIsPremiumKey;
import 'services/shared_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const AppPostItApp(),
    ),
  );
}

class AppPostItApp extends ConsumerStatefulWidget {
  const AppPostItApp({super.key});

  @override
  ConsumerState<AppPostItApp> createState() => _AppPostItAppState();
}

class _AppPostItAppState extends ConsumerState<AppPostItApp>
    with WidgetsBindingObserver {
  String _lastNativeAction = 'no action yet'; // TEMPORARY debug field.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The provider's own initial value is a same-platform-instant guess
    // (see insertCountProvider's doc comment) -- correct it for real right
    // after first frame, the same way a resume does.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshFromStorage());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Both the insert counter and the premium flag can be written natively
    // -- the counter by the keyboard extension on every insert, the
    // premium flag by this same app but (on iOS) through a different
    // storage path than this cached instance sees. Either way, refresh
    // from the source of truth whenever the app comes back to the
    // foreground rather than trusting whatever was cached at launch.
    if (state == AppLifecycleState.resumed) {
      _refreshFromStorage();
    }
  }

  Future<void> _refreshFromStorage() async {
    final storage = ref.read(sharedStorageProvider);

    // A read immediately after launch/resume can race the App Group
    // store's cross-process propagation of a very recent keyboard write
    // -- confirmed by testing: the first read after opening the app came
    // back null, but a later read (triggered by navigating elsewhere)
    // correctly saw the value. Retry a few times with a short gap rather
    // than trusting the first attempt.
    int? count = await storage.getInt(insertCountKey);
    if (Platform.isIOS) {
      for (var attempt = 0; count == null && attempt < 4; attempt++) {
        await Future.delayed(const Duration(milliseconds: 400));
        count = await storage.getInt(insertCountKey);
      }
    }

    final premium = await storage.getBool(kIsPremiumKey);
    // TEMPORARY: round-trip self-test -- write a value then read it right
    // back, to tell apart "can't persist to the shared suite at all" from
    // "can't see the keyboard extension's specific writes." Also refetch
    // the container path so its exact string can be compared against
    // KeyboardViewController's own logged container path.
    await storage.setBool('_debug_roundtrip', true);
    await storage.getBool('_debug_roundtrip');
    await AppGroupPathChannel.getContainerPath();
    final nativeAction = await storage.debugNativeAction();
    if (!mounted) return;
    ref.read(insertCountProvider.notifier).state = count ?? 0;
    ref.read(isPremiumProvider.notifier).state = premium ?? false;
    setState(() => _lastNativeAction = nativeAction); // Refresh the TEMPORARY debug banner.
  }

  @override
  Widget build(BuildContext context) {
    final hasSeenWelcome = ref.watch(hasSeenWelcomeProvider);
    final isLocked = ref.watch(isLockedProvider);
    // Kick off purchase-service init (product details, restore purchases)
    // once; nothing in the UI needs to await this directly.
    ref.watch(purchaseInitProvider);

    return MaterialApp(
      title: 'AppPostIt',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // Runs for every route regardless of navigation depth, so hitting the
      // free-post limit mid-session immediately replaces whatever's on
      // screen with the paywall -- not just what a fresh `home:` swap would
      // cover.
      builder: (context, child) {
        final content = isLocked ? const PaywallScreen() : (child ?? const SizedBox.shrink());
        return Stack(
          children: [
            content,
            // TEMPORARY: diagnostic banner for the iOS shared-storage
            // channel. Remove once confirmed working.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Material(
                  color: Colors.black87,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      'APP DEBUG: ${SharedStorage.debugLog.entries.map((e) => '${e.key} ${e.value}').join(' | ')}\n'
                      'container=${AppGroupPathChannel.debugLastPath}\n'
                      'nativeAction=$_lastNativeAction',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      home:
          hasSeenWelcome ? const CategoryListScreen() : const WelcomeScreen(),
    );
  }
}
