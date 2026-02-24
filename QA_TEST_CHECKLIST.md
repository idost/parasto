# Myna App - QA Test Checklist

## 🧪 STEP 1: Manual Test Checklist by Role

---

## A) LISTENER Role Tests

### A1. Authentication & Routing

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| L-AUTH-01 | Successful Login | Valid listener account exists | 1. Open app 2. Enter valid email/password 3. Tap login | User lands on listener home screen (MainShell) |
| L-AUTH-02 | Wrong Password | Valid listener account exists | 1. Open app 2. Enter valid email + wrong password 3. Tap login | Error message in Persian: "ایمیل یا رمز عبور اشتباه است" |
| L-AUTH-03 | Invalid Email Format | None | 1. Enter invalid email (e.g., "test@") 2. Tap login | Form validation error shown |
| L-AUTH-04 | Logout | User logged in as listener | 1. Go to Profile tab 2. Tap logout | User returns to login screen, auth state cleared |
| L-AUTH-05 | Session Persistence | User previously logged in | 1. Close app completely 2. Reopen app | User auto-logged in, lands on home screen |
| L-AUTH-06 | Expired Session | Session expired on server | 1. Wait for session expiry 2. Try any action | Redirect to login screen with appropriate message |

### A2. Main Flows - Browse & Discovery

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| L-BROWSE-01 | Home Screen Load | User logged in | 1. Open home tab | Featured, New, Popular sections load with covers visible |
| L-BROWSE-02 | Pull to Refresh | On home screen | 1. Pull down on home screen | Sections refresh, loading indicator appears |
| L-BROWSE-03 | Featured Carousel | Featured books exist | 1. Observe featured section | Books show covers, can swipe horizontally |
| L-BROWSE-04 | Category Navigation | Categories exist | 1. Tap on category chip or categories button | Category screen shows filtered audiobooks |
| L-BROWSE-05 | Category Empty State | Category with no books | 1. Open empty category | "هیچ کتابی در این دسته موجود نیست" message |

### A3. Main Flows - Search

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| L-SEARCH-01 | Search by Title | Audiobooks exist | 1. Tap search 2. Type book title 3. Wait for results | Matching books appear |
| L-SEARCH-02 | Search No Results | None | 1. Search for gibberish text | "نتیجه‌ای یافت نشد" message |
| L-SEARCH-03 | Search Clear | Search results showing | 1. Clear search field | Results cleared or default view shown |

### A4. Main Flows - Book Details & Preview

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| L-DETAIL-01 | Open Book Details | Book exists | 1. Tap any book cover | Detail screen shows: cover, title, narrator, description, chapters |
| L-DETAIL-02 | Preview Chapter | Book has preview chapter | 1. Open book detail 2. Tap preview chapter | Audio plays, player screen opens |
| L-DETAIL-03 | Locked Chapters | Book not owned, paid chapters | 1. Open book detail 2. Tap locked chapter | Lock icon visible, tap does nothing or shows "buy" prompt |
| L-DETAIL-04 | Reviews Section | Book has reviews | 1. Scroll to reviews section | Reviews displayed with rating stars |

### A5. Main Flows - Purchase & Library

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| L-BUY-01 | Claim Free Book | Free book exists, not owned | 1. Open free book detail 2. Tap "افزودن به کتابخانه" | Book added to library, button changes to "پخش" |
| L-BUY-02 | Paid Book Flow | Paid book exists, payment configured | 1. Open paid book 2. Tap buy button | Payment flow starts (or coming soon dialog if not configured) |
| L-BUY-03 | Library Tab | User owns books | 1. Go to Library tab | Owned books shown with progress indicators |
| L-BUY-04 | Empty Library | User owns no books | 1. Go to Library tab | "هنوز کتابی خریداری نکرده‌اید" message |
| L-BUY-05 | Wishlist Tab | User has wishlist items | 1. Go to Library > Wishlist tab | Wishlist books shown |
| L-BUY-06 | Empty Wishlist | No wishlist items | 1. Go to Library > Wishlist | "لیست علاقه‌مندی خالی است" message |
| L-BUY-07 | Add to Wishlist | Book not in wishlist | 1. Open book detail 2. Tap heart/wishlist icon | Book added to wishlist |
| L-BUY-08 | Remove from Wishlist | Book in wishlist | 1. Go to wishlist 2. Tap heart/remove icon | Book removed, list updates |

### A6. Main Flows - Playback

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| L-PLAY-01 | Start Playback | Owns book with chapters | 1. Open book 2. Tap play | Player opens, audio plays |
| L-PLAY-02 | Pause/Resume | Audio playing | 1. Tap pause 2. Tap play | Audio pauses, then resumes from same position |
| L-PLAY-03 | Skip Forward/Back | Audio playing | 1. Tap skip buttons | Position jumps 15/30 seconds |
| L-PLAY-04 | Seek Bar | Audio playing | 1. Drag seek bar to new position | Audio seeks to that position |
| L-PLAY-05 | Chapter Navigation | Multi-chapter book | 1. Tap next/prev chapter | Switches to next/prev chapter |
| L-PLAY-06 | Speed Control | Audio playing | 1. Tap speed button 2. Select different speed | Playback speed changes |
| L-PLAY-07 | Background Playback | Audio playing | 1. Press home/switch app | Audio continues in background |
| L-PLAY-08 | Continue Listening | Partially listened book | 1. Close player 2. Reopen book 3. Tap "ادامه" | Resumes from last position |
| L-PLAY-09 | Progress Saved | Play for 30+ seconds | 1. Play chapter 2. Close app 3. Reopen | Progress percentage updated in library |
| L-PLAY-10 | Mini Player | Audio playing, navigate away | 1. Go to other tabs while playing | Mini player visible at bottom |

### A7. Main Flows - Downloads

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| L-DL-01 | Download Chapter | Owns book, on mobile | 1. Open book 2. Tap download icon on chapter | Download starts, progress shown |
| L-DL-02 | Download All | Owns book | 1. Tap "دانلود برای پخش آفلاین" | All chapters start downloading |
| L-DL-03 | Play Downloaded | Chapter downloaded | 1. Turn off internet 2. Play downloaded chapter | Plays from local file |
| L-DL-04 | Delete Download | Chapter downloaded | 1. Tap delete icon on chapter | File deleted, icon changes back to download |
| L-DL-05 | Delete All Downloads | Book fully downloaded | 1. Tap "حذف تمام دانلودها" 2. Confirm | All chapter files deleted |
| L-DL-06 | Download Progress | Download in progress | 1. Observe UI | Progress bar shown on chapter row |
| L-DL-07 | Cancel Download | Download in progress | 1. Tap cancel/X button | Download cancelled, partial file cleaned |

### A8. Offline & Bad Network

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| L-NET-01 | Open App Offline | No internet | 1. Disable network 2. Open app | Appropriate error message, possibly cached data |
| L-NET-02 | Browse Offline | No internet | 1. Disable network 2. Try to browse | "خطا در اتصال به اینترنت" message |
| L-NET-03 | Play Downloaded Offline | Downloaded chapters, no internet | 1. Disable network 2. Play downloaded chapter | Plays successfully |
| L-NET-04 | Play Non-Downloaded Offline | No downloads, no internet | 1. Disable network 2. Try to play | Error message shown |
| L-NET-05 | Network Restored | Was offline, network restored | 1. Restore network 2. Pull to refresh | Data loads successfully |

---

## B) NARRATOR Role Tests

### B1. Authentication & Routing

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| N-AUTH-01 | Narrator Login | Account with narrator role | 1. Login with narrator account | Lands on NarratorMainShell (Dashboard) |
| N-AUTH-02 | Role-Based Access | Narrator account | 1. Login | Sees narrator tabs: Dashboard, Books, Upload, Profile |

### B2. Main Flows - Create Audiobook

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| N-CREATE-01 | Open Upload Screen | Logged in as narrator | 1. Tap Upload tab | Upload form shown |
| N-CREATE-02 | Pick Cover Image | On upload screen | 1. Tap cover area 2. Select image | Image preview shown |
| N-CREATE-03 | Fill Required Fields | On upload screen | 1. Enter title_fa 2. Select category 3. Enter description | Form passes validation |
| N-CREATE-04 | Missing Required Field | On upload screen | 1. Leave title_fa empty 2. Tap submit | Validation error shown |
| N-CREATE-05 | Submit Draft Book | All required fields filled | 1. Fill form 2. Tap submit | Book created with status "draft", redirects to chapter management |
| N-CREATE-06 | Price Toggle | On upload screen | 1. Toggle free/paid 2. If paid, enter price | Price field shows/hides, value saved |

### B3. Main Flows - Chapter Management

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| N-CHAPTER-01 | Open Chapter Screen | Draft book exists | 1. Open book 2. Tap manage chapters | Chapter management screen opens |
| N-CHAPTER-02 | Upload Valid Audio | On chapter screen | 1. Tap add chapter 2. Select MP3/M4A file 3. Enter title 4. Confirm | Chapter uploads, appears in list |
| N-CHAPTER-03 | Upload Invalid Audio | On chapter screen | 1. Tap add 2. Select invalid file (e.g., .txt) | Error: "فرمت فایل پشتیبانی نمی‌شود" |
| N-CHAPTER-04 | Upload Too Large | On chapter screen | 1. Select file >100MB | Warning or error about file size |
| N-CHAPTER-05 | Mark Preview | Chapter exists | 1. Toggle preview checkbox on chapter | Chapter marked as preview, saves |
| N-CHAPTER-06 | Reorder Chapters | Multiple chapters | 1. Drag chapter to new position | Order updated |
| N-CHAPTER-07 | Delete Chapter | Chapter exists | 1. Tap delete 2. Confirm | Chapter removed, audio file deleted |
| N-CHAPTER-08 | Edit Chapter Title | Chapter exists | 1. Tap edit 2. Change title 3. Save | Title updated |

### B4. Main Flows - Submit & Review

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| N-SUBMIT-01 | Submit for Review | Draft book with chapters | 1. Open book 2. Tap submit for review | Status changes to "submitted" |
| N-SUBMIT-02 | Submit No Chapters | Draft book, 0 chapters | 1. Try to submit | Error: "حداقل یک فصل اضافه کنید" |
| N-SUBMIT-03 | View Submitted Status | Submitted book | 1. Open my books | Shows "در انتظار بررسی" status |
| N-SUBMIT-04 | Edit Submitted Book | Book status "submitted" | 1. Try to edit | Should be restricted or warned |

### B5. Feedback System (New)

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| N-FB-01 | See Feedback Badge | Admin left feedback | 1. Open dashboard | Badge shows unread count (e.g., "3 جدید") |
| N-FB-02 | Open Feedback Screen | Feedback exists | 1. Tap feedback section on dashboard | Feedback screen opens, shows all feedback |
| N-FB-03 | Read Feedback | Unread feedback exists | 1. Open feedback screen | Feedback items shown with type badge (info/change/rejection) |
| N-FB-04 | Badge Updates | Read all feedback | 1. Open feedback screen 2. Go back to dashboard | Badge cleared or count reduced |
| N-FB-05 | Feedback Per Book | Book has feedback | 1. Open book detail 2. Check feedback | Shows feedback specific to that book |
| N-FB-06 | Rejection Reason | Book was rejected | 1. Open rejected book feedback | Shows rejection reason with "دلیل رد" badge |

### B6. Offline & Upload Failures

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| N-NET-01 | Upload No Internet | Network disconnected | 1. Try to upload audio file | Error message, no partial/corrupt data |
| N-NET-02 | Upload Interrupted | Upload in progress | 1. Disable network mid-upload | Error message, can retry |
| N-NET-03 | Save Draft Offline | Network disconnected | 1. Try to save book info | Error message |

---

## C) ADMIN Role Tests

### C1. Authentication & Routing

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| A-AUTH-01 | Admin Login | Account with admin role | 1. Login with admin account | Lands on AdminShell (Dashboard) |
| A-AUTH-02 | Admin Tabs | Admin logged in | 1. Check bottom nav | Sees: Dashboard, Audiobooks, Users, Settings |

### C2. Main Flows - Review Books

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| A-REVIEW-01 | See Pending Books | Books with "submitted" status | 1. Open Audiobooks tab 2. Filter by pending | Shows submitted books |
| A-REVIEW-02 | Open Book Detail | Pending book exists | 1. Tap book | Detail screen shows all info + chapters |
| A-REVIEW-03 | Approve Book | Pending book open | 1. Tap "approved" status chip | Status changes, success message |
| A-REVIEW-04 | Reject Book | Pending book open | 1. Tap "rejected" status chip | Rejection dialog appears, requires reason |
| A-REVIEW-05 | Reject Without Reason | Rejection dialog open | 1. Leave reason empty 2. Tap reject | Validation error, cannot submit |
| A-REVIEW-06 | Reject With Reason | Rejection dialog open | 1. Enter reason 2. Tap reject | Status changes, feedback created for narrator |
| A-REVIEW-07 | Play Chapter | Book detail open | 1. Tap chapter | Audio plays for admin review |

### C3. Feedback System (New)

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| A-FB-01 | Add Book Feedback | Book detail open | 1. Tap feedback icon in AppBar 2. Select type 3. Enter message 4. Submit | Feedback saved, appears in list |
| A-FB-02 | Add Chapter Feedback | Book detail open | 1. Tap feedback icon on chapter row 2. Enter message 3. Submit | Feedback saved with chapter reference |
| A-FB-03 | Select Feedback Type | Feedback dialog open | 1. Tap different type chips | Type changes (info/change required/rejection) |
| A-FB-04 | View Feedback History | Book has feedback | 1. Scroll to feedback section | All feedback for book shown |
| A-FB-05 | Delete Feedback | Feedback exists | 1. Swipe feedback item 2. Confirm delete | Feedback removed |

### C4. Editorial Controls (New)

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| A-EDIT-01 | Open Edit Screen | Book detail open | 1. Tap edit icon in AppBar | Edit screen opens with current values |
| A-EDIT-02 | Edit Title | Edit screen open | 1. Change title_fa 2. Save | Title updated, visible on refresh |
| A-EDIT-03 | Edit Description | Edit screen open | 1. Change description 2. Save | Description updated |
| A-EDIT-04 | Change Category | Edit screen open | 1. Select different category 2. Save | Category updated |
| A-EDIT-05 | Change Cover | Edit screen open | 1. Pick new image 2. Save | Cover updated |
| A-EDIT-06 | Toggle Featured | Edit screen open | 1. Toggle featured switch 2. Save | Featured status updated |
| A-EDIT-07 | Change Price | Edit screen open | 1. Toggle paid 2. Enter new price 3. Save | Price updated |
| A-EDIT-08 | Listener Sees Updates | Admin edited book | 1. Login as listener 2. View same book | Updated info visible |
| A-EDIT-09 | Narrator Sees Updates | Admin edited narrator's book | 1. Login as narrator 2. View book | Updated info visible |

### C5. Offline & Error Handling

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| A-NET-01 | Dashboard Offline | No internet | 1. Open admin dashboard | Error message or cached data |
| A-NET-02 | Save Fails | Network error during save | 1. Try to save changes 2. Network fails | Error message, data not corrupted |
| A-NET-03 | Refresh After Error | Error state shown | 1. Restore network 2. Pull to refresh | Data loads |

---

## D) Data Consistency Tests

| Test ID | Test Case | Preconditions | Steps | Expected Result |
|---------|-----------|---------------|-------|-----------------|
| D-DATA-01 | Wishlist Persistence | Added to wishlist | 1. Add book 2. Close app 3. Reopen | Book still in wishlist |
| D-DATA-02 | Progress Persistence | Listened to book | 1. Play 50% 2. Close app 3. Reopen | Progress shows ~50% |
| D-DATA-03 | Download List Accuracy | Downloaded chapters | 1. Check download icons | Icons match actual downloaded files |
| D-DATA-04 | Null Title Handling | Book with null title_fa | 1. Try to display | No crash, shows fallback or empty string |
| D-DATA-05 | Null Cover Handling | Book with null cover_url | 1. View in list | Placeholder icon shown, no crash |
| D-DATA-06 | Missing Narrator | Book with no narrator profile | 1. View book | Shows "نامشخص" or empty, no crash |

---

## 🧠 STEP 2: Likely Bugs & Weak Points

### Critical Issues (Will Cause Crashes/Failures)

| # | Issue | Location | Why It's a Problem | User Symptom |
|---|-------|----------|-------------------|--------------|
| 1 | ~~**Wishlist table name mismatch**~~ | ~~`wishlist_service.dart`, `library_screen.dart`~~ | ✅ **FIXED** - Now uses `user_wishlist` everywhere | ~~Supabase error~~ |
| 2 | ~~**FeedbackTypeExtension.fromString static method**~~ | ~~`narrator_feedback_screen.dart`, `admin_audiobook_detail_screen.dart`~~ | ✅ **FIXED** - Uses `FeedbackTypeExtension.fromString()` | ~~Compile error~~ |
| 3 | ~~**Rating column name mismatch**~~ | ~~Multiple screens using `average_rating`~~ | ✅ **FIXED** - Now uses `avg_rating` everywhere | ~~Shows 0 rating~~ |

### High Priority (Data/Functionality Issues)

| # | Issue | Location | Why It's a Problem | User Symptom |
|---|-------|----------|-------------------|--------------|
| 4 | **narrator_name field access** | `library_screen.dart:287`, `audiobook_detail_screen.dart:348` | Accessing `narrator_name` directly from audiobook, but it may not be joined/returned | Shows empty narrator name |
| 5 | ~~**Wishlist uses different table than service**~~ | ~~`library_screen.dart` vs `wishlist_service.dart`~~ | ✅ **FIXED** - Both now use `user_wishlist` | ~~All wishlist ops fail~~ |
| 6 | **Download file cleanup on chapter delete** | `chapter_management_screen.dart` | When narrator deletes chapter, audio file deleted from Supabase but local downloads not cleaned | Listener has orphaned local files |
| 7 | **Progress not invalidated after edit** | `admin_edit_audiobook_screen.dart` | After admin edits, narrator/listener providers may show stale data | Stale information until manual refresh |

### Medium Priority (Edge Cases)

| # | Issue | Location | Why It's a Problem | User Symptom |
|---|-------|----------|-------------------|--------------|
| 8 | **No validation on feedback message length** | `admin_feedback_dialog.dart` | Empty or very long messages allowed | Empty feedback confusing, very long messages may truncate |
| 9 | **Race condition in download service** | `download_service.dart:181-182` | Check isDownloaded + isDownloading not atomic | Double downloads possible if tapped quickly |
| 10 | **No internet detection in feedback submit** | `admin_feedback_dialog.dart`, `feedback_service.dart` | Network errors not caught specifically | Generic error message instead of "check internet" |
| 11 | **Rejection dialog uses local context for SnackBar** | `admin_audiobook_detail_screen.dart:196` | SnackBar shown in dialog context, may not appear correctly | User doesn't see validation message |
| 12 | **Profile provider not invalidated on login** | `auth_service.dart` | After login, profile may be cached as null | Old/stale profile data shown |

### Lower Priority (UX Issues)

| # | Issue | Location | Why It's a Problem | User Symptom |
|---|-------|----------|-------------------|--------------|
| 13 | **No loading state when marking feedback read** | `narrator_feedback_screen.dart` | markAllAsRead called in initState with no loading indicator | Badge might flash or show stale count briefly |
| 14 | **Download status not persisted across app restarts** | `download_service.dart` | Only downloaded files persisted, not failed status | Failed downloads show as not started after restart |
| 15 | **Hardcoded "مدیر" for admin name fallback** | Multiple feedback screens | If admin profile not joined properly, shows generic "مدیر" | Narrator can't identify which admin |

---

## 🛠 STEP 3: Prioritized Fix Plan

### Immediate Fixes (Before Any Testing)

| Priority | Fix | Files Affected | Verification |
|----------|-----|----------------|--------------|
| **P0** | ~~**Verify/fix wishlist table name**~~ | ~~`wishlist_service.dart`, `library_screen.dart`~~ | ✅ **DONE** - Changed to `user_wishlist` |
| **P1** | ~~**Verify `avg_rating` column**~~ | ~~Multiple screens~~ | ✅ **DONE** - All use `avg_rating` now |
| **P2** | **Verify narrator_name field in queries** | `library_screen.dart:18`, `audiobook_detail_screen.dart:56` | Check if narrator name shows in library and detail screens |

### Short-Term Fixes (Before Production)

| Priority | Fix | Files Affected | Verification |
|----------|-----|----------------|--------------|
| **P3** | Add minimum message length to feedback dialog | `admin_feedback_dialog.dart` | Test A-FB-01 with empty message |
| **P4** | Invalidate related providers after admin edit | `admin_edit_audiobook_screen.dart` | Test A-EDIT-08,09 - verify listener/narrator see updates |
| **P5** | Add network error handling to feedback service | `feedback_service.dart` | Test with network off during feedback submit |

### Implementation Order

1. ✅ **DONE**: Run `flutter analyze` to catch any compile errors
2. ✅ **DONE**: Wishlist table → `user_wishlist`
3. ✅ **DONE**: Rating column → `avg_rating`
4. **Next**: Run through Critical test cases (L-BUY-05 through 08, rating display)
5. **Then**: Address P3-P5 fixes

### Pre-Testing Checklist

- [x] Wishlist table name fixed to `user_wishlist`
- [x] Rating column fixed to `avg_rating`
- [ ] Narrator name join confirmed working
- [ ] All test cases in sections A1-A3 pass
- [ ] Feedback flow (N-FB-01 through 06, A-FB-01 through 05) works end-to-end
