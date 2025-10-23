//
//  ShimmerEffect.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/23.
//

import Foundation
import SwiftUI


struct ShimmerEffect: ViewModifier {
    @State private var isInitialLoad = true
    let isActive: Bool
    let duration: Double
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isActive {
                        LinearGradient(
                            colors: Constants.Shimmer.gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .offset(x: isInitialLoad ? -1 : 1)
                        .mask(content)
                    }
                }
            )
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Shimmer.delay) {
                    isInitialLoad = false
                }
            }
            .onChange(of: isActive) { oldValue, newValue in
                if newValue {
                    isInitialLoad = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Shimmer.delay) {
                        isInitialLoad = false
                    }
                }
            }
    }
}
