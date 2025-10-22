//
//  CryptoListView.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/21.
//

import SwiftUI

struct CryptoListView: View {
    @StateObject private var viewModel = CryptoListViewModel()
    @State private var hasAppeared = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main content
                VStack(spacing: 0) {
                    headerView
                    searchField
                    
                    if viewModel.isLoading {
                        loadingView
                    } else {
                        cryptoList
                    }
                }
                
                // Rate limit banner (floating at top)
                if let rateLimitInfo = viewModel.rateLimitInfo {
                    rateLimitBanner(rateLimitInfo)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                print("📱 ListView appeared")
                if !hasAppeared {
                    hasAppeared = true
                    viewModel.resumeUpdates()
                } else {
                    // When coming back from detail view
                    viewModel.resumeUpdates()
                }
            }
            .onDisappear {
                print("📱 ListView disappeared")
                // Only pause if we're actually leaving the list view entirely
                // Not when just navigating to detail view
            }
        }
        .task {
            await viewModel.fetchInitialData()
        }
    
}

private var headerView: some View {
    HStack {
        Text("Cryptocurrencies")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            // Live indicator on the right side
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.rateLimitInfo == nil ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                
                Text(viewModel.rateLimitInfo == nil ? "LIVE" : "PAUSED")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(viewModel.rateLimitInfo == nil ? .green : .orange)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private func rateLimitBanner(_ info: CryptoListViewModel.RateLimitInfo) -> some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rate Limit Reached")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)
                    
                    Text(info.message)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Countdown circle
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                        .frame(width: 30, height: 30)
                    
                    Text("\(info.secondsRemaining)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top, 8)
            
            Spacer()
        }
    }
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
            
            TextField("Search cryptocurrencies", text: $viewModel.searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16))
            
            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading prices...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var cryptoList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(viewModel.filteredCellViewModels) { cellViewModel in
                    // Make sure you're using the shared instance
                    // In CryptoListView - make sure you're passing the existing viewModel instance
                    NavigationLink(
                        destination: CryptoDetailView(
                            cryptoId: cellViewModel.id,
                            listViewModel: viewModel // Pass the same instance
                        )
                    ) {
                        CryptoListRow(viewModel: cellViewModel)
                            .padding(.horizontal, 16)
                            .background(Color(.systemBackground))
                    }
                    
                    Divider()
                        .padding(.leading, 16)
                }
            }
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
}


private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .medium
    formatter.dateStyle = .none
    return formatter
}()


// Views/CryptoListRow.swift
// Views/CryptoListRow.swift
import SwiftUI

struct CryptoListRow: View {
    @StateObject var viewModel: CryptoCellViewModel
    
    init(viewModel: CryptoCellViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Cached crypto icon
            cachedCryptoIcon
            
            // Static name and symbol
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(viewModel.symbol.uppercased())
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Dynamic price data
            priceSection
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(
            viewModel.isUpdating ?
            Color.gray.opacity(0.1) :
            Color.clear
        )
        .animation(.easeInOut(duration: 0.3), value: viewModel.isUpdating)
        .id(viewModel.updateId) // Force SwiftUI to recreate the view when updateId changes
    }
    
    // Cached icon that loads once and reuses
    private var cachedCryptoIcon: some View {
        CachedAsyncImage(
            url: URL(string: viewModel.image),
            placeholder: Image(systemName: "dollarsign.circle")
        )
        .frame(width: 36, height: 36)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
    
    // Dynamic price section
    private var priceSection: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                if viewModel.showPriceShimmer {
                    // Shimmer placeholder
                    Text("$00,000.00")
                        .font(.system(size: 16, weight: .semibold))
                        .monospacedDigit()
                        .redacted(reason: .placeholder)
                        .shimmering(isActive: true)
                } else {
                    Text(viewModel.formattedPrice)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .monospacedDigit()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                if viewModel.isUpdating {
                    Circle()
                        .fill(viewModel.priceChangeColor)
                        .frame(width: 6, height: 6)
                }
            }
            
            if let change = viewModel.priceChangePercentage24h {
                if viewModel.showPercentageShimmer {
                    // Shimmer placeholder for percentage
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                        Text("+0.00%")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .redacted(reason: .placeholder)
                    .shimmering(isActive: true)
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: viewModel.priceChangeArrow)
                            .font(.system(size: 10, weight: .bold))
                        
                        Text(viewModel.formattedPriceChange)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(viewModel.priceChangeColor)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
        }
        .contentShape(Rectangle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showPriceShimmer)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showPercentageShimmer)
    }
}

// Views/ShimmerModifier.swift
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
                            colors: [
                                .clear,
                                .white.opacity(0.4),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .offset(x: isInitialLoad ? -1 : 1)
                        .mask(content)
                    }
                }
            )
            .onAppear {
                // Small delay for initial load to avoid immediate shimmer
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInitialLoad = false
                }
            }
            .onChange(of: isActive) { newValue in
                if newValue {
                    // Reset animation when activated
                    isInitialLoad = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isInitialLoad = false
                    }
                }
            }
    }
}

extension View {
    func shimmering(isActive: Bool, duration: Double = 1.0) -> some View {
        self.modifier(ShimmerEffect(isActive: isActive, duration: duration))
    }
}
