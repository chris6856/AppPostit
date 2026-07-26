import 'package:apppostit/data/database.dart';
import 'package:apppostit/data/repositories/category_repository.dart';
import 'package:apppostit/data/repositories/post_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository categoryRepo;
  late PostRepository postRepo;
  late int categoryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    categoryRepo = CategoryRepository(db);
    postRepo = PostRepository(db);
    categoryId = await categoryRepo.create('Allergies');
  });

  tearDown(() => db.close());

  test('create adds a post scoped to its category', () async {
    await postRepo.create(categoryId: categoryId, body: 'Great question!');

    final posts = await postRepo.watchByCategory(categoryId).first;
    expect(posts.single.body, 'Great question!');
    expect(posts.single.label, isNull);
  });

  test('update changes body and label', () async {
    final id = await postRepo.create(categoryId: categoryId, body: 'Draft');
    await postRepo.update(id, body: 'Final text', label: 'FAQ #1');

    final posts = await postRepo.watchByCategory(categoryId).first;
    expect(posts.single.body, 'Final text');
    expect(posts.single.label, 'FAQ #1');
  });

  test('delete removes the post', () async {
    final id = await postRepo.create(categoryId: categoryId, body: 'Draft');
    await postRepo.delete(id);

    final posts = await postRepo.watchByCategory(categoryId).first;
    expect(posts, isEmpty);
  });

  test('deleting the category cascades to its posts', () async {
    await postRepo.create(categoryId: categoryId, body: 'Draft');
    await categoryRepo.delete(categoryId);

    final posts = await postRepo.watchByCategory(categoryId).first;
    expect(posts, isEmpty);
  });

  test('posts are scoped per category', () async {
    final otherCategoryId = await categoryRepo.create('Promo');
    await postRepo.create(categoryId: categoryId, body: 'Allergy reply');
    await postRepo.create(categoryId: otherCategoryId, body: 'Promo reply');

    final allergyPosts = await postRepo.watchByCategory(categoryId).first;
    expect(allergyPosts.map((p) => p.body), ['Allergy reply']);
  });
}
