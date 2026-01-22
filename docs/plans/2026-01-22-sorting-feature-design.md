# Book List Sorting Feature Design

## Overview

Add sorting options to the book list screen to allow users to organize their collection by title, author, or date added.

## Sort Options

| Option | Behavior |
|--------|----------|
| Date Added | Newest first (default) |
| Title (A-Z) | Alphabetical by book title |
| Author (A-Z) | Alphabetical by author name |

## User Flow

1. User taps sort icon in app bar (next to filter icon)
2. Popup menu shows all 3 options with checkmark on current selection
3. User taps option → menu closes → books re-sort immediately
4. Sort preference persists during session, resets to Date Added on app restart

## Technical Implementation

### State Management

Add to `BookListScreenState`:
- `_selectedSort` enum with values: `dateAdded`, `title`, `author`
- Default: `dateAdded`
- No persistence required

### Sorting Logic

In `_filterBooks` method, after filtering apply sort:

```dart
switch (_selectedSort) {
  case SortOption.title:
    filtered.sort((a, b) => a.title.compareTo(b.title));
  case SortOption.author:
    filtered.sort((a, b) => a.author.compareTo(b.author));
  case SortOption.dateAdded:
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
}
```

### Files to Modify

1. `lib/features/books/screens/book_list_screen.dart`
   - Add `SortOption` enum
   - Add `_selectedSort` state variable
   - Add sort icon to app bar actions
   - Add `PopupMenuButton` for sort selection
   - Update `_filterBooks` to apply sorting

2. `lib/features/books/screens/wishlist_screen.dart`
   - Apply same sorting feature for consistency

## UI Specification

### App Bar
- Sort icon (`Icons.sort`) placed left of filter icon
- Standard `PopupMenuButton` widget

### Popup Menu
```
┌─────────────────────┐
│ ✓ Date Added        │
│   Title (A-Z)       │
│   Author (A-Z)      │
└─────────────────────┘
```
- Checkmark indicates current selection
- Single tap selects and dismisses

## Scope

### In Scope
- Sort by title, author, date added
- Popup menu UI in app bar
- Apply to both book list and wishlist screens

### Out of Scope
- Descending sort options (Z-A)
- Persisting sort preference across sessions
- Custom/manual sort order
