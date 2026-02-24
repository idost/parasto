# Parasto App - UI/Icon Designer Handoff Pack

**Project:** Parasto (پرستو) - Persian Audiobook Platform
**Platform:** Flutter (iOS/Android)
**Task:** App icon and splash screen redesign
**Date Created:** 2025-12-30

---

## 📋 What's in This Pack?

This handoff pack contains everything a designer needs to create new app icons and splash screens for the Parasto audiobook app. No technical Flutter knowledge required - just follow the specs!

### Documents Included

1. **[ASSET_INVENTORY.md](./ASSET_INVENTORY.md)** - Current state of all app assets
   - What exists now
   - Where everything is located
   - Current branding colors and fonts
   - Issues with current implementation

2. **[ICON_SPECS_IOS.md](./ICON_SPECS_IOS.md)** - iOS app icon requirements
   - 15 required icon sizes (exact pixel dimensions)
   - Design guidelines and safe zones
   - File format specifications
   - Quality checklist

3. **[ICON_SPECS_ANDROID.md](./ICON_SPECS_ANDROID.md)** - Android app icon requirements
   - Legacy mipmap icons (5 sizes)
   - Adaptive icon system (foreground + background)
   - Safe zone requirements
   - Deliverable structure

4. **[SPLASH_SPECS.md](./SPLASH_SPECS.md)** - Launch/splash screen requirements
   - iOS LaunchImage specifications
   - Android launch_image specifications
   - Design approach and recommendations
   - Aspect ratio considerations

5. **[DESIGNER_DELIVERABLES_CHECKLIST.md](./DESIGNER_DELIVERABLES_CHECKLIST.md)** ⭐ **START HERE**
   - Complete checklist of all required files
   - File naming conventions
   - Folder structure
   - Quality control checklist
   - Delivery instructions

### Reference Files Included

- `ios-appicon-contents.json` - iOS AppIcon asset catalog configuration
- `android-adaptive-icon.xml` - Android adaptive icon XML structure
- `android-colors.xml` - Android color resources (includes launcher background color)

---

## 🎯 Quick Start for Designer

### Step 1: Read the Checklist
Start with **[DESIGNER_DELIVERABLES_CHECKLIST.md](./DESIGNER_DELIVERABLES_CHECKLIST.md)** - this is your master task list.

### Step 2: Understand the Brand
Read the "Brand Design Direction" section in:
- [ASSET_INVENTORY.md](./ASSET_INVENTORY.md) - Section 6 (Branding Colors)
- [DESIGNER_DELIVERABLES_CHECKLIST.md](./DESIGNER_DELIVERABLES_CHECKLIST.md) - "Brand Design Direction for Parasto"

**Key brand elements:**
- **Icon concept:** Two barn swallows (پرستو) + golden sound wave
- **Color palette:** Warm gold `#F2B544`, orange `#E67634`, navy `#1E3A5F`, cream `#FAF7F2`
- **Feel:** Warm, poetic, Persian, premium (NOT techy, NOT gloomy)

### Step 3: Review Platform-Specific Specs

**For iOS icons:**
- Read [ICON_SPECS_IOS.md](./ICON_SPECS_IOS.md)
- Focus on the required sizes table
- Note: NO transparency allowed (opaque backgrounds)
- 15 PNG files required

**For Android icons:**
- Read [ICON_SPECS_ANDROID.md](./ICON_SPECS_ANDROID.md)
- Understand adaptive icon system (foreground + background layers)
- Focus on safe zone requirements (center 66% visible)
- 10 PNG files + 1 background color

**For splash screens:**
- Read [SPLASH_SPECS.md](./SPLASH_SPECS.md)
- Centered logo approach recommended
- iOS: 3 PNG files + background color
- Android: 5 PNG files + background color

### Step 4: Design & Export

1. Create master files (vector preferred - AI, SVG, Sketch, Figma)
2. Export all required PNG sizes using exact dimensions from specs
3. Follow file naming conventions precisely (case-sensitive!)
4. Organize into folder structure from checklist

### Step 5: Quality Check

Use the quality checklists in each spec document:
- [ ] All sizes perfectly square
- [ ] Correct color profiles (sRGB)
- [ ] No transparency where not allowed
- [ ] Files named exactly as specified
- [ ] Test at smallest sizes (still recognizable?)

### Step 6: Deliver

- ZIP all files following folder structure in [DESIGNER_DELIVERABLES_CHECKLIST.md](./DESIGNER_DELIVERABLES_CHECKLIST.md)
- Include README in ZIP explaining deliverables
- Provide background color hex codes in text files
- Send via cloud storage link or direct transfer

---

## 📊 Deliverable Summary (TL;DR)

### What You Need to Design

**1. App Icon Design**
- Square icon design (1:1 aspect ratio)
- Works at sizes from 20×20 px to 1024×1024 px
- Two variations:
  - iOS: Opaque background (no transparency)
  - Android adaptive foreground: Transparent background (PNG with alpha)

**2. Splash Logo Design**
- Centered logo/icon artwork
- Transparent background (background color provided separately)
- Square or flexible aspect ratio
- Works on all device screen sizes

### How Many Files?

| Asset Type | Count | Notes |
|------------|-------|-------|
| iOS app icons | 15 PNG | All sizes of same design |
| iOS splash images | 3 PNG | @1x, @2x, @3x scales |
| Android legacy icons | 5 PNG | All densities of same design |
| Android adaptive foreground | 5 PNG | With transparency |
| Android adaptive background | 1 color code | Hex value (or 5 PNG if using image) |
| Android splash images | 5 PNG | All densities |
| Master design files | 2-3 files | AI/SVG/Sketch/Figma |
| **TOTAL** | **~36-41 files** | + master files |

**Total time estimate:** 8-16 hours for experienced icon designer (including revisions)

---

## 🎨 Design Guidelines Highlights

### Icon Design Tips

**✅ Do:**
- Keep it simple and bold (icons are small!)
- Use high contrast colors
- Test at 20×20 px (smallest iOS size)
- Use the brand color palette
- Make it instantly recognizable
- Design one master, scale to all sizes

**❌ Don't:**
- Use fine details (disappear at small sizes)
- Add text or wordmarks (hard to read)
- Use transparency on iOS icons (not allowed)
- Create different designs for different sizes
- Put critical content too close to edges (gets cropped)

### Adaptive Icon (Android) Safe Zone

Only the **center 72 dp (66%)** of the 108 dp canvas is guaranteed visible:

```
┌─────────────────────────┐
│   May be cropped (18dp) │
│  ┌───────────────────┐  │
│  │                   │  │
│  │  SAFE ZONE (72dp) │  │  ← Keep logo here
│  │                   │  │
│  └───────────────────┘  │
│   May be cropped (18dp) │
└─────────────────────────┘
```

**Why?** Android devices use different mask shapes (circle, squircle, rounded square).

### Splash Screen Approach

**Recommended design:**
- Centered logo (200×200 pt base size for iOS)
- Solid background color (provided as hex)
- Transparent PNG logo artwork
- Works on all aspect ratios (9:16 to 3:4)

**Safe areas:**
- iOS: Avoid top 100pt and bottom 80pt (notch/home indicator)
- Android: Center logo in middle 70% of screen

---

## 🔍 Current State Issues

From [ASSET_INVENTORY.md](./ASSET_INVENTORY.md):

### Problems with Current Icons
❌ Source files are JPEG instead of PNG (lossy compression)
❌ One source file is non-square (728×716 instead of square)
❌ Typo in filename: `app_ico0n.png` (zero instead of 'o')
❌ iOS splash is 1×1 transparent pixels (effectively invisible)
❌ Android splash is white only (no branding)

### What's Working
✅ All required iOS icon sizes present (19 files)
✅ Complete Android icon set (mipmaps + adaptive)
✅ Well-defined brand color system
✅ Persian font configured (Vazirmatn)

---

## 📐 Technical Specs Quick Reference

### iOS App Icon Sizes (15 required)

| Size | Dimensions | Usage |
|------|------------|-------|
| 20pt | 20/40/60 px | Notifications |
| 29pt | 29/58/87 px | Settings |
| 40pt | 40/80/120 px | Spotlight |
| 60pt | 120/180 px | iPhone App |
| 76pt | 76/152 px | iPad App |
| 83.5pt | 167 px | iPad Pro |
| 1024pt | 1024 px | App Store ⭐ |

### Android Icon Sizes

**Legacy Mipmaps:**
- mdpi: 48×48 px
- hdpi: 72×72 px
- xhdpi: 96×96 px
- xxhdpi: 144×144 px
- xxxhdpi: 192×192 px

**Adaptive Foreground/Background:**
- mdpi: 108×108 px
- hdpi: 162×162 px
- xhdpi: 216×216 px
- xxhdpi: 324×324 px
- xxxhdpi: 432×432 px

### Splash Logo Sizes

**iOS:**
- @1x: ~200×200 px
- @2x: ~400×400 px
- @3x: ~600×600 px

**Android:**
- mdpi: 192×192 px
- hdpi: 288×288 px
- xhdpi: 384×384 px
- xxhdpi: 576×576 px
- xxxhdpi: 768×768 px

---

## 🎨 Brand Color Palette

Use these colors in your icon design:

| Color Name | Hex | RGB | Usage |
|------------|-----|-----|-------|
| **Primary Gold** | `#F2B544` | 242, 181, 68 | Sound wave, CTAs |
| **Secondary Orange** | `#E67634` | 230, 118, 52 | Swallow chest |
| **Navy Blue** | `#1E3A5F` | 30, 58, 95 | Swallow wings |
| **Warm Cream** | `#FAF7F2` | 250, 247, 242 | Light background |
| **Dark Navy** | `#0F1825` | 15, 24, 37 | Dark background |
| **Warm White** | `#F9F5F0` | 249, 245, 240 | Text/highlights |

**Recommended splash background:** `#FAF7F2` (warm cream) for light, inviting feel.

---

## ❓ Questions or Issues?

### Before Starting Design

If anything is unclear:
1. Check the relevant spec document ([ICON_SPECS_IOS.md](./ICON_SPECS_IOS.md), [ICON_SPECS_ANDROID.md](./ICON_SPECS_ANDROID.md), or [SPLASH_SPECS.md](./SPLASH_SPECS.md))
2. Review the [DESIGNER_DELIVERABLES_CHECKLIST.md](./DESIGNER_DELIVERABLES_CHECKLIST.md)
3. Contact developer with specific questions

### During Design

Common questions answered in specs:
- **"What size should I design at?"** → Start with 1024×1024 px (iOS App Store size), scale down
- **"Can I use gradients?"** → Yes! Just ensure they look good at small sizes
- **"Can icons have transparency?"** → iOS: No. Android adaptive foreground: Yes, required.
- **"What about rounded corners?"** → iOS applies them automatically. Design square, no rounding needed.
- **"Do all sizes need to be different designs?"** → No! All sizes should be scaled versions of one master design.

---

## ✅ Pre-Delivery Checklist

Before sending files:

- [ ] All PNG files exported at exact dimensions specified
- [ ] Filenames match specifications exactly (case-sensitive)
- [ ] iOS icons have NO transparency (opaque backgrounds)
- [ ] Android adaptive foreground HAS transparency
- [ ] sRGB color profile on all PNGs
- [ ] Master design files included
- [ ] Background color hex codes provided in text files
- [ ] Folder structure matches [DESIGNER_DELIVERABLES_CHECKLIST.md](./DESIGNER_DELIVERABLES_CHECKLIST.md)
- [ ] README included in delivery ZIP
- [ ] ZIP file tested (extracts correctly)

---

## 📦 Delivery Format

### Folder Structure

```
parasto-design-handoff/
├── README.md
├── master/
│   ├── app-icon-master.ai (or .svg)
│   └── splash-logo-master.ai (or .svg)
├── ios-icons/
│   └── (15 PNG files)
├── android-icons/
│   ├── legacy-mipmaps/ (5 PNG files)
│   ├── adaptive-foreground/ (5 PNG files)
│   └── adaptive-background/ (color or 5 PNG files)
├── ios-splash/
│   └── (3 PNG files + background-color.txt)
└── android-splash/
    └── (5 PNG files + background-color.txt)
```

### Delivery Method

- **Compressed:** ZIP archive
- **Naming:** `parasto-design-handoff-YYYY-MM-DD.zip`
- **Transfer:** Cloud storage link (Google Drive, Dropbox, WeTransfer) or direct transfer if < 50MB

---

## 🎯 Success Criteria

Your design will be considered complete when:

✅ All required PNG files delivered with exact dimensions
✅ Files named precisely as specified
✅ Master design files included
✅ Icons look sharp and recognizable at smallest sizes
✅ Android adaptive icon works with circle mask (safe zone respected)
✅ Brand colors and aesthetic maintained
✅ Documentation (README) included in delivery

---

## 📚 Additional Resources

### Design Inspiration

- **Apple Human Interface Guidelines:** [iOS App Icon Design](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- **Android Material Design:** [Product Icons](https://m3.material.io/styles/icons/designing-icons)
- **Persian Calligraphy:** Consider incorporating Persian aesthetic elements
- **Audiobook Themes:** Sound waves, books, listening, storytelling

### Design Tools

Recommended tools for icon design:
- **Sketch** (Mac) - Icon template files available
- **Figma** (Web/Desktop) - Free, collaborative
- **Adobe Illustrator** (Cross-platform) - Industry standard
- **Affinity Designer** (One-time purchase alternative)

Batch export tools:
- **Sketch:** Built-in export presets
- **Figma:** Batch export with naming patterns
- **Illustrator:** Asset Export panel
- **Icon Slate** (Mac) - Dedicated icon generator

---

**Ready to start? Begin with [DESIGNER_DELIVERABLES_CHECKLIST.md](./DESIGNER_DELIVERABLES_CHECKLIST.md)!** 🎨

Good luck, and thank you for designing for Parasto! 📚🎧✨
