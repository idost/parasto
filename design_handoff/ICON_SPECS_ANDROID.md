# Android App Icon Specifications - Parasto

**Platform:** Android 5.0+ (API 21+)
**Adaptive Icon:** Android 8.0+ (API 26+)
**Themed Icon:** Android 13+ (API 33+) - **Not yet implemented**

---

## 1. Icon System Overview

Android uses **three icon types**:

### A. Legacy Mipmap Icons (Android 5-7)
- **Location:** `android/app/src/main/res/mipmap-{density}/ic_launcher.png`
- **Format:** PNG raster images at 5 densities
- **Shape:** Square icons (will be displayed as-is on older devices)

### B. Adaptive Icons (Android 8+) ⭐ **Primary System**
- **Location:** `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- **Layers:** Foreground + Background (separate images/colors)
- **System behavior:** Android crops icons into various shapes (circle, squircle, rounded square) based on device OEM
- **Safe zone:** Only center 66% of icon is guaranteed visible

### C. Themed/Monochrome Icons (Android 13+) - **Optional, not yet implemented**
- **Location:** Would go in `ic_launcher.xml` as `<monochrome>` layer
- **Purpose:** Single-color icon for system themes (Material You)
- **Format:** Vector drawable or single-color PNG

---

## 2. Required Deliverables

### PART A: Legacy Mipmap Icons (5 sizes)

**Location:** `android/app/src/main/res/mipmap-*/ic_launcher.png`

| Density | DPI | Exact Dimensions | Filename |
|---------|-----|------------------|----------|
| mdpi | ~160 | 48×48 px | mipmap-mdpi/ic_launcher.png |
| hdpi | ~240 | 72×72 px | mipmap-hdpi/ic_launcher.png |
| xhdpi | ~320 | 96×96 px | mipmap-xhdpi/ic_launcher.png |
| xxhdpi | ~480 | 144×144 px | mipmap-xxhdpi/ic_launcher.png |
| xxxhdpi | ~640 | 192×192 px | mipmap-xxxhdpi/ic_launcher.png |

**Format:** PNG, 24-bit RGB or 32-bit RGBA (transparency allowed)
**Design:** Full square icon (will be cropped on modern devices, only shown as-is on Android 5-7)

---

### PART B: Adaptive Icon - Foreground Layer (5 sizes)

**Location:** `android/app/src/main/res/drawable-*/ic_launcher_foreground.png`

| Density | Exact Dimensions | Filename |
|---------|------------------|----------|
| mdpi | 108×108 px | drawable-mdpi/ic_launcher_foreground.png |
| hdpi | 162×162 px | drawable-hdpi/ic_launcher_foreground.png |
| xhdpi | 216×216 px | drawable-xhdpi/ic_launcher_foreground.png |
| xxhdpi | 324×324 px | drawable-xxhdpi/ic_launcher_foreground.png |
| xxxhdpi | 432×432 px | drawable-xxxhdpi/ic_launcher_foreground.png |

**Format:** PNG with **transparency** (RGBA)
**Critical Safe Zone:** Only the **center 72×72 dp** (66% of canvas) is guaranteed visible
**Full bleed area:** Use full 108×108 dp for background elements that can extend beyond safe zone

#### Safe Zone Breakdown (using xxxhdpi 432×432 as example)

```
432×432 px total canvas (108 dp × 4)
├─ Outer 18 dp (72px) - MAY BE CROPPED by system mask
│  └─ This area might be visible on some devices, invisible on others
├─ Safe Zone: Center 72 dp (288×288 px)
│  └─ GUARANTEED VISIBLE - keep all critical content here
│  └─ This is 66% of total canvas
└─ Recommended content area: ~60 dp (240×240 px) for comfortable padding
```

**Design Guidelines:**
- **Critical elements** (logo, text, faces) → keep within center 288×288 px (for xxxhdpi)
- **Decorative elements** (glow, patterns, background shapes) → can extend to full 432×432 px
- **Test with masks:** Circle, squircle, rounded square, teardrop

---

### PART C: Adaptive Icon - Background Layer

**Current Implementation:** Solid color `#1a1a2e` (dark navy-blue)

**Location:** `android/app/src/main/res/values/colors.xml`
```xml
<color name="ic_launcher_background">#1a1a2e</color>
```

**Designer Options:**

#### Option 1: Solid Color Background (Current) - **Recommended**
- Simplest approach
- Provide color hex code (e.g., `#FAF7F2` for cream background)
- No image files needed

#### Option 2: Image Background (Alternative)
- Create 5 PNG files at same dimensions as foreground layer
- Location: `drawable-*/ic_launcher_background.png`
- Same dimensions: 108×108 dp (mdpi) up to 432×432 px (xxxhdpi)
- Can include gradients, patterns, textures
- **Warning:** Increases APK size

**Recommendation for Parasto:**
Use **solid color background** (`#FAF7F2` warm cream from brand palette) for simplicity and performance.

---

### PART D: Monochrome Icon (Android 13+ Themed Icons) - **Optional Future Enhancement**

**Status:** ❌ Not yet implemented in Parasto

**If desired:**
- Single-color silhouette version of icon
- Used for Material You themed wallpapers
- Format: Vector drawable (XML) or single-color PNG
- Dimensions: Same as foreground layer (108 dp base)

**Example configuration:**
```xml
<adaptive-icon>
  <background android:drawable="@color/ic_launcher_background"/>
  <foreground android:drawable="@drawable/ic_launcher_foreground"/>
  <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>
</adaptive-icon>
```

**For now:** Skip this unless specifically requested. Not critical for launch.

---

## 3. Adaptive Icon Design Guide

### Understanding the Adaptive System

Android adaptive icons have **two layers** that move independently:

1. **Foreground layer** - Your logo/icon artwork (with transparency)
2. **Background layer** - Solid color or image behind foreground

**System behavior:**
- Android applies a **mask shape** (varies by device: circle, squircle, rounded square)
- Layers create **parallax effect** when icon is touched/moved
- Only **center 66% guaranteed visible** due to different mask shapes

### Safe Zone Diagram (108 dp base unit)

```
┌─────────────────────────────────────┐
│  Full Canvas: 108 dp × 108 dp       │ ← Total drawable area
│  ┌───────────────────────────────┐  │
│  │  Trim Area: 18dp margin       │  │ ← May be cropped by mask
│  │  ┌─────────────────────────┐  │  │
│  │  │                         │  │  │
│  │  │   SAFE ZONE: 72dp       │  │  │ ← Keep critical content here
│  │  │   (Center 66%)          │  │  │
│  │  │                         │  │  │
│  │  └─────────────────────────┘  │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘

Recommended content: ~60dp (comfortable padding)
```

### Design Strategy for Parasto Icon

Based on existing brand (two swallows + sound wave):

**Foreground Layer:**
- Two barn swallows facing each other
- Golden sound wave between them
- Keep swallow bodies + sound wave within **center 72 dp safe zone**
- Wing tips can extend slightly into outer 18 dp for visual interest
- Use **transparency** around the artwork (let background show through)

**Background Layer:**
- Solid warm cream color `#FAF7F2` (from brand palette)
- OR subtle radial gradient (cream to slightly darker beige)
- If using gradient: export as PNG at 5 densities

---

## 4. Exact Pixel Dimensions Reference

For designer's export settings:

### Foreground/Background Adaptive Icon Layers

| Density | Base (dp) | Scale Factor | Exact Pixels | DPI |
|---------|-----------|--------------|--------------|-----|
| mdpi | 108 dp | 1× | **108×108 px** | ~160 |
| hdpi | 108 dp | 1.5× | **162×162 px** | ~240 |
| xhdpi | 108 dp | 2× | **216×216 px** | ~320 |
| xxhdpi | 108 dp | 3× | **324×324 px** | ~480 |
| xxxhdpi | 108 dp | 4× | **432×432 px** | ~640 |

**Safe zone (center 66%):**
- mdpi: 72×72 px
- hdpi: 108×108 px
- xhdpi: 144×144 px
- xxhdpi: 216×216 px
- xxxhdpi: 288×288 px

### Legacy Mipmap Icons

| Density | Base (dp) | Scale Factor | Exact Pixels |
|---------|-----------|--------------|--------------|
| mdpi | 48 dp | 1× | **48×48 px** |
| hdpi | 48 dp | 1.5× | **72×72 px** |
| xhdpi | 48 dp | 2× | **96×96 px** |
| xxhdpi | 48 dp | 3× | **144×144 px** |
| xxxhdpi | 48 dp | 4× | **192×192 px** |

---

## 5. File Format Requirements

### PNG Specifications

- **Color depth:** 24-bit RGB or 32-bit RGBA
- **Color profile:** sRGB (standard)
- **Compression:** PNG compression (lossless)
- **Foreground layer:** **MUST have transparency** (RGBA)
- **Background layer (if image):** Can be opaque (RGB) or RGBA
- **Legacy mipmaps:** Can have transparency but usually opaque

### File Naming

**Critical:** Filenames must be **exactly** as specified (case-sensitive on Linux):

✅ Correct: `ic_launcher.png`
❌ Wrong: `Ic_launcher.png`, `ic_launcher.PNG`, `icon_launcher.png`

---

## 6. Google Play Store Assets (Additional)

**Not part of app bundle, but required for Play Store listing:**

### Feature Graphic (Banner)
- **Dimensions:** 1024×500 px
- **Format:** PNG or JPEG
- **Usage:** Store listing header

### Screenshots
- **Phone:** Minimum 320 px on short side, up to 3840 px on long side
- **Tablet (optional):** 7" and 10" screenshots
- **Format:** PNG or JPEG

**Note:** These are uploaded separately to Google Play Console, not bundled with app.

---

## 7. Design Checklist for Parasto Android Icons

### Adaptive Icon Foreground Layer
- [ ] Created at 5 densities (108/162/216/324/432 px)
- [ ] PNG with **transparent background** (RGBA)
- [ ] Critical elements (swallows + sound wave) within center 72 dp safe zone
- [ ] Tested with circle mask (worst case - crops most)
- [ ] Tested with squircle mask (most common)
- [ ] Files named exactly: `ic_launcher_foreground.png`

### Background Layer
- [ ] **Option A:** Solid color hex provided (e.g., `#FAF7F2`)
- [ ] **Option B (if image):** Created at 5 densities matching foreground
- [ ] No transparency needed (can be opaque)

### Legacy Mipmap Icons
- [ ] Created at 5 densities (48/72/96/144/192 px)
- [ ] Square format (full icon visible on Android 5-7)
- [ ] Files named exactly: `ic_launcher.png`

### Optional Enhancements
- [ ] Monochrome icon for Android 13+ themed icons (future)
- [ ] Round icon variant `ic_launcher_round.png` (if desired)

---

## 8. Testing Recommendations

After receiving icons, developer should test on:

- [ ] **Android 13+ device** - verify themed icon (if implemented)
- [ ] **Android 8-12 device** - verify adaptive icon with different masks
- [ ] **Android 5-7 emulator** - verify legacy mipmap displays correctly
- [ ] **Different OEMs** - Samsung (squircle), Google (rounded square), others (circle)
- [ ] **Parallax effect** - touch and drag icon to see layer separation
- [ ] **Icon scaling** - verify all densities are sharp (no blurriness)

---

## 9. Deliverable Folder Structure

```
parasto-android-icons/
├── master/
│   ├── adaptive-foreground-master.ai (or .svg)
│   └── adaptive-background-color.txt (#FAF7F2)
├── adaptive-foreground/
│   ├── drawable-mdpi/
│   │   └── ic_launcher_foreground.png (108×108)
│   ├── drawable-hdpi/
│   │   └── ic_launcher_foreground.png (162×162)
│   ├── drawable-xhdpi/
│   │   └── ic_launcher_foreground.png (216×216)
│   ├── drawable-xxhdpi/
│   │   └── ic_launcher_foreground.png (324×324)
│   └── drawable-xxxhdpi/
│       └── ic_launcher_foreground.png (432×432)
├── legacy-mipmaps/
│   ├── mipmap-mdpi/
│   │   └── ic_launcher.png (48×48)
│   ├── mipmap-hdpi/
│   │   └── ic_launcher.png (72×72)
│   ├── mipmap-xhdpi/
│   │   └── ic_launcher.png (96×96)
│   ├── mipmap-xxhdpi/
│   │   └── ic_launcher.png (144×144)
│   └── mipmap-xxxhdpi/
│       └── ic_launcher.png (192×192)
└── preview/
    ├── adaptive-icon-preview.png (mockup showing different masks)
    └── safe-zone-guide.png (showing what's visible in circle mask)
```

---

## 10. Common Mistakes to Avoid

❌ **Don't:**
- Put critical content outside the 72 dp safe zone (will be cropped on some devices)
- Use opaque white background on foreground layer (won't work with circle mask)
- Create different designs for different densities (should all scale from one master)
- Forget transparency on foreground layer
- Export at wrong dimensions
- Use wrong filenames (case-sensitive!)

✅ **Do:**
- Keep logo/text/faces within center 72 dp
- Use transparency on foreground layer
- Test with circle mask (worst case scenario)
- Scale consistently from master artwork
- Export all 5 densities
- Use exact filenames specified

---

## 11. Reference: Current Configuration

**Adaptive Icon XML** (`mipmap-anydpi-v26/ic_launcher.xml`):
```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/ic_launcher_background"/>
  <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
```

**Background Color** (`values/colors.xml`):
```xml
<color name="ic_launcher_background">#1a1a2e</color>
```

**Designer Action:** Provide new color hex to replace `#1a1a2e` (e.g., `#FAF7F2` for cream).

---

**Next:** See [SPLASH_SPECS.md](./SPLASH_SPECS.md) for launch/splash screen requirements.
