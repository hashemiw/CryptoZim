//
//  NetworkServiceProtocol.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/23.
//

import Foundation


protocol NetworkServiceProtocol {
    func fetchCryptocurrencies() async throws -> [Crypto]
}
