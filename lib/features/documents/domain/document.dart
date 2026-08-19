class Document {
  const Document({
    required this.id,
    required this.personId,
    required this.title,
    required this.categoryId,
    required this.tags,
    required this.notes,
    required this.originalFileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.storageKey,
    this.thumbnailKey,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String personId;
  final String title;
  final String categoryId;
  final List<String> tags;
  final String notes;
  final String originalFileName;
  final String mimeType;
  final int sizeBytes;
  final String storageKey;
  final String? thumbnailKey;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}
