# Parasto Reflection Rules

This file stores **persistent project-specific rules and preferences** for the Parasto / Myna app.

It is maintained by the `/reflect` skill, with human approval.

**Last updated:** 2026-01-05

---

## 1. High-Confidence Rules (DO / DON'T)

### 1.1 Audio & Playback

- **ALWAYS use Xcode for iOS device builds** — `flutter run` can hit CodeSign errors due to deployment target mismatch (project.pbxproj: 12.0 vs Podfile: 13.0). Use `flutter build ios --debug --no-codesign` then open Runner.xcworkspace.

- **NEVER put business logic in audio_handler.dart** — Keep MynaAudioHandler thin. All decisions (auto-next, sleep timer, ownership checks) belong in AudioNotifier. Handler only executes commands and caches state for iOS background.

- **ALWAYS sync autoPlayNext/sleepTimer state to handler** — iOS background playback needs cached values (`setAutoPlayNext()`, `setSleepTimerActive()`, `setOwnershipState()`). Without sync, background auto-next fails.

- **NEVER trust client-supplied price** — Always read audiobook price from database in `create-payment-intent`. Client can lie.

### 1.2 Flutter UI

- (empty)

### 1.3 Backend / Supabase

- **PREFER SECURITY DEFINER functions for RLS circular dependencies** — `user_owns_audiobook()` and `user_is_admin()` prevent infinite recursion in RLS policies.

### 1.4 Testing & QA

- **ALWAYS test `canPlayChapter` ownership path separately** — Ownership (`isOwned=true`) bypasses bounds checking entirely. Tests must cover both owned and non-owned paths to catch edge cases.

- **PREFER pure state class tests before mocking** — `AudioState` tests required zero mocking and caught real behavior (ownership bounds bypass). Start with pure logic tests.

- **REMEMBER PlaylistItem requires `createdAt`** — When creating test fixtures, don't forget required DateTime fields. Use `DateTime(2024, 1, 1)` for deterministic tests.

---

## 2. Medium-Confidence Patterns

- **Use `_chapterCompleteInProgress` guard pattern for all completion-like events** — Both `processingStateStream` and `onPlaybackComplete` callback can fire. Guard prevents double-handling.

- **Cache SharedPreferences values for performance** — `_cachedAutoPlayNext` avoids async `SharedPreferences.getInstance()` on every chapter completion (~50-200ms savings).

- **Capture state upfront in async methods** — In `_onChapterComplete()`, capture `currentState` before any `await` to prevent race conditions where state changes mid-execution.

---

## 3. Low-Confidence Observations

- **Consider adding bounds check to `canPlayChapter` even when owned** — Current behavior allows `canPlayChapter(999)` to return `true` when owned, which could mask bugs upstream. Needs discussion.

- **iOS/Android auto-next code paths diverge** — iOS uses `_handleAutoNextiOS()` directly in handler, Android uses callback to notifier. Consider unifying to reduce duplication.

- **Narrator wallet UI exists but backend is placeholder** — `total_earnings` displayed in dashboard but no withdrawal system. Decide: implement or remove UI.
