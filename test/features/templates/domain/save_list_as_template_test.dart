import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlist/core/database/app_database.dart';
import 'package:promptlist/features/lists/data/drift_list_item_repository.dart';
import 'package:promptlist/features/lists/data/drift_list_repository.dart';
import 'package:promptlist/features/lists/data/drift_section_repository.dart';
import 'package:promptlist/features/templates/data/drift_template_repository.dart';
import 'package:promptlist/features/templates/domain/save_list_as_template.dart';

void main() {
  late AppDatabase database;
  late DriftListRepository listRepository;
  late DriftSectionRepository sectionRepository;
  late DriftListItemRepository itemRepository;
  late DriftTemplateRepository templateRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    listRepository = DriftListRepository(database);
    sectionRepository = DriftSectionRepository(database);
    itemRepository = DriftListItemRepository(database);
    templateRepository = DriftTemplateRepository(database);
  });

  tearDown(() => database.close());

  test(
    'copies sections/items but not completion state into a new template',
    () async {
      final list = await listRepository.createList(title: 'Groceries');
      final section =
          (await sectionRepository.watchSections(list.id).first).single;
      await sectionRepository.renameSection(
        sectionId: section.id,
        title: 'Produce',
      );
      final milk = await itemRepository.addItemToSection(
        sectionId: section.id,
        text: 'Milk',
      );
      await itemRepository.addItemToSection(
        sectionId: section.id,
        text: 'Eggs',
      );
      await itemRepository.setItemCompleted(itemId: milk.id, completed: true);

      final template = await saveListAsTemplate(
        sectionRepository: sectionRepository,
        itemRepository: itemRepository,
        templateRepository: templateRepository,
        listId: list.id,
        name: 'Grocery Template',
        description: 'Saved from Groceries',
      );

      expect(template.name, 'Grocery Template');
      expect(template.description, 'Saved from Groceries');
      expect(template.isBuiltIn, isFalse);

      final withSections = await templateRepository.getTemplate(template.id);
      expect(withSections!.sections, hasLength(1));
      expect(withSections.sections.single.section.title, 'Produce');
      expect(withSections.sections.single.items.map((i) => i.content).toSet(), {
        'Milk',
        'Eggs',
      });
    },
  );

  test('a list with multiple sections copies each one', () async {
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

    final template = await saveListAsTemplate(
      sectionRepository: sectionRepository,
      itemRepository: itemRepository,
      templateRepository: templateRepository,
      listId: list.id,
      name: 'Trip Template',
    );

    final withSections = await templateRepository.getTemplate(template.id);
    expect(withSections!.sections.map((s) => s.section.title).toList(), [
      'Clothing',
      'Electronics',
    ]);
  });

  test(
    'full flow: list -> template -> new list is independent end to end',
    () async {
      final sourceList = await listRepository.createList(title: 'Groceries');
      final sourceSection =
          (await sectionRepository.watchSections(sourceList.id).first).single;
      final sourceItem = await itemRepository.addItemToSection(
        sectionId: sourceSection.id,
        text: 'Milk',
      );
      await itemRepository.setItemCompleted(
        itemId: sourceItem.id,
        completed: true,
      );

      final template = await saveListAsTemplate(
        sectionRepository: sectionRepository,
        itemRepository: itemRepository,
        templateRepository: templateRepository,
        listId: sourceList.id,
        name: 'Grocery Template',
      );

      final withSections = await templateRepository.getTemplate(template.id);
      final newList = await listRepository.createListFromTemplate(
        withSections!,
      );

      // The new list's copy starts unchecked, independent of the
      // source list's completed item.
      final newItems = await itemRepository.watchItems(newList.id).first;
      expect(newItems.single.content, 'Milk');
      expect(newItems.single.completed, isFalse);

      // Editing the new list mutates neither the template nor the
      // original source list.
      await itemRepository.editItemText(
        itemId: newItems.single.id,
        text: 'Oat milk',
      );

      final reloadedTemplate = await templateRepository.getTemplate(
        template.id,
      );
      expect(reloadedTemplate!.sections.single.items.single.content, 'Milk');

      final reloadedSourceItems = await itemRepository
          .watchItems(sourceList.id)
          .first;
      expect(reloadedSourceItems.single.content, 'Milk');
      expect(reloadedSourceItems.single.completed, isTrue);
    },
  );
}
