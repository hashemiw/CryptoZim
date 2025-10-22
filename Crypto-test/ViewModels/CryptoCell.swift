//
//  CryptoCell.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/22.
//

// ViewModels/CryptoCellViewModel.swift
import Foundation
import Combine
import SwiftUI

@MainActor
class CryptoCellViewModel: ObservableObject, Identifiable {
    let id: String
    let symbol: String
    let name: String
    let image: String
    
    @Published var currentPrice: Double
    @Published var priceChangePercentage24h: Double?
    @Published var isUpdating: Bool = false
    @Published var showPriceShimmer: Bool = false
    @Published var showPercentageShimmer: Bool = false
    
    // Add a unique identifier that changes with each update
    @Published var updateId: UUID = UUID()
    
    private var cancellables = Set<AnyCancellable>()
    
    init(cryptocurrency: CryptoCurrency) {
        self.id = cryptocurrency.id
        self.symbol = cryptocurrency.symbol
        self.name = cryptocurrency.name
        self.image = cryptocurrency.image
        self.currentPrice = cryptocurrency.currentPrice
        self.priceChangePercentage24h = cryptocurrency.priceChangePercentage24h
    }
    
    func updatePriceData(with cryptocurrency: CryptoCurrency) -> Bool {
        guard self.id == cryptocurrency.id else { return false }
        
        let oldPrice = currentPrice
        let oldChange = priceChangePercentage24h
        
        // Check if values actually changed (with tolerance for floating point precision)
        let priceChanged = !oldPrice.isApproximatelyEqual(to: cryptocurrency.currentPrice, tolerance: 0.001)
        let percentageChanged: Bool
        
        if let oldChange = oldChange, let newChange = cryptocurrency.priceChangePercentage24h {
            percentageChanged = !oldChange.isApproximatelyEqual(to: newChange, tolerance: 0.001)
        } else {
            percentageChanged = (oldChange != nil) != (cryptocurrency.priceChangePercentage24h != nil)
        }
        
        // Only update if something actually changed
        guard priceChanged || percentageChanged else {
            print("⚡ \(symbol.uppercased()): No changes - skipping update")
            return false
        }
        
        print("🔄 \(symbol.uppercased()): Price changed $\(oldPrice) → $\(cryptocurrency.currentPrice)")
        
        // Start shimmer before updating values
        startShimmerAnimation()
        
        // Update values after a small delay to show shimmer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Update values
            self.currentPrice = cryptocurrency.currentPrice
            self.priceChangePercentage24h = cryptocurrency.priceChangePercentage24h
            
            // Force UI update by changing the updateId
            self.updateId = UUID()
            
            // Stop shimmer after values are updated
            self.stopShimmerAnimation()
        }
        
        // Trigger full update animation
        triggerUpdateAnimation()
        return true
    }
    
    private func startShimmerAnimation() {
        showPriceShimmer = true
        showPercentageShimmer = true
    }
    
    private func stopShimmerAnimation() {
        showPriceShimmer = false
        showPercentageShimmer = false
    }
    
    private func triggerUpdateAnimation() {
        isUpdating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.isUpdating = false
        }
    }
    
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = currentPrice < 1 ? 4 : 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: currentPrice)) ?? "$0.00"
    }
    
    var formattedPriceChange: String {
        guard let change = priceChangePercentage24h else { return "N/A" }
        return "\(change >= 0 ? "+" : "")\(String(format: "%.2f", change))%"
    }
    
    var priceChangeColor: Color {
        guard let change = priceChangePercentage24h else { return .secondary }
        return change >= 0 ? .green : .red
    }
    
    var priceChangeArrow: String {
        guard let change = priceChangePercentage24h else { return "minus" }
        return change >= 0 ? "arrow.up.right" : "arrow.down.right"
    }
}
