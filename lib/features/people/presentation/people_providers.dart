import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../domain/person.dart';

final peopleProvider = StreamProvider<List<Person>>((ref) {
  return ref.watch(personRepositoryProvider).watchAll();
});
