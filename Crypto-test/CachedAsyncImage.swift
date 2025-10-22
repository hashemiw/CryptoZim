//
//  CachedAsyncImage.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/22.
//

// Views/CachedAsyncImage.swift
import SwiftUI

struct CachedAsyncImage: View {
    let url: URL?
    let placeholder: Image
    
    @State private var image: Image?
    @State private var isLoading = false
    
    init(url: URL?, placeholder: Image = Image(systemName: "dollarsign.circle")) {
        self.url = url
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                image
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                placeholder
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray.opacity(0.4))
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url, image == nil else { return }
        
        // Check memory cache first
        if let cachedImage = ImageCache.shared.get(forKey: url.absoluteString) {
            self.image = cachedImage
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    let image = Image(uiImage: uiImage)
                    
                    // Cache the image
                    ImageCache.shared.set(image, forKey: url.absoluteString)
                    
                    await MainActor.run {
                        self.image = image
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// Image Cache Manager
actor ImageCache {
    static let shared = ImageCache()
    
    private var cache: [String: Image] = [:]
    private let maxSize = 100 // Maximum number of images to cache
    
    private init() {}
    
    func get(forKey key: String) -> Image? {
        return cache[key]
    }
    
    func set(_ image: Image, forKey key: String) {
        // Simple LRU cache implementation
        if cache.count >= maxSize {
            // Remove first item (oldest)
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

