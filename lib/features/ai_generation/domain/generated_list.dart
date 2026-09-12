/// A single checklist item proposed by AI generation or modification.
///
/// This is a preview-only DTO. It carries no persisted id, completion
/// state, or sort order -- the app assigns those only after the user
/// explicitly accepts the generated content.
class GeneratedItem {
  const GeneratedItem({required this.text});

  final String text;

  /// Encodes this item using the canonical field names from
  /// `docs/AI_CONTRACT.md`, e.g. for sending an existing list snapshot
  /// as part of a modification request (TASK-050).
  Map<String, dynamic> toJson() => {'text': text};

  @override
  bool operator ==(Object other) =>
      other is GeneratedItem && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'GeneratedItem($text)';
}

/// A section of proposed items. [title] is null for an untitled section.
class GeneratedSection {
  const GeneratedSection({this.title, required this.items});

  final String? title;
  final List<GeneratedItem> items;

  Map<String, dynamic> toJson() => {
    'title': title,
    'items': items.map((item) => item.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is GeneratedSection &&
      other.title == title &&
      _listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(title, Object.hashAll(items));

  @override
  String toString() => 'GeneratedSection($title, $items)';
}

/// The canonical AI-generated list contract described in
/// `docs/AI_CONTRACT.md`. Both generation (TASK-040+) and future
/// modification (TASK-050+) proposals use this same shape so the rest of
/// the app -- validation, preview, and acceptance -- only needs to know
/// about one structure.
///
/// This model is intentionally separate from the persisted `Lists`,
/// `Sections`, and `ListItems` Drift entities: nothing here is written to
/// the database until the user explicitly accepts a preview.
class GeneratedList {
  const GeneratedList({
    required this.title,
    this.description,
    required this.sections,
  });

  final String title;
  final String? description;
  final List<GeneratedSection> sections;

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'sections': sections.map((section) => section.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is GeneratedList &&
      other.title == title &&
      other.description == description &&
      _listEquals(other.sections, sections);

  @override
  int get hashCode => Object.hash(title, description, Object.hashAll(sections));

  @override
  String toString() => 'GeneratedList($title, $description, $sections)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
