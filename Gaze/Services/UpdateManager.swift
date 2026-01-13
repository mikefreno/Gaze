//
//  UpdateManager.swift
//  Gaze
//
//  Created by Mike Freno on 1/11/26.
//

import Combine
import Foundation

#if !APPSTORE
    import Sparkle
#endif

@MainActor
class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()

    #if !APPSTORE
        private var updaterController: SPUStandardUpdaterController?
        private var automaticallyChecksObservation: NSKeyValueObservation?
        private var lastCheckDateObservation: NSKeyValueObservation?
    #endif

    @Published var automaticallyChecksForUpdates = false
    @Published var lastUpdateCheckDate: Date?

    private override init() {
        super.init()
        #if !APPSTORE
            setupUpdater()
        #endif
    }

    #if !APPSTORE
        private func setupUpdater() {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )

            guard let updater = updaterController?.updater else {
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
    #endif

    func checkForUpdates() {
        #if !APPSTORE
            guard let updater = updaterController?.updater else {
                return
            }
            updater.checkForUpdates()
        #else
        #endif
    }

    deinit {
        #if !APPSTORE
            automaticallyChecksObservation?.invalidate()
            lastCheckDateObservation?.invalidate()
        #endif
    }
}
