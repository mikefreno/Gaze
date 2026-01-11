//
//  UpdateManager.swift
//  Gaze
//
//  Created by Mike Freno on 1/11/26.
//

import Combine
import Foundation
import Sparkle

@MainActor
class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()
    
    private var updaterController: SPUStandardUpdaterController?
    private var automaticallyChecksObservation: NSKeyValueObservation?
    private var lastCheckDateObservation: NSKeyValueObservation?
    
    @Published var automaticallyChecksForUpdates = false
    @Published var lastUpdateCheckDate: Date?
    
    private override init() {
        super.init()
        setupUpdater()
    }
    
    private func setupUpdater() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        guard let updater = updaterController?.updater else {
            print("Failed to initialize Sparkle updater")
            return
        }
        
        automaticallyChecksObservation = updater.observe(
            \.automaticallyChecksForUpdates,
            options: [.new, .initial]
        ) { [weak self] _, change in
            guard let self = self, let newValue = change.newValue else { return }
            Task { @MainActor in
                self.automaticallyChecksForUpdates = newValue
            }
        }
        
        lastCheckDateObservation = updater.observe(
            \.lastUpdateCheckDate,
            options: [.new, .initial]
        ) { [weak self] _, change in
            guard let self = self else { return }
            Task { @MainActor in
                self.lastUpdateCheckDate = change.newValue ?? nil
            }
        }
    }
    
    func checkForUpdates() {
        guard let updater = updaterController?.updater else {
            print("Updater not initialized")
            return
        }
        updater.checkForUpdates()
    }
    
    deinit {
        automaticallyChecksObservation?.invalidate()
        lastCheckDateObservation?.invalidate()
    }
}
