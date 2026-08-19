import '../../categories/domain/category.dart';
import '../../people/domain/person.dart';
import 'document.dart';

class DocumentListItem {
  const DocumentListItem({
    required this.document,
    required this.person,
    required this.category,
  });

  final Document document;
  final Person person;
  final Category category;
}
