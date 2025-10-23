//
//  NetworkError.swift
//  Crypto-test
//
//  Created by Alireza Hashemi on 2025/10/23.
//

import Foundation


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

extension NetworkError: Equatable {
    static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
            case (.invalidURL, .invalidURL):
                return true
            case (.invalidResponse, .invalidResponse):
                return true
            case (.decodingError, .decodingError):
                return true
            case (.rateLimitExceeded, .rateLimitExceeded):
                return true
            case (.serverError(let lhsCode), .serverError(let rhsCode)):
                return lhsCode == rhsCode
            default:
                return false
        }
    }
}

