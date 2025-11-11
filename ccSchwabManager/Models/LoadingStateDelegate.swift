import Foundation

@MainActor
protocol LoadingStateDelegate: AnyObject, Sendable {
    func setLoading(_ isLoading: Bool)
} 