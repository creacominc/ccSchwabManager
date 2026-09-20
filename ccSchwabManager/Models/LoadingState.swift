import Foundation
import SwiftUI
import os.log

@MainActor
class LoadingState: ObservableObject, LoadingStateDelegate {
    @Published var isLoading: Bool = false
    // private var loadingCallStack: String = ""
    private var loadingTimeoutTask: Task<Void, Never>?
    private var loadingStartTime: Date?
    
    // Create a logger for this class
    private let logger = Logger(subsystem: "com.creacom.ccSchwabManager", category: "LoadingState")
    
    func setLoading(_ isLoading: Bool) {
        // let callStack = Thread.callStackSymbols.prefix(5).joined(separator: "\n")            
        if isLoading {
            // self.loadingCallStack = callStack
            self.loadingStartTime = Date()
            // AppLogger.shared.info("🔄 LoadingState.setLoading(TRUE) - Call stack:\n\(callStack)")

            loadingTimeoutTask?.cancel()
            loadingTimeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                AppLogger.shared.warning("⏰ LoadingState timeout - automatically clearing stuck loading state")
                self?.isLoading = false
                self?.loadingStartTime = nil
            }
        } else {
            // let duration = self.loadingStartTime.map { Date().timeIntervalSince($0) } ?? 0
            // AppLogger.shared.info("✅ LoadingState.setLoading(FALSE) - Duration: \(String(format: "%.2f", duration))s - Previous call stack:\n\(self.loadingCallStack)")
            // self.loadingCallStack = ""
            self.loadingStartTime = nil
            loadingTimeoutTask?.cancel()
            loadingTimeoutTask = nil
        }
        
        self.isLoading = isLoading
    }
    
    func forceClearLoading() {
        AppLogger.shared.warning("🧹 LoadingState.forceClearLoading - Force clearing stuck loading state")
        self.isLoading = false
        // self.loadingCallStack = ""
        self.loadingStartTime = nil
        loadingTimeoutTask?.cancel()
        loadingTimeoutTask = nil
    }
    
    nonisolated deinit {
        // Timer will be cleaned up automatically on deallocation
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
