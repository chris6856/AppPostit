import 'package:apppostit/data/database.dart';
import 'package:apppostit/data/repositories/category_repository.dart';
import 'package:apppostit/data/repositories/post_repository.dart';
import 'package:apppostit/main.dart';
import 'package:apppostit/providers/providers.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'shows the paywall once the free post limit is reached, '
      'even mid-navigation', (tester) async {
    final db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);

    final categoryId = await CategoryRepository(db).create('Allergies');
    final postRepo = PostRepository(db);
    for (var i = 0; i < kFreePostLimit; i++) {
      await postRepo.create(categoryId: categoryId, body: 'Post $i');
    }

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

    expect(find.text("You've saved $kFreePostLimit posts!"), findsOneWidget);
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

    final categoryId = await CategoryRepository(db).create('Allergies');
    final postRepo = PostRepository(db);
    for (var i = 0; i < kFreePostLimit + 5; i++) {
      await postRepo.create(categoryId: categoryId, body: 'Post $i');
    }

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

    expect(find.text("You've saved $kFreePostLimit posts!"), findsNothing);
    expect(find.text('Allergies'), findsOneWidget);
  });
}
