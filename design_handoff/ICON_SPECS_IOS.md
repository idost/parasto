# iOS App Icon Specifications - Parasto

**Platform:** iOS/iPadOS
**Asset Catalog:** `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
**Configuration File:** `Contents.json`

---

## 1. Required Icon Sizes

### Standard Icon Set (19 icons total)

All icons must be delivered as **PNG format** with the following specifications:

| Filename | Exact Dimensions | Scale | Device/Usage |
|----------|------------------|-------|--------------|
| Icon-App-20x20@1x.png | 20×20 px | @1x | iPad notifications |
| Icon-App-20x20@2x.png | 40×40 px | @2x | iPhone/iPad notifications |
| Icon-App-20x20@3x.png | 60×60 px | @3x | iPhone notifications |
| Icon-App-29x29@1x.png | 29×29 px | @1x | iPad Settings |
| Icon-App-29x29@2x.png | 58×58 px | @2x | iPhone/iPad Settings |
| Icon-App-29x29@3x.png | 87×87 px | @3x | iPhone Settings |
| Icon-App-40x40@1x.png | 40×40 px | @1x | iPad Spotlight |
| Icon-App-40x40@2x.png | 80×80 px | @2x | iPhone/iPad Spotlight |
| Icon-App-40x40@3x.png | 120×120 px | @3x | iPhone Spotlight |
| Icon-App-60x60@2x.png | 120×120 px | @2x | iPhone App |
| Icon-App-60x60@3x.png | 180×180 px | @3x | iPhone App |
| Icon-App-76x76@1x.png | 76×76 px | @1x | iPad App |
| Icon-App-76x76@2x.png | 152×152 px | @2x | iPad App |
| Icon-App-83.5x83.5@2x.png | 167×167 px | @2x | iPad Pro App |
| Icon-App-1024x1024@1x.png | 1024×1024 px | @1x | **App Store** |

### Deprecated/Legacy Icons (Optional - for older iOS versions)

These are currently present in the project but NOT required for modern iOS apps:

| Filename | Dimensions | Notes |
|----------|------------|-------|
| Icon-App-50x50@1x.png | 50×50 px | iOS 6 Spotlight (deprecated) |
| Icon-App-50x50@2x.png | 100×100 px | iOS 6 Spotlight @2x (deprecated) |
| Icon-App-57x57@1x.png | 57×57 px | iOS 6 App (deprecated) |
| Icon-App-57x57@2x.png | 114×114 px | iOS 6 App @2x (deprecated) |
| Icon-App-72x72@1x.png | 72×72 px | iOS 6 iPad (deprecated) |
| Icon-App-72x72@2x.png | 144×144 px | iOS 6 iPad @2x (deprecated) |

**Recommendation:** Skip these unless targeting iOS 6 support (extremely unlikely).

---

## 2. Design Requirements

### Alpha Channel
- **NO TRANSPARENCY** - Icons must have opaque backgrounds
- iOS will reject icons with alpha channels in the App Store submission
- Fill any transparent areas with your background color

### Color Profile
- **sRGB color space** (required by App Store)
- Do NOT use Display P3, Adobe RGB, or other wide-gamut profiles

### File Format
- **PNG only** (24-bit RGB or 32-bit RGB with opaque alpha)
- No JPEG, no GIF, no WebP

### Aspect Ratio
- All icons must be **perfectly square** (1:1 aspect ratio)
- No rounded corners needed - iOS applies corner radius automatically
- Design should work within a square canvas

### Safe Area
- **Recommended:** Keep critical content within **90% of canvas** (allow 5% margin on all sides)
- iOS applies automatic corner rounding - content too close to edges may be clipped
- The 1024×1024 App Store icon has **~22.37% corner radius** (228px radius)

### Design Consistency
- All sizes should be **scaled versions of the same master design**
- Do NOT create different designs for different sizes
- Ensure legibility at smallest size (20×20px) - test at actual pixel dimensions

---

## 3. App Store Icon (1024×1024px) - Special Requirements

This is the **most important icon** - used for:
- App Store listing
- Search results
- Today tab features
- Share sheets
- Siri suggestions

### Additional Requirements
- **Highest quality** - will be scrutinized during App Store review
- Must **accurately represent the app**
- Cannot include promotional elements (no "NEW", "SALE", "FREE" badges)
- Cannot include Apple hardware imagery
- Must **exactly match** the smaller icons (same design, just larger)

---

## 4. Design Guidelines for Parasto

### Brand Identity (from existing design system)

**Icon Concept:** Two barn swallows (پرستو) facing each other with golden sound wave

**Color Palette:**
- **Background:** Warm cream/beige `#FAF7F2` (soft, not stark white)
- **Swallow wings/back:** Deep navy-blue `#1E3A5F`
- **Swallow chest:** Warm orange `#E67634`
- **Sound wave:** Golden amber `#F2B544`
- **Accents:** Clean white for belly/highlights

**Design Philosophy:**
- Warm, poetic, Persian, premium
- NOT gloomy, NOT techy-neon, NOT "AI-ish"
- Comfortable and inviting
- Should evoke storytelling, Persian culture, audio/listening

### Icon Composition Tips

1. **Centered focal point** - place main elements in the center 80% of canvas
2. **High contrast** - icon must be recognizable at 20×20px
3. **Avoid fine details** - thin lines disappear at small sizes
4. **Test at actual size** - view 60×60px and 20×20px at 100% zoom
5. **No text/wordmarks** - icons with text are harder to read
6. **Consistent style** - match the warm, premium aesthetic of color scheme

---

## 5. Master File Recommendations

### For Designer to Create

1. **Master Icon File:**
   - **Format:** Vector (AI/SVG) or very high-res raster (4096×4096px minimum)
   - **Workspace:** Square artboard with guides showing safe area
   - **Layers:** Organized, named layers for easy editing

2. **Export Template:**
   - Use automated export (Sketch, Figma, Illustrator batch export)
   - Name files **exactly** as specified in table above
   - Export all 15 required sizes (skip the 6 legacy sizes)

3. **Deliverable Structure:**
   ```
   parasto-ios-icons/
   ├── master/
   │   └── parasto-app-icon-master.ai (or .svg)
   ├── exports/
   │   ├── Icon-App-1024x1024@1x.png
   │   ├── Icon-App-20x20@1x.png
   │   ├── Icon-App-20x20@2x.png
   │   └── ... (all 15 required sizes)
   └── preview/
       └── icon-preview-mockup.png (optional)
   ```

---

## 6. Testing Checklist

After delivering icons, developer should verify:

- [ ] All 15 PNG files present with exact filenames
- [ ] All images are perfectly square (width = height)
- [ ] No alpha transparency (fully opaque)
- [ ] sRGB color profile
- [ ] File sizes reasonable (1024×1024 should be < 1MB)
- [ ] Icons look sharp at small sizes (20×20, 29×29)
- [ ] Visual consistency across all sizes
- [ ] App Store icon (1024×1024) is pristine quality

---

## 7. Reference: Contents.json Structure

The developer will update this file to reference your icons:

```json
{
  "images" : [
    {
      "size" : "20x20",
      "idiom" : "iphone",
      "filename" : "Icon-App-20x20@2x.png",
      "scale" : "2x"
    },
    ... (15 entries total)
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
```

**Note:** You don't need to edit this - just provide the PNG files with correct names.

---

## 8. Common Mistakes to Avoid

❌ **Don't:**
- Use transparency (alpha channel)
- Export as JPEG
- Create non-square images
- Use Display P3 color profile
- Add drop shadows that extend beyond canvas
- Create different designs for different sizes
- Include promotional text/badges
- Use very fine details that disappear at small sizes

✅ **Do:**
- Export all icons as opaque PNG
- Use sRGB color profile
- Keep all icons perfectly square
- Scale from single master design
- Test at actual pixel sizes
- Leave safe margin for corner rounding
- Maintain brand color consistency

---

**Next:** See [ICON_SPECS_ANDROID.md](./ICON_SPECS_ANDROID.md) for Android icon requirements.
