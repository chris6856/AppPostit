import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

/// Filename shared with the native keyboard-extension readers.
/// Keep this in sync with SqliteReader.swift / SqliteReader.kt.
const String kDatabaseFileName = 'apppostit.sqlite';

@DriftDatabase(tables: [Categories, Posts])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, kDatabaseFileName));
    return NativeDatabase.createInBackground(
      file,
      setup: (database) {
        // WAL mode lets the native keyboard-extension readers safely read
        // the file while this app is also open and writing.
        database.execute('PRAGMA journal_mode=WAL');
      },
    );
  });
}
