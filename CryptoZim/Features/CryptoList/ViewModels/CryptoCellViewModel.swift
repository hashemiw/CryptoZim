//
//  CryptoCellViewModel.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/22.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class CryptoCellViewModel: ObservableObject, Identifiable, Equatable {
    let id: String
    let symbol: String
    let name: String
    let image: String
    
    @Published var currentPrice: Double
    @Published var priceChangePercentage24h: Double?
    @Published var isUpdating: Bool = false
    @Published var showPriceShimmer: Bool = false
    @Published var showPercentageShimmer: Bool = false
    
    @Published var updateId: UUID = UUID()
    
    private var cancellables = Set<AnyCancellable>()
    
    init(cryptocurrency: Crypto) {
        self.id = cryptocurrency.id
        self.symbol = cryptocurrency.symbol
        self.name = cryptocurrency.name
        self.image = cryptocurrency.image
        self.currentPrice = cryptocurrency.currentPrice
        self.priceChangePercentage24h = cryptocurrency.priceChangePercentage24h
    }
    
    func updatePriceData(with cryptocurrency: Crypto) -> Bool {
        guard self.id == cryptocurrency.id else { return false }
        
        let oldPrice = currentPrice
        let oldChange = priceChangePercentage24h
        
        let priceChanged = !oldPrice.isApproximatelyEqual(to: cryptocurrency.currentPrice, tolerance: 0.001)
        let percentageChanged: Bool
        
        if let oldChange = oldChange, let newChange = cryptocurrency.priceChangePercentage24h {
            percentageChanged = !oldChange.isApproximatelyEqual(to: newChange, tolerance: 0.001)
        } else {
            percentageChanged = (oldChange != nil) != (cryptocurrency.priceChangePercentage24h != nil)
        }
        
        guard priceChanged || percentageChanged else {
            return false
        }
        
        startShimmerAnimation()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.UI.shimmerDelay) {
            self.currentPrice = cryptocurrency.currentPrice
            self.priceChangePercentage24h = cryptocurrency.priceChangePercentage24h
            self.updateId = UUID()
            self.stopShimmerAnimation()
        }
        
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
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.UI.shimmerStopDelay) {
            self.isUpdating = false
        }
    }
    
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Constants.Currency.code
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
    
    static func == (lhs: CryptoCellViewModel, rhs: CryptoCellViewModel) -> Bool {
        return lhs.id == rhs.id &&
        lhs.currentPrice == rhs.currentPrice &&
        lhs.priceChangePercentage24h == rhs.priceChangePercentage24h &&
        lhs.isUpdating == rhs.isUpdating
    }
}
