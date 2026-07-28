import 'package:apppostit/data/database.dart';
import 'package:apppostit/main.dart';
import 'package:apppostit/providers/providers.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('create a category and a post, then see them listed',
      (tester) async {
    // closeStreamsSynchronously avoids drift's default one-event-loop-delay
    // stream cleanup, which otherwise leaves a pending Timer that
    // flutter_test's strict teardown check flags as an error.
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
          databaseProvider.overrideWithValue(db),
          hasSeenWelcomeProvider.overrideWith((ref) => true),
        ],
        child: const AppPostItApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Create your first category to start saving posts.'),
      findsOneWidget,
    );

    // Add a category.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Allergies');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Allergies'), findsOneWidget);

    // Open the category and add a post.
    await tester.tap(find.text('Allergies'));
    await tester.pumpAndSettle();
    expect(find.text('No saved posts yet. Tap + to add one.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Post text'),
      'Great question! We recommend checking the allergen chart.',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Great question!'), findsOneWidget);
  });
}
