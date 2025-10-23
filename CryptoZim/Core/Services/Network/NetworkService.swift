//
//  NetworkService.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/21.
//

import Foundation
import Combine

class NetworkService: NetworkServiceProtocol {
    private let baseURL = Constants.API.baseURL
    
    nonisolated init() { }
    
    func fetchCryptocurrencies() async throws -> [Crypto] {
        guard var urlComponents = URLComponents(string: baseURL) else {
            throw NetworkError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "vs_currency", value: Constants.API.vsCurrency),
            URLQueryItem(name: "order", value: Constants.API.order),
            URLQueryItem(name: "per_page", value: Constants.API.perPage),
            URLQueryItem(name: "page", value: Constants.API.page),
            URLQueryItem(name: "sparkline", value: Constants.API.sparkline),
            URLQueryItem(name: "price_change_percentage", value: Constants.API.priceChangeKey)
        ]
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = Constants.API.timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if httpResponse.statusCode == 429 {
            throw NetworkError.rateLimitExceeded
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }
        
        do {
            let cryptocurrencies = try JSONDecoder().decode([Crypto].self, from: data)
            
            
            return cryptocurrencies
        } catch {
            throw NetworkError.decodingError
        }
    }
}
