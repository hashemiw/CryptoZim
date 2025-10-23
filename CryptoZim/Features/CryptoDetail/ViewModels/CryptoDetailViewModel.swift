//
//  CryptoDetailViewModel.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/23.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class CryptoDetailViewModel: ObservableObject {
    @Published var cryptocurrency: Crypto
    
    init(cryptocurrency: Crypto) {
        self.cryptocurrency = cryptocurrency
    }
    
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Constants.Currency.code
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
