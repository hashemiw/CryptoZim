//
//  CryptoViewModel.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/21.
//

// ViewModels/CryptoListViewModel.swift
import Foundation
import Combine
import SwiftUI

@MainActor
class CryptoListViewModel: ObservableObject {
    @Published var cellViewModels: [CryptoCellViewModel] = []
    @Published var filteredCellViewModels: [CryptoCellViewModel] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var rateLimitInfo: RateLimitInfo?
    @Published var lastUpdated: Date = Date()
    @Published var updateCount: Int = 0
    @Published var isUpdating: Bool = false
    
    private let networkService: NetworkServiceProtocol
    private let dataService: SwiftDataServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var autoRefreshTimer: Timer?
    private let refreshInterval: TimeInterval = 12.0
    
    // Cache for quick lookups
    private var cellViewModelCache: [String: CryptoCellViewModel] = [:]
    // Rate limit tracking
     private var rateLimitRetryTimer: Timer?
     
     struct RateLimitInfo {
         let message: String
         let retryTime: Date
         let secondsRemaining: Int
     }
    
    init(networkService: NetworkServiceProtocol, dataService: SwiftDataServiceProtocol) {
        self.networkService = networkService
        self.dataService = dataService
        setupSearch()
    }
    
    convenience init() {
        self.init(networkService: NetworkService(), dataService: SwiftDataService())
    }
    
    deinit {
        print("🧹 CryptoListViewModel deinitialized")
    }

    func printState() {
        print("""
        📊 ViewModel State:
        - Cell VMs: \(cellViewModels.count)
        - Update Count: \(updateCount)
        - Last Updated: \(lastUpdated)
        - Timer Active: \(autoRefreshTimer != nil)
        - Rate Limit: \(rateLimitInfo != nil ? "Active" : "None")
        """)
    }
    

    
    private func setupSearch() {
        $searchText
            .combineLatest($cellViewModels)
            .map { searchText, cellViewModels in
                guard !searchText.isEmpty else { return cellViewModels }
                return cellViewModels.filter { cellVM in
                    cellVM.name.lowercased().contains(searchText.lowercased()) ||
                    cellVM.symbol.lowercased().contains(searchText.lowercased())
                }
            }
            .assign(to: &$filteredCellViewModels)
    }
    
    // In CryptoListViewModel
    private func startAutoRefresh() {
        autoRefreshTimer?.invalidate()
        
        print("🔄 Starting live price updates every \(refreshInterval) seconds")
        
        // Use RunLoop to keep timer alive even when view changes
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            print("⏰ Timer fired - fetching live data...")
            Task { [weak self] in
                await self?.fetchLivePriceData()
            }
        }
        
        // Add timer to RunLoop to keep it alive during navigation
        if let timer = autoRefreshTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    func pauseUpdates() {
        print("⏸️ Pausing updates")
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }

    func resumeUpdates() {
        print("▶️ Resuming updates")
        if autoRefreshTimer == nil {
            startAutoRefresh()
        }
    }
    
    // In CryptoListViewModel - enhance fetchLivePriceData
    private func fetchLivePriceData() async {
        // Don't try to fetch if we're in rate limit cooldown
        if let rateLimitInfo = rateLimitInfo, rateLimitInfo.retryTime > Date() {
            print("⏸️ Skipping fetch - rate limit cooldown active")
            return
        }
        
        // Clear any previous rate limit info if we're attempting a new fetch
        if rateLimitInfo != nil {
            rateLimitInfo = nil
        }
        
        do {
            print("🌐 Starting network request...")
            let updatedCryptos = try await networkService.fetchCryptocurrencies()
            print("🌐 Network request completed with \(updatedCryptos.count) cryptos")
            
            // Save to database first
            await dataService.saveOrUpdateCryptocurrencies(updatedCryptos)
            
            // Then update UI from database
            await updateFromDatabase()
            
            lastUpdated = Date()
            updateCount += 1
            print("✅ Update #\(updateCount) completed at \(lastUpdated)")
            
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            // If network fails, try to load from database
            await loadFromDatabase()
            await handleNetworkError(error)
        }
    }
        
    
    private func updateFromDatabase() async {
        let cryptosFromDB = await dataService.getLatestPrices()
        await updateCellViewModels(with: cryptosFromDB)
        print("💰 Price update #\(updateCount) - \(cellViewModels.count) cryptos from DB")
    }
    
    private func loadFromDatabase() async {
        let cryptosFromDB = await dataService.getLatestPrices()
        if !cryptosFromDB.isEmpty {
            await updateCellViewModels(with: cryptosFromDB)
            print("📀 Loaded \(cellViewModels.count) cryptos from local database")
        }
    }
    
    private func updateCellViewModels(with cryptos: [CryptoCurrency]) async {
        if cellViewModels.isEmpty {
            // Initial load - create all cell view models
            await createInitialCellViewModels(cryptos)
        } else {
            // Live update - only update price data in existing cells
            await updateExistingPriceData(cryptos)
        }
    }
    
    private func createInitialCellViewModels(_ cryptos: [CryptoCurrency]) async {
        let newCellViewModels = cryptos.map { CryptoCellViewModel(cryptocurrency: $0) }
        
        // Build cache
        for cellVM in newCellViewModels {
            cellViewModelCache[cellVM.id] = cellVM
        }
        
        cellViewModels = newCellViewModels
    }
    
    // In CryptoListViewModel - add detailed logging
    private func updateExistingPriceData(_ newCryptos: [CryptoCurrency]) async {
        var updatedCount = 0
        var unchangedCount = 0
        var changedCryptos: [String] = []
        
        print("🔄 Starting UI update with \(newCryptos.count) cryptos from API")
        
        for crypto in newCryptos {
            if let existingCellVM = cellViewModelCache[crypto.id] {
                let oldPrice = existingCellVM.currentPrice
                let oldChange = existingCellVM.priceChangePercentage24h
                
                // Update only if values actually changed
                let wasUpdated = existingCellVM.updatePriceData(with: crypto)
                
                if wasUpdated {
                    updatedCount += 1
                    changedCryptos.append("\(crypto.symbol.uppercased()) $\(oldPrice)→$\(crypto.currentPrice)")
                } else {
                    unchangedCount += 1
                }
            } else {
                // New crypto - add to list
                let newCellVM = CryptoCellViewModel(cryptocurrency: crypto)
                cellViewModelCache[crypto.id] = newCellVM
                cellViewModels.append(newCellVM)
                print("➕ Added new crypto: \(crypto.name)")
                updatedCount += 1
                changedCryptos.append("\(crypto.symbol.uppercased()) NEW")
            }
        }
        
        if updatedCount > 0 {
            print("✅ Updated \(updatedCount) cryptocurrencies:")
            for changed in changedCryptos {
                print("   📈 \(changed)")
            }
            print("   ⚡ \(unchangedCount) unchanged")
            
            // Only force UI refresh if we actually updated something
            let updatedViewModels = cellViewModels
            cellViewModels = []
            cellViewModels = updatedViewModels
            
            objectWillChange.send()
        } else {
            print("⚡ All \(newCryptos.count) cryptocurrencies unchanged - skipping UI update")
        }
    }
    
    private func handleNetworkError(_ error: Error) async {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .rateLimitExceeded:
                await handleRateLimitExceeded()
            default:
                // For other errors, just use cached data silently
                print("🌐 Network error: \(networkError.errorDescription ?? "Unknown") - using cached data")
            }
        } else {
            // For unknown errors, use cached data silently
            print("🌐 Unknown error: \(error.localizedDescription) - using cached data")
        }
    }
    
    private func handleRateLimitExceeded() async {
        let retryTime = Date().addingTimeInterval(60) // 1 minute cooldown
        let secondsRemaining = Int(retryTime.timeIntervalSince(Date()))
        
        rateLimitInfo = RateLimitInfo(
            message: "Rate limit reached. Updates paused for 1 minute.",
            retryTime: retryTime,
            secondsRemaining: secondsRemaining
        )
        
        print("🚫 Rate limit exceeded. Retry at \(retryTime)")
        
        // Start countdown timer
        startRateLimitCountdown()
    }

    private func startRateLimitCountdown() {
         rateLimitRetryTimer?.invalidate()
         
         rateLimitRetryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
             Task { @MainActor [weak self] in
                 guard let self = self, let rateLimitInfo = self.rateLimitInfo else { return }
                 
                 let secondsRemaining = Int(rateLimitInfo.retryTime.timeIntervalSince(Date()))
                 
                 if secondsRemaining <= 0 {
                     // Rate limit cooldown finished
                     self.rateLimitInfo = nil
                     self.rateLimitRetryTimer?.invalidate()
                     print("✅ Rate limit cooldown finished - resuming updates")
                 } else {
                     // Update countdown
                     self.rateLimitInfo = RateLimitInfo(
                         message: "Rate limit reached. Resuming in \(secondsRemaining)s",
                         retryTime: rateLimitInfo.retryTime,
                         secondsRemaining: secondsRemaining
                     )
                 }
             }
         }
     }
     
    func fetchInitialData() async {
        guard cellViewModels.isEmpty else { return }
        
        isLoading = true
//        errorMessage = nil
        
        // REMOVE: await dataService.generateMockBitcoinData()
        
        // First try to load from database (offline support)
        await loadFromDatabase()
        
        // Then try to fetch from network
        do {
            let cryptos = try await networkService.fetchCryptocurrencies()
            await dataService.saveOrUpdateCryptocurrencies(cryptos)
            await updateFromDatabase()
            lastUpdated = Date()
            
            startAutoRefresh()
        } catch {
            await handleNetworkError(error)
            // If we have data from DB, we can still start auto-refresh
            if !cellViewModels.isEmpty {
                startAutoRefresh()
            }
        }
        
        isLoading = false
    }
    
    
    
    // MARK: - Detail View Methods
    
    // In CryptoListViewModel
    func getCryptoDetail(by id: String) async -> CryptoCurrency? {
        let crypto = await dataService.getCryptocurrency(by: id)
        print("🔍 getCryptoDetail for \(id): \(crypto?.name ?? "not found")")
        return crypto
    }

    func getPriceHistory(for cryptoId: String, hours: Int = 24) async -> [PriceHistory] {
        let history = await dataService.getPriceHistory(for: cryptoId, hours: hours)
        print("📈 getPriceHistory for \(cryptoId): \(history.count) records")
        return history
    }
}

// Update CryptoDetailViewModel for Color support
@MainActor
class CryptoDetailViewModel: ObservableObject {
    @Published var cryptocurrency: CryptoCurrency
    
    init(cryptocurrency: CryptoCurrency) {
        self.cryptocurrency = cryptocurrency
    }
    
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = cryptocurrency.currentPrice < 1 ? 6 : 2
        return formatter.string(from: NSNumber(value: cryptocurrency.currentPrice)) ?? "$0.00"
    }
    
    var formattedPriceChange: String {
        guard let change = cryptocurrency.priceChangePercentage24h else { return "N/A" }
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", change))%"
    }
    
    var priceChangeColor: Color {
        guard let change = cryptocurrency.priceChangePercentage24h else { return .secondary }
        return change >= 0 ? .green : .red
    }
}


extension NetworkError: Equatable {
    static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL):
            return true
        case (.invalidResponse, .invalidResponse):
            return true
        case (.decodingError, .decodingError):
            return true
        case (.rateLimitExceeded, .rateLimitExceeded):
            return true
        case (.serverError(let lhsCode), .serverError(let rhsCode)):
            return lhsCode == rhsCode
        default:
            return false
        }
    }
}


// Remove the debug extension from public API, keep it internal if needed for development
extension CryptoListViewModel {
    // These methods are now internal only, not part of the public interface
    func printDatabaseContents() async {
        print("🔄 Printing database contents...")
        await dataService.printAllCryptocurrencies()
    }
    
    func printCryptoHistory(_ cryptoId: String) async {
        print("🔄 Printing history for crypto: \(cryptoId)")
        await dataService.printPriceHistory(for: cryptoId)
    }
    
    func printDatabaseStatistics() async {
        print("🔄 Printing database statistics...")
        await dataService.printDatabaseStats()
    }
    
    func printCryptoDetails(_ cryptoId: String) async {
        print("🔄 Printing details for crypto: \(cryptoId)")
        await dataService.printCryptoDetails(cryptoId)
    }
}
