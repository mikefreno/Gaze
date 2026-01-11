import Foundation

protocol Migration {
    var targetVersion: String { get }
    func migrate(_ data: [String: Any]) throws -> [String: Any]
}

enum MigrationError: Error, LocalizedError {
    case migrationFailed(String)
    case invalidDataStructure
    case versionMismatch
    case noBackupAvailable
    
    var errorDescription: String? {
        switch self {
        case .migrationFailed(let message):
            return "Migration failed: \(message)"
        case .invalidDataStructure:
            return "Invalid data structure for migration"
        case .versionMismatch:
            return "Version mismatch during migration"
        case .noBackupAvailable:
            return "No backup data available for restoration"
        }
    }
}

class MigrationManager {
    private let userDefaults = UserDefaults.standard
    private var migrations: [Migration] = []
    private let versionKey = "app_version"
    private let settingsKey = "gazeAppSettings"
    private let backupKey = "gazeAppSettings_backup"
    
    init() {
        setupMigrations()
    }
    
    func getCurrentVersion() -> String {
        return userDefaults.string(forKey: versionKey) ?? "0.0.0"
    }
    
    func setCurrentVersion(_ version: String) {
        userDefaults.set(version, forKey: versionKey)
    }
    
    func migrateSettingsIfNeeded() throws -> [String: Any]? {
        let currentVersion = getCurrentVersion()
        let targetVersion = getTargetVersion()
        
        if isUpToDate(currentVersion: currentVersion, targetVersion: targetVersion) {
            return loadSettingsFromDefaults()
        }
        
        guard let data = userDefaults.data(forKey: settingsKey) else {
            return nil
        }
        
        guard let settingsData = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MigrationError.invalidDataStructure
        }
        
        saveBackup(settingsData)
        
        var migratedData = settingsData
        
        for migration in migrations {
            if shouldMigrate(from: currentVersion, to: migration.targetVersion) {
                do {
                    migratedData = try migration.migrate(migratedData)
                } catch {
                    try restoreFromBackup()
                    throw MigrationError.migrationFailed("Migration to \(migration.targetVersion) failed: \(error.localizedDescription)")
                }
            }
        }
        
        setCurrentVersion(targetVersion)
        clearBackup()
        
        return migratedData
    }
    
    private func setupMigrations() {
        migrations.append(Version101Migration())
        migrations.append(Version102Migration())
    }
    
    private func getTargetVersion() -> String {
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            return version
        }
        return "1.0.0"
    }
    
    private func isUpToDate(currentVersion: String, targetVersion: String) -> Bool {
        return compareVersions(currentVersion, targetVersion) >= 0
    }
    
    private func shouldMigrate(from currentVersion: String, to targetVersion: String) -> Bool {
        return compareVersions(currentVersion, targetVersion) < 0
    }
    
    private func compareVersions(_ version1: String, _ version2: String) -> Int {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxLength {
            let v1 = i < v1Components.count ? v1Components[i] : 0
            let v2 = i < v2Components.count ? v2Components[i] : 0
            
            if v1 > v2 {
                return 1
            } else if v1 < v2 {
                return -1
            }
        }
        
        return 0
    }
    
    private func loadSettingsFromDefaults() -> [String: Any]? {
        guard let data = userDefaults.data(forKey: settingsKey),
              let settingsDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return settingsDict
    }
    
    private func saveBackup(_ data: [String: Any]) {
        guard let backupData = try? JSONSerialization.data(withJSONObject: data) else {
            print("Failed to create backup")
            return
        }
        userDefaults.set(backupData, forKey: backupKey)
    }
    
    private func restoreFromBackup() throws {
        guard let backupData = userDefaults.data(forKey: backupKey) else {
            throw MigrationError.noBackupAvailable
        }
        
        guard let backupDict = try? JSONSerialization.jsonObject(with: backupData) as? [String: Any],
              let finalData = try? JSONSerialization.data(withJSONObject: backupDict) else {
            throw MigrationError.migrationFailed("Failed to restore from backup")
        }
        
        userDefaults.set(finalData, forKey: settingsKey)
        clearBackup()
    }
    
    private func clearBackup() {
        userDefaults.removeObject(forKey: backupKey)
    }
}

class Version101Migration: Migration {
    var targetVersion: String = "1.0.1"
    
    func migrate(_ data: [String: Any]) throws -> [String: Any] {
        let migratedData = data
        
        // Example migration logic:
        // Add any new fields with default values if they don't exist
        // Transform data structures as needed
        
        return migratedData
    }
}

class Version102Migration: Migration {
    var targetVersion: String = "1.0.2"
    
    func migrate(_ data: [String: Any]) throws -> [String: Any] {
        var migratedData = data
        
        // Migrate subtleReminderSizePercentage (Double) to subtleReminderSize (ReminderSize enum)
        if let oldPercentage = migratedData["subtleReminderSizePercentage"] as? Double {
            // Map old percentage values to new enum cases
            let reminderSize: String
            if oldPercentage <= 2.0 {
                reminderSize = "small"
            } else if oldPercentage <= 3.5 {
                reminderSize = "medium"
            } else {
                reminderSize = "large"
            }
            
            migratedData["subtleReminderSize"] = reminderSize
            migratedData.removeValue(forKey: "subtleReminderSizePercentage")
        } else if migratedData["subtleReminderSize"] == nil {
            // If neither old nor new key exists, set default
            migratedData["subtleReminderSize"] = "large"
        }
        
        return migratedData
    }
}
