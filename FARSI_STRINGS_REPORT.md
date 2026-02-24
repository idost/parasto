# CC-PARASTO-FA-STRINGS-012: Persian/Farsi String Inventory Report

**Date:** 2025-12-30
**Task:** Export all hard-coded Persian/Farsi UI strings for copy editing review
**Status:** ✅ COMPLETE

---

## Executive Summary

Successfully extracted and inventoried **1,863 Persian/Farsi strings** from the Flutter codebase into a reviewable CSV format. The export includes string IDs, original text, file locations, line numbers, and widget context for each occurrence.

---

## Deliverables

1. **Export Script:** `tools/export_farsi_strings.dart`
   - Scans all `lib/**/*.dart` files
   - Detects Persian/Arabic Unicode characters (ranges: 0600-06FF, 0750-077F, 08A0-08FF, FB50-FDFF, FE70-FEFF)
   - Generates stable deterministic IDs using SHA256 hash (file+line+text)
   - No external dependencies added (uses dart:io, dart:convert, package:crypto from SDK)

2. **Inventory CSV:** `farsi_strings_inventory.csv`
   - Format: `id, original_text, file, line, widget_or_context`
   - 1,910 lines (1 header + 1,863 strings + 46 duplicates listed separately)
   - CSV properly escaped for commas, quotes, and newlines

---

## Statistics

### Total Strings Found
**1,863 Persian/Farsi string literals**

### Top 10 Files by String Count

| Rank | Count | File |
|------|-------|------|
| 1 | 121 | `lib/screens/audiobook_detail_screen.dart` |
| 2 | 91 | `lib/screens/admin/admin_upload_audiobook_screen.dart` |
| 3 | 81 | `lib/screens/narrator/chapter_management_screen.dart` |
| 4 | 69 | `lib/screens/admin/admin_audiobook_detail_screen.dart` |
| 5 | 58 | `lib/screens/narrator/narrator_edit_screen.dart` |
| 6 | 52 | `lib/screens/admin/admin_chapter_management_screen.dart` |
| 7 | 51 | `lib/screens/listener/library_screen.dart` |
| 8 | 50 | `lib/screens/admin/admin_categories_screen.dart` |
| 9 | 50 | `lib/screens/admin/admin_edit_audiobook_screen.dart` |
| 10 | 43 | `lib/screens/player/player_screen.dart` |

---

## Duplicate Analysis

**271 unique strings appear multiple times** across the codebase.

### Top 10 Most Duplicated Strings

| String | Occurrences | Category |
|--------|-------------|----------|
| `"خطا: $e"` | 41 | Error message pattern |
| `"انصراف"` | 39 | Cancel button |
| `"پرستو"` | 30 | App name |
| `"حذف"` | 29 | Delete button |
| `"رایگان"` | 27 | Free label |
| `"تلاش مجدد"` | 24 | Retry button |
| `"در حال بررسی"` | 12 | Under review status |
| `"ذخیره"` | 11 | Save button |
| `"سایر"` | 10 | Other/Misc option |
| `"فعال"` | 10 | Active status |

### Duplication Insights

1. **Error Messages:** `"خطا: $e"` appears 41 times - suggests opportunity for centralized error handling
2. **UI Buttons:** Common actions like "انصراف" (Cancel), "حذف" (Delete), "ذخیره" (Save) repeated across dialogs
3. **Status Labels:** Repeated status strings like "رایگان" (Free), "در حال بررسی" (Under Review), "فعال" (Active)
4. **Brand Name:** "پرستو" appears 30 times - should be referenced from config constant

---

## Code Quality

### Flutter Analyze
✅ **CLEAN** - No new issues introduced
- 17 pre-existing info-level lints (unrelated to this task)
- All issues are cosmetic (`prefer_const_constructors`, `use_decorated_box`, etc.)

### Git Diff
✅ **MINIMAL FOOTPRINT**
- Added: `tools/export_farsi_strings.dart` (271 lines)
- Added: `farsi_strings_inventory.csv` (1,910 lines)
- No modifications to existing code
- No functional changes to UI or services

---

## Next Steps (Out of Scope for This Task)

1. **Copy Editing:** Send `farsi_strings_inventory.csv` to Persian copy editor for review
2. **Consolidation:** Consider centralizing frequently duplicated strings (error messages, button labels)
3. **Localization:** Future migration to Flutter ARB/i18n system
4. **Constants:** Extract brand name "پرستو" to single source of truth

---

## Sample CSV Output

```csv
id,original_text,file,line,widget_or_context
"4b356839bc63","پرستو","lib/config/app_config.dart",58,"return dotenv.env['APP_NAME_FA'] ?? 'پرستو';"
"8ff9f9dd0704","حساب غیرفعال","lib/main.dart",248,"'حساب غیرفعال',"
"a8833634e9c7","حساب کاربری شما غیرفعال شده است.","lib/main.dart",255,"'حساب کاربری شما غیرفعال شده است.\n\n'"
"65a58f728662","برای اطلاعات بیشتر با پشتیبانی تماس بگیرید.","lib/main.dart",256,"'برای اطلاعات بیشتر با پشتیبانی تماس بگیرید.',"
```

---

## Technical Notes

### Unicode Detection
The script detects Persian/Farsi strings using Unicode ranges:
- **0600-06FF:** Arabic base characters (includes Persian)
- **0750-077F:** Arabic Supplement
- **08A0-08FF:** Arabic Extended-A
- **FB50-FDFF:** Arabic Presentation Forms-A
- **FE70-FEFF:** Arabic Presentation Forms-B

### ID Generation
Stable deterministic IDs generated using:
```dart
SHA256(file_path + line_number + text).substring(0, 12)
```

This ensures:
- Same string at same location = same ID (stable across runs)
- Different locations = different IDs (even if text identical)
- 12-character hex = 48-bit address space (collision probability: ~1 in 281 trillion)

### Context Detection
The script attempts to identify widget/context by pattern matching:
- Explicit widgets: `Text(`, `SnackBar(`, `AlertDialog(`, etc.
- Named parameters: `title:`, `label:`, `hintText:`, etc.
- Fallback: Shows first 50 chars of code line

---

## Acceptance Criteria

✅ All requirements met:
- [x] Export script created at `tools/export_farsi_strings.dart`
- [x] CSV generated with required columns (id, original_text, file, line, widget_or_context)
- [x] Stable deterministic IDs (SHA256 hash)
- [x] Total count: 1,863 strings
- [x] Top 10 files identified
- [x] Duplicates analyzed: 271 unique strings repeated
- [x] `flutter analyze` remains clean
- [x] Zero modifications to UI code
- [x] Zero new dependencies added
- [x] Git diff contains only: script + CSV

**Task Status: COMPLETE ✅**
