import 'package:apppostit/data/database.dart';
import 'package:apppostit/main.dart';
import 'package:apppostit/providers/providers.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'shows the welcome screen on first launch and dismisses it via '
      'Get Started', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: const AppPostItApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thanks for downloading AppPostIt!'), findsOneWidget);
    expect(find.text('Build your categories and posts'), findsOneWidget);

    await tester.ensureVisible(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Thanks for downloading AppPostIt!'), findsNothing);
    expect(prefs.getBool(hasSeenWelcomeKey), isTrue);
  });

  testWidgets('skips the welcome screen if already seen', (tester) async {
    SharedPreferences.setMockInitialValues({hasSeenWelcomeKey: true});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: const AppPostItApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thanks for downloading AppPostIt!'), findsNothing);
    expect(
      find.text('Create your first category to start saving posts.'),
      findsOneWidget,
    );
  });
}
