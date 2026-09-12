import 'package:drift/drift.dart';

/// A saved checklist. Row class is named [ListRecord] (rather than the
/// auto-derived `List`) to avoid colliding with `dart:core`'s `List`.
@DataClassName('ListRecord')
class Lists extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  TextColumn get source => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A group of items within a list. Every item belongs to a section; a
/// list may use a single default section to keep simple lists simple
/// (see ARCHITECTURE.md "Default Section Strategy").
@DataClassName('SectionRecord')
class Sections extends Table {
  TextColumn get id => text()();
  TextColumn get listId =>
      text().references(Lists, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().nullable()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A single checklist entry. The column is named `content` rather than
/// `text` to avoid colliding with Drift's `text()` column-builder method
/// on [Table]; it holds the item's text.
@DataClassName('ListItemRecord')
class ListItems extends Table {
  TextColumn get id => text()();
  TextColumn get sectionId =>
      text().references(Sections, #id, onDelete: KeyAction.cascade)();
  TextColumn get content => text()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
