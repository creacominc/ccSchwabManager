import Foundation
import SwiftUI

class LoadingState: ObservableObject, LoadingStateDelegate {
    @Published var isLoading: Bool = false
    private var loadingCallStack: String = ""
    private var loadingTimer: Timer?
    
    func setLoading(_ isLoading: Bool) {
        let callStack = Thread.callStackSymbols.prefix(5).joined(separator: "\n")
        let timestamp = Date().timeIntervalSince1970
        
        if isLoading {
            loadingCallStack = callStack
            print("🔄 [\(timestamp)] LoadingState.setLoading(TRUE) - Call stack:\n\(callStack)")
            
            // Set a timeout to automatically clear loading state after 30 seconds
            loadingTimer?.invalidate()
            loadingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
                print("⏰ LoadingState timeout - automatically clearing loading state")
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
            }
        } else {
            print("✅ [\(timestamp)] LoadingState.setLoading(FALSE) - Previous call stack:\n\(loadingCallStack)")
            loadingCallStack = ""
            
            // Cancel the timeout timer
            loadingTimer?.invalidate()
            loadingTimer = nil
        }
        
        DispatchQueue.main.async {
            self.isLoading = isLoading
        }
    }
    
    deinit {
        loadingTimer?.invalidate()
        if isLoading {
            print("⚠️ LoadingState deallocated while still loading! Call stack:\n\(loadingCallStack)")
        }
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