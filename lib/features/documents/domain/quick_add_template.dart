class QuickAddTemplate {
  const QuickAddTemplate({
    required this.id,
    required this.label,
    required this.title,
    required this.categoryId,
    required this.tags,
    this.suggestExpiry = false,
    required this.icon,
  });

  final String id;
  final String label;
  final String title;
  final String categoryId;
  final List<String> tags;
  final bool suggestExpiry;
  final String icon;
}

const quickAddTemplates = <QuickAddTemplate>[
  QuickAddTemplate(
    id: 'aadhaar',
    label: 'Aadhaar',
    title: 'Aadhaar',
    categoryId: 'category-identity',
    tags: ['aadhaar'],
    icon: 'badge',
  ),
  QuickAddTemplate(
    id: 'pan',
    label: 'PAN Card',
    title: 'PAN Card',
    categoryId: 'category-identity',
    tags: ['pan'],
    icon: 'badge',
  ),
  QuickAddTemplate(
    id: 'passport',
    label: 'Passport',
    title: 'Passport',
    categoryId: 'category-travel',
    tags: ['passport'],
    suggestExpiry: true,
    icon: 'flight',
  ),
  QuickAddTemplate(
    id: 'driving_license',
    label: 'Driving License',
    title: 'Driving License',
    categoryId: 'category-vehicle',
    tags: ['license'],
    suggestExpiry: true,
    icon: 'directions_car',
  ),
  QuickAddTemplate(
    id: 'insurance',
    label: 'Insurance Policy',
    title: 'Insurance Policy',
    categoryId: 'category-finance',
    tags: ['insurance'],
    icon: 'account_balance',
  ),
  QuickAddTemplate(
    id: 'voter_id',
    label: 'Voter ID',
    title: 'Voter ID',
    categoryId: 'category-identity',
    tags: ['voter'],
    icon: 'how_to_vote',
  ),
];

QuickAddTemplate? quickAddTemplateById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final template in quickAddTemplates) {
    if (template.id == id) return template;
  }
  return null;
}
