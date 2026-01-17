# PaperTrail Feature Summary

PaperTrail is a cross-platform Flutter app for managing your physical book collection.

## Core Features

### Book Management
- Add books manually with title, author, publisher, and description
- Edit and delete existing books
- View detailed book information including page count and publication date
- Store local cover photos or use thumbnail URLs

### Barcode Scanning
- Scan ISBN barcodes using your device camera
- Auto-fill book details from scanned codes
- Manual ISBN entry option as fallback
- Real-time barcode detection with visual overlay

### Family Tagging
- Create family member profiles with custom colors
- Assign book ownership to family members
- Track who owns or is reading each book
- Color-coded identification throughout the app

### Categories
- Create custom categories to organize books
- Assign books to categories
- Filter and browse books by category

### Wishlist
- Mark books as wishlist items
- Separate view for books you want to acquire
- Convert wishlist items to owned books

### User Interface
- Light and dark theme support
- System theme auto-detection
- Clean Material Design 3 interface
- Home dashboard with collection statistics
- Quick action cards for common tasks

## Technical Features

### Data Storage
- Local SQLite database for offline-first experience
- Persistent storage of all book data
- Image storage for book covers

### Platform Support
- iOS (iPhone and iPad)
- Android
- Web (Chrome)
- macOS desktop

### Architecture
- Feature-based folder structure
- Riverpod state management
- Repository pattern for data access
- Separation of concerns (models, screens, widgets, providers)

## Supported Book Data

| Field | Description |
|-------|-------------|
| ISBN | 10 or 13 digit book identifier |
| Title | Book title |
| Author | Author name |
| Publisher | Publishing company |
| Published Date | Publication date |
| Description | Book summary |
| Page Count | Number of pages |
| Cover Image | Local photo or URL |
| Owner | Family member assignment |
| Category | Custom category |
| Wishlist | Wishlist flag |
