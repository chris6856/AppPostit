import 'package:apppostit/data/database.dart';
import 'package:apppostit/data/repositories/category_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CategoryRepository(db);
  });

  tearDown(() => db.close());

  test('create adds a category with incrementing sort order', () async {
    await repo.create('Allergies');
    await repo.create('Promo');

    final categories = await repo.watchAll().first;
    expect(categories.map((c) => c.name), ['Allergies', 'Promo']);
    expect(categories.map((c) => c.sortOrder), [0, 1]);
  });

  test('rename updates the category name', () async {
    final id = await repo.create('Allergies');
    await repo.rename(id, 'Allergy FAQs');

    final categories = await repo.watchAll().first;
    expect(categories.single.name, 'Allergy FAQs');
  });

  test('delete removes the category', () async {
    final id = await repo.create('Allergies');
    await repo.delete(id);

    final categories = await repo.watchAll().first;
    expect(categories, isEmpty);
  });

  test('updateSortOrder reorders categories', () async {
    final firstId = await repo.create('Allergies');
    final secondId = await repo.create('Promo');

    await repo.updateSortOrder([secondId, firstId]);

    final categories = await repo.watchAll().first;
    expect(categories.map((c) => c.id), [secondId, firstId]);
  });
}
