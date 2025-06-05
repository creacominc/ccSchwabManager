import Foundation
import SwiftUI

class LoadingState: ObservableObject {
    @Published var isLoading: Bool = false
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