//
//  Extensions.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/23.
//

import Foundation
import SwiftUI


extension Double {
    
    var formattedCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Constants.Currency.code
        formatter.maximumFractionDigits = self < 1 ? 6 : 2
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
    
    var formattedChartPrice: String {
        if self >= 1000000 {
            return String(format: "$%.1fM", self/1000000)
        } else if self >= 1000 {
            return String(format: "$%.1fK", self/1000)
        } else if self >= 1 {
            return String(format: "$%.2f", self)
        } else {
            return String(format: "$%.6f", self)
        }
    }
    
    func isApproximatelyEqual(to other: Double, tolerance: Double = 0.0001) -> Bool {
        return abs(self - other) <= tolerance
    }
}

extension View {
    func shimmering(isActive: Bool, duration: Double = 1.0) -> some View {
        self.modifier(ShimmerEffect(isActive: isActive, duration: duration))
    }
}
