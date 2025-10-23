//
//  CryptoData.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/22.
//

import Foundation
import SwiftData


@Model
class CryptoData {
    var id: String
    var symbol: String
    var name: String
    var image: String
    var currentPrice: Double
    var priceChangePercentage24h: Double?
    var lastUpdated: Date
    
    @Relationship(deleteRule: .cascade)
    var priceHistory: [PriceHistory] = []
    
    init(id: String, symbol: String, name: String, image: String, currentPrice: Double, priceChangePercentage24h: Double?, lastUpdated: Date = Date()) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.image = image
        self.currentPrice = currentPrice
        self.priceChangePercentage24h = priceChangePercentage24h
        self.lastUpdated = lastUpdated
    }
    
    convenience init(from crypto: Crypto) {
        self.init(
            id: crypto.id,
            symbol: crypto.symbol,
            name: crypto.name,
            image: crypto.image,
            currentPrice: crypto.currentPrice,
            priceChangePercentage24h: crypto.priceChangePercentage24h
        )
    }
}
