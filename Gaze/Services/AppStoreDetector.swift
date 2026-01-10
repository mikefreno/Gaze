//
//  AppStoreDetector.swift
//  Gaze
//
//  Created by Mike Freno on 1/10/26.
//

import Foundation

enum AppStoreDetector {
    /// Returns true if the app was downloaded from the Mac App Store
    ///
    /// Uses a heuristic approach that checks for the presence of a valid App Store receipt.
    /// This is sufficient for distinguishing App Store builds from direct distribution.
    ///
    /// Note: This does not perform full cryptographic validation of the receipt signature, its
    /// only used to determine if we should show the 'buy me a coffee' link.
    static var isAppStoreVersion: Bool {
        #if DEBUG
            return false
        #else
            guard let receiptURL = Bundle.main.appStoreReceiptURL else {
                return false
            }

            guard FileManager.default.fileExists(atPath: receiptURL.path) else {
                return false
            }

            guard let receiptData = try? Data(contentsOf: receiptURL),
                receiptData.count > 2
            else {
                return false
            }

            // Verify receipt has PKCS#7 signature format (starts with ASN.1 SEQUENCE tag)
            let bytes = [UInt8](receiptData.prefix(2))
            return bytes[0] == 0x30 && bytes[1] == 0x82
        #endif
    }

    /// Checks if the app is running in TestFlight
    ///
    /// TestFlight builds have a receipt named "sandboxReceipt" instead of "receipt"
    static var isTestFlight: Bool {
        #if DEBUG
            return false
        #else
            return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }
}
