# CLAUDE.md — Parasto (پرستو) Architecture Reference

> For Claude Code agents working on this codebase. Last updated: 2026-02-24.

## Quick Start

```bash
# Working directory (worktree)
cd /Users/abdullahkhodadad/Projects/ParastoLocal/myna_flutter/.claude/worktrees/relaxed-taussig

# Run
flutter run          # iOS Simulator / attached device
flutter analyze      # Lint check (must pass before commit)
flutter test         # Unit tests

# Build
flutter build ios --debug --no-codesign   # Debug iOS build
# Then open ios/Runner.xcworkspace in Xcode for device deployment
```

## Critical Gotchas

1. **`.env` file is gitignored** — must be manually copied to worktrees. Without it: blank screen (no crash).
2. **After `git stash pop`** — always scan for conflict markers: `grep -rn "^<<<<<<<\|^=======\s*$\|^>>>>>>>" lib/ --include="*.dart"`. Unresolved markers → blank screen.
3. **First Xcode build after clean** often fails with Swift errors — just retry.
4. **`ios/build/` is gitignored** — do NOT commit Xcode build artifacts.
5. **Blank screen diagnosis**: (1) missing `.env`, (2) conflict markers in Dart files, (3) `flutter assemble` silent failure.

## Toolchain

- **Flutter**: 3.38.7 (stable) — locked in `pubspec.yaml` via `flutter: '>=3.38.7'`
- **Dart**: 3.10.7 — locked via `sdk: '>=3.10.7 <4.0.0'`
- **Backend**: Supabase (Postgres + Auth + Storage + Realtime)
- **State Management**: Riverpod 2.x (`flutter_riverpod`)
- **Audio**: `just_audio` + `audio_service` (background playback)
- **Payments**: `in_app_purchase` (iOS StoreKit 2 + SK1 fallback), Stripe (web/admin)

## Project Structure

```
lib/
├── main.dart                 # Entry point: env → Supabase → audio → app
├── config/
│   ├── app_config.dart       # .env loader (flutter_dotenv)
│   ├── env.dart              # Static getters wrapping AppConfig
│   └── audio_config.dart     # Audio timing constants
├── models/                   # (Minimal — most data is Map<String, dynamic>)
├── providers/                # Riverpod providers (26 files)
│   ├── audio_provider.dart   # AudioNotifier — the big one (~2200 lines)
│   ├── home_providers.dart   # Continue listening, streaks, stats
│   ├── download_provider.dart
│   ├── search_providers.dart
│   ├── bookmark_provider.dart
│   ├── category_affinity_provider.dart
│   ├── content_preference_provider.dart
│   └── ...
├── services/                 # Business logic & API layer (33 files)
│   ├── access_gate_service.dart   # SINGLE source of truth for content access
│   ├── audio_handler.dart         # audio_service background handler
│   ├── download_service.dart      # Dio downloads with resume
│   ├── subscription_service.dart  # IAP + Supabase sync
│   ├── search_service.dart        # Dual search (RPC + ILIKE)
│   └── ...
├── screens/                  # UI screens (91 files)
│   ├── listener/             # Main user-facing screens
│   │   ├── main_shell.dart   # Bottom nav (Home / Library / Search / Profile)
│   │   ├── home_screen.dart  # Dynamic home with sections
│   │   ├── library_screen.dart
│   │   ├── search_screen.dart
│   │   ├── bookstore_screen.dart
│   │   └── ...
│   ├── admin/                # Admin panel (35+ screens)
│   ├── narrator/             # Narrator dashboard & uploads
│   ├── player/               # Player + car mode
│   ├── auth/                 # Login, signup, reset
│   ├── subscription/         # Paywall
│   └── support/              # Tickets
├── widgets/                  # Reusable widgets (79 files)
│   ├── content_card_base.dart      # Base card: cover + title + subtitle + badges
│   ├── content_type_micro_label.dart # Farsi type pill on covers
│   ├── audiobook_card.dart         # Legacy card (aspect-ratio-aware)
│   ├── home/                       # Home-specific widgets
│   │   ├── content_cards.dart      # AudiobookCard, MusicCard, EbookCard
│   │   ├── content_sections.dart   # Section containers
│   │   └── ...
│   └── ...
├── theme/
│   └── app_theme.dart        # Design system: AppColors, AppTypography,
│                             # AppSpacing, AppRadius, AppDimensions
└── utils/
    ├── app_strings.dart      # i18n: Farsi/English/Tajiki
    ├── app_logger.dart       # Logging wrapper
    └── farsi_utils.dart      # Number conversion, RTL helpers
```

## Architecture Patterns

### Data Flow: Supabase → Provider → Widget

```
Supabase (Postgres)
  ↓
Service (lib/services/*.dart)     — Supabase queries, business logic
  ↓
Provider (lib/providers/*.dart)   — Riverpod FutureProvider/StateNotifier
  ↓
Screen/Widget                     — ref.watch(provider) → build UI
```

**Most data is `Map<String, dynamic>`** — the codebase does NOT use generated model classes for audiobooks/ebooks. Type-safe access is done inline: `(book['title_fa'] as String?) ?? ''`.

### Riverpod Conventions

- `FutureProvider.autoDispose` for one-shot data fetching (e.g., home sections)
- `StateNotifierProvider` for mutable state (e.g., downloads, bookmarks, audio)
- `ref.invalidate(provider)` to force refetch after mutations
- `invalidateUserProviders(ref)` on auth change — invalidates all user-specific data

### Access Control — Single Source of Truth

All content access goes through `AccessGateService.checkAccess()`:
- **Purchased** → always accessible (permanent)
- **Preview chapters** → always accessible (checked BEFORE subscription)
- **Free items + active subscription** → accessible
- **Free items + no subscription** → LOCKED (paywall)
- **Paid items not owned** → LOCKED (purchase)

### Audio Architecture

`AudioNotifier` (StateNotifier, ~2200 lines) is the central audio state manager:
- Wraps `just_audio` AudioPlayer
- Background via `audio_service` AudioHandler
- Platform-specific auto-next: iOS runs in native context (`_handleAutoNextiOS`), Android uses callback
- Sleep timer: 3 modes (countdown, end-of-chapter, cancel)
- Progress saving: every 15 seconds + on pause/stop + on chapter change

### Content Types

All content lives in a single `audiobooks` table with a `content_type` TEXT column:
- `'music'` → music (1:1 square cover)
- `'podcast'` → podcast (1:1 square cover)
- `'article'` → article (1:1 square cover)
- `'ebook'` → ebook (2:3 portrait cover)
- `'audiobook'` (default) → audiobook (2:3 portrait cover)

Detection logic: `ContentTypeMicroLabel._detectType()` and `ContentTypeMicroIcon._detectType()`.
The old boolean flags (`is_music`, `is_podcast`, `is_article`) have been removed.

### Card System

Two card systems coexist:
1. **Modern**: `ContentCardBase` (generic) → `AudiobookCard`, `MusicCard`, `EbookCard` in `content_cards.dart`
2. **Legacy**: `AudiobookCard` in `audiobook_card.dart` — used in home, search, bookstore, audiobooks screens

Both now have:
- Aspect-ratio-aware covers (1:1 for square content, 2:3 for books)
- `ContentTypeMicroLabel` at bottom-start of cover (Farsi text pill)
- `microLabel` slot in ContentCardBase

### i18n — Three Languages

`AppStrings` class with static getters, each returning the right string based on `currentLanguage`:
- **Farsi** (fa) — default, RTL
- **English** (en) — LTR
- **Tajiki** (tg) — LTR, uses Farsi→Tajiki transliteration + Azure Translator API

### Design System (`app_theme.dart`)

| Token Class | Examples |
|-------------|----------|
| `AppColors` | `.primary` (gold), `.secondary` (orange), `.background`, `.surface` |
| `AppTypography` | `.cardTitle`, `.cardSubtitle`, `.badge`, `.fontFamily` (Abar) |
| `AppSpacing` | `.xs` (4), `.sm` (8), `.md` (16), `.lg` (24), `.xl` (32) |
| `AppRadius` | `.sm` (8), `.md` (12), `.lg` (16), `.xl` (20) |
| `AppDimensions` | `.cardWidth` (140), `.cardCoverHeight` (210), `.musicCardCoverHeight` (160), `.carouselHeightBook` (390), `.carouselHeightSquare` (310) |

**Always prefer design tokens over hardcoded values.**

## Environment Variables (.env)

Required:
- `SUPABASE_URL` — Supabase project URL
- `SUPABASE_ANON_KEY` — Supabase anon/public key

Optional:
- `APP_NAME`, `APP_NAME_FA`
- `AUDIO_BUCKET`, `COVERS_BUCKET`, `PROFILE_IMAGES_BUCKET`
- `AUDIO_URL_EXPIRY` (default: 3600)
- `STRIPE_PUBLISHABLE_KEY`, `STRIPE_MERCHANT_ID`
- `AZURE_TRANSLATOR_KEY`, `AZURE_TRANSLATOR_REGION`

## Roles

The app supports 3 user roles with separate shells:
- **Listener** → `MainShell` (Home / Library / Search / Profile)
- **Narrator** → `NarratorMainShell` (Dashboard / Audiobooks / Upload / Profile)
- **Admin** → `AdminShell` (Sidebar navigation, 35+ management screens)

Role is stored in Supabase `profiles.role` and checked in `main.dart` after auth.

## Key Services Reference

| Service | Purpose |
|---------|---------|
| `AccessGateService` | Content access control (pure logic, no Supabase) |
| `AudioHandler` | Background audio (audio_service integration) |
| `DownloadService` | Dio downloads with resume, 3-concurrent semaphore |
| `SubscriptionService` | IAP purchase flow + Supabase subscription sync |
| `SearchService` | Dual search: `search_content` RPC + ILIKE fallback |
| `BookmarkService` | Supabase CRUD for bookmarks table |
| `NotificationService` | Admin in-app via Supabase Realtime (no FCM yet) |
| `CatalogService` | Audiobook/ebook listings, categories, shelves |
| `EbookService` | Ebook-specific queries and operations |
| `AuthService` | Supabase Auth + social (Google, Apple) |

## Known Issues (as of 2026-02-24)

1. Content preferences: articles section on home screen checks `showEbooks` flag (should be `showArticles`)
2. Home screen doesn't filter audiobooks/music by content preference toggles
3. No listener push notifications (FCM not integrated)
4. Server receipt verification is TODO in `subscription_service.dart`

## Testing

```bash
flutter test                    # All tests
flutter test test/widget_test.dart  # Single file
flutter analyze                 # Static analysis (must be clean)
```

## Git Workflow

- Main repo: `/Users/abdullahkhodadad/Projects/ParastoLocal/myna_flutter`
- Worktrees: `.claude/worktrees/<name>` (e.g., `relaxed-taussig`)
- `.env` must be manually copied to each worktree
- `ios/build/` is gitignored — never commit Xcode artifacts
- `pubspec.lock` IS committed — ensures reproducible builds
