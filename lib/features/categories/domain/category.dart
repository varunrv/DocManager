class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.sortOrder,
    required this.isDefault,
  });

  final String id;
  final String name;
  final String icon;
  final int sortOrder;
  final bool isDefault;
}
