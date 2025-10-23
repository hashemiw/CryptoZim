//
//  CryptoZim.swift
//  CryptoZim
//
//  Created by Alireza Hashemi on 2025/10/21.
//

import SwiftUI

@main
struct CryptoZim: App {
    @StateObject private var listViewModel = CryptoListViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(listViewModel)
        }
    }
}
