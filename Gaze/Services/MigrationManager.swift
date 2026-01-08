import Foundation

// MARK: - Migration Protocol
protocol Migration {
    var targetVersion: String { get }
    func migrate(_ data: [String: Any]) -> [String: Any]
}

// MARK: - Migration Error
enum MigrationError: Error, LocalizedError {
    case migrationFailed(String)
    case invalidDataStructure
    case versionMismatch
    
    var errorDescription: String? {
        switch self {
        case .migrationFailed(let message):
            return "Migration failed: \(message)"
        case .invalidDataStructure:
            return "Invalid data structure for migration"
        case .versionMismatch:
            return "Version mismatch during migration"
        }
    }
}

// MARK: - Migration Manager
class MigrationManager {
    private let userDefaults = UserDefaults.standard
    private var migrations: [Migration] = []
    private let versionKey = "app_version"
    
    // MARK: - Initialization
    init() {
        setupMigrations()
    }
    
    // MARK: - Public Methods
    func getCurrentVersion() -> String {
        return userDefaults.string(forKey: versionKey) ?? "0.0.0"
    }
    
    func setCurrentVersion(_ version: String) {
        userDefaults.set(version, forKey: versionKey)
    }
    
    func migrateSettingsIfNeeded() throws -> [String: Any]? {
        let currentVersion = getCurrentVersion()
        let targetVersion = getTargetVersion()
        
        // If we're already at the latest version, return the data as is
        if isUpToDate(currentVersion: currentVersion, targetVersion: targetVersion) {
            return loadSettingsFromDefaults()
        }
        
        // Load current settings from defaults
        guard let data = userDefaults.data(forKey: "gazeAppSettings") else {
            return nil
        }
        
        do {
            guard let settingsData = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw MigrationError.invalidDataStructure
            }
            
            // Create a backup before migration
            saveBackup(settingsData)
            
            // Apply migrations sequentially
            var migratedData = settingsData
            
            for migration in migrations {
                if shouldMigrate(from: currentVersion, to: migration.targetVersion) {
                    do {
                        migratedData = try performMigration(migration, data: migratedData)
                    } catch {
                        // If a migration fails, restore from backup and rethrow
                        try restoreFromBackup()
                        throw MigrationError.migrationFailed("Migration to \(migration.targetVersion) failed")
                    }
                }
            }
            
            // Update the stored version
            setCurrentVersion(targetVersion)
            
            return migratedData
            
        } catch {
            print("Migration error occurred: \(error)")
            // If there's an error during migration, restore from backup if available
            try? restoreFromBackup()
            throw error
        }
    }
    
    // MARK: - Private Methods
    private func setupMigrations() {
        // Register your migrations here in order of execution
        migrations.append(Version101Migration())
    }
    
    private func getTargetVersion() -> String {
        // This would typically come from package.json or a config file
        // For this example, we'll hardcode it but in practice you'd fetch it dynamically
        return "1.0.1"
    }
    
    private func isUpToDate(currentVersion: String, targetVersion: String) -> Bool {
        return compareVersions(currentVersion, targetVersion) >= 0
    }
    
    private func shouldMigrate(from currentVersion: String, to targetVersion: String) -> Bool {
        return compareVersions(currentVersion, targetVersion) < 0
    }
    
    private func compareVersions(_ version1: String, _ version2: String) -> Int {
        // Simple version comparison - in a real app you'd use a proper semantic versioning library
        let v1Components = version1.split(separator: ".").map { Int($0) ?? 0 }
        let v2Components = version2.split(separator: ".").map { Int($0) ?? 0 }
        
        for (v1, v2) in zip(v1Components, v2Components) {
            if v1 > v2 {
                return 1
            } else if v1 < v2 {
                return -1
            }
        }
        
        return v1Components.count - v2Components.count
    }
    
    private func loadSettingsFromDefaults() -> [String: Any]? {
        guard let data = userDefaults.data(forKey: "gazeAppSettings") else {
            return nil
        }
        
        do {
            if let settingsDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return settingsDict
            }
        } catch {
            print("Failed to load settings from defaults: \(error)")
        }
        
        return nil
    }
    
    private func performMigration(_ migration: Migration, data: [String: Any]) throws -> [String: Any] {
        // Wrap migration in a guard clause to handle potential errors gracefully
        do {
            let result = migration.migrate(data)
            return result
        } catch {
            throw MigrationError.migrationFailed("Migration to \(migration.targetVersion) failed with error: \(error)")
        }
    }
    
    private func saveBackup(_ data: [String: Any]) {
        // Create a backup of the current settings before migration
        do {
            let backupData = try JSONSerialization.data(withJSONObject: data)
            userDefaults.set(backupData, forKey: "gazeAppSettings_backup")
        } catch {
            print("Failed to create backup: \(error)")
        }
    }
    
    private func restoreFromBackup() throws {
        // Restore settings from backup if available
        guard let backupData = userDefaults.data(forKey: "gazeAppSettings_backup") else {
            throw MigrationError.migrationFailed("No backup data available")
        }
        
        do {
            if let backupDict = try JSONSerialization.jsonObject(with: backupData) as? [String: Any] {
                // Save the backup back to the main settings key
                let finalData = try JSONSerialization.data(withJSONObject: backupDict)
                userDefaults.set(finalData, forKey: "gazeAppSettings")
                
                // Clear the backup
                userDefaults.removeObject(forKey: "gazeAppSettings_backup")
            }
        } catch {
            throw MigrationError.migrationFailed("Failed to restore from backup: \(error)")
        }
    }
}

// MARK: - Version 1.0.1 Migration
class Version101Migration: Migration {
    var targetVersion: String = "1.0.1"
    
    func migrate(_ data: [String: Any]) -> [String: Any] {
        // Example migration for version 1.0.1:
        // If there's a field that needs to be moved or renamed
        var migratedData = data
        
        // For example, if we had to add a new field or change structure
        // This is where you would implement your specific migration logic
        // For now, just return the original data as an example
        return migratedData
    }
}