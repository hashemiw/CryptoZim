//
//  SwiftDataServiceProtocol.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/22.
//

import Foundation

protocol DBProtocol {
    func saveOrUpdateCryptocurrencies(_ cryptocurrencies: [Crypto]) async
    func getAllCryptocurrencies() async -> [Crypto]
    func getCryptocurrency(by id: String) async -> Crypto?
    func savePriceHistory(_ crypto: Crypto) async
    func getPriceHistory(for cryptoId: String, hours: Int) async -> [PriceHistory]
    func getLatestPrices() async -> [Crypto]
}

