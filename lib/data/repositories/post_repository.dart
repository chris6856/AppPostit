import 'package:drift/drift.dart';

import '../database.dart';

class PostRepository {
  PostRepository(this._db);

  final AppDatabase _db;

  Stream<List<Post>> watchByCategory(int categoryId) {
    return (_db.select(_db.posts)
          ..where((p) => p.categoryId.equals(categoryId))
          ..orderBy([(p) => OrderingTerm(expression: p.sortOrder)]))
        .watch();
  }

  Future<int> create({
    required int categoryId,
    required String body,
    String? label,
  }) async {
    final nextOrder = await _nextSortOrder(categoryId);
    return _db.into(_db.posts).insert(
          PostsCompanion.insert(
            categoryId: categoryId,
            body: body,
            label: Value(label),
            sortOrder: Value(nextOrder),
          ),
        );
  }

  Future<void> update(int id, {required String body, String? label}) {
    return (_db.update(_db.posts)..where((p) => p.id.equals(id))).write(
      PostsCompanion(
        body: Value(body),
        label: Value(label),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.posts)..where((p) => p.id.equals(id))).go();
  }

  Future<void> updateSortOrder(List<int> orderedIds) {
    return _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.posts)
              ..where((p) => p.id.equals(orderedIds[i])))
            .write(PostsCompanion(sortOrder: Value(i)));
      }
    });
  }

  Future<int> _nextSortOrder(int categoryId) async {
    final rows = await (_db.select(_db.posts)
          ..where((p) => p.categoryId.equals(categoryId)))
        .get();
    if (rows.isEmpty) return 0;
    return rows.map((r) => r.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
  }
}
