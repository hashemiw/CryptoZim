//
//  CryptoService.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/21.
//

// Services/NetworkService.swift
// Services/NetworkService.swift
import Foundation
import Combine

protocol NetworkServiceProtocol {
    func fetchCryptocurrencies() async throws -> [CryptoCurrency]
}

// In NetworkService - add better error handling
class NetworkService: NetworkServiceProtocol {
    private let baseURL = "https://api.coingecko.com/api/v3/coins/markets"
    
    // Track request count for rate limit awareness
    private var requestCount = 0
    private let maxRequestsPerMinute = 5
    
    nonisolated init() { }
    
    func fetchCryptocurrencies() async throws -> [CryptoCurrency] {
        requestCount += 1
        
        // Basic client-side rate limiting awareness
        if requestCount >= maxRequestsPerMinute {
            print("⚠️ Approaching rate limit: \(requestCount) requests")
        }
        
        guard var urlComponents = URLComponents(string: baseURL) else {
            throw NetworkError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "order", value: "market_cap_desc"),
            URLQueryItem(name: "per_page", value: "30"), // Reduced for safety
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "sparkline", value: "false"),
            URLQueryItem(name: "price_change_percentage", value: "24h")
        ]
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        // Handle rate limiting
        if httpResponse.statusCode == 429 {
            // Reset counter on rate limit
            requestCount = 0
            throw NetworkError.rateLimitExceeded
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }
        
        do {
            let cryptocurrencies = try JSONDecoder().decode([CryptoCurrency].self, from: data)
            
            // Reset counter on successful request
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                self.requestCount = max(0, self.requestCount - 1)
            }
            
            return cryptocurrencies
        } catch {
            throw NetworkError.decodingError
        }
    }
}
// Add these new models for rate limit handling
struct RateLimitResponse: Codable {
    let status: RateLimitStatus
}

struct RateLimitStatus: Codable {
    let errorCode: Int
    let errorMessage: String
    
    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case errorMessage = "error_message"
    }
}

// Updated NetworkError enum
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    case rateLimitExceeded
    case serverError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError:
            return "Failed to decode data"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please wait a moment."
        case .serverError(let statusCode):
            return "Server error: \(statusCode)"
        }
    }
}
