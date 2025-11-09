import SwiftUI

/// Centralized font styles that support Dynamic Type
/// Users can adjust font sizes via iOS Settings > Accessibility > Display & Text Size
struct FontStyles {
    /// Table cell content font - scales with user's preferred size
    static let tableCell = Font.system(.body)
    
    /// Table cell content font with medium weight
    static let tableCellMedium = Font.system(.body, design: .default, weight: .medium)
    
    /// Small detail text in tables and lists
    static let detail = Font.system(.caption)
    
    /// Smaller detail text for secondary information
    static let detailSmall = Font.system(.caption2)
    
    /// Header text for tables and sections
    static let tableHeader = Font.system(.headline)
    
    /// For cases where you need a fixed size (use sparingly)
    /// These sizes will scale with Dynamic Type when accessed through `scaled()` modifier
    enum FixedSize: CGFloat {
        case small = 14
        case medium = 16
        case large = 18
        
        /// Returns a font that scales with Dynamic Type
        func scaled(weight: Font.Weight = .regular) -> Font {
            return Font.system(size: self.rawValue, weight: weight)
        }
    }
}

/// Environment value to track Dynamic Type size changes
struct DynamicTypeSize: EnvironmentKey {
    static let defaultValue: ContentSizeCategory = .medium
}

extension EnvironmentValues {
    var dynamicTypeSize: ContentSizeCategory {
        get { self[DynamicTypeSize.self] }
        set { self[DynamicTypeSize.self] = newValue }
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

