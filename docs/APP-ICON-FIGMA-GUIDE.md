# Kinex Fit App Icon - Figma Template Guide

Complete guide to create app icons in Figma with all required iOS sizes.

## Quick Start

1. **Open Figma**: Go to https://figma.com (free account works)
2. **Create new file**: "Kinex Fit App Icons"
3. **Follow setup instructions** below
4. **Design at 1024×1024** (master artboard)
5. **Export all sizes** using specifications below

---

## Figma File Setup

### Frame Structure

Create these frames on your canvas (use Frame tool: `F`):

```
Kinex Fit App Icons
├── Master Icon (1024×1024) ← Design here!
├── App Store (1024×1024)
├── iPhone 3x (180×180)
├── iPhone 2x (120×120)
├── Spotlight 3x (120×120)
├── Spotlight 2x (80×80)
├── Settings 3x (87×87)
├── Settings 2x (58×58)
├── Notification 3x (60×60)
└── Notification 2x (40×40)
```

### Master Icon Frame (1024×1024)

1. Press `F` to create frame
2. Set dimensions: **1024 × 1024**
3. Name: "Master Icon"
4. Background: Solid color or gradient

**Design Guidelines for Master:**
- Keep important elements **100px from edges** (10% safe zone)
- Use high-contrast colors
- Simple, bold shapes
- No text or fine details
- Vector shapes only (scales perfectly)

---

## Design Concepts for Kinex Fit

### Concept 1: "K" Letter Mark with Dumbbell

**Visual Description:**
- Bold "K" letter in modern sans-serif
- Dumbbell integrated into the "K" diagonal stroke
- Gradient fill: Blue (#007AFF) → Purple (#5856D6)
- White background or subtle radial gradient

**Figma Steps:**
1. Create text "K" with font: SF Pro Display or Inter (Bold, 700pt)
2. Convert to vector: Right-click → Outline Stroke
3. Add dumbbell shape overlapping the diagonal
4. Apply gradient: Linear 45°, Blue → Purple
5. Add subtle shadow or glow (Inner Shadow, 2px blur, 20% opacity)

### Concept 2: Strength Symbol (Recommended)

**Visual Description:**
- Stylized dumbbell or kettlebell icon
- Circular background with gradient
- Modern, minimalist geometric design
- Circuit pattern or subtle glow effect

**Figma Steps:**
1. Create circle: 1024×1024, gradient background
2. Add dumbbell shape (use pen tool or rectangles + circles):
   - Weight plates: Two circles (200×200) on left and right
   - Bar: Rectangle (600×80) connecting them
   - Grip: Centered rectangle (200×100) with darker shade
3. Apply gradient to dumbbell shape
4. Add subtle glow effect (Layer Blur, 10px)
5. Optional: Add circuit pattern overlay at 10% opacity

### Concept 3: Progress Ring

**Visual Description:**
- Circular progress ring (75% complete)
- Athletic figure or "K" letter in center
- Dynamic gradient showing movement/progress
- Clean, motivational design

**Figma Steps:**
1. Create outer circle: 900×900, no fill, stroke 100px
2. Set stroke to gradient: Blue → Purple
3. Trim stroke to 75% (use Arc plugin or manual path edit)
4. Add inner content: "K" or minimal athletic icon
5. Add centered shadow for depth

### Concept 4: AI + Fitness Fusion

**Visual Description:**
- Dumbbell with neural network pattern
- Tech-forward, modern aesthetic
- Blue/purple gradient with white accents
- Shows "smart fitness" positioning

**Figma Steps:**
1. Create dumbbell icon (simplified)
2. Add connected dots pattern (neural network style)
3. Use Auto Layout for even spacing
4. Apply gradient overlay
5. Add glow effects on connection points

---

## Recommended Color Palette

### Primary Gradient
```
Blue to Purple Gradient:
- Start: #007AFF (iOS Blue)
- End: #5856D6(iOS Purple)
- Angle: 135° (diagonal)
```

### Background Options

**Option A: White Background**
- Background: #FFFFFF
- Icon: Blue → Purple gradient
- Shadow: Subtle, 4px blur, 10% black

**Option B: Gradient Background**
- Background: Radial gradient
  - Center: #FFFFFF
  - Edge: #F0F0F5
- Icon: Blue → Purple gradient
- Better depth and dimension

**Option C: Dark Mode Variant**
- Background: #1C1C1E (iOS dark)
- Icon: Lighter blue → purple gradient
- Glow effect for visibility

### Accent Colors
```
Yellow (Energy):  #FFD60A
Orange (Action):  #FF9500
Green (Success):  #34C759
```

---

## Figma Export Settings

### Setup Export for Each Frame

1. **Select frame** (e.g., "Master Icon")
2. **Click "Export"** in right panel (bottom)
3. **Click "+"** to add export setting
4. **Configure export:**
   - Format: **PNG**
   - Scale: **1x** (frames are already at correct size)
   - Suffix: Leave blank
5. **Repeat for all frames**

### Export Settings Table

| Frame Name | Size | Export Name | Usage |
|------------|------|-------------|-------|
| Master Icon | 1024×1024 | `Icon-1024.png` | App Store |
| iPhone 3x | 180×180 | `Icon-180.png` | iPhone App (3x) |
| iPhone 2x | 120×120 | `Icon-120.png` | iPhone App (2x) |
| Spotlight 3x | 120×120 | `Icon-120.png` | Same as above |
| Spotlight 2x | 80×80 | `Icon-80.png` | Spotlight Search |
| Settings 3x | 87×87 | `Icon-87.png` | Settings |
| Settings 2x | 58×58 | `Icon-58.png` | Settings |
| Notification 3x | 60×60 | `Icon-60.png` | Notifications |
| Notification 2x | 40×40 | `Icon-40.png` | Notifications |

### Batch Export

1. **Select all frames** (Cmd/Ctrl + click each)
2. **Export all** in right panel
3. **Choose destination:** `ios/KinexFit/Resources/AppIcon.appiconset/`
4. **Click "Export"**

---

## Step-by-Step Figma Workflow

### Phase 1: Setup (5 minutes)

1. Open Figma: https://figma.com
2. Create new file: "Kinex Fit App Icons"
3. Create master frame: 1024×1024 (press `F`, type dimensions)
4. Name frame: "Master Icon"
5. Set background color/gradient

### Phase 2: Design (30-60 minutes)

1. **Choose concept** (from above or your own)
2. **Create shapes** using:
   - Rectangle tool (`R`)
   - Ellipse tool (`O`)
   - Pen tool (`P`) for custom shapes
   - Text tool (`T`) for letter marks
3. **Apply colors/gradients**:
   - Select shape → Fill → Gradient
   - Set color stops and angle
4. **Add effects**:
   - Select layer → Effects → Inner Shadow / Drop Shadow
   - Blur effects for glow
5. **Test at small size**:
   - Duplicate frame
   - Resize to 40×40
   - Check if recognizable

### Phase 3: Create All Sizes (15 minutes)

1. **Select Master Icon frame**
2. **Duplicate** (Cmd/Ctrl + D)
3. **Rename** (e.g., "iPhone 3x")
4. **Resize** to target dimensions:
   - Right panel → Frame → Width/Height
   - Enable "Constrain proportions"
   - Enter 180×180 (or target size)
5. **Repeat** for all required sizes

**Pro Tip:** Use Components
- Convert master design to Component (Cmd/Ctrl + Alt + K)
- Create instances for each size
- Changes to master update all instances automatically

### Phase 4: Export (5 minutes)

1. **Setup exports** (see Export Settings above)
2. **Select all frames**
3. **Export** → Choose folder
4. **Done!** All PNG files ready

---

## Design Tips & Best Practices

### Do's ✅

- **Use vector shapes** (scales perfectly)
- **High contrast** between elements
- **Simple, bold design** (recognizable at 40px)
- **Consistent visual weight**
- **Test at smallest size** (40×40) before finalizing
- **Use grid/guides** for alignment (8px or 16px grid)
- **Round to pixel values** (avoid sub-pixel rendering)

### Don'ts ❌

- **No text** (even "K" should be graphic/shape)
- **No transparency** (solid background required)
- **No fine details** (won't show at small sizes)
- **No screenshots or photos**
- **No rounded corners** (iOS adds automatically)
- **No iOS UI elements**
- **No gradients that are too subtle** (must be visible small)

### Common Mistakes to Avoid

1. **Too much detail** → Simplify at small sizes
2. **Low contrast** → Increase difference between elements
3. **Off-center design** → Use alignment tools
4. **Inconsistent style** → Keep visual language unified
5. **Wrong export format** → Must be PNG, not JPG

---

## Figma Plugins (Optional but Helpful)

Install from Figma Community (Plugins menu):

1. **Iconify** - 100,000+ icons to use as reference
2. **Unsplash** - High-quality images for inspiration
3. **Arc** - Create perfect circular progress rings
4. **Autoflow** - Add arrows/connections for neural network patterns
5. **iOS App Icon Template** - Pre-made template with all sizes

To install: Figma → Plugins → Browse all plugins → Search → Install

---

## Testing Your Icon

### In Figma
1. Zoom out to 10% view
2. Icon should still be recognizable
3. Colors should have good contrast

### Before Adding to Xcode
1. Open each PNG in Preview/Photos
2. Check for transparency (should see checkerboard if present - bad!)
3. Verify dimensions (Get Info on file)
4. Check file size (1024×1024 should be ~100-500KB)

### In Xcode
1. Add all PNGs to Assets.xcassets/AppIcon.appiconset/
2. Build and run simulator
3. Check home screen, settings, notifications
4. Test dark mode appearance

---

## Example Figma File Structure

```
Pages:
├── 📱 App Icons (main page)
│   ├── 🎨 Master Icon (1024×1024) ← Design here
│   ├── Exports/
│   │   ├── App Store (1024×1024)
│   │   ├── iPhone 3x (180×180)
│   │   ├── iPhone 2x (120×120)
│   │   ├── Spotlight 3x (120×120)
│   │   ├── Spotlight 2x (80×80)
│   │   ├── Settings 3x (87×87)
│   │   ├── Settings 2x (58×58)
│   │   ├── Notification 3x (60×60)
│   │   └── Notification 2x (40×40)
│   └── References/
│       ├── Color Palette
│       ├── Inspiration (other fitness apps)
│       └── Concept Sketches
```

---

## Resources

### Figma Templates (Community)
Search Figma Community for:
- "iOS App Icon Template"
- "App Icon Generator"
- "Mobile Icon Kit"

### Inspiration
- **Dribbble:** Search "fitness app icon"
- **Behance:** Search "mobile app branding"
- **Apple HIG:** https://developer.apple.com/design/human-interface-guidelines/app-icons

### Fonts (Free)
- **SF Pro** (Apple's system font)
- **Inter** (Google Fonts)
- **Montserrat** (Bold, modern)
- **Poppins** (Friendly, rounded)

---

## Quick Reference: All Required Sizes

```
iPhone:
- 40×40   (Notification 2x)
- 60×60   (Notification 3x)
- 58×58   (Settings 2x)
- 87×87   (Settings 3x)
- 80×80   (Spotlight 2x)
- 120×120 (Spotlight 3x / App 2x)
- 180×180 (App 3x)
- 1024×1024 (App Store)

iPad (if supporting):
- 20×20   (Notification 1x)
- 40×40   (Notification 2x)
- 29×29   (Settings 1x)
- 58×58   (Settings 2x)
- 40×40   (Spotlight 1x)
- 80×80   (Spotlight 2x)
- 76×76   (App 1x)
- 152×152 (App 2x)
- 167×167 (App Pro 2x)
```

---

## Next Steps

1. ✅ Open Figma and create new file
2. ✅ Set up frames with correct dimensions
3. ✅ Design master icon (1024×1024)
4. ✅ Test at 40×40 size
5. ✅ Create all required size variants
6. ✅ Export all PNGs
7. ✅ Add to Xcode Assets.xcassets
8. ✅ Build and test in simulator

**Estimated Time:** 1-2 hours for complete icon set

**Need Help?** Reference the design concepts above or search Figma Community for iOS icon templates.
