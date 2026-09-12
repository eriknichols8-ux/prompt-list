import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/data/drift_list_item_repository.dart';
import 'package:promptlist/features/lists/data/drift_list_repository.dart';
import 'package:promptlist/features/lists/data/drift_section_repository.dart';
import 'package:promptlist/features/lists/domain/build_list_snapshot.dart';

void main() {
  late AppDatabase database;
  late DriftListRepository listRepository;
  late DriftSectionRepository sectionRepository;
  late DriftListItemRepository itemRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    listRepository = DriftListRepository(database);
    sectionRepository = DriftSectionRepository(database);
    itemRepository = DriftListItemRepository(database);
  });

  tearDown(() => database.close());

  test('captures title, description, sections, and item text', () async {
    final list = await listRepository.createList(
      title: 'Groceries',
      description: 'Weekly run',
    );
    final section =
        (await sectionRepository.watchSections(list.id).first).single;
    await sectionRepository.renameSection(
      sectionId: section.id,
      title: 'Produce',
    );
    await itemRepository.addItemToSection(
      sectionId: section.id,
      text: 'Apples',
    );
    await itemRepository.addItemToSection(sectionId: section.id, text: 'Milk');

    final snapshot = await buildListSnapshot(
      list: list,
      sectionRepository: sectionRepository,
      itemRepository: itemRepository,
    );

    expect(snapshot.title, 'Groceries');
    expect(snapshot.description, 'Weekly run');
    expect(snapshot.sections, hasLength(1));
    expect(snapshot.sections.single.title, 'Produce');
    expect(snapshot.sections.single.items.map((i) => i.text), [
      'Apples',
      'Milk',
    ]);
  });

  test('never includes completion state', () async {
    final list = await listRepository.createList(title: 'Groceries');
    final section =
        (await sectionRepository.watchSections(list.id).first).single;
    final milk = await itemRepository.addItemToSection(
      sectionId: section.id,
      text: 'Milk',
    );
    await itemRepository.setItemCompleted(itemId: milk.id, completed: true);

    final snapshot = await buildListSnapshot(
      list: list,
      sectionRepository: sectionRepository,
      itemRepository: itemRepository,
    );

    // GeneratedItem has no completion field at all -- there is nothing
    // to assert false other than its absence from the type itself, so
    // this just confirms the text still comes through untouched.
    expect(snapshot.sections.single.items.single.text, 'Milk');
  });

  test(
    'groups items under the right section across multiple sections',
    () async {
      final list = await listRepository.createList(title: 'Trip');
      final firstSection =
          (await sectionRepository.watchSections(list.id).first).single;
      await sectionRepository.renameSection(
        sectionId: firstSection.id,
        title: 'Clothing',
      );
      await itemRepository.addItemToSection(
        sectionId: firstSection.id,
        text: 'Shirts',
      );
      final secondSection = await sectionRepository.createSection(
        listId: list.id,
        title: 'Electronics',
      );
      await itemRepository.addItemToSection(
        sectionId: secondSection.id,
        text: 'Charger',
      );

      final snapshot = await buildListSnapshot(
        list: list,
        sectionRepository: sectionRepository,
        itemRepository: itemRepository,
      );

      expect(snapshot.sections, hasLength(2));
      expect(snapshot.sections[0].title, 'Clothing');
      expect(snapshot.sections[0].items.single.text, 'Shirts');
      expect(snapshot.sections[1].title, 'Electronics');
      expect(snapshot.sections[1].items.single.text, 'Charger');
    },
  );

  test('an empty section produces an empty items list', () async {
    final list = await listRepository.createList(title: 'Empty list');

    final snapshot = await buildListSnapshot(
      list: list,
      sectionRepository: sectionRepository,
      itemRepository: itemRepository,
    );

    expect(snapshot.sections, hasLength(1));
    expect(snapshot.sections.single.items, isEmpty);
  });
}
