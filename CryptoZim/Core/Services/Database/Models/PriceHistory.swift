//
//  PriceHistory.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/23.
//

import Foundation
import SwiftData

@Model
class PriceHistory {
    var cryptoId: String
    var price: Double
    var priceChangePercentage: Double?
    var timestamp: Date
    
    init(cryptoId: String, price: Double, priceChangePercentage: Double?, timestamp: Date = Date()) {
        self.cryptoId = cryptoId
        self.price = price
        self.priceChangePercentage = priceChangePercentage
        self.timestamp = timestamp
    }
}

