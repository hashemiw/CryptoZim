//
//  ImageCache.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/23.
//

import Foundation
import SwiftUI


actor ImageCache {
    static let shared = ImageCache()
    
    private var cache: [String: Image] = [:]
    private let maxSize = 100
    
    private init() {}
    
    func get(forKey key: String) -> Image? {
        return cache[key]
    }
    
    func set(_ image: Image, forKey key: String) {
        if cache.count >= maxSize {
            if let firstKey = cache.keys.first {
                cache.removeValue(forKey: firstKey)
            }
        }
        cache[key] = image
    }
    
    func clear() {
        cache.removeAll()
    }
}

