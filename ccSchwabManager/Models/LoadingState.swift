import Foundation
import SwiftUI
import os.log

class LoadingState: ObservableObject, LoadingStateDelegate {
    @Published var isLoading: Bool = false
    // private var loadingCallStack: String = ""
    private var loadingTimer: Timer?
    private var loadingStartTime: Date?
    
    // Create a logger for this class
    private let logger = Logger(subsystem: "com.creacom.ccSchwabManager", category: "LoadingState")
    
    func setLoading(_ isLoading: Bool) {
        // Ensure this runs on the main thread
        DispatchQueue.main.async {
            // let callStack = Thread.callStackSymbols.prefix(5).joined(separator: "\n")            
            if isLoading {
                // self.loadingCallStack = callStack
                self.loadingStartTime = Date()
                // AppLogger.shared.info("🔄 LoadingState.setLoading(TRUE) - Call stack:\n\(callStack)")

                // Set a timeout to automatically clear loading state after 30 seconds
                self.loadingTimer?.invalidate()
                self.loadingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
                    AppLogger.shared.warning("⏰ LoadingState timeout - automatically clearing stuck loading state")
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        self?.loadingStartTime = nil
                    }
                }
            } else {
                let duration = self.loadingStartTime.map { Date().timeIntervalSince($0) } ?? 0
                // AppLogger.shared.info("✅ LoadingState.setLoading(FALSE) - Duration: \(String(format: "%.2f", duration))s - Previous call stack:\n\(self.loadingCallStack)")
                // self.loadingCallStack = ""
                self.loadingStartTime = nil
                self.loadingTimer?.invalidate()
                self.loadingTimer = nil
            }
            
            self.isLoading = isLoading
        }
    }
    
    func forceClearLoading() {
        DispatchQueue.main.async {
            AppLogger.shared.warning("🧹 LoadingState.forceClearLoading - Force clearing stuck loading state")
            self.isLoading = false
            // self.loadingCallStack = ""
            self.loadingStartTime = nil
            self.loadingTimer?.invalidate()
            self.loadingTimer = nil
        }
    }
    
    deinit {
        loadingTimer?.invalidate()
        // if isLoading {
        //     print("⚠️ LoadingState deallocated while still loading! Call stack:\n\(loadingCallStack)")
        // }
    }
}

extension View {
    func withLoadingState(_ loadingState: LoadingState) -> some View {
        self.modifier(LoadingStateModifier(loadingState: loadingState))
    }
}

struct LoadingStateModifier: ViewModifier {
    @ObservedObject var loadingState: LoadingState
    
    func body(content: Content) -> some View {
        ZStack {
            content
            if loadingState.isLoading {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
    }
} 
