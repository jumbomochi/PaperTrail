class Book {
  final String id;
  final String? isbn;
  final String title;
  final String author;
  final String? publisher;
  final String? publishedDate;
  final String? description;
  final String? coverImagePath;
  final String? thumbnailUrl;
  final int? pageCount;
  final String? ownerId;
  final String? categoryId;
  final bool isWishlist;
  final DateTime createdAt;
  final DateTime updatedAt;

  Book({
    required this.id,
    this.isbn,
    required this.title,
    required this.author,
    this.publisher,
    this.publishedDate,
    this.description,
    this.coverImagePath,
    this.thumbnailUrl,
    this.pageCount,
    this.ownerId,
    this.categoryId,
    this.isWishlist = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'isbn': isbn,
      'title': title,
      'author': author,
      'publisher': publisher,
      'published_date': publishedDate,
      'description': description,
      'cover_image_path': coverImagePath,
      'thumbnail_url': thumbnailUrl,
      'page_count': pageCount,
      'owner_id': ownerId,
      'category_id': categoryId,
      'is_wishlist': isWishlist ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as String,
      isbn: map['isbn'] as String?,
      title: map['title'] as String,
      author: map['author'] as String,
      publisher: map['publisher'] as String?,
      publishedDate: map['published_date'] as String?,
      description: map['description'] as String?,
      coverImagePath: map['cover_image_path'] as String?,
      thumbnailUrl: map['thumbnail_url'] as String?,
      pageCount: map['page_count'] as int?,
      ownerId: map['owner_id'] as String?,
      categoryId: map['category_id'] as String?,
      isWishlist: (map['is_wishlist'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Book copyWith({
    String? id,
    String? isbn,
    String? title,
    String? author,
    String? publisher,
    String? publishedDate,
    String? description,
    String? coverImagePath,
    String? thumbnailUrl,
    int? pageCount,
    String? ownerId,
    String? categoryId,
    bool? isWishlist,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Book(
      id: id ?? this.id,
      isbn: isbn ?? this.isbn,
      title: title ?? this.title,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      publishedDate: publishedDate ?? this.publishedDate,
      description: description ?? this.description,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      pageCount: pageCount ?? this.pageCount,
      ownerId: ownerId ?? this.ownerId,
      categoryId: categoryId ?? this.categoryId,
      isWishlist: isWishlist ?? this.isWishlist,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Book && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
