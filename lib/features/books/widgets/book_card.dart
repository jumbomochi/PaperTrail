import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:paper_trail/features/books/models/book.dart';

class BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback? onTap;
  final String? ownerName;
  final Color? ownerColor;
  final int quoteCount;

  const BookCard({
    super.key,
    required this.book,
    this.onTap,
    this.ownerName,
    this.ownerColor,
    this.quoteCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildCoverImage()),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            book.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _buildIndicators(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.author,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    if (ownerName != null) _buildOwnerChip(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage() {
    if (book.coverImagePath != null) {
      return Image.file(
        File(book.coverImagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } else if (book.thumbnailUrl != null) {
      return CachedNetworkImage(
        imageUrl: book.thumbnailUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(Icons.menu_book, size: 40, color: Colors.grey.shade400),
      ),
    );
  }

  Widget _buildOwnerChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ownerColor?.withValues(alpha: 0.2) ?? Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        ownerName!,
        style: TextStyle(
          fontSize: 10,
          color: ownerColor ?? Colors.grey.shade700,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildIndicators() {
    final hasReview = (book.review ?? '').isNotEmpty;
    if (!hasReview && quoteCount == 0) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasReview)
          Icon(Icons.star, size: 14, color: Colors.amber.shade700),
        if (quoteCount > 0) ...[
          if (hasReview) const SizedBox(width: 4),
          Icon(Icons.format_quote, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 2),
          Text(
            '$quoteCount',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ],
    );
  }
}
