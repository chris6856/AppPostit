import 'dart:convert';

import 'package:apppostit/data/database.dart';
import 'package:apppostit/providers/providers.dart';
import 'package:apppostit/screens/smart_reply_screen.dart';
import 'package:apppostit/services/smart_reply_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late List<http.Request> requests;

  setUp(() {
    db = AppDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    requests = [];
  });

  tearDown(() => db.close());

  Future<SharedPreferences> pumpScreen(
    WidgetTester tester, {
    Map<String, Object> prefsValues = const {},
    http.Response Function(http.Request)? respond,
  }) async {
    // A tall, phone-shaped screen, so the drafted reply below the form is
    // built by the lazy ListView without scrolling.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();
    final client = MockClient((request) async {
      requests.add(request);
      return respond?.call(request) ??
          http.Response(
            jsonEncode({'reply': 'Thanks for reaching out!'}),
            200,
            headers: {'content-type': 'application/json'},
          );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          smartReplyServiceProvider.overrideWithValue(
            SmartReplyService(prefs, client: client),
          ),
        ],
        child: const MaterialApp(home: SmartReplyScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return prefs;
  }

  Future<void> enterMessageAndGenerate(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'Incoming message'),
      'My engine is overheating. Repair or replace?',
    );
    await tester.tap(find.text('Ask Our Assistant'));
    await tester.pumpAndSettle();
  }

  testWidgets('asks for consent once, then drafts and counts a reply',
      (tester) async {
    final prefs = await pumpScreen(tester);
    expect(find.text('3 of 3 free Smart Replies left'), findsOneWidget);

    await enterMessageAndGenerate(tester);
    expect(find.text('Send text to our assistant?'), findsOneWidget);
    expect(requests, isEmpty);

    await tester.tap(find.text('Agree'));
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    final sent = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(sent['mode'], 'generate');
    expect(sent['message'], 'My engine is overheating. Repair or replace?');
    expect(sent['profile_name'], 'General');
    expect(sent['tone'], 'helpful');
    expect(requests.single.headers['X-AppPostIt-Key'], kSmartReplyAppToken);

    expect(find.text('Thanks for reaching out!'), findsOneWidget);
    expect(find.text('2 of 3 free Smart Replies left'), findsOneWidget);
    expect(prefs.getBool(smartReplyConsentKey), isTrue);
    expect(prefs.getInt(smartReplyCountKey), 1);

    // Consent is remembered: Shorten goes straight to the server.
    await tester.scrollUntilVisible(
      find.text('Shorten'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Shorten'));
    await tester.pumpAndSettle();
    expect(find.text('Send text to our assistant?'), findsNothing);
    expect(requests, hasLength(2));
    final shorten = jsonDecode(requests.last.body) as Map<String, dynamic>;
    expect(shorten['mode'], 'shorten');
    expect(shorten['draft'], 'Thanks for reaching out!');
  });

  testWidgets('blocks free users at the limit without calling the server',
      (tester) async {
    await pumpScreen(tester, prefsValues: {
      smartReplyConsentKey: true,
      smartReplyCountKey: kFreeSmartReplyLimit,
    });

    await enterMessageAndGenerate(tester);

    // The pack sheet opens instead, with both packs and their prices.
    expect(
      find.text("You've used your $kFreeSmartReplyLimit free Smart Replies"),
      findsOneWidget,
    );
    expect(find.text('50 replies'), findsOneWidget);
    expect(find.text(r'$1.99'), findsOneWidget);
    expect(find.text('125 replies'), findsOneWidget);
    expect(find.text(r'$4.99'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('the posts unlock does not include Smart Reply',
      (tester) async {
    await pumpScreen(tester, prefsValues: {
      smartReplyConsentKey: true,
      smartReplyCountKey: kFreeSmartReplyLimit,
      'is_premium': true,
    });

    await enterMessageAndGenerate(tester);

    expect(find.text('50 replies'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('uses purchased replies once the free trial is used up',
      (tester) async {
    final prefs = await pumpScreen(tester, prefsValues: {
      smartReplyConsentKey: true,
      smartReplyCountKey: kFreeSmartReplyLimit,
      smartReplyCreditsKey: 2,
    });
    expect(find.text('2 Smart Replies left'), findsOneWidget);

    await enterMessageAndGenerate(tester);

    expect(requests, hasLength(1));
    expect(find.text('Thanks for reaching out!'), findsOneWidget);
    expect(prefs.getInt(smartReplyCreditsKey), 1);
    expect(prefs.getInt(smartReplyCountKey), kFreeSmartReplyLimit);
    expect(find.text('1 Smart Reply left'), findsOneWidget);
  });

  test('credits each pack purchase exactly once', () async {
    SharedPreferences.setMockInitialValues({smartReplyCreditsKey: 4});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final grant = Provider<Future<void> Function(String, int)>(
      (ref) => (key, n) => grantPurchasedReplies(ref, key, n),
    );

    await container.read(grant)('txn-1', 50);
    // The store redelivering the same unfinished transaction.
    await container.read(grant)('txn-1', 50);
    await container.read(grant)('txn-2', 125);

    expect(container.read(smartReplyCreditsProvider), 179);
    expect(prefs.getInt(smartReplyCreditsKey), 179);
  });

  testWidgets("shows the server's error and doesn't count a failed call",
      (tester) async {
    final prefs = await pumpScreen(
      tester,
      prefsValues: {smartReplyConsentKey: true},
      respond: (_) => http.Response(
        jsonEncode({'error': "You've reached today's Smart Reply limit."}),
        429,
      ),
    );

    await enterMessageAndGenerate(tester);

    expect(
      find.text("You've reached today's Smart Reply limit."),
      findsOneWidget,
    );
    expect(prefs.getInt(smartReplyCountKey), isNull);
    expect(find.text('Copy'), findsNothing);
  });
}
