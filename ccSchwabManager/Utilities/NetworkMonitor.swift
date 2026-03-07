//
//  NetworkMonitor.swift
//  ccSchwabManager
//
//  Created by AI Assistant on 2026-03-07.
//

import Foundation
import Network
import SwiftUI

#if os(iOS)
import SystemConfiguration.CaptiveNetwork
import UIKit
#endif

/// Monitors network connection type (WiFi vs Cellular) and signal strength
@MainActor
class NetworkMonitor: ObservableObject {
    @Published var connectionType: ConnectionType = .unknown
    @Published var signalStrength: SignalStrength = .none
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    enum SignalStrength: Int, CaseIterable {
        case none = 0
        case weak = 1
        case fair = 2
        case good = 3
        case excellent = 4
        
        var iconName: String {
            switch self {
            case .none:
                return "wifi.slash"
            case .weak:
                return "wifi"
            case .fair:
                return "wifi"
            case .good:
                return "wifi"
            case .excellent:
                return "wifi"
            }
        }
        
        var bars: Int {
            return self.rawValue
        }
    }
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                
                if path.status == .satisfied {
                    if path.usesInterfaceType(.wifi) {
                        self.connectionType = .wifi
                        self.updateWiFiSignalStrength()
                    } else if path.usesInterfaceType(.cellular) {
                        self.connectionType = .cellular
                        self.updateCellularSignalStrength()
                    } else if path.usesInterfaceType(.wiredEthernet) {
                        self.connectionType = .ethernet
                        self.signalStrength = .excellent
                    } else {
                        self.connectionType = .unknown
                        self.signalStrength = .none
                    }
                } else {
                    self.connectionType = .unknown
                    self.signalStrength = .none
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    #if os(iOS)
    private func updateWiFiSignalStrength() {
        // On iOS, we can't directly access WiFi signal strength without private APIs
        // However, we can use a workaround by checking RSSI if available
        // For now, we'll show a generic WiFi indicator
        // In a real implementation, you might use CoreWLAN on macOS or
        // third-party libraries that use private APIs (not recommended for App Store)
        
        // Since we can't reliably get WiFi signal strength on iOS without private APIs,
        // we'll show a generic WiFi indicator
        signalStrength = .good // Default to good since we're connected
    }
    
    private func updateCellularSignalStrength() {
        // On iOS, we cannot access cellular signal strength without private APIs
        // Apple restricts this information for security/privacy reasons
        // We'll show a generic cellular indicator
        signalStrength = .good // Default to good since we're connected
    }
    #else
    private func updateWiFiSignalStrength() {
        signalStrength = .good
    }
    
    private func updateCellularSignalStrength() {
        signalStrength = .good
    }
    #endif
    
    deinit {
        monitor.cancel()
    }
}

/// View component that displays network connection indicator
struct NetworkIndicatorView: View {
    @EnvironmentObject var monitor: NetworkMonitor
    
    var body: some View {
        HStack(spacing: 4) {
            // Connection type icon
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.system(size: 14))
            
            // Signal strength bars
            if monitor.connectionType != .unknown && monitor.signalStrength != .none {
                HStack(spacing: 2) {
                    ForEach(1...4, id: \.self) { bar in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(bar <= monitor.signalStrength.bars ? iconColor : Color.gray.opacity(0.3))
                            .frame(width: 3, height: CGFloat(bar * 2 + 2))
                    }
                }
                .frame(height: 12)
            }
        }
    }
    
    private var iconName: String {
        switch monitor.connectionType {
        case .wifi:
            return "wifi"
        case .cellular:
            return "antenna.radiowaves.left.and.right"
        case .ethernet:
            return "cable.connector"
        case .unknown:
            return "wifi.slash"
        }
    }
    
    private var iconColor: Color {
        switch monitor.connectionType {
        case .wifi, .ethernet:
            return .blue
        case .cellular:
            return .green
        case .unknown:
            return .gray
        }
    }
}
