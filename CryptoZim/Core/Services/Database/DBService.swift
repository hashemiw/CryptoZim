//
//  SwiftDataService.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/23.
//

import Foundation
import SwiftData

@MainActor
class DBService: DBProtocol {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    
    init() {
        do {
            modelContainer = try ModelContainer(for: CryptoData.self, PriceHistory.self)
            modelContext = ModelContext(modelContainer)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    func saveOrUpdateCryptocurrencies(_ cryptocurrencies: [Crypto]) async {
        for crypto in cryptocurrencies {
            await saveOrUpdateCrypto(crypto)
        }
        await cleanOldHistory()
    }
    
    private func saveOrUpdateCrypto(_ crypto: Crypto) async {
        let descriptor = FetchDescriptor<CryptoData>(
            predicate: #Predicate { $0.id == crypto.id }
        )
        
        do {
            let existing = try modelContext.fetch(descriptor).first
            
            if let existing = existing {
                let priceChanged = !existing.currentPrice.isApproximatelyEqual(
                    to: crypto.currentPrice,
                    tolerance: Constants.DB.priceTolerance
                )
                
                let percentageChanged: Bool
                if let existingChange = existing.priceChangePercentage24h,
                   let newChange = crypto.priceChangePercentage24h {
                    percentageChanged = !existingChange.isApproximatelyEqual(
                        to: newChange,
                        tolerance: Constants.DB.priceTolerance
                    )
                } else {
                    percentageChanged = (existing.priceChangePercentage24h != nil) != (crypto.priceChangePercentage24h != nil)
                }
                
                guard priceChanged || percentageChanged else {
                    return  
                }
                
                existing.currentPrice = crypto.currentPrice
                existing.priceChangePercentage24h = crypto.priceChangePercentage24h
                existing.lastUpdated = Date()
            } else {
                let newCrypto = CryptoData(from: crypto)
                modelContext.insert(newCrypto)
            }
            
            await savePriceHistory(crypto)
            try modelContext.save()
        } catch {
        }
    }
    
    func getAllCryptocurrencies() async -> [Crypto] {
        let descriptor = FetchDescriptor<CryptoData>(
            sortBy: [SortDescriptor(\.currentPrice, order: .reverse)]
        )
        
        do {
            let cryptoData = try modelContext.fetch(descriptor)
            return cryptoData.map {
                Crypto(
                    id: $0.id,
                    symbol: $0.symbol,
                    name: $0.name,
                    image: $0.image,
                    currentPrice: $0.currentPrice,
                    priceChangePercentage24h: $0.priceChangePercentage24h
                )
            }
        } catch {
            return []
        }
    }
    
    func getCryptocurrency(by id: String) async -> Crypto? {
        let descriptor = FetchDescriptor<CryptoData>(
            predicate: #Predicate { $0.id == id }
        )
        
        do {
            guard let cryptoData = try modelContext.fetch(descriptor).first else {
                return nil
            }
            
            return Crypto(
                id: cryptoData.id,
                symbol: cryptoData.symbol,
                name: cryptoData.name,
                image: cryptoData.image,
                currentPrice: cryptoData.currentPrice,
                priceChangePercentage24h: cryptoData.priceChangePercentage24h
            )
        } catch {
            return nil
        }
    }
    
    func savePriceHistory(_ crypto: Crypto) async {
        let history = PriceHistory(
            cryptoId: crypto.id,
            price: crypto.currentPrice,
            priceChangePercentage: crypto.priceChangePercentage24h
        )
        
        let descriptor = FetchDescriptor<CryptoData>(
            predicate: #Predicate { $0.id == crypto.id }
        )
        
        do {
            if let cryptoData = try modelContext.fetch(descriptor).first {
                cryptoData.priceHistory.append(history)
                try modelContext.save()
            }
        } catch {
        }
    }
    
    func getPriceHistory(for cryptoId: String, hours: Int) async -> [PriceHistory] {
        let timeAgo = Date().addingTimeInterval(-Double(hours) * 60 * 60)
        
        let descriptor = FetchDescriptor<CryptoData>(
            predicate: #Predicate { $0.id == cryptoId }
        )
        
        do {
            guard let cryptoData = try modelContext.fetch(descriptor).first else {
                return []
            }
            
            return cryptoData.priceHistory
                .filter { $0.timestamp >= timeAgo }
                .sorted { $0.timestamp < $1.timestamp }
        } catch {
            return []
        }
    }
    
    func getLatestPrices() async -> [Crypto] {
        await getAllCryptocurrencies()
    }
    
    private func cleanOldHistory() async {
        let twentyFourHoursAgo = Date().addingTimeInterval(Constants.DB.cleanupInterval)
        
        let descriptor = FetchDescriptor<PriceHistory>(
            predicate: #Predicate { $0.timestamp < twentyFourHoursAgo }
        )
        
        do {
            let oldHistory = try modelContext.fetch(descriptor)
            for history in oldHistory {
                modelContext.delete(history)
            }
            try modelContext.save()
        } catch {
        }
    }
}
