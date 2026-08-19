import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app.dart';
import '../../../app/widgets/constrained_page_body.dart';
import '../../../core/errors.dart';
import '../../../core/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/mime_utils.dart';
import '../../categories/presentation/categories_providers.dart';
import '../../people/presentation/people_providers.dart';
import '../../people/presentation/person_editor.dart';
import '../domain/document.dart';

class DocumentFormScreen extends ConsumerStatefulWidget {
  const DocumentFormScreen({super.key, this.documentId});

  final String? documentId;

  @override
  ConsumerState<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends ConsumerState<DocumentFormScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagsController = TextEditingController();

  String? _personId;
  String? _categoryId;
  DateTime? _expiresAt;
  String? _fileName;
  String? _mimeType;
  Uint8List? _bytes;
  var _loading = true;
  var _saving = false;
  Document? _existing;

  bool get _isEditing => widget.documentId != null;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final people = await ref.read(personRepositoryProvider).getAll();
    final categories = await ref.read(categoryRepositoryProvider).getAll();
    String? personId = people.where((p) => p.isSelf).firstOrNull?.id;
    String? categoryId = categories.firstOrNull?.id;

    if (widget.documentId != null) {
      final existing =
          await ref.read(documentRepositoryProvider).getById(widget.documentId!);
      if (existing != null) {
        _existing = existing;
        _titleController.text = existing.title;
        _notesController.text = existing.notes;
        _tagsController.text = tagsToInput(existing.tags);
        personId = existing.personId;
        categoryId = existing.categoryId;
        _expiresAt = existing.expiresAt;
        _fileName = existing.originalFileName;
        _mimeType = existing.mimeType;
      }
    }

    if (mounted) {
      setState(() {
        _personId = personId;
        _categoryId = categoryId;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile();
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      _applyPickedFile(
        file.name,
        guessMimeType(file.name, null),
        bytes,
      );
    } catch (_) {
      if (mounted) showAppMessage(context, 'Could not read that file.');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    _applyPickedFile(
      file.name,
      guessMimeType(file.name, file.mimeType),
      bytes,
    );
  }

  void _applyPickedFile(String name, String mime, Uint8List bytes) {
    setState(() {
      _fileName = name;
      _mimeType = mime;
      _bytes = bytes;
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = titleFromFileName(name);
      }
    });
  }

  Future<void> _addPerson() async {
    final created = await showPersonEditor(context);
    if (created != null) {
      setState(() => _personId = created.id);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (_personId == null || _categoryId == null) {
      showAppMessage(context, 'Choose who this is for and a category.');
      return;
    }
    if (title.isEmpty) {
      showAppMessage(context, 'Enter a title.');
      return;
    }
    if (!_isEditing && _bytes == null) {
      showAppMessage(context, 'Attach a file first.');
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(documentRepositoryProvider);
    try {
      if (_isEditing && _existing != null) {
        await repo.update(
          id: _existing!.id,
          personId: _personId!,
          title: title,
          categoryId: _categoryId!,
          tags: parseTags(_tagsController.text),
          notes: _notesController.text,
          expiresAt: _expiresAt,
          originalFileName: _bytes != null ? _fileName : null,
          mimeType: _bytes != null ? _mimeType : null,
          bytes: _bytes,
        );
        if (!mounted) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/document/${_existing!.id}');
        }
      } else {
        final created = await repo.add(
          personId: _personId!,
          title: title,
          categoryId: _categoryId!,
          tags: parseTags(_tagsController.text),
          notes: _notesController.text,
          originalFileName: _fileName!,
          mimeType: _mimeType ?? 'application/octet-stream',
          bytes: _bytes!,
          expiresAt: _expiresAt,
        );
        if (!mounted) return;
        context.pushReplacement('/document/${created.id}');
      }
    } on AppException catch (error) {
      if (mounted) showAppMessage(context, error.message);
    } catch (_) {
      if (mounted) {
        showAppMessage(
          context,
          'Could not save this document. If you are on the web, storage may be full.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(peopleProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit document' : 'Add document'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ConstrainedPageBody(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(
                    'Who is this for?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey('person-$_personId-${people.length}'),
                    initialValue: people.any((p) => p.id == _personId)
                        ? _personId
                        : null,
                    decoration: const InputDecoration(labelText: 'Owner'),
                    items: [
                      for (final person in people)
                        DropdownMenuItem(
                          value: person.id,
                          child: Text(person.ownerLabel),
                        ),
                    ],
                    onChanged: (value) => setState(() => _personId = value),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addPerson,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Add someone'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _FilePickerCard(
                    fileName: _fileName,
                    mimeType: _mimeType,
                    size: _bytes?.length ?? _existing?.sizeBytes,
                    onPickFile: _pickFile,
                    onPickGallery: () => _pickImage(ImageSource.gallery),
                    onPickCamera: kIsWeb
                        ? null
                        : () => _pickImage(ImageSource.camera),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey('category-$_categoryId'),
                    initialValue: categories.any((c) => c.id == _categoryId)
                        ? _categoryId
                        : null,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      for (final category in categories)
                        DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _categoryId = value),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Tags',
                      hintText: 'passport, 2024, school',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notesController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Expiry date'),
                    subtitle: Text(
                      _expiresAt == null
                          ? 'None'
                          : formatDate(_expiresAt!),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_expiresAt != null)
                          IconButton(
                            onPressed: () => setState(() => _expiresAt = null),
                            icon: const Icon(Icons.clear),
                          ),
                        IconButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _expiresAt ?? DateTime.now(),
                              firstDate: DateTime(1990),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => _expiresAt = picked);
                            }
                          },
                          icon: const Icon(Icons.event),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditing ? 'Save changes' : 'Save document'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _FilePickerCard extends StatelessWidget {
  const _FilePickerCard({
    required this.fileName,
    required this.mimeType,
    required this.size,
    required this.onPickFile,
    required this.onPickGallery,
    required this.onPickCamera,
  });

  final String? fileName;
  final String? mimeType;
  final int? size;
  final VoidCallback onPickFile;
  final VoidCallback onPickGallery;
  final VoidCallback? onPickCamera;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fileName == null
                  ? 'No file attached'
                  : '$fileName${size == null ? '' : ' · ${formatBytes(size!)}'}',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onPickFile,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Choose file'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onPickGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
                if (onPickCamera != null)
                  FilledButton.tonalIcon(
                    onPressed: onPickCamera,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Camera'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
