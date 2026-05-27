class Quote {
  final String id;
  final String bookId;
  final String text;
  final int? page;
  final DateTime createdAt;

  const Quote({
    required this.id,
    required this.bookId,
    required this.text,
    this.page,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'text': text,
      'page': page,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Quote.fromMap(Map<String, dynamic> map) {
    return Quote(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      text: map['text'] as String,
      page: map['page'] as int?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Quote copyWith({
    String? id,
    String? bookId,
    String? text,
    int? page,
    DateTime? createdAt,
  }) {
    return Quote(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      text: text ?? this.text,
      page: page ?? this.page,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Quote && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
