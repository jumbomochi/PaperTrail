# PaperTrail

A Flutter app for tracking your physical book collection with photos, barcode scanning, and family tagging.

## Features

- **Book Collection Management** - Add, edit, and organize your physical books
- **Barcode Scanning** - Quickly add books by scanning their ISBN barcodes
- **Photo Support** - Capture and store photos of your books
- **Family Tagging** - Track which family members own or are reading each book
- **Categories** - Organize books by custom categories
- **Wishlist** - Keep track of books you want to add to your collection

## Tech Stack

- Flutter 3.x
- Dart SDK ^3.10.7
- Riverpod for state management
- SQLite for local storage
- mobile_scanner for barcode scanning

## Getting Started

### Prerequisites

- Flutter SDK installed
- iOS Simulator or Android Emulator (or physical device)

### Installation

1. Clone the repository:
   ```bash
   git clone git@github.com:jumbomochi/PaperTrail.git
   cd PaperTrail
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── core/
│   ├── database/       # SQLite database helper
│   ├── services/       # Image and API services
│   └── theme/          # App theming
├── features/
│   ├── books/          # Book management (models, screens, widgets)
│   ├── categories/     # Category management
│   ├── family/         # Family member management
│   ├── home/           # Home screen
│   ├── scanner/        # Barcode scanner
│   └── wishlist/       # Wishlist feature
└── shared/
    └── widgets/        # Shared UI components
```

## License

This project is private and not published to pub.dev.
