//
//  AppStoreDetector.swift
//  Gaze
//
//  Created by Mike Freno on 1/10/26.
//

import Foundation

enum AppStoreDetector {
    /// Returns true if the app was downloaded from the Mac App Store
    static var isAppStoreVersion: Bool {
        #if DEBUG
            return false
        #else
            guard let receiptURL = Bundle.main.appStoreReceiptURL else {
                return false
            }

            // Check if receipt exists and is in the expected App Store location
            let fileManager = FileManager.default
            let receiptExists = fileManager.fileExists(atPath: receiptURL.path)
            let isInMASReceipt = receiptURL.path.contains("_MASReceipt")

            return receiptExists && isInMASReceipt
        #endif
    }
}
