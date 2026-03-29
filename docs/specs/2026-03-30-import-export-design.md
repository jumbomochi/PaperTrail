# Import/Export Feature Design

## Overview

Data-only backup and restore for PaperTrail via JSON export/import, accessed from a new Settings page. Also includes reordering the Add Book screen to emphasize ISBN-based entry.

## Export

- **Entry point:** Gear icon in Home screen app bar → Settings page → "Export Library" button
- **Format:** Single JSON file
- **Filename:** `papertrail_backup_YYYY-MM-DD.json`
- **Delivery:** iOS share sheet (save to Files, AirDrop, email, etc.)
- **Contents:** All books, categories, and family members. No cover images — only metadata and thumbnail URLs.

### JSON structure

```json
{
  "version": 1,
  "exported_at": "2026-03-30T12:00:00.000Z",
  "books": [
    {
      "id": "...",
      "isbn": "978-...",
      "title": "...",
      "author": "...",
      "publisher": "...",
      "published_date": "...",
      "description": "...",
      "thumbnail_url": "...",
      "page_count": 320,
      "owner_id": "...",
      "category_id": "...",
      "is_wishlist": 0,
      "created_at": "...",
      "updated_at": "..."
    }
  ],
  "categories": [
    {
      "id": "...",
      "name": "Fiction",
      "icon": "icon_fiction",
      "created_at": "..."
    }
  ],
  "family_members": [
    {
      "id": "...",
      "name": "...",
      "color": 4284513675,
      "created_at": "..."
    }
  ]
}
```

Notes:
- `cover_image_path` is excluded from export (local file paths are not portable)
- `thumbnail_url` is included (Google Books URLs work across devices)
- `version` field allows future format changes

## Import

- **Entry point:** Settings page → "Import Library" button
- **Flow:**
  1. iOS file picker opens, filtered to `.json` files
  2. File is parsed and validated (check `version` field, required keys)
  3. Confirmation dialog: "Import 42 books, 8 categories, 3 family members?"
  4. User confirms → data merged into DB
- **Conflict handling:** Upsert — matching IDs are overwritten, new records are inserted. Existing data not in the import file is left untouched.
- **Error handling:** Show snackbar on invalid file format or parse errors. Do not partially import — validate everything before writing.
- **Imported books:** `cover_image_path` set to null (images not included). Books with `thumbnail_url` will still display covers via cached network images.

## Settings Page

New minimal settings screen:
- **Export Library** — button with subtitle "Save your collection as a JSON file"
- **Import Library** — button with subtitle "Restore from a backup file"
- **App version** — displayed at bottom

Entry point: gear icon added to Home screen app bar.

## Add Book Screen — ISBN Emphasis

Reorder the Add Book screen to lead with ISBN:
- ISBN field and "Scan Barcode" button placed at the top of the form
- Helper text: "Enter an ISBN or scan a barcode for best results"
- Manual entry fields (title, author, etc.) remain below as a secondary path
- No functional changes to the lookup logic — just a layout reorder

## Dependencies

- `share_plus` package — for sharing the export file via iOS share sheet
- `file_picker` package — for selecting import files
- No new native permissions required

## Files to create/modify

- **New:** `lib/features/settings/screens/settings_screen.dart`
- **New:** `lib/core/services/backup_service.dart` — export/import logic
- **Modify:** `lib/features/home/screens/home_screen.dart` — add gear icon to app bar
- **Modify:** `lib/features/books/screens/add_book_screen.dart` — reorder form fields
- **Modify:** `pubspec.yaml` — add `share_plus` and `file_picker` dependencies
