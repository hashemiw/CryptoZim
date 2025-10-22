//
//  Crypto_testApp.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/21.
//

import SwiftUI

// In your App file - Use this approach instead
@main
struct Crypto_testApp: App {
    @StateObject private var listViewModel = CryptoListViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(listViewModel)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var viewModel: CryptoListViewModel
    
    var body: some View {
        CryptoListView()
            .environmentObject(viewModel)
            .onAppear {
                print("🚀 App started")
            }
    }
}
