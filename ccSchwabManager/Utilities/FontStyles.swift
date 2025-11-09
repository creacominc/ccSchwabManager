import SwiftUI

/// Centralized font styles that support Dynamic Type
/// Users can adjust font sizes via iOS/visionOS Settings > Accessibility > Display & Text Size
struct FontStyles {
    /// Table cell content font - scales with user's preferred size
    /// Note: Must be computed property to respond to Dynamic Type changes
    static var tableCell: Font {
        Font.system(.body)
    }
    
    /// Table cell content font with medium weight
    /// Note: Must be computed property to respond to Dynamic Type changes
    static var tableCellMedium: Font {
        Font.system(.body, design: .default, weight: .medium)
    }
    
    /// Small detail text in tables and lists
    /// Note: Must be computed property to respond to Dynamic Type changes
    static var detail: Font {
        Font.system(.caption)
    }
    
    /// Smaller detail text for secondary information
    /// Note: Must be computed property to respond to Dynamic Type changes
    static var detailSmall: Font {
        Font.system(.caption2)
    }
    
    /// Header text for tables and sections
    /// Note: Must be computed property to respond to Dynamic Type changes
    static var tableHeader: Font {
        Font.system(.headline)
    }
    
    /// For cases where you need a fixed size (use sparingly)
    /// These sizes will scale with Dynamic Type when accessed through `scaled()` modifier
    enum FixedSize: CGFloat {
        case small = 12
        case medium = 14
        case large = 16
        
        /// Returns a font that scales with Dynamic Type
        func scaled(weight: Font.Weight = .regular) -> Font {
            return Font.system(size: self.rawValue, weight: weight)
        }
    }
}

/// View modifier to apply consistent font styles
extension View {
    /// Apply table cell font style
    func tableCellFont(weight: Font.Weight = .regular) -> some View {
        self.font(weight == .regular ? FontStyles.tableCell : FontStyles.tableCellMedium)
    }
    
    /// Apply detail font style
    func detailFont() -> some View {
        self.font(FontStyles.detail)
    }
    
    /// Apply table header font style
    func tableHeaderFont() -> some View {
        self.font(FontStyles.tableHeader)
    }
}

