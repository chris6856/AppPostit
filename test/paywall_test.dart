import 'package:apppostit/data/database.dart';
import 'package:apppostit/data/repositories/category_repository.dart';
import 'package:apppostit/main.dart';
import 'package:apppostit/providers/providers.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'shows the paywall once the free insert limit is reached, '
      'even mid-navigation', (tester) async {
    final db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);

    // Inserts are only ever recorded by the keyboard's native UsageTracker,
    // never by the Dart side -- simulate that by seeding the pref directly.
    SharedPreferences.setMockInitialValues({
      insertCountKey: kFreeInsertLimit,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          hasSeenWelcomeProvider.overrideWith((ref) => true),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const AppPostItApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("You've used your $kFreeInsertLimit free inserts!"),
      findsOneWidget,
    );
    expect(find.text('Allergies'), findsNothing);
  });

  testWidgets('does not show the paywall for a premium user', (tester) async {
    final db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);

    await CategoryRepository(db).create('Allergies');

    SharedPreferences.setMockInitialValues({
      insertCountKey: kFreeInsertLimit + 5,
      'is_premium': true,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          hasSeenWelcomeProvider.overrideWith((ref) => true),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const AppPostItApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("You've used your $kFreeInsertLimit free inserts!"),
      findsNothing,
    );
    expect(find.text('Allergies'), findsOneWidget);
  });

  testWidgets(
      'can open the paywall directly from User Management before hitting '
      'the limit, and close it again', (tester) async {
    final db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          hasSeenWelcomeProvider.overrideWith((ref) => true),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const AppPostItApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Not locked yet -- normal app content, not the paywall takeover.
    expect(find.text('Unlock Unlimited Posts'), findsNothing);

    await tester.tap(find.text('User Management'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unlock Unlimited Posts'));
    await tester.pumpAndSettle();

    // Reached voluntarily, so the "you've used your limit" copy shouldn't
    // show -- this is what lets App Review (or a curious user) find the
    // IAP without configuring and using the keyboard extension first.
    expect(find.text('Unlock Unlimited Posts'), findsOneWidget);
    expect(find.textContaining('free inserts!'), findsNothing);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Unlock Unlimited Posts'), findsNothing);
    expect(
      find.text('Create your first category to start saving posts.'),
      findsOneWidget,
    );
  });

  testWidgets('hides the direct-unlock menu entry once premium',
      (tester) async {
    final db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);

    SharedPreferences.setMockInitialValues({'is_premium': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          hasSeenWelcomeProvider.overrideWith((ref) => true),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const AppPostItApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('User Management'));
    await tester.pumpAndSettle();

    expect(find.text('Unlock Unlimited Posts'), findsNothing);
  });
}
