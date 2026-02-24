# Designer Deliverables Checklist - Parasto App Icon & Splash Redesign

**Project:** Parasto (پرستو) - Persian Audiobook Platform
**Designer Task:** App icon, splash screen, and branding assets redesign
**Platforms:** iOS & Android

---

## 📋 Complete Deliverables Checklist

### ✅ Master Design Files

- [ ] **App Icon Master**
  - Format: AI, Sketch, Figma, or SVG vector file
  - Minimum artboard: 1024×1024 px (iOS App Store size)
  - Recommended: 4096×4096 px for future scalability
  - Organized layers with proper naming
  - Includes safe area guides (see specs)

- [ ] **Splash Logo Master**
  - Format: AI, Sketch, Figma, or SVG vector file
  - Artboard: 600×600 px (for @3x iOS export)
  - Transparent background version
  - All elements on separate editable layers

- [ ] **Brand Guidelines Document (Optional but recommended)**
  - Logo usage guidelines
  - Color palette with hex codes
  - Clear space/padding rules
  - Do's and don'ts

---

## 📱 iOS App Icons (19 PNG files required)

Export all icons as PNG, **no transparency**, sRGB color space:

### Standard iOS Icons (Required)
- [ ] `Icon-App-20x20@1x.png` - 20×20 px
- [ ] `Icon-App-20x20@2x.png` - 40×40 px
- [ ] `Icon-App-20x20@3x.png` - 60×60 px
- [ ] `Icon-App-29x29@1x.png` - 29×29 px
- [ ] `Icon-App-29x29@2x.png` - 58×58 px
- [ ] `Icon-App-29x29@3x.png` - 87×87 px
- [ ] `Icon-App-40x40@1x.png` - 40×40 px
- [ ] `Icon-App-40x40@2x.png` - 80×80 px
- [ ] `Icon-App-40x40@3x.png` - 120×120 px
- [ ] `Icon-App-60x60@2x.png` - 120×120 px
- [ ] `Icon-App-60x60@3x.png` - 180×180 px
- [ ] `Icon-App-76x76@1x.png` - 76×76 px
- [ ] `Icon-App-76x76@2x.png` - 152×152 px
- [ ] `Icon-App-83.5x83.5@2x.png` - 167×167 px
- [ ] `Icon-App-1024x1024@1x.png` - 1024×1024 px ⭐ **App Store icon**

### Quality Checks
- [ ] All icons perfectly square (width = height)
- [ ] No alpha transparency (fully opaque backgrounds)
- [ ] sRGB color profile (not Display P3)
- [ ] All icons scaled from same master design
- [ ] Test at smallest size (20×20 px) - still recognizable?
- [ ] 1024×1024 icon is pristine quality (< 1MB file size)

---

## 🤖 Android App Icons

### Part A: Legacy Mipmap Icons (5 PNG files)

Export as PNG (RGB or RGBA), exact dimensions:

- [ ] `mipmap-mdpi/ic_launcher.png` - 48×48 px
- [ ] `mipmap-hdpi/ic_launcher.png` - 72×72 px
- [ ] `mipmap-xhdpi/ic_launcher.png` - 96×96 px
- [ ] `mipmap-xxhdpi/ic_launcher.png` - 144×144 px
- [ ] `mipmap-xxxhdpi/ic_launcher.png` - 192×192 px

### Part B: Adaptive Icon - Foreground Layer (5 PNG files)

Export as PNG with **transparency** (RGBA), exact dimensions:

- [ ] `drawable-mdpi/ic_launcher_foreground.png` - 108×108 px
- [ ] `drawable-hdpi/ic_launcher_foreground.png` - 162×162 px
- [ ] `drawable-xhdpi/ic_launcher_foreground.png` - 216×216 px
- [ ] `drawable-xxhdpi/ic_launcher_foreground.png` - 324×324 px
- [ ] `drawable-xxxhdpi/ic_launcher_foreground.png` - 432×432 px

**Critical:** Keep main logo/elements within **center 72 dp safe zone**:
- xxxhdpi: center 288×288 px
- xxhdpi: center 216×216 px
- xhdpi: center 144×144 px
- hdpi: center 108×108 px
- mdpi: center 72×72 px

### Part C: Adaptive Icon - Background

**Option 1 (Recommended):** Solid Color
- [ ] Provide hex color code in `background-color.txt`
- Example: `#FAF7F2` (warm cream)

**Option 2 (Alternative):** Image Background
- [ ] `drawable-mdpi/ic_launcher_background.png` - 108×108 px
- [ ] `drawable-hdpi/ic_launcher_background.png` - 162×162 px
- [ ] `drawable-xhdpi/ic_launcher_background.png` - 216×216 px
- [ ] `drawable-xxhdpi/ic_launcher_background.png` - 324×324 px
- [ ] `drawable-xxxhdpi/ic_launcher_background.png` - 432×432 px

### Quality Checks
- [ ] Foreground layer has transparent background (RGBA)
- [ ] Critical content within safe zone (test with circle mask)
- [ ] All densities scale consistently from master
- [ ] Filenames exactly match specification (case-sensitive)
- [ ] Test adaptive icon with different mask shapes

---

## 🚀 iOS Launch Screen (3 PNG files)

Export as PNG with **transparency** (RGBA), sRGB:

- [ ] `LaunchImage.png` - ~200×200 px (@1x)
- [ ] `LaunchImage@2x.png` - ~400×400 px (@2x)
- [ ] `LaunchImage@3x.png` - ~600×600 px (@3x)

**Plus:**
- [ ] Provide background color hex in `ios-splash-background.txt`

### Design Notes
- Logo/icon artwork only (no background in PNG)
- Transparent background (background color set in storyboard)
- Centered content that works on all device aspect ratios
- Keep away from top 100pt and bottom 80pt (safe areas)

---

## 🤖 Android Launch Screen (5 PNG files)

Export as PNG with **transparency** (RGBA), sRGB:

- [ ] `drawable-mdpi/launch_image.png` - 192×192 px
- [ ] `drawable-hdpi/launch_image.png` - 288×288 px
- [ ] `drawable-xhdpi/launch_image.png` - 384×384 px
- [ ] `drawable-xxhdpi/launch_image.png` - 576×576 px
- [ ] `drawable-xxxhdpi/launch_image.png` - 768×768 px

**Plus:**
- [ ] Provide background color hex in `android-splash-background.txt`

### Design Notes
- Logo/icon artwork only (no background in PNG)
- Transparent background (background color set in XML)
- Centered logo that works on all screen sizes/ratios

---

## 📦 File Naming & Organization

### Required Folder Structure

```
parasto-design-handoff/
├── README.md (overview of deliverables)
├── master/
│   ├── parasto-app-icon-master.ai (or .svg, .sketch, .fig)
│   ├── parasto-splash-logo-master.ai (or .svg)
│   └── brand-guidelines.pdf (optional)
│
├── ios-icons/
│   ├── Icon-App-20x20@1x.png
│   ├── Icon-App-20x20@2x.png
│   └── ... (all 15 iOS icons)
│
├── android-icons/
│   ├── legacy-mipmaps/
│   │   ├── mipmap-mdpi/ic_launcher.png
│   │   ├── mipmap-hdpi/ic_launcher.png
│   │   └── ... (all 5 densities)
│   ├── adaptive-foreground/
│   │   ├── drawable-mdpi/ic_launcher_foreground.png
│   │   ├── drawable-hdpi/ic_launcher_foreground.png
│   │   └── ... (all 5 densities)
│   └── adaptive-background/
│       └── background-color.txt (#FAF7F2)
│
├── ios-splash/
│   ├── LaunchImage.png
│   ├── LaunchImage@2x.png
│   ├── LaunchImage@3x.png
│   └── ios-splash-background.txt (#FAF7F2)
│
├── android-splash/
│   ├── drawable-mdpi/launch_image.png
│   ├── drawable-hdpi/launch_image.png
│   ├── ... (all 5 densities)
│   └── android-splash-background.txt (#FAF7F2)
│
└── previews/ (optional but nice to have)
    ├── ios-icons-preview.png (mockup of icons on iOS home screen)
    ├── android-icons-preview.png (mockup with different masks)
    └── splash-preview.png (mockup of launch screen)
```

---

## 🎨 Design Requirements Summary

### File Formats
- **Master files:** AI, SVG, Sketch, Figma (vector preferred)
- **Exported icons:** PNG only (no JPEG, no GIF)
- **Color profile:** sRGB (not Display P3, not Adobe RGB)

### Alpha/Transparency
- **iOS app icons:** ❌ No transparency (opaque background required)
- **Android legacy mipmaps:** ✅ Can have transparency (but usually opaque)
- **Android adaptive foreground:** ✅ Must have transparency (RGBA required)
- **Android adaptive background:** Your choice (color or image)
- **Splash logos (both platforms):** ✅ Must have transparency (RGBA required)

### Aspect Ratio
- **All app icons:** Perfect square (1:1 ratio, width = height)
- **Splash logos:** Square recommended, but flexible

### Safe Zones
- **iOS app icons:** 90% center area (allow 5% margin for corner rounding)
- **Android adaptive icons:** 72 dp center (66% of 108 dp canvas)
- **Splash screens:** Center content, avoid top/bottom 15%

---

## ✨ Brand Design Direction for Parasto

### Visual Identity
**Parasto (پرستو)** = Barn Swallow in Persian

**Current brand concept:**
- Two barn swallows facing each other
- Golden sound wave between them
- Warm cream background (light mode) or navy background (dark mode)

**Color Palette:**
| Element | Hex Code |
|---------|----------|
| Primary Gold (sound wave) | `#F2B544` |
| Secondary Orange (swallow chest) | `#E67634` |
| Navy Blue (swallow wings) | `#1E3A5F` |
| Warm Cream (light bg) | `#FAF7F2` |
| Dark Navy (dark bg) | `#0F1825` |
| Text (warm white) | `#F9F5F0` |

### Design Philosophy
**✅ Should feel:**
- Warm, poetic, Persian, premium
- Inviting for long listening sessions
- Cultural (Persian literary tradition)
- Audio-focused (sound/listening theme)

**❌ Should NOT feel:**
- Techy, AI-ish, futuristic
- Gloomy or dark (even in dark mode - keep it warm)
- Generic, corporate, cold
- Overly minimalist or sterile

### Icon Design Tips
1. **Keep it simple** - icons are viewed at tiny sizes
2. **High contrast** - must work on light and dark backgrounds
3. **Unique silhouette** - recognizable shape even as tiny thumbnail
4. **Cultural relevance** - Persian aesthetic appreciated
5. **Audio theme** - visual representation of audiobooks/listening

---

## 🔍 Quality Control Checklist

Before delivering files, verify:

### Technical
- [ ] All PNG files are losslessly compressed (use ImageOptim or similar)
- [ ] No extra metadata/EXIF data in PNGs
- [ ] All filenames exactly match specification (case-sensitive)
- [ ] Folder structure matches required organization
- [ ] Color profiles are sRGB (check in Photoshop/Preview)
- [ ] No accidental alpha channels on iOS app icons

### Visual
- [ ] Icons look sharp at smallest size (20×20 px iOS)
- [ ] Icons are recognizable when masked to circle (Android)
- [ ] Splash logos are centered and properly sized
- [ ] Colors match brand palette
- [ ] All sizes scaled consistently from master

### Documentation
- [ ] Master files included
- [ ] Background colors provided as hex codes
- [ ] README explains any non-obvious decisions
- [ ] Optional: Brand guidelines for future use

---

## 📬 Delivery Method

### Preferred Delivery
1. **ZIP archive** of complete folder structure above
2. **File naming:** `parasto-design-handoff-YYYY-MM-DD.zip`
3. **Delivery via:**
   - Cloud storage link (Google Drive, Dropbox, WeTransfer)
   - OR direct file transfer if < 50MB

### Delivery Checklist
- [ ] All files present and organized per folder structure
- [ ] ZIP file name includes date
- [ ] Include README.md with:
  - List of all deliverables
  - Background color hex codes
  - Any special instructions
  - Design rationale (brief)
- [ ] Test ZIP extraction (make sure it extracts correctly)

---

## 🎯 Priority Deliverables (If Time-Constrained)

### Phase 1 (Critical - Ship MVP)
1. iOS app icon (15 standard sizes) ⭐
2. Android adaptive icon (foreground + background color) ⭐
3. iOS splash logo (3 sizes) ⭐
4. Android splash logo (5 sizes) ⭐

### Phase 2 (Nice to Have)
5. Android legacy mipmap icons (5 sizes)
6. Master design files (AI/SVG)
7. Brand guidelines document
8. Preview mockups

### Phase 3 (Future Enhancement)
9. Android monochrome icon (for themed icons)
10. Round icon variant
11. Animated splash transition
12. Custom in-app icon set

**Recommendation:** Deliver Phase 1 first for immediate implementation, then Phase 2 for documentation.

---

## ❓ Questions for Designer?

If anything is unclear, contact developer with:
1. **Specific file/requirement** in question
2. **What you need clarified** (size, format, safe zone, etc.)
3. **Reference** to specific section in specs

**Specs documents available:**
- [ASSET_INVENTORY.md](./ASSET_INVENTORY.md) - Current state analysis
- [ICON_SPECS_IOS.md](./ICON_SPECS_IOS.md) - iOS icon details
- [ICON_SPECS_ANDROID.md](./ICON_SPECS_ANDROID.md) - Android icon details
- [SPLASH_SPECS.md](./SPLASH_SPECS.md) - Splash screen details

---

## ✅ Final Checklist Before Delivery

- [ ] All required PNG files exported
- [ ] All master files included
- [ ] Background colors provided as hex codes
- [ ] Filenames exactly match specifications
- [ ] Folder structure matches requirement
- [ ] Files tested (open in Preview/Photoshop to verify)
- [ ] ZIP created and named correctly
- [ ] README.md included in ZIP
- [ ] Delivery link/file ready to send

---

**Thank you for designing for Parasto! 🎨📚🎧**

If you have questions or need clarification on any requirement, please reach out before starting design work.
