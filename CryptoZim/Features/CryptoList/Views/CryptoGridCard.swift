//
//  CryptoGridCard.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/23.
//

import Foundation
import SwiftUI

struct CryptoGridCard: View {
    @ObservedObject var viewModel: CryptoCellViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    cachedCryptoIcon
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(viewModel.symbol.uppercased())
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .frame(minHeight: 36)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if viewModel.showPriceShimmer {
                    Text("$00,000.00")
                        .font(.system(size: 20, weight: .bold))
                        .monospacedDigit()
                        .redacted(reason: .placeholder)
                        .shimmering(isActive: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(viewModel.formattedPrice)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                if viewModel.priceChangePercentage24h != nil {
                    HStack(spacing: 4) {
                        if viewModel.showPercentageShimmer {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .bold))
                                Text("+0.00%")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .redacted(reason: .placeholder)
                            .shimmering(isActive: true)
                        } else {
                            Image(systemName: viewModel.priceChangeArrow)
                                .font(.system(size: 10, weight: .bold))
                            
                            Text(viewModel.formattedPriceChange)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .foregroundColor(viewModel.priceChangeColor)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                
                if viewModel.isUpdating {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(viewModel.priceChangeColor)
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
        .padding(12)
        .frame(height: 130)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .background(
            viewModel.isUpdating ?
            Color.gray.opacity(0.05) :
                Color.clear
        )
        .animation(.easeInOut(duration: 0.3), value: viewModel.isUpdating)
        .id(viewModel.updateId)
    }
    
    private var cachedCryptoIcon: some View {
        ImageHandler(
            url: URL(string: viewModel.image),
            placeholder: Image(systemName: "dollarsign.circle")
        )
        .frame(width: 28, height: 28)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}
