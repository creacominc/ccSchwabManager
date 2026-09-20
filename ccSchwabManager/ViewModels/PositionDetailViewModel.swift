import Foundation
import Observation

@MainActor
@Observable
final class PositionDetailViewModel {
    var priceHistory: CandleList?
    var isLoadingPriceHistory = false
    var isLoadingTransactions = false
    var quoteData: QuoteData?
    var taxLotData: [SalesCalcPositionsRecord] = []
    var isLoadingTaxLots = false
    var computedATRValue = 0.0
    var computedSharesAvailableForTrading = 0.0
    var transactions: [Transaction] = []
    var isRefreshing = false
    var loadStates: [SecurityDataGroup: SecurityDataLoadState] = [:]

    @ObservationIgnored var dataLoadTask: Task<Void, Never>?
    @ObservationIgnored var prefetchTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored var isPrefetchPaused = false
    @ObservationIgnored var tabLoadTasks: [SecurityDataGroup: Task<Void, Never>] = [:]
    @ObservationIgnored var hasUserInteraction = false
    @ObservationIgnored var lastUserInteractionTime = Date()
    @ObservationIgnored var prefetchQueue: [String] = []
    @ObservationIgnored var prefetchProcessorTask: Task<Void, Never>?
    @ObservationIgnored var historyBackfillTask: Task<Void, Never>?
    @ObservationIgnored var prefetchUserIdleResumeTask: Task<Void, Never>?
    @ObservationIgnored private var loadingTimeoutTask: Task<Void, Never>?
    @ObservationIgnored private var refreshIndicatorTask: Task<Void, Never>?

    func clearData() {
        priceHistory = nil
        transactions = []
        quoteData = nil
        computedATRValue = 0
        taxLotData = []
        computedSharesAvailableForTrading = 0
        loadStates = [:]
        isLoadingPriceHistory = false
        isLoadingTransactions = false
        isLoadingTaxLots = false
    }

    func apply(_ snapshot: SecurityDataSnapshot, loadingState: LoadingState) {
        if let history = snapshot.priceHistory {
            priceHistory = history
        }
        if let transactions = snapshot.transactions {
            self.transactions = transactions
        }
        if let quote = snapshot.quoteData {
            quoteData = quote
        }
        if let atrValue = snapshot.atrValue {
            computedATRValue = atrValue
        }
        if let taxLots = snapshot.taxLotData {
            taxLotData = taxLots
        }
        if let shares = snapshot.sharesAvailableForTrading {
            computedSharesAvailableForTrading = shares
        }

        loadStates = snapshot.loadStates
        isLoadingPriceHistory = snapshot.isLoading(.priceHistory)
        isLoadingTransactions = snapshot.isLoading(.transactions)
        isLoadingTaxLots = snapshot.isLoading(.taxLots)
        loadingState.setLoading(snapshot.loadStates.values.contains { $0.isLoading })
    }

    func cancelBackgroundTasks() {
        dataLoadTask?.cancel()
        dataLoadTask = nil
        tabLoadTasks.values.forEach { $0.cancel() }
        tabLoadTasks.removeAll()
        prefetchProcessorTask?.cancel()
        prefetchProcessorTask = nil
        prefetchTasks.values.forEach { $0.cancel() }
        prefetchTasks.removeAll()
        prefetchUserIdleResumeTask?.cancel()
        prefetchUserIdleResumeTask = nil
        historyBackfillTask?.cancel()
        historyBackfillTask = nil
        loadingTimeoutTask?.cancel()
        loadingTimeoutTask = nil
        refreshIndicatorTask?.cancel()
        refreshIndicatorTask = nil
    }

    func scheduleLoadingTimeout(for loadingState: LoadingState) {
        loadingTimeoutTask?.cancel()
        loadingTimeoutTask = Task { [weak loadingState] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled, loadingState?.isLoading == true else { return }
            AppLogger.shared.debug("PositionDetailView: Loading timeout - clearing stuck loading state")
            loadingState?.forceClearLoading()
        }
    }

    func scheduleRefreshIndicatorReset() {
        refreshIndicatorTask?.cancel()
        refreshIndicatorTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.isRefreshing = false
        }
    }
}
