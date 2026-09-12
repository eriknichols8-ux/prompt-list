import 'package:promptlist/features/templates/domain/template_repository.dart';

/// One built-in template's fixed content.
class BuiltInTemplateDefinition {
  const BuiltInTemplateDefinition({
    required this.name,
    this.description,
    required this.sections,
  });

  final String name;
  final String? description;
  final List<TemplateSectionInput> sections;
}

/// PromptList's starter set of built-in templates. Deterministic and
/// requires no network/AI access --- see TASK-031.
const builtInTemplates = <BuiltInTemplateDefinition>[
  BuiltInTemplateDefinition(
    name: 'Grocery Run',
    description: 'A well-rounded weekly grocery list.',
    sections: [
      TemplateSectionInput(
        title: 'Produce',
        items: ['Bananas', 'Apples', 'Spinach', 'Tomatoes', 'Onions'],
      ),
      TemplateSectionInput(
        title: 'Dairy & Eggs',
        items: ['Milk', 'Eggs', 'Butter', 'Cheese', 'Yogurt'],
      ),
      TemplateSectionInput(
        title: 'Pantry',
        items: ['Bread', 'Rice', 'Pasta', 'Olive oil', 'Coffee'],
      ),
      TemplateSectionInput(
        title: 'Household',
        items: ['Paper towels', 'Dish soap', 'Trash bags'],
      ),
    ],
  ),
  BuiltInTemplateDefinition(
    name: 'Weekend Trip Packing',
    description: 'Everything for a short trip away from home.',
    sections: [
      TemplateSectionInput(
        title: 'Clothing',
        items: ['Shirts', 'Pants', 'Underwear', 'Socks', 'Pajamas', 'Jacket'],
      ),
      TemplateSectionInput(
        title: 'Toiletries',
        items: [
          'Toothbrush',
          'Toothpaste',
          'Deodorant',
          'Shampoo',
          'Medications',
        ],
      ),
      TemplateSectionInput(
        title: 'Electronics',
        items: ['Phone charger', 'Headphones', 'Power bank'],
      ),
      TemplateSectionInput(
        title: 'Documents',
        items: ['ID or passport', 'Tickets or confirmations', 'Wallet'],
      ),
    ],
  ),
  BuiltInTemplateDefinition(
    name: 'Moving Day',
    description: 'Stay organized before, during, and after a move.',
    sections: [
      TemplateSectionInput(
        title: 'Before the Move',
        items: [
          'Confirm moving truck or help',
          'Label all boxes by room',
          'Set up utilities at the new place',
          'Update your address',
        ],
      ),
      TemplateSectionInput(
        title: 'Moving Day',
        items: [
          'Do a final walkthrough',
          'Load fragile items carefully',
          'Take utility meter readings',
          'Hand over the keys',
        ],
      ),
      TemplateSectionInput(
        title: 'After the Move',
        items: [
          'Unpack the essentials box first',
          'Check that utilities are on',
          'Update your address with bank and employer',
        ],
      ),
    ],
  ),
  BuiltInTemplateDefinition(
    name: 'Weekly House Cleaning',
    description: 'A recurring room-by-room cleaning routine.',
    sections: [
      TemplateSectionInput(
        title: 'Kitchen',
        items: [
          'Wipe counters',
          'Clean stovetop',
          'Empty the trash',
          'Sweep and mop the floor',
        ],
      ),
      TemplateSectionInput(
        title: 'Bathroom',
        items: [
          'Scrub the toilet',
          'Clean sink and mirror',
          'Wipe down the shower',
        ],
      ),
      TemplateSectionInput(
        title: 'Living Areas',
        items: ['Dust surfaces', 'Vacuum carpets and rugs', 'Tidy up clutter'],
      ),
    ],
  ),
  BuiltInTemplateDefinition(
    name: 'Morning Routine',
    description: 'A simple checklist to start the day.',
    sections: [
      TemplateSectionInput(
        items: [
          'Make the bed',
          'Drink a glass of water',
          'Stretch or exercise',
          "Review today's priorities",
          'Eat breakfast',
        ],
      ),
    ],
  ),
];
