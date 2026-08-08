import 'package:apppostit/data/database.dart';
import 'package:apppostit/data/repositories/category_repository.dart';
import 'package:apppostit/main.dart';
import 'package:apppostit/providers/providers.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
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
}
