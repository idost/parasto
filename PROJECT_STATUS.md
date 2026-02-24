# Parasto (پرستو) — Project Status

> Last updated: 2026-02-24

## Toolchain

| Tool | Version | Locked in |
|------|---------|-----------|
| Flutter | 3.38.7 (stable) | `pubspec.yaml` `flutter: '>=3.38.7'` |
| Dart | 3.10.7 | `pubspec.yaml` `sdk: '>=3.10.7 <4.0.0'` |
| Xcode | Current stable | Build-only (no lock file) |
| CocoaPods | System | `Podfile.lock` committed |

## Codebase Metrics

| Metric | Count |
|--------|-------|
| Dart files | 273 |
| Screens | 91 |
| Providers | 26 |
| Services | 33 |
| Widgets | 79 |
| Dependencies | ~35 (pubspec.yaml) |
| Test files | See `test/` |

## Completed Sprints

### Sprint 1 — Core Audio & Admin (Phases 1–4)
- Supabase schema + RLS policies
- Audio playback (just_audio + audio_service)
- Admin panel (audiobook CRUD, user management, analytics)
- Narrator role & upload flow

### Sprint 2 — Listener Home & Library (Phases 5–7)
- Home screen with dynamic sections (banners, shelves, categories)
- Library screen (owned content, continue listening)
- Category affinity algorithm
- Author follow system

### Sprint 3 — Player & Downloads (Phases 8–10)
- Full player screen (seek, chapters, speed, sleep timer, bookmarks)
- Car mode
- Download manager (Dio, 3-concurrent semaphore, resume support)
- Offline playback

### Sprint 4 — Search, Subscriptions & Polish (Phases 11–14)
- Dual search (Supabase RPC + ILIKE fallback)
- Subscription/IAP (Apple SK2 + SK1 fallback)
- Access gate system (ownership/subscription/preview)
- Paywall screen
- Notifications (admin in-app via Supabase Realtime)
- Listening streaks & stats

### Sprint 5 — Ebook Vertical
- Ebook detail screen + EPUB reader (cosmos_epub)
- Ebook service + providers
- Ebook cards in home, library, search, bookstore
- Swipeable ebook detail navigation

### Sprint 6 — Polish Pass
- PaletteGenerator audit (ebook cover colours)
- Image loading optimization (CachedNetworkImage)
- Dead code cleanup
- Cover ratio system (2:3 books, 1:1 music/podcasts/articles)
- Farsi micro text labels on covers (پادکست, مقاله, کتاب, کتاب‌گویا, موسیقی)
- Carousel height constants (responsive to content type)

## Algorithm Audit Summary (2026-02-24)

13 systems traced end-to-end:

| # | System | Verdict |
|---|--------|---------|
| 3.1 | Category Affinity | ✅ Working |
| 3.2 | Author Follow / Recommendations | ✅ Working |
| 3.3 | Listening Progress (Continue Listening) | ✅ Working |
| 3.4 | Listening Streaks | ✅ Working |
| 3.5 | Download Manager | ✅ Working |
| 3.6 | Sleep Timer | ✅ Working |
| 3.7 | Playback Speed | ✅ Working |
| 3.8 | Bookmarks | ✅ Working |
| 3.9 | Auto-Next Chapter | ✅ Working |
| 3.10 | Content Preferences | ⚠️ Articles use wrong flag |
| 3.11 | Search | ✅ Working |
| 3.12 | Notifications | ⚠️ Admin only; listener push not built |
| 3.13 | Subscription / Premium | ✅ Working |

### Known Issues (Priority Order)

1. **Content Preferences Bug** (trivial) — `home_screen.dart` line 346: articles section checks `showEbooks` instead of a dedicated `showArticles` flag
2. **Audiobook content filtering** (small) — Home screen shows audiobooks regardless of `showAudiobooks` preference
3. **Music content filtering** (small) — Same issue for music items
4. **Listener push notifications** (large) — No FCM integration; only admin in-app notifications via Supabase Realtime
5. **Server receipt verification** (medium) — `subscription_service.dart` line 322–325 has `// TODO: verify receipt with Apple/Google`

## Architecture Overview

See `CLAUDE.md` for full architecture reference.
