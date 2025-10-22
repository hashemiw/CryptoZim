//
//  SwiftDataServiceProtocol.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/22.
//

// Services/SwiftDataService.swift
import Foundation
import SwiftData

protocol SwiftDataServiceProtocol {
    // Core Data Operations
    func saveOrUpdateCryptocurrencies(_ cryptocurrencies: [CryptoCurrency]) async
    func getAllCryptocurrencies() async -> [CryptoCurrency]
    func getCryptocurrency(by id: String) async -> CryptoCurrency?
    func savePriceHistory(_ crypto: CryptoCurrency) async
    func getPriceHistory(for cryptoId: String, hours: Int) async -> [PriceHistory]
    func getLatestPrices() async -> [CryptoCurrency]
    
    // Debug Methods
    func printAllCryptocurrencies() async
    func printPriceHistory(for cryptoId: String) async
    func printDatabaseStats() async
    func printCryptoDetails(_ cryptoId: String) async
}


@MainActor
class SwiftDataService: SwiftDataServiceProtocol {
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
    
    func saveOrUpdateCryptocurrencies(_ cryptocurrencies: [CryptoCurrency]) async {
        for crypto in cryptocurrencies {
            await saveOrUpdateCrypto(crypto)
        }
        
        // Clean old history (keep only last 24 hours)
        await cleanOldHistory()
    }
    
    // In SwiftDataService - optimize save operations
    private func saveOrUpdateCrypto(_ crypto: CryptoCurrency) async -> Bool {
        let descriptor = FetchDescriptor<CryptoData>(
            predicate: #Predicate { $0.id == crypto.id }
        )
        
        do {
            let existing = try modelContext.fetch(descriptor).first
            
            if let existing = existing {
                // Check if values actually changed before updating
                let priceChanged = !existing.currentPrice.isApproximatelyEqual(to: crypto.currentPrice, tolerance: 0.001)
                let percentageChanged: Bool
                
                if let existingChange = existing.priceChangePercentage24h, let newChange = crypto.priceChangePercentage24h {
                    percentageChanged = !existingChange.isApproximatelyEqual(to: newChange, tolerance: 0.001)
                } else {
                    percentageChanged = (existing.priceChangePercentage24h != nil) != (crypto.priceChangePercentage24h != nil)
                }
                
                guard priceChanged || percentageChanged else {
                    print("⚡ DB: \(crypto.symbol.uppercased()) unchanged - skipping save")
                    return false
                }
                
                // Update existing
                existing.currentPrice = crypto.currentPrice
                existing.priceChangePercentage24h = crypto.priceChangePercentage24h
                existing.lastUpdated = Date()
                
                print("💾 DB: Updated \(crypto.symbol.uppercased()) $\(existing.currentPrice)")
            } else {
                // Create new
                let newCrypto = CryptoData(from: crypto)
                modelContext.insert(newCrypto)
                print("💾 DB: Added new \(crypto.symbol.uppercased())")
            }
            
            // Always save price history (for chart data)
            await savePriceHistory(crypto)
            
            try modelContext.save()
            return true
        } catch {
            print("Error saving crypto: \(error)")
            return false
        }
    }
    
    func getAllCryptocurrencies() async -> [CryptoCurrency] {
        let descriptor = FetchDescriptor<CryptoData>(
            sortBy: [SortDescriptor(\.currentPrice, order: .reverse)]
        )
        
        do {
            let cryptoData = try modelContext.fetch(descriptor)
            return cryptoData.map { cryptoData in
                CryptoCurrency(
                    id: cryptoData.id,
                    symbol: cryptoData.symbol,
                    name: cryptoData.name,
                    image: cryptoData.image,
                    currentPrice: cryptoData.currentPrice,
                    priceChangePercentage24h: cryptoData.priceChangePercentage24h
                )
            }
        } catch {
            print("Error fetching cryptos: \(error)")
            return []
        }
    }
    
    func getCryptocurrency(by id: String) async -> CryptoCurrency? {
        let descriptor = FetchDescriptor<CryptoData>(
            predicate: #Predicate { $0.id == id }
        )
        
        do {
            guard let cryptoData = try modelContext.fetch(descriptor).first else {
                return nil
            }
            
            return CryptoCurrency(
                id: cryptoData.id,
                symbol: cryptoData.symbol,
                name: cryptoData.name,
                image: cryptoData.image,
                currentPrice: cryptoData.currentPrice,
                priceChangePercentage24h: cryptoData.priceChangePercentage24h
            )
        } catch {
            print("Error fetching crypto: \(error)")
            return nil
        }
    }
    
    func savePriceHistory(_ crypto: CryptoCurrency) async {
        let history = PriceHistory(
            cryptoId: crypto.id,
            price: crypto.currentPrice,
            priceChangePercentage: crypto.priceChangePercentage24h
        )
        
        // Find the crypto data and add history
        let descriptor = FetchDescriptor<CryptoData>(
            predicate: #Predicate { $0.id == crypto.id }
        )
        
        do {
            if let cryptoData = try modelContext.fetch(descriptor).first {
                cryptoData.priceHistory.append(history)
                try modelContext.save()
            }
        } catch {
            print("Error saving price history: \(error)")
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
            print("Error fetching price history: \(error)")
            return []
        }
    }
    
    func getLatestPrices() async -> [CryptoCurrency] {
        await getAllCryptocurrencies()
    }
    
    private func cleanOldHistory() async {
        let twentyFourHoursAgo = Date().addingTimeInterval(-24 * 60 * 60)
        
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
            print("Error cleaning old history: \(error)")
        }
    }
    
    // REMOVE the generateMockBitcoinData method entirely
}
// Add these methods to your SwiftDataService class
extension SwiftDataService {
    // Print all cryptocurrencies in database
    func printAllCryptocurrencies() async {
        let descriptor = FetchDescriptor<CryptoData>(
            sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
        )
        
        do {
            let cryptoData = try modelContext.fetch(descriptor)
            print("📊 DATABASE CONTENTS - CRYPTOCURRENCIES")
            print("========================================")
            print("Total cryptocurrencies: \(cryptoData.count)")
            print("")
            
            for crypto in cryptoData {
                print("🔸 \(crypto.name) (\(crypto.symbol.uppercased()))")
                print("   ID: \(crypto.id)")
                print("   Price: $\(crypto.currentPrice)")
                print("   24h Change: \(crypto.priceChangePercentage24h ?? 0)%")
                print("   Last Updated: \(crypto.lastUpdated)")
                print("   History Records: \(crypto.priceHistory.count)")
                print("")
            }
        } catch {
            print("❌ Error fetching cryptocurrencies: \(error)")
        }
    }
    
    // Print price history for a specific cryptocurrency
    func printPriceHistory(for cryptoId: String) async {
        let descriptor = FetchDescriptor<CryptoData>(
            predicate: #Predicate { $0.id == cryptoId }
        )
        
        do {
            if let cryptoData = try modelContext.fetch(descriptor).first {
                print("📈 PRICE HISTORY - \(cryptoData.name.uppercased())")
                print("========================================")
                print("Total history records: \(cryptoData.priceHistory.count)")
                print("")
                
                let sortedHistory = cryptoData.priceHistory.sorted { $0.timestamp < $1.timestamp }
                
                for (index, history) in sortedHistory.enumerated() {
                    print("\(index + 1). $\(history.price) - \(history.timestamp)")
                }
                
                if let first = sortedHistory.first, let last = sortedHistory.last {
                    let change = ((last.price - first.price) / first.price) * 100
                    print("")
                    print("📊 Summary:")
                    print("   First: $\(first.price) at \(first.timestamp)")
                    print("   Last: $\(last.price) at \(last.timestamp)")
                    print("   Change: \(String(format: "%.2f", change))%")
                }
            } else {
                print("❌ No cryptocurrency found with ID: \(cryptoId)")
            }
        } catch {
            print("❌ Error fetching price history: \(error)")
        }
    }
    
    // Print database statistics
    func printDatabaseStats() async {
        let cryptoDescriptor = FetchDescriptor<CryptoData>()
        let historyDescriptor = FetchDescriptor<PriceHistory>()
        
        do {
            let cryptos = try modelContext.fetch(cryptoDescriptor)
            let history = try modelContext.fetch(historyDescriptor)
            
            print("📊 DATABASE STATISTICS")
            print("=====================")
            print("Total Cryptocurrencies: \(cryptos.count)")
            print("Total Price History Records: \(history.count)")
            print("")
            
            // Count history per crypto
            for crypto in cryptos {
                print("   \(crypto.symbol.uppercased()): \(crypto.priceHistory.count) records")
            }
            
            print("")
            print("📅 Data Time Range:")
            if let oldestHistory = history.min(by: { $0.timestamp < $1.timestamp }) {
                let newestHistory = history.max(by: { $0.timestamp < $1.timestamp })
                print("   Oldest: \(oldestHistory.timestamp)")
                print("   Newest: \(newestHistory?.timestamp ?? Date())")
            }
        } catch {
            print("❌ Error fetching database stats: \(error)")
        }
    }
    
    // Print specific crypto with detailed info
    func printCryptoDetails(_ cryptoId: String) async {
        let descriptor = FetchDescriptor<CryptoData>(
            predicate: #Predicate { $0.id == cryptoId }
        )
        
        do {
            if let crypto = try modelContext.fetch(descriptor).first {
                print("🔍 DETAILED CRYPTO INFO")
                print("======================")
                print("Name: \(crypto.name)")
                print("Symbol: \(crypto.symbol.uppercased())")
                print("ID: \(crypto.id)")
                print("Current Price: $\(crypto.currentPrice)")
                print("24h Change: \(crypto.priceChangePercentage24h ?? 0)%")
                print("Last Updated: \(crypto.lastUpdated)")
                print("Image URL: \(crypto.image)")
                print("")
                print("📈 Price History (\(crypto.priceHistory.count) records):")
                
                let sortedHistory = crypto.priceHistory.sorted { $0.timestamp > $1.timestamp }
                for history in sortedHistory.prefix(5) { // Show last 5 records
                    print("   $\(history.price) - \(history.timestamp)")
                }
                
                if crypto.priceHistory.count > 5 {
                    print("   ... and \(crypto.priceHistory.count - 5) more records")
                }
            } else {
                print("❌ Crypto not found: \(cryptoId)")
            }
        } catch {
            print("❌ Error fetching crypto details: \(error)")
        }
    }
}
