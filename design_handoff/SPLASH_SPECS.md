# Launch/Splash Screen Specifications - Parasto

**Purpose:** Branded screen shown while app initializes
**Duration:** Typically 1-3 seconds (Flutter framework loading time)

---

## 1. Current Implementation Status

### iOS Launch Screen

**Status:** ⚠️ **Minimal implementation** (1×1 transparent placeholders)

**Implementation Method:**
- **LaunchScreen.storyboard** (iOS native storyboard)
- **Assets:** `ios/Runner/Assets.xcassets/LaunchImage.imageset/`

**Current Configuration:**
- Background: White (`#FFFFFF`)
- Image: `LaunchImage` (centered, content mode: center)
- **Problem:** Current LaunchImage files are 1×1 px transparent pixels (effectively invisible)

**Storyboard Metadata:**
- Original design intent: 168×185 pt centered image
- Auto-layout constraints: centerX, centerY (horizontally and vertically centered)

---

### Android Launch Screen

**Status:** ⚠️ **Minimal implementation** (white background only)

**Implementation Method:**
- **launch_background.xml** drawable layer-list
- No image currently configured (commented out)

**Current Configuration:**
- Background: White (`@android:color/white`)
- No logo/branding image

**Location:** `android/app/src/main/res/drawable/launch_background.xml`

---

## 2. Recommended Approach: Manual Implementation

**Why not flutter_native_splash?**
- Package not currently used in project
- Manual control offers more design flexibility
- Simpler for single-image centered design

**Strategy:** Native iOS + Android splash screens with centered logo

---

## 3. iOS Launch Screen Deliverables

### Design Specifications

**Layout:**
```
┌─────────────────────────────┐
│                             │
│                             │
│          [LOGO]             │  ← Centered vertically and horizontally
│                             │
│                             │
└─────────────────────────────┘
```

**Background:**
- **Color:** Warm cream `#FAF7F2` (matches brand light mode background)
- **Alternative:** Solid brand primary `#F2B544` (gold) - if preferred for more impact
- **Alternative 2:** Dark navy `#0F1825` (matches app's dark mode) - for consistency with app content

**Logo/Image:**
- **Recommended size:** ~200×200 pt (logical points)
- **Centered:** Both horizontally and vertically
- **Content:** Simplified Parasto logo or app icon artwork
  - Option 1: Just the two swallows + sound wave (no background)
  - Option 2: App icon itself (with transparent background to let splash bg show through)
  - Option 3: "پرستو" text logo (if wordmark exists)

**Safe Area:**
- Keep logo away from edges (minimum 44pt margin on all sides)
- Avoid notch area on iPhone X+ (top ~44pt)
- Avoid home indicator area on modern iPhones (bottom ~34pt)

### Required Asset Deliverables

**3 PNG files** for `ios/Runner/Assets.xcassets/LaunchImage.imageset/`:

| Filename | Dimensions | Scale | Notes |
|----------|------------|-------|-------|
| LaunchImage.png | ~200×200 px | @1x | Base size (for older devices) |
| LaunchImage@2x.png | ~400×400 px | @2x | Standard retina (iPhone 8, SE) |
| LaunchImage@3x.png | ~600×600 px | @3x | Super retina (iPhone 12+) |

**Format:**
- PNG with **transparency** (RGBA)
- Logo/icon artwork only (no background in PNG - storyboard provides background color)
- sRGB color profile

**Alternative: Full-screen splash image**
If you prefer a full-screen design instead of centered logo:
- Provide images at multiple iPhone screen sizes
- Requires creating a launch screen asset catalog
- More complex implementation

**Recommended:** Stick with centered logo approach for simplicity.

### Developer Implementation Notes

Developer will:
1. Replace 1×1 placeholder PNGs with your logo images
2. Update `LaunchScreen.storyboard` background color to match your design
3. Optionally adjust image size constraints if 200pt isn't optimal

---

## 4. Android Launch Screen Deliverables

### Design Specifications

**Layout:** Same as iOS - centered logo on solid background

**Background Color:**
- Provide hex color code (e.g., `#FAF7F2` cream)
- Developer will update `launch_background.xml`

**Logo/Image:**
- **Recommended size:** ~192×192 dp (density-independent pixels)
- This scales to:
  - mdpi: 192 px
  - hdpi: 288 px
  - xhdpi: 384 px
  - xxhdpi: 576 px
  - xxxhdpi: 768 px

### Required Asset Deliverables

**5 PNG files** for `android/app/src/main/res/drawable-*/launch_image.png`:

| Density | Dimensions | Filename Location |
|---------|------------|-------------------|
| mdpi | 192×192 px | drawable-mdpi/launch_image.png |
| hdpi | 288×288 px | drawable-hdpi/launch_image.png |
| xhdpi | 384×384 px | drawable-xhdpi/launch_image.png |
| xxhdpi | 576×576 px | drawable-xxhdpi/launch_image.png |
| xxxhdpi | 768×768 px | drawable-xxxhdpi/launch_image.png |

**Format:**
- PNG with **transparency** (RGBA)
- Logo/icon artwork only (background provided by XML)
- sRGB color profile

### Developer Implementation Notes

Developer will:
1. Add your PNG files to appropriate drawable-* folders
2. Update `launch_background.xml` to reference `@drawable/launch_image`
3. Set background color to your specified hex value
4. Configure `android:gravity="center"` for centered positioning

**Example updated XML:**
```xml
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/splash_background" />
    <item>
        <bitmap
            android:gravity="center"
            android:src="@drawable/launch_image" />
    </item>
</layer-list>
```

---

## 5. Design Guidelines for Parasto Splash

### Brand-Consistent Approach

**Option A: Light & Warm (Recommended)**
- **Background:** Warm cream `#FAF7F2`
- **Logo:** Two swallows + golden sound wave (from app icon)
- **Colors:** Navy swallows `#1E3A5F`, orange chest `#E67634`, gold wave `#F2B544`
- **Feel:** Inviting, warm, premium - matches light mode aesthetic

**Option B: Bold & Impactful**
- **Background:** Primary gold `#F2B544`
- **Logo:** White or navy version of swallows + sound wave
- **Feel:** Eye-catching, energetic, memorable

**Option C: Dark & Consistent**
- **Background:** Dark navy `#0F1825` (matches app's dark theme)
- **Logo:** Full-color swallows + gold wave (as in icon)
- **Feel:** Seamless transition to app content

**Recommendation:** **Option A** - warm cream background creates welcoming first impression and differentiates splash from dark app content.

### Logo Design Considerations

**Keep it simple:**
- Launch screens appear for 1-3 seconds only
- Logo should be **instantly recognizable**
- Avoid fine details that won't be visible at quick glance

**Possible approaches:**
1. **App icon artwork** (two swallows + sound wave) - simplest, most consistent
2. **Simplified icon** (just the sound wave symbol) - minimalist
3. **Icon + wordmark** (icon above "پرستو" text) - if wordmark exists
4. **Wordmark only** ("پرستو" in brand font) - if strong text logo exists

**Recommended:** Use **app icon artwork** for maximum brand recognition and consistency.

---

## 6. Aspect Ratio Considerations

### iOS Device Screens (Sample)

| Device | Screen Size (pt) | Aspect Ratio |
|--------|------------------|--------------|
| iPhone SE (3rd) | 375×667 | ~9:16 |
| iPhone 14 | 390×844 | ~9:19.5 |
| iPhone 14 Pro Max | 430×932 | ~9:19.5 |
| iPad Pro 12.9" | 1024×1366 | ~3:4 |

**Impact:** Centered logo approach works across all aspect ratios (no stretching/cropping issues).

### Android Device Screens (Highly Variable)

- **Aspect ratios:** 16:9, 18:9, 19:9, 19.5:9, 20:9, and more
- **Screen sizes:** 4" phones to 12" tablets

**Impact:** Centered logo with solid background is **safest approach** - works on all devices.

---

## 7. Safe Area Guidelines

### iOS Safe Areas

**Top Safe Area (notch/Dynamic Island):**
- iPhone 14 Pro+: ~59pt from top
- Older notch iPhones: ~44pt from top
- Keep logo **below 100pt from top edge** to be safe

**Bottom Safe Area (home indicator):**
- Modern iPhones: ~34pt from bottom
- Keep logo **above 80pt from bottom edge** to be safe

**Recommendation:** Center logo in middle 60% of screen (vertically).

### Android Safe Areas

- Most Android devices have **no notch** or use software navigation
- Some have punch-hole cameras (top-center or top-corner)
- **Recommendation:** Center logo in middle 70% of screen

**General Rule:** Centered logo with ~20% margin on all sides is safe for both platforms.

---

## 8. Animation & Transitions (Future Enhancement)

**Current:** Static image (no animation)

**Future possibilities:**
- Fade-in logo animation
- Subtle scale animation (logo grows in)
- Sound wave animation (if logo includes wave)
- Transition to app with crossfade

**Note:** Requires custom native code - skip for initial launch. Static splash is fine.

---

## 9. Testing Checklist

After implementing splash screens:

### iOS
- [ ] Test on iPhone SE (small screen, no notch)
- [ ] Test on iPhone 14 Pro (Dynamic Island)
- [ ] Test on iPad (different aspect ratio)
- [ ] Verify background color matches design
- [ ] Verify logo is sharp at @2x and @3x
- [ ] Verify logo is centered and sized appropriately
- [ ] Check transition from splash to app (smooth?)

### Android
- [ ] Test on small phone (5" screen)
- [ ] Test on large phone (6.5"+ screen)
- [ ] Test on tablet (if app supports tablets)
- [ ] Verify all density variants are sharp
- [ ] Verify logo doesn't overlap with status bar
- [ ] Verify background color matches design

---

## 10. Deliverable Summary

### For Designer to Provide

**iOS Launch Images:**
```
ios-launch-images/
├── LaunchImage.png (200×200 px, @1x)
├── LaunchImage@2x.png (400×400 px, @2x)
└── LaunchImage@3x.png (600×600 px, @3x)
```

**Android Launch Images:**
```
android-launch-images/
├── drawable-mdpi/launch_image.png (192×192 px)
├── drawable-hdpi/launch_image.png (288×288 px)
├── drawable-xhdpi/launch_image.png (384×384 px)
├── drawable-xxhdpi/launch_image.png (576×576 px)
└── drawable-xxxhdpi/launch_image.png (768×768 px)
```

**Background Color:**
```
splash-background-color.txt
└── iOS: #FAF7F2 (or your chosen hex)
└── Android: #FAF7F2 (or your chosen hex)
```

**Master File:**
```
master/
└── parasto-splash-logo-master.ai (or .svg)
    └── Artboard: 600×600 px (for @3x export)
```

---

## 11. Alternative: Full-Screen Splash Image (Advanced)

**Not recommended for Parasto** - but if you want a full-screen branded splash:

### iOS
- Requires multiple image sizes for different devices:
  - iPhone SE: 750×1334 px (@2x)
  - iPhone 14: 1170×2532 px (@3x)
  - iPhone 14 Pro Max: 1290×2796 px (@3x)
  - iPad Pro: 2048×2732 px (@2x)
- More complex implementation (launch screen asset catalog)

### Android
- Single 9-patch drawable or vector drawable
- Scales to all screen sizes
- More complex to design (must work on all aspect ratios)

**Verdict:** Centered logo approach is **much simpler** and works beautifully for Parasto's brand.

---

**Next:** See [DESIGNER_DELIVERABLES_CHECKLIST.md](./DESIGNER_DELIVERABLES_CHECKLIST.md) for complete handoff requirements.
