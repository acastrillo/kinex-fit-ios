# Launch Screen Setup - Kinex Fit iOS

Complete guide to configure the app's launch screen (splash screen shown while app is loading).

## Current Configuration

The launch screen is configured in `Info.plist` using the modern `UILaunchScreen` dictionary (iOS 14+):

```xml
<key>UILaunchScreen</key>
<dict>
    <key>UIColorName</key>
    <string>LaunchScreenBackground</string>
    <key>UIImageName</key>
    <string>AppIcon</string>
    <key>UIImageRespectsSafeAreaInsets</key>
    <true/>
</dict>
```

This configuration will:
- Display the app icon centered on screen
- Use a custom background color from Asset Catalog
- Respect safe area insets (notch, home indicator)

---

## Setup Required in Xcode

### Step 1: Create LaunchScreenBackground Color Asset

1. **Open Xcode project**
2. **Navigate to Assets.xcassets** in Project Navigator
3. **Right-click** in the asset list → **New Color Set**
4. **Rename** to: `LaunchScreenBackground`
5. **Configure the color** (select the color set):
   - **Light Appearance**: `#007AFF` (iOS Blue) - RGB(0, 122, 255)
   - **Dark Appearance**: `#1C1C1E` (iOS Dark Background) - RGB(28, 28, 30)
6. **Save** (Cmd+S)

**Color Configuration Details:**
- **Any Appearance** tab: Set default color `#007AFF`
- **Dark** tab: Set dark mode color `#1C1C1E`
- Color Space: sRGB
- Opacity: 100%

### Step 2: Verify App Icon Reference

The launch screen automatically uses your app icon (once added to Assets.xcassets/AppIcon.appiconset/).

**Requirements:**
- App icon must be added to `AppIcon.appiconset` (see APP-ICON-AI-GENERATION.md)
- All required PNG sizes must be present
- Icon appears automatically on launch screen

### Step 3: Test Launch Screen

1. **Clean Build Folder** (Cmd+Shift+K)
2. **Build and Run** (Cmd+R)
3. **Launch app** → Launch screen appears briefly
4. **Test both light and dark mode**:
   - Settings app → Developer → Dark Appearance
   - Or: Xcode → Environment Overrides → Appearance → Dark

**What to Check:**
- [ ] App icon appears centered
- [ ] Background color is iOS Blue in light mode
- [ ] Background color is dark gray in dark mode
- [ ] No white flash before launch screen
- [ ] Transitions smoothly to main app

---

## Design Specifications

### Layout
- **App Icon**: Centered horizontally and vertically
- **Icon Size**: Automatically scaled (typically 120x120pt)
- **Background**: Full screen, solid color
- **Safe Area**: Respected (content avoids notch/home indicator)

### Colors

**Light Mode:**
- Background: `#007AFF` (iOS Blue)
- Icon: Full color (as designed)

**Dark Mode:**
- Background: `#1C1C1E` (iOS Dark)
- Icon: Full color (as designed)

**Alternative Color Options:**

If you want a gradient effect (requires custom solution):
- Light: White `#FFFFFF` with subtle gray `#F0F0F5`
- Dark: `#1C1C1E` to `#000000`

Note: UILaunchScreen doesn't support gradients. For gradients, you'd need a custom storyboard or image.

---

## Alternative: Custom Launch Screen Image

If you want more control (logo + text, gradients, etc.), you can create a custom launch image:

### Create Launch Image

1. **Design a 1170x2532 PNG** (iPhone 14 Pro resolution):
   - App icon or logo centered
   - App name text (optional)
   - Background gradient or solid color
   - No animation or interactive elements

2. **Add to Assets.xcassets**:
   - Create new Image Set: `LaunchScreenImage`
   - Add image for 3x (1170x2532)
   - Add image for 2x (750x1624)

3. **Update Info.plist**:
```xml
<key>UILaunchScreen</key>
<dict>
    <key>UIImageName</key>
    <string>LaunchScreenImage</string>
</dict>
```

**Advantages:**
- Full design control (gradients, text, custom layout)
- Consistent across all device sizes

**Disadvantages:**
- Larger app size
- Doesn't adapt to different device sizes as well
- More work to create

---

## Best Practices

### Do's ✅
- **Keep it simple** - Minimal design, fast load
- **Match your app** - Use brand colors and logo
- **Support dark mode** - Provide dark appearance variant
- **No text** - Apple discourages text on launch screens
- **No animations** - Launch screens are static
- **Fast transition** - Should match first screen of app

### Don'ts ❌
- **No advertising** - Can't include marketing messages
- **No placeholders** - Must look finished/polished
- **No "Loading..."** text - Apple rejects apps with loading text
- **No version numbers** - Launch screen shouldn't change between updates
- **No interactive elements** - Buttons, links, etc. not allowed

---

## Troubleshooting

### Launch Screen Not Updating

If changes don't appear:

1. **Clean Build Folder** (Cmd+Shift+K)
2. **Delete app from simulator**:
   - Long press app icon → Remove App
3. **Rebuild and run**
4. **Restart simulator** if still not working

### Wrong Colors Showing

- Verify color asset named exactly `LaunchScreenBackground`
- Check Info.plist `UIColorName` matches color set name
- Ensure color set has both Light and Dark appearances

### App Icon Not Showing

- Verify app icon added to AppIcon.appiconset
- All PNG files present (see APP-ICON-AI-GENERATION.md)
- Build succeeds without "missing app icon" warning
- Info.plist `UIImageName` = `AppIcon` (exact match)

### White Flash Before Launch Screen

This can happen if:
- Color asset not loading fast enough
- Use solid color instead of image
- Ensure color asset is in main app target

---

## Quick Checklist

Before App Store submission:

- [ ] LaunchScreenBackground color added to Assets.xcassets
- [ ] App icon added to AppIcon.appiconset
- [ ] Launch screen tested in light mode
- [ ] Launch screen tested in dark mode
- [ ] No text or placeholders visible
- [ ] Smooth transition to main app
- [ ] Tested on multiple device sizes
- [ ] No "Loading" text or indicators

---

## Summary: What You Need to Do

**In Xcode:**
1. Open Assets.xcassets
2. Create color set: `LaunchScreenBackground`
3. Set Light color: `#007AFF` (blue)
4. Set Dark color: `#1C1C1E` (dark gray)
5. Add app icon PNGs to AppIcon.appiconset (from APP-ICON-AI-GENERATION.md)
6. Build and test

**Result:**
- Professional launch screen
- App icon centered
- Brand-colored background
- Dark mode support
- Meets Apple guidelines

**Time Required:** 5 minutes (once app icon is ready)

---

## References

- Apple HIG: [Launch Screens](https://developer.apple.com/design/human-interface-guidelines/launching)
- WWDC 2020: [Design for the Launch Experience](https://developer.apple.com/videos/play/wwdc2020/10044/)

---

**Status:** ⏳ Requires manual setup in Xcode (Info.plist is configured)

**Next Steps:**
1. Add LaunchScreenBackground color in Xcode
2. Add app icon PNGs (see APP-ICON-AI-GENERATION.md)
3. Test in simulator
4. Ready for App Store! ✅
