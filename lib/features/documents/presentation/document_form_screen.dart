import 'package:file_picker/file_picker.dart';
import 'dart:convert';
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
import '../../settings/presentation/lock_providers.dart';
import '../domain/document.dart';
import 'document_providers.dart';

class DocumentFormScreen extends ConsumerStatefulWidget {
  const DocumentFormScreen({super.key, this.documentId});

  final String? documentId;

  @override
  ConsumerState<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends ConsumerState<DocumentFormScreen> {
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
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
  _DocumentInputMode _inputMode = _DocumentInputMode.file;

  bool get _isEditing => widget.documentId != null;
  bool get _isTextMode => _inputMode == _DocumentInputMode.text;

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
        _inputMode = isPlainTextMime(existing.mimeType)
            ? _DocumentInputMode.text
            : _DocumentInputMode.file;
        if (_inputMode == _DocumentInputMode.text) {
          final bytes =
              await ref.read(documentRepositoryProvider).readFile(existing);
          _textController.text = utf8.decode(bytes, allowMalformed: true);
        }
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
    _textController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<T> _runWithoutRelock<T>(Future<T> Function() action) async {
    final suspendCount = ref.read(lockSuspendCountProvider);
    ref.read(lockSuspendCountProvider.notifier).state = suspendCount + 1;
    try {
      return await action();
    } finally {
      final current = ref.read(lockSuspendCountProvider);
      ref.read(lockSuspendCountProvider.notifier).state =
          current > 0 ? current - 1 : 0;
    }
  }

  Future<void> _pickFile() async {
    final file = await _runWithoutRelock(FilePicker.pickFile);
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
    final file = await _runWithoutRelock(
      () => ImagePicker().pickImage(source: source),
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    // file.mimeType is the most reliable source for camera/gallery images;
    // fall back to guessing from the filename only if it is absent.
    final mime = (file.mimeType?.isNotEmpty == true)
        ? file.mimeType!
        : guessMimeType(file.name, null);
    _applyPickedFile(file.name, mime, bytes);
  }

  void _applyPickedFile(String name, String mime, Uint8List bytes) {
    setState(() {
      _inputMode = _DocumentInputMode.file;
      _fileName = name;
      _mimeType = mime;
      _bytes = bytes;
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = titleFromFileName(name);
      }
    });
  }

  void _switchToTextMode() {
    setState(() {
      _inputMode = _DocumentInputMode.text;
      _fileName = null;
      _mimeType = 'text/plain';
      _bytes = null;
    });
  }

  Future<void> _addPerson() async {
    final created = await showPersonEditor(context);
    if (created != null) {
      setState(() => _personId = created.id);
    }
  }

  Future<void> _maybeShowLockReminder() async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final lockEnabled =
        ref.read(appLockEnabledProvider) || settingsRepo.isAppLockEnabled;
    if (lockEnabled) {
      if (!settingsRepo.isDocReminderShown) {
        await settingsRepo.markDocReminderShown();
      }
      return;
    }
    if (settingsRepo.isDocReminderShown || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final shouldEnable = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _LockReminderDialog(
            onEnable: () => Navigator.of(ctx).pop(true),
            onSkip: () => Navigator.of(ctx).pop(false),
          ),
        ) ??
        false;

    await settingsRepo.markDocReminderShown();

    if (!shouldEnable || !mounted) return;

    final canAuth = await settingsRepo.canAuthenticate();
    if (!mounted) return;
    if (!canAuth) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No screen lock set up on this device. '
            'Add a PIN, pattern, or biometric in device settings first.'),
      ));
      return;
    }

    final success = await settingsRepo.authenticate();
    if (!mounted) return;
    if (success) {
      await settingsRepo.setAppLockEnabled(true);
      ref.read(appLockEnabledProvider.notifier).state = true;
      ref.read(lockProvider.notifier).unlock();
      messenger.showSnackBar(
        const SnackBar(content: Text('App lock enabled.')),
      );
    } else {
      messenger.showSnackBar(const SnackBar(
        content: Text(
          'Authentication failed. You can enable lock in Settings anytime.',
        ),
      ));
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
    if (_isTextMode && _textController.text.trim().isEmpty) {
      showAppMessage(context, 'Enter some text to save.');
      return;
    }
    if (!_isTextMode && !_isEditing && _bytes == null) {
      showAppMessage(context, 'Attach a file first.');
      return;
    }

    final textBytes = _isTextMode
        ? Uint8List.fromList(utf8.encode(_textController.text))
        : null;
    final saveBytes = _isTextMode ? textBytes : _bytes;
    final saveMimeType = _isTextMode ? 'text/plain' : _mimeType;
    final saveFileName =
        _isTextMode ? _textFileName(title) : _fileName;

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
          originalFileName: saveBytes != null ? saveFileName : null,
          mimeType: saveBytes != null ? saveMimeType : null,
          bytes: saveBytes,
        );
        if (!mounted) return;
        ref.invalidate(documentItemProvider(_existing!.id));
        ref.invalidate(documentBytesProvider(_existing!.id));
        ref.invalidate(storageBytesProvider);
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/document/${_existing!.id}');
        }
      } else {
        await _maybeShowLockReminder();
        if (!mounted) return;
        final created = await repo.add(
          personId: _personId!,
          title: title,
          categoryId: _categoryId!,
          tags: parseTags(_tagsController.text),
          notes: _notesController.text,
          originalFileName: saveFileName!,
          mimeType: saveMimeType ?? 'application/octet-stream',
          bytes: saveBytes!,
          expiresAt: _expiresAt,
        );
        if (!mounted) return;
        ref.invalidate(documentItemProvider(created.id));
        ref.invalidate(documentBytesProvider(created.id));
        ref.invalidate(storageBytesProvider);
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
                    isTextMode: _isTextMode,
                    fileName: _fileName,
                    mimeType: _mimeType,
                    size: _bytes?.length ?? _existing?.sizeBytes,
                    onPickFile: _pickFile,
                    onPickGallery: () => _pickImage(ImageSource.gallery),
                    onPickCamera: kIsWeb
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    onTypeText: _switchToTextMode,
                    textLength: _textController.text.trim().length,
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
                  if (_isTextMode) ...[
                    TextField(
                      controller: _textController,
                      onChanged: (_) => setState(() {}),
                      minLines: 8,
                      maxLines: 16,
                      decoration: const InputDecoration(
                        labelText: 'Text content',
                        alignLabelWithHint: true,
                        hintText: 'Type anything you want to save here',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
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

  String _textFileName(String title) {
    final base = title.trim().isEmpty ? 'note' : title.trim();
    final sanitized = base
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final fileBase = sanitized.isEmpty ? 'note' : sanitized;
    return fileBase.toLowerCase().endsWith('.txt')
        ? fileBase
        : '$fileBase.txt';
  }
}

class _FilePickerCard extends StatelessWidget {
  const _FilePickerCard({
    required this.isTextMode,
    required this.fileName,
    required this.mimeType,
    required this.size,
    required this.onPickFile,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onTypeText,
    required this.textLength,
  });

  final bool isTextMode;
  final String? fileName;
  final String? mimeType;
  final int? size;
  final VoidCallback onPickFile;
  final VoidCallback onPickGallery;
  final VoidCallback? onPickCamera;
  final VoidCallback onTypeText;
  final int textLength;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isTextMode
                  ? 'Text note${textLength == 0 ? '' : ' · $textLength characters'}'
                  : fileName == null
                      ? 'No file attached'
                      : '$fileName${size == null ? '' : ' · ${formatBytes(size!)}'}',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onTypeText,
                  icon: const Icon(Icons.notes_outlined),
                  label: const Text('Type text'),
                ),
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

enum _DocumentInputMode { file, text }

class _LockReminderDialog extends StatelessWidget {
  const _LockReminderDialog({
    required this.onEnable,
    required this.onSkip,
  });

  final VoidCallback onEnable;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.shield_outlined, size: 40),
      title: const Text('Protect your documents'),
      content: const Text(
        'You now have documents stored here. Enable App Lock to protect them with your device biometrics, PIN, or pattern.',
      ),
      actions: [
        TextButton(
          onPressed: onSkip,
          child: const Text('Skip'),
        ),
        FilledButton.icon(
          onPressed: onEnable,
          icon: const Icon(Icons.lock_outline),
          label: const Text('Enable'),
        ),
      ],
    );
  }
}
