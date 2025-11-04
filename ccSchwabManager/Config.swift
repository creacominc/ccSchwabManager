import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Trading Algorithm Configuration
public struct TradingConfig {
    /// Multiplier for ATR (Average True Range) calculations in trading algorithms
    /// Used to determine target gain percentages and trailing stop calculations
    public static let atrMultiplier: Double = 5.0
}

// MARK: - Deployment Target Configuration
// This file explicitly declares our deployment targets to help the linter understand
// that we're targeting the latest macOS and iOS versions.

#if os(macOS)
@available(macOS 15.2, *)
public typealias PlatformView = NSView
#elseif os(iOS)
@available(iOS 18.2, *)
public typealias PlatformView = UIView
#endif

// MARK: - Platform Availability Helpers
public struct PlatformConfig {
    public static let macOSDeploymentTarget = "15.2"
    public static let iOSDeploymentTarget = "18.2"
    
    #if os(macOS)
    @available(macOS 15.2, *)
    public static func isSupported() -> Bool {
        return true
    }
    #elseif os(iOS)
    @available(iOS 18.2, *)
    public static func isSupported() -> Bool {
        return true
    }
    #endif
} 
