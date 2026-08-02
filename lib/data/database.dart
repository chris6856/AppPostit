import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../platform/app_group_path_channel.dart';
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
    // On iOS the keyboard extension is a separate process/sandbox, so the
    // database has to live in the shared App Group container rather than
    // this app's own documents directory (which the extension can't see
    // at all). Android's keyboard runs in the same app package/UID, so it
    // can already read the default documents directory directly.
    final String dbFolderPath;
    if (Platform.isIOS) {
      final containerPath = await AppGroupPathChannel.getContainerPath();
      if (containerPath == null) {
        throw StateError(
          'App Group container path was null -- check that both the '
          'Runner and keyboard extension targets have the App Group '
          'entitlement configured.',
        );
      }
      dbFolderPath = containerPath;
    } else {
      dbFolderPath = (await getApplicationDocumentsDirectory()).path;
    }
    final file = File(p.join(dbFolderPath, kDatabaseFileName));
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
