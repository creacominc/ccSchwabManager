# Testing Dynamic Font Scaling

## Quick Test Guide

### On Device/Simulator

#### 1. **View Current State**
- Launch the app and note the current font sizes in your Holdings table

#### 2. **Increase Font Size**
- iOS/iPadOS: Open **Settings** → **Accessibility** → **Display & Text Size**
- Drag the "Larger Text" slider to the right
- Return to your app (don't relaunch)
- ✨ All text should be larger

#### 3. **Test Accessibility Sizes**
- In Settings, enable "Larger Accessibility Sizes"
- Move slider further right
- Return to app
- ✨ Text should scale even larger

#### 4. **Restore Default**
- Return to Settings
- Move slider back to middle
- Disable "Larger Accessibility Sizes"
- Return to app
- ✨ Text returns to normal size

### In Xcode Previews

You can test different sizes in SwiftUI previews by adding:

```swift
#Preview("Default Size") {
    HoldingsTableRow(...)
}

#Preview("Large Text") {
    HoldingsTableRow(...)
        .environment(\.sizeCategory, .extraExtraLarge)
}

#Preview("Accessibility Large") {
    HoldingsTableRow(...)
        .environment(\.sizeCategory, .accessibilityExtraLarge)
}
```

### Test Different Size Categories

Available size categories to test:
- **Standard**: `.extraSmall`, `.small`, `.medium` (default), `.large`
- **Extra Large**: `.extraLarge`, `.extraExtraLarge`, `.extraExtraExtraLarge`
- **Accessibility**: `.accessibilityMedium`, `.accessibilityLarge`, `.accessibilityExtraLarge`, `.accessibilityExtraExtraLarge`, `.accessibilityExtraExtraExtraLarge`

## What to Look For

### ✅ Expected Behavior
- [ ] All text in Holdings table scales proportionally
- [ ] Table remains readable at all sizes
- [ ] No text truncation (uses wrapping or ellipsis)
- [ ] Buttons and icons scale appropriately
- [ ] Layout adjusts gracefully

### ⚠️ Potential Issues to Watch
- Text overlapping at large sizes
- Truncated labels
- Buttons becoming too small at small sizes
- Layout breaking at extreme sizes

## Key Files to Test

### Primary Focus
- **Holdings Table** (`HoldingsTableRow.swift`)
  - Symbol, Quantity, Average, Market Value, P/L, etc.
  
- **Position Detail** (`PositionDetailContent.swift`)
  - Navigation arrows
  - Tab bar buttons

### Already Dynamic Type Compatible
These were already using semantic fonts and should work well:
- Details Tab
- Sales Calculator
- Transactions
- OCO Orders
- All other views

## Example Test Sequence

### Test 1: Holdings Table
1. Open app to Holdings view
2. Change system font size to "Extra Large"
3. Verify all column headers and data scale
4. Check that copy buttons remain functional
5. Test row selection

### Test 2: Position Detail
1. Select a position
2. Verify tab buttons resize
3. Check navigation arrows
4. Switch between tabs
5. Verify content in each tab scales

### Test 3: Extreme Sizes
1. Set to smallest size
2. Verify readability
3. Set to largest accessibility size
4. Check layout doesn't break
5. Test all interactive elements

## Keyboard Shortcuts for Testing

While testing, remember:
- **Left/Right Arrow**: Navigate positions (in detail view)
- **Tab**: Switch between tabs
- These should work at all font sizes

## Screenshots for Comparison

Consider taking screenshots at:
- Default size (`.medium`)
- Large size (`.extraExtraLarge`)
- Accessibility size (`.accessibilityLarge`)

Compare layouts to ensure consistency.

## Accessibility Inspector (Advanced)

For thorough testing:
1. Open Xcode → Window → Accessibility Inspector
2. Select your simulator/device
3. Use the text size controls
4. Check color contrast at different sizes
5. Verify touch target sizes

## Tips

### Performance
- Dynamic Type changes are instant
- No need to restart the app
- System-wide setting affects all compatible apps

### Best Practices
- Test with real content (full position list)
- Try different device sizes (iPhone, iPad)
- Test in both orientations
- Use with real user data when possible

### Common Size Preferences
- **Default**: Most users
- **Larger**: Users 50+, outdoor use
- **Accessibility**: Users with low vision

## Feedback Questions

When testing, consider:
- Is all text still readable?
- Are touch targets large enough?
- Does layout feel balanced?
- Are there any visual glitches?
- Is important information still visible?

## Rollback (If Needed)

If you need to revert these changes:
```bash
git diff HEAD -- ccSchwabManager/Views/HoldingsView/HoldingsTableRow.swift
git diff HEAD -- ccSchwabManager/Views/HoldingsView/PositionDetailView/PositionDetailContent/PositionDetailContent.swift
git checkout HEAD -- ccSchwabManager/Utilities/FontStyles.swift
```

But the changes are backward compatible and safe!

---

**Remember**: This is a standard iOS feature. Users expect apps to respect their accessibility preferences. Your app now does! 🎉

