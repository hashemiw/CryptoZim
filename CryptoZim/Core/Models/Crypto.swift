//
//  Crypto.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/21.
//

import Foundation

struct Crypto: Codable, Identifiable, Equatable {
    let id: String
    let symbol: String
    let name: String
    let image: String
    let currentPrice: Double
    let priceChangePercentage24h: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, symbol, name, image
        case currentPrice = "current_price"
        case priceChangePercentage24h = "price_change_percentage_24h"
    }
    
    static func == (lhs: Crypto, rhs: Crypto) -> Bool {
        lhs.id == rhs.id
    }
}
