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
    private let gridColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView
                searchField
                
                if viewModel.isLoading {
                    loadingView
                } else {
                    cryptoGrid
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if !hasAppeared {
                    hasAppeared = true
                    viewModel.resumeUpdates()
                } else {
                    viewModel.resumeUpdates()
                }
            }
        }
        .task {
            await viewModel.fetchInitialData()
        }
    }
}

extension CryptoListView {
    private var headerView: some View {
        HStack {
            Text(Constants.ListView.title)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.rateLimitInfo == nil ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                
                Text(viewModel.rateLimitInfo == nil ? Constants.ListView.liveStatus : Constants.ListView.pausedStatus)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(viewModel.rateLimitInfo == nil ? .green : .orange)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
            
            TextField(Constants.ListView.searchPlaceholder, text: $viewModel.searchText)
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
            
            Text(Constants.ListView.loadingText)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var cryptoGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(viewModel.filteredCellViewModels) { cellViewModel in
                    NavigationLink(
                        destination: CryptoDetailView(
                            cryptoId: cellViewModel.id,
                            listViewModel: viewModel
                        )
                    ) {
                        CryptoGridCard(viewModel: cellViewModel)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
}
