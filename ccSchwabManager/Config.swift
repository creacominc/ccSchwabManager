import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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