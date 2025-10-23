//
//  CryptoListViewModel.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/21.
//

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
    @Published var isUpdating: Bool = false
    
    private let networkService: NetworkServiceProtocol
    private let dataService: DBProtocol
    private var cancellables = Set<AnyCancellable>()
    private var autoRefreshTimer: Timer?
    private let refreshInterval = Constants.Refresh.autoRefreshInterval
    
    private var cellViewModelCache: [String: CryptoCellViewModel] = [:]
    private var rateLimitRetryTimer: Timer?
    
    struct RateLimitInfo {
        let message: String
        let retryTime: Date
        let secondsRemaining: Int
    }
    
    init(networkService: NetworkServiceProtocol, dataService: DBProtocol) {
        self.networkService = networkService
        self.dataService = dataService
        setupSearch()
    }
    
    convenience init() {
        self.init(networkService: NetworkService(), dataService: DBService())
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
    
    private func startAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.fetchLivePriceData()
            }
        }
        
        if let timer = autoRefreshTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    func pauseUpdates() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }
    
    func resumeUpdates() {
        if autoRefreshTimer == nil {
            startAutoRefresh()
        }
    }
    
    private func fetchLivePriceData() async {
        if let rateLimitInfo = rateLimitInfo, rateLimitInfo.retryTime > Date() {
            return
        }
        
        if rateLimitInfo != nil {
            rateLimitInfo = nil
        }
        
        do {
            let updatedCryptos = try await networkService.fetchCryptocurrencies()
            await dataService.saveOrUpdateCryptocurrencies(updatedCryptos)
            await updateFromDatabase()
            
            lastUpdated = Date()
            
        } catch {
            await loadFromDatabase()
            await handleNetworkError(error)
        }
    }
    
    private func updateFromDatabase() async {
        let cryptosFromDB = await dataService.getLatestPrices()
        await updateCellViewModels(with: cryptosFromDB)
    }
    
    private func loadFromDatabase() async {
        let cryptosFromDB = await dataService.getLatestPrices()
        if !cryptosFromDB.isEmpty {
            await updateCellViewModels(with: cryptosFromDB)
        }
    }
    
    private func updateCellViewModels(with cryptos: [Crypto]) async {
        if cellViewModels.isEmpty {
            await createInitialCellViewModels(cryptos)
        } else {
            await updateExistingPriceData(cryptos)
        }
    }
    
    private func createInitialCellViewModels(_ cryptos: [Crypto]) async {
        let newCellViewModels = cryptos.map { CryptoCellViewModel(cryptocurrency: $0) }
        
        for cellVM in newCellViewModels {
            cellViewModelCache[cellVM.id] = cellVM
        }
        
        cellViewModels = newCellViewModels
    }
    
    private func updateExistingPriceData(_ newCryptos: [Crypto]) async {
        var updatedCount = 0
        var unchangedCount = 0
        
        for crypto in newCryptos {
            if let existingCellVM = cellViewModelCache[crypto.id] {
                let wasUpdated = existingCellVM.updatePriceData(with: crypto)
                
                if wasUpdated {
                    updatedCount += 1
                } else {
                    unchangedCount += 1
                }
            } else {
                let newCellVM = CryptoCellViewModel(cryptocurrency: crypto)
                cellViewModelCache[crypto.id] = newCellVM
                cellViewModels.append(newCellVM)
                updatedCount += 1
            }
        }
        
        if updatedCount > 0 {
            let updatedViewModels = cellViewModels
            cellViewModels = []
            cellViewModels = updatedViewModels
            
            objectWillChange.send()
        }
    }
    
    private func handleNetworkError(_ error: Error) async {
        if let networkError = error as? NetworkError {
            switch networkError {
                case .rateLimitExceeded:
                    await handleRateLimitExceeded()
                default:
                    break
            }
        }
    }
    
    private func handleRateLimitExceeded() async {
        let retryTime = Date().addingTimeInterval(Constants.API.rateLimitRetryInterval)
        let secondsRemaining = Int(retryTime.timeIntervalSince(Date()))
        
        rateLimitInfo = RateLimitInfo(
            message: "Rate limit reached. Updates paused for 1 minute.",
            retryTime: retryTime,
            secondsRemaining: secondsRemaining
        )
        
        startRateLimitCountdown()
    }
    
    private func startRateLimitCountdown() {
        rateLimitRetryTimer?.invalidate()
        
        rateLimitRetryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let rateLimitInfo = self.rateLimitInfo else { return }
                
                let secondsRemaining = Int(rateLimitInfo.retryTime.timeIntervalSince(Date()))
                
                if secondsRemaining <= 0 {
                    self.rateLimitInfo = nil
                    self.rateLimitRetryTimer?.invalidate()
                } else {
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
        await loadFromDatabase()
        
        do {
            let cryptos = try await networkService.fetchCryptocurrencies()
            await dataService.saveOrUpdateCryptocurrencies(cryptos)
            await updateFromDatabase()
            lastUpdated = Date()
            
            startAutoRefresh()
        } catch {
            await handleNetworkError(error)
            if !cellViewModels.isEmpty {
                startAutoRefresh()
            }
        }
        isLoading = false
    }
    
    func getCryptoDetail(by id: String) async -> Crypto? {
        let crypto = await dataService.getCryptocurrency(by: id)
        return crypto
    }
    
    func getPriceHistory(for cryptoId: String, hours: Int = 24) async -> [PriceHistory] {
        let history = await dataService.getPriceHistory(for: cryptoId, hours: hours)
        return history
    }
}

