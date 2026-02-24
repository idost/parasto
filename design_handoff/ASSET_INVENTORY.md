# Parasto App - Current Asset Inventory

**Project:** Parasto (پرستو) - Persian Audiobook Platform
**Platform:** Flutter (iOS/Android)
**Date:** 2025-12-30

---

## 1. Flutter Assets (pubspec.yaml)

### Configured Assets
```yaml
assets:
  - .env
```

**Note:** Currently only `.env` file is listed. No image/icon assets are declared in pubspec.yaml.

### Font Assets
```yaml
fonts:
  - family: Vazirmatn
    fonts:
      - asset: assets/fonts/Vazirmatn/Vazirmatn-Regular.ttf (weight: 400)
      - asset: assets/fonts/Vazirmatn/Vazirmatn-Medium.ttf (weight: 500)
      - asset: assets/fonts/Vazirmatn/Vazirmatn-SemiBold.ttf (weight: 600)
      - asset: assets/fonts/Vazirmatn/Vazirmatn-Bold.ttf (weight: 700)
```

**Primary Font:** Vazirmatn - Persian/Farsi font family optimized for audiobook reading

---

## 2. Local Assets Directory

### `assets/icons/` - Source Icon Files

| File | Type | Dimensions | Purpose |
|------|------|------------|---------|
| `app_icon.png` | JPEG (not PNG!) | 728x716 | App icon source (non-square, JPEG format issue) |
| `app_ico0n.png` | JPEG (typo in name) | 1024x1024 | App icon source (JPEG format issue) |
| `app_fg.png` | PNG (RGBA) | 192x192 | Foreground layer for adaptive icon |

**⚠️ Issues Identified:**
1. Source files are **JPEG format** instead of PNG (lossy compression, not ideal for icons)
2. Typo in filename: `app_ico0n.png` (zero instead of 'o')
3. `app_icon.png` is **not square** (728x716 - should be 1:1 aspect ratio)

### `assets/fonts/Vazirmatn/` - Font Files
- Vazirmatn-Regular.ttf
- Vazirmatn-Medium.ttf
- Vazirmatn-SemiBold.ttf
- Vazirmatn-Bold.ttf

---

## 3. iOS Assets

### App Icons - `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

**Status:** ✅ All 19 required iOS icon sizes present

**Configuration:** `Contents.json` specifies standard iOS app icon set

| File | Dimensions | Device |
|------|------------|--------|
| Icon-App-20x20@1x.png | 20x20 | iPad |
| Icon-App-20x20@2x.png | 40x40 | iPhone/iPad |
| Icon-App-20x20@3x.png | 60x60 | iPhone |
| Icon-App-29x29@1x.png | 29x29 | iPad |
| Icon-App-29x29@2x.png | 58x58 | iPhone/iPad |
| Icon-App-29x29@3x.png | 87x87 | iPhone |
| Icon-App-40x40@1x.png | 40x40 | iPad |
| Icon-App-40x40@2x.png | 80x80 | iPhone/iPad |
| Icon-App-40x40@3x.png | 120x120 | iPhone |
| Icon-App-60x60@2x.png | 120x120 | iPhone |
| Icon-App-60x60@3x.png | 180x180 | iPhone |
| Icon-App-76x76@1x.png | 76x76 | iPad |
| Icon-App-76x76@2x.png | 152x152 | iPad |
| Icon-App-83.5x83.5@2x.png | 167x167 | iPad Pro |
| Icon-App-1024x1024@1x.png | 1024x1024 | App Store |

**Legacy icons also present (not in Contents.json):**
- Icon-App-50x50@1x.png (50x50)
- Icon-App-50x50@2x.png (100x100)
- Icon-App-57x57@1x.png (57x57)
- Icon-App-57x57@2x.png (114x114)
- Icon-App-72x72@1x.png (72x72)
- Icon-App-72x72@2x.png (144x144)

### Launch Screen - `ios/Runner/Assets.xcassets/LaunchImage.imageset/`

**Status:** ⚠️ Placeholder images (1x1 transparent pixels)

| File | Dimensions | Purpose |
|------|------------|---------|
| LaunchImage.png | 1x1 | @1x placeholder |
| LaunchImage@2x.png | 1x1 | @2x placeholder |
| LaunchImage@3x.png | 1x1 | @3x placeholder |

**Launch Screen Implementation:**
- Uses `LaunchScreen.storyboard` (centered image on white background)
- References "LaunchImage" from Assets.xcassets
- Current images are effectively invisible (1x1 transparent pixels)
- Original design intent: 168x185 pt image (from storyboard metadata)

---

## 4. Android Assets

### Launcher Icons - Mipmap Raster Icons

**Location:** `android/app/src/main/res/mipmap-*/ic_launcher.png`

| Density | Dimensions | DPI | File |
|---------|------------|-----|------|
| mdpi | 48x48 | ~160 | mipmap-mdpi/ic_launcher.png |
| hdpi | 72x72 | ~240 | mipmap-hdpi/ic_launcher.png |
| xhdpi | 96x96 | ~320 | mipmap-xhdpi/ic_launcher.png |
| xxhdpi | 144x144 | ~480 | mipmap-xxhdpi/ic_launcher.png |
| xxxhdpi | 192x192 | ~640 | mipmap-xxxhdpi/ic_launcher.png |

**Status:** ✅ All 5 density variants present (PNG RGB format)

### Adaptive Icon (Android 8.0+)

**Configuration:** `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`

```xml
<adaptive-icon>
  <background android:drawable="@color/ic_launcher_background"/>
  <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
```

**Background Layer:** Solid color `#1a1a2e` (dark navy-blue)
**Foreground Layer:** PNG drawables at multiple densities

| Density | Dimensions | File |
|---------|------------|------|
| mdpi | 108x108 | drawable-mdpi/ic_launcher_foreground.png |
| hdpi | 162x162 | drawable-hdpi/ic_launcher_foreground.png |
| xhdpi | 216x216 | drawable-xhdpi/ic_launcher_foreground.png |
| xxhdpi | 324x324 | drawable-xxhdpi/ic_launcher_foreground.png |
| xxxhdpi | 432x432 | drawable-xxxhdpi/ic_launcher_foreground.png |

**Status:** ✅ Adaptive icon fully implemented with color background + PNG foreground

**Note:** No monochrome icon layer (Android 13+ themed icons not implemented)

### Launch/Splash Screen

**Location:** `android/app/src/main/res/drawable/launch_background.xml`

**Current Implementation:** White background only (no logo/image)

```xml
<layer-list>
    <item android:drawable="@android:color/white" />
    <!-- Image commented out -->
</layer-list>
```

**Status:** ⚠️ Minimal splash (solid white, no branding)

---

## 5. In-App Icon Usage

### Icon System Analysis

**Material Icons:** ✅ Enabled (`uses-material-design: true` in pubspec.yaml)

**Custom Icons:** None found
- No `Image.asset()` or `AssetImage()` usage in Dart code
- No SVG icons (`flutter_svg` not used)
- No custom icon fonts

**Primary Icon Source:** Material Icons (default Flutter icon set)

**Implications for Designer:**
- App uses standard Material Design icons throughout
- No custom in-app icon set currently
- Opportunity to create custom icon set if desired for brand consistency

---

## 6. Branding Colors

### Color Palette (from `lib/theme/app_theme.dart`)

**Design Philosophy:**
> Inspired by Parasto (barn swallow) app icon:
> - Background: warm cream/beige with soft vignette
> - Two barn swallows facing each other:
>   • Deep navy-blue wings and back
>   • Warm orange chest/throat
>   • Clean white belly
> - Golden sound-wave in the middle

#### Core Brand Colors

| Color | Hex | Usage |
|-------|-----|-------|
| **Primary Gold** | `#F2B544` | CTAs, active indicators, progress, prices |
| Primary Gold Dark | `#E5A020` | Gold pressed/active state |
| Primary Gold Light | `#F6CB7A` | Gold soft/hover state |
| **Secondary Orange** | `#E67634` | Secondary CTAs, tags, chapter badges |
| Secondary Orange Light | `#EF8F4D` | Orange soft state |
| **Navy** | `#1E3A5F` | Badges, special indicators, premium features |
| Navy Light | `#2A4A73` | Navy lighter variant |

#### Dark Mode (Primary Theme)

| Element | Hex | Description |
|---------|-----|-------------|
| Background | `#0F1825` | Rich warm navy (primary bg) |
| Surface | `#181F2C` | Cards/surfaces |
| Surface Light | `#202737` | Elevated surfaces |
| Surface Elevated | `#2A3344` | Nested cards, overlays |
| Surface Top | `#323B4F` | Modals, important dialogs |

#### Light Mode (Future)

| Element | Hex | Description |
|---------|-----|-------------|
| Background Light | `#FAF7F2` | Warm cream (like icon background) |
| Surface Light Mode | `#FFFFFF` | Pure white |
| Surface Light Elevated | `#F5F2ED` | Cream elevated |

#### Typography Colors (Dark Mode)

| Text Type | Hex | Description |
|-----------|-----|-------------|
| Primary | `#F9F5F0` | Warm off-white (main text) |
| Secondary | `#B8BCC8` | Muted blue-grey (descriptions) |
| Tertiary | `#8B92A5` | Labels, timestamps |
| Disabled | `#5A6275` | Inactive text |
| On Primary | `#1A1A1A` | Text on gold buttons |
| On Secondary | `#FFFFFF` | Text on orange buttons |

#### Semantic Colors

| Purpose | Hex |
|---------|-----|
| Success | `#4ADE80` |
| Error | `#EF4444` |
| Warning | `#F59E0B` |
| Info | `#3B82F6` |

---

## 7. Typography

### Primary Font Family

**Vazirmatn** - Persian/Farsi optimized font

**Weights Available:**
- Regular (400)
- Medium (500)
- SemiBold (600)
- Bold (700)

**RTL Support:** ✅ Full Persian/Farsi support
**Usage:** Primary font for all UI text and content

---

## 8. Asset Generation Mechanism

### Current Process

**iOS Icons:**
- Manually generated and placed in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- Follows standard Xcode AppIcon asset catalog structure

**Android Icons:**
- Manually generated and placed in density-specific directories
- Adaptive icon manually configured with XML + drawable layers

**No Automated Tool Detected:**
- No `flutter_launcher_icons` package in pubspec.yaml
- No `flutter_native_splash` package in pubspec.yaml
- Icons appear to be manually created and placed

**Recommendation for Designer:**
After providing new icon assets, consider setting up `flutter_launcher_icons` for automated icon generation across all required sizes.

---

## 9. Web/Desktop Assets

**Status:** ❌ Not present in repository

No web or desktop launcher icons found. App appears to be iOS/Android only.

---

## 10. Summary for Designer

### What Exists
✅ Complete iOS icon set (19 sizes)
✅ Complete Android raster icons (5 densities)
✅ Android adaptive icon (foreground + background color)
✅ Comprehensive color palette defined
✅ Persian font family configured

### What Needs Improvement
⚠️ iOS launch screen (1x1 placeholder images)
⚠️ Android splash screen (white only, no branding)
⚠️ Source icon files are JPEG (should be PNG)
⚠️ Source icon has non-square dimensions (728x716)
⚠️ No monochrome icon for Android 13+ themed icons
⚠️ No custom in-app icon set (currently using Material icons)

### Design Direction
The app has a **well-defined brand identity** inspired by:
- **Parasto (barn swallow)** imagery
- **Warm, poetic, Persian, premium** aesthetic
- **Golden sound wave** motif
- **Navy blue and warm orange** color scheme
- **Not techy, not AI-ish, not gloomy** - comfortable for long listening sessions

---

**Next Step:** Review [ICON_SPECS_IOS.md](./ICON_SPECS_IOS.md) and [ICON_SPECS_ANDROID.md](./ICON_SPECS_ANDROID.md) for exact deliverable requirements.
