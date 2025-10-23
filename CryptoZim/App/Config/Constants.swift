//
//  Constants.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/23.
//

import Foundation
import SwiftUI

enum Constants {
    
    enum DB {
        
        static let priceTolerance: Double = 0.001
        static let cleanupInterval: TimeInterval = -24 * 60 * 60
    }
    
    enum API {
        static let baseURL = "https://api.coingecko.com/api/v3/coins/markets"
        static let vsCurrency = "usd"
        static let order = "market_cap_desc"
        static let perPage = "30"
        static let page = "1"
        static let sparkline = "false"
        static let priceChangeKey = "24h"
        static let rateLimitRetryInterval: TimeInterval = 60.0
        
        static let timeoutInterval: TimeInterval = 10
        static let maxRequestsPerMinute = 5
    }
    
    enum Currency {
        static let code = "USD"
        static let symbol = "$"
    }
    
    enum UI {
        static let shimmerDuration: Double = 1.0
        static let shimmerDelay: Double = 0.3
        static let shimmerStopDelay: Double = 0.6
    }
    
    enum Refresh {
        static let autoRefreshInterval: TimeInterval = 12.0
    }
    
    enum DetailView {
        static let defaultNavigationTitle = "Crypto Details"
        static let chartHeight: CGFloat = 220
        static let statCardCornerRadius: CGFloat = 16
        static let statCardShadowOpacity: Double = 0.05
        static let defaultCurrencyCode = "USD"
        static let placeholderPrice = "$0.00"
    }
    
    enum ListView {
        static let title = "Cryptocurrencies"
        static let searchPlaceholder = "Search cryptocurrencies"
        static let gridSpacing: CGFloat = 12
        static let liveStatus = "LIVE"
        static let pausedStatus = "PAUSED"
        static let loadingText = "Loading prices..."
    }
    
    enum Shimmer {
        static let delay: TimeInterval = 0.1
        static let gradientColors: [Color] = [
            .clear,
            .white.opacity(0.4),
            .clear
        ]
    }
}
