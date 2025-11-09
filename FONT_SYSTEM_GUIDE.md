# Font System Guide

## Overview

The app now uses a centralized font system that supports **Dynamic Type**, allowing users to adjust font sizes system-wide through iOS Settings.

## How It Works

### Dynamic Type Support

Users can adjust font sizes via:
- **iOS/iPadOS**: Settings → Accessibility → Display & Text Size → Larger Text
- **visionOS**: Settings → Accessibility → Text Size

The app will automatically respond to these changes and scale fonts appropriately.

### FontStyles Utility

Located in `ccSchwabManager/Utilities/FontStyles.swift`, this provides:

#### Semantic Font Styles
- `FontStyles.tableCell` - Standard table cell content (scales with `.body` size)
- `FontStyles.tableCellMedium` - Table cell with medium weight
- `FontStyles.detail` - Small detail text (scales with `.caption` size)
- `FontStyles.detailSmall` - Smaller details (scales with `.caption2` size)
- `FontStyles.tableHeader` - Header text (scales with `.headline` size)

#### View Modifiers (Convenience Methods)
```swift
Text("Example")
    .tableCellFont()           // Regular weight
    .tableCellFont(weight: .medium)  // Medium weight
    
Text("Detail")
    .detailFont()              // Caption size
    
Text("Header")
    .tableHeaderFont()         // Headline size
```

#### Fixed Sizes (Use Sparingly)
For rare cases where you need specific sizes:
```swift
Text("Fixed Size")
    .font(FontStyles.FixedSize.small.scaled())  // 12pt (but still scales)
    .font(FontStyles.FixedSize.medium.scaled()) // 14pt (but still scales)
    .font(FontStyles.FixedSize.large.scaled())  // 16pt (but still scales)
```

## Implementation Status

### ✅ Completed
- ✅ Created centralized `FontStyles` utility
- ✅ Replaced hard-coded font sizes in:
  - `HoldingsTableRow.swift` (11 instances)
  - `PositionDetailContent.swift` (4 instances)
- ✅ All fonts now support Dynamic Type scaling

### Already Using Dynamic Type
These files were already using semantic font styles (`.body`, `.caption`, etc.):
- Most View components (26 files)
- Auth views
- OCO Orders
- Sales Calculator
- Transaction history
- And more...

## Best Practices

### ✅ DO
- Use semantic font styles (`.body`, `.caption`, `.headline`, etc.)
- Use `FontStyles` constants for consistency
- Use view modifiers (`.tableCellFont()`, etc.) for convenience
- Test your UI with different Dynamic Type sizes

### ❌ DON'T
- Use hard-coded `.font(.system(size: 14))` values
- Use fixed sizes unless absolutely necessary
- Forget to test with accessibility sizes

## Testing Dynamic Type

### In Simulator/Device
1. Open **Settings** → **Accessibility** → **Display & Text Size**
2. Adjust the **Larger Text** slider
3. Switch back to your app - fonts should scale automatically

### In Xcode Preview
```swift
#Preview {
    YourView()
        .environment(\.sizeCategory, .accessibilityLarge)
}
```

### Test Different Sizes
- `.extraSmall` - Smallest size
- `.small`, `.medium`, `.large` - Standard sizes
- `.extraLarge`, `.extraExtraLarge`, `.extraExtraExtraLarge` - Large sizes
- `.accessibilityMedium` through `.accessibilityExtraExtraExtraLarge` - Accessibility sizes

## Migration Guide

### Before
```swift
Text("Hello")
    .font(.system(size: 14))
```

### After
```swift
Text("Hello")
    .tableCellFont()
```

Or use semantic styles directly:
```swift
Text("Hello")
    .font(.body)
```

## Additional Resources

- [Apple Human Interface Guidelines - Typography](https://developer.apple.com/design/human-interface-guidelines/typography)
- [Supporting Dynamic Type](https://developer.apple.com/documentation/uikit/uifont/scaling_fonts_automatically)
- [Accessibility - Text Size](https://developer.apple.com/design/human-interface-guidelines/accessibility/)

## Future Enhancements

Consider adding:
- Custom font scaling curves for specific components
- Per-view font size overrides (if needed for specific designs)
- Font size preview in app settings
- Support for custom fonts while maintaining Dynamic Type

