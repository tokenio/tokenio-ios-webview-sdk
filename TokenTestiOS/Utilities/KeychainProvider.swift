//
//  KeychainProvider.swift
//  TokenTestiOS
//
//  Created by Josh Lister on 28/05/2025.
//

import Foundation

/// Protocol defining the interface for keychain operations
protocol KeychainProvider {
    /// Retrieves the API key from the keychain
    /// - Throws: An error if the key cannot be retrieved
    /// - Returns: The API key as a string
    func getApiKey() throws -> String
}

/// Default implementation of KeychainProvider that uses the KeychainHelper
class DefaultKeychainProvider: KeychainProvider {
    func getApiKey() throws -> String {
        return try KeychainHelper.getApiKey()
    }
}
