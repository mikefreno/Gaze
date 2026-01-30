//
//  IdleMonitoringService.swift
//  Gaze
//
//  Created by Mike Freno on 1/14/26.
//

import AppKit
import Combine
import Foundation

class IdleMonitoringService: ObservableObject {
    @Published private(set) var isIdle = false
    @Published private(set) var idleTimeSeconds: TimeInterval = 0
    
    private var timer: Timer?
    private var idleThresholdSeconds: TimeInterval
    
    init(idleThresholdMinutes: Int = 5) {
        self.idleThresholdSeconds = TimeInterval(idleThresholdMinutes * 60)
        startMonitoring()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func updateThreshold(minutes: Int) {
        idleThresholdSeconds = TimeInterval(minutes * 60)
        checkIdleState()
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.checkIdleState()
        }
    }
    
    private func checkIdleState() {
        idleTimeSeconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .mouseMoved
        )
        
        // Also check keyboard events and use the minimum
        let keyboardIdleTime = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .keyDown
        )
        
        idleTimeSeconds = min(idleTimeSeconds, keyboardIdleTime)
        
        let wasIdle = isIdle
        isIdle = idleTimeSeconds >= idleThresholdSeconds
        
        if wasIdle != isIdle {
            print("🔄 Idle state changed: \(isIdle ? "IDLE" : "ACTIVE") (idle: \(Int(idleTimeSeconds))s, threshold: \(Int(idleThresholdSeconds))s)")
        }
    }
    
    func forceUpdate() {
        checkIdleState()
    }
}

struct UsageStatistics: Codable {
    var totalActiveSeconds: TimeInterval
    var totalIdleSeconds: TimeInterval
    var lastResetDate: Date
    var sessionStartDate: Date

    var totalActiveMinutes: Int {
        Int(totalActiveSeconds / 60)
    }

    var totalIdleMinutes: Int {
        Int(totalIdleSeconds / 60)
    }
}

class UsageTrackingService: ObservableObject {
    @Published private(set) var statistics: UsageStatistics

    private var lastUpdateTime: Date
    private var wasIdle: Bool = false
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    private let statisticsKey = "gazeUsageStatistics"
    private var resetThresholdMinutes: Int

    private var idleService: IdleMonitoringService?

    init(resetThresholdMinutes: Int = 60) {
        self.resetThresholdMinutes = resetThresholdMinutes
        self.lastUpdateTime = Date()

        if let data = userDefaults.data(forKey: statisticsKey),
           let decoded = try? JSONDecoder().decode(UsageStatistics.self, from: data) {
            self.statistics = decoded
        } else {
            self.statistics = UsageStatistics(
                totalActiveSeconds: 0,
                totalIdleSeconds: 0,
                lastResetDate: Date(),
                sessionStartDate: Date()
            )
        }

        checkForReset()
        startTracking()
    }

    func setupIdleMonitoring(_ idleService: IdleMonitoringService) {
        self.idleService = idleService

        idleService.$isIdle
            .sink { [weak self] isIdle in
                self?.updateTracking(isIdle: isIdle)
            }
            .store(in: &cancellables)
    }

    func updateResetThreshold(minutes: Int) {
        resetThresholdMinutes = minutes
        checkForReset()
    }

    private func startTracking() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.tick()
        }
    }

    private func tick() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = now

        let isCurrentlyIdle = idleService?.isIdle ?? false

        if isCurrentlyIdle {
            statistics.totalIdleSeconds += elapsed
        } else {
            statistics.totalActiveSeconds += elapsed
        }

        wasIdle = isCurrentlyIdle

        checkForReset()
        save()
    }

    private func updateTracking(isIdle: Bool) {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastUpdateTime)

        if wasIdle {
            statistics.totalIdleSeconds += elapsed
        } else {
            statistics.totalActiveSeconds += elapsed
        }

        lastUpdateTime = now
        wasIdle = isIdle
        save()
    }

    private func checkForReset() {
        let totalMinutes = statistics.totalActiveMinutes + statistics.totalIdleMinutes

        if totalMinutes >= resetThresholdMinutes {
            reset()
            print("♻️ Usage statistics reset after \(totalMinutes) minutes (threshold: \(resetThresholdMinutes))")
        }
    }

    func reset() {
        statistics = UsageStatistics(
            totalActiveSeconds: 0,
            totalIdleSeconds: 0,
            lastResetDate: Date(),
            sessionStartDate: Date()
        )
        lastUpdateTime = Date()
        save()
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(statistics) {
            userDefaults.set(encoded, forKey: statisticsKey)
        }
    }

    func getFormattedActiveTime() -> String {
        formatDuration(seconds: Int(statistics.totalActiveSeconds))
    }

    func getFormattedIdleTime() -> String {
        formatDuration(seconds: Int(statistics.totalIdleSeconds))
    }

    func getFormattedTotalTime() -> String {
        let total = Int(statistics.totalActiveSeconds + statistics.totalIdleSeconds)
        return formatDuration(seconds: total)
    }

    private func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, secs)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
}
