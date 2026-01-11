//
//  AppStoreDetector.swift
//  Gaze
//
//  Created by Mike Freno on 1/10/26.
//

import Foundation
import StoreKit

enum AppStoreDetector {
    /// Returns true if the app was downloaded from the Mac App Store.
    ///
    /// Uses StoreKit's AppTransaction API on macOS 15+ to verify if the app is an App Store version.
    /// Falls back to a heuristic receipt check on macOS versions prior to 15.
    ///
    /// This method is asynchronous due to the use of StoreKit's async API.
    static func isAppStoreVersion() async -> Bool {
        #if DEBUG
            return false
        #else
            if #available(macOS 15.0, *) {
                do {
                    _ = try await AppTransaction.shared
                    return true
                } catch {
                    return false
                }
            } else {
                // Fallback for older macOS: use legacy receipt check
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
                let bytes = [UInt8](receiptData.prefix(2))
                return bytes[0] == 0x30 && bytes[1] == 0x82
            }
        #endif
    }

    /// Checks if the app is running in TestFlight.
    ///
    /// On macOS 15+, StoreKit does not expose a TestFlight receipt type.
    /// This method returns false on macOS 15+ as a result.
    /// On earlier versions, it checks for the presence of a "sandboxReceipt".
    ///
    /// This method is asynchronous for API consistency.
    static func isTestFlight() async -> Bool {
        #if DEBUG
            return false
        #else
            if #available(macOS 15.0, *) {
                // StoreKit does not expose TestFlight receipt type.
                // As a workaround, fallback to legacy method if available, else return false.
                return false  // No supported TestFlight check post-macOS 15
            } else {
                return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
            }
        #endif
    }
}
