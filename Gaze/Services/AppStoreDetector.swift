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
            print("🔍 AppStoreDetector: DEBUG build, returning false")
            return false
        #else
            print("🔍 AppStoreDetector: Checking App Store status...")
            if #available(macOS 15.0, *) {
                print("  ℹ️ Using macOS 15+ AppTransaction API")
                do {
                    let transaction = try await AppTransaction.shared
                    print("  ✅ AppTransaction found: This is an App Store version")
                    return true
                } catch {
                    print("  ⚠️ AppTransaction error: \(error.localizedDescription)")
                    print("  → Assuming NOT an App Store version")
                    return false
                }
            } else {
                // Fallback for older macOS: use legacy receipt check
                print("  ℹ️ Using legacy receipt check (macOS <15)")
                
                guard let receiptURL = Bundle.main.appStoreReceiptURL else {
                    print("  ⚠️ No receipt URL available")
                    return false
                }
                print("  📄 Receipt URL: \(receiptURL.path)")
                
                do {
                    let fileExists = FileManager.default.fileExists(atPath: receiptURL.path)
                    guard fileExists else {
                        print("  ⚠️ Receipt file does not exist")
                        return false
                    }
                    print("  ✓ Receipt file exists")
                    
                    guard let receiptData = try? Data(contentsOf: receiptURL),
                        receiptData.count > 2
                    else {
                        print("  ⚠️ Receipt file is empty or unreadable")
                        return false
                    }
                    print("  ✓ Receipt data loaded (\(receiptData.count) bytes)")
                    
                    let bytes = [UInt8](receiptData.prefix(2))
                    let isValid = bytes[0] == 0x30 && bytes[1] == 0x82
                    print("  \(isValid ? "✅" : "⚠️") Receipt validation: \(isValid)")
                    return isValid
                } catch {
                    print("  ❌ Receipt check error: \(error.localizedDescription)")
                    return false
                }
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
