//
//  CachedAsyncImage.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/22.
//

import SwiftUI

struct ImageHandler: View {
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
            Task {
                await loadImage()
            }
        }
    }
    
    private func loadImage() async {
        guard let url = url, image == nil else { return }
        
        if let cachedImage = await ImageCache.shared.get(forKey: url.absoluteString) {
            await MainActor.run {
                self.image = cachedImage
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                let image = Image(uiImage: uiImage)
                
                await ImageCache.shared.set(image, forKey: url.absoluteString)
                
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
