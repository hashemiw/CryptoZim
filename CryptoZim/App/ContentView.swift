//
//  ContentView.swift
//  CryptoZim
//
//  Created by Alireza Hashemi on 2025/10/24.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: CryptoListViewModel
    
    var body: some View {
        CryptoListView()
            .environmentObject(viewModel)
            .onAppear {
                print("App started")
            }
    }
}
