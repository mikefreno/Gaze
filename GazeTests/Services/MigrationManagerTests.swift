//
//  MigrationManagerTests.swift
//  GazeTests
//
//  Created by Mike Freno on 1/8/26.
//

import XCTest
@testable import Gaze

final class MigrationManagerTests: XCTestCase {
    
    var migrationManager: MigrationManager!
    
    override func setUp() {
        super.setUp()
        migrationManager = MigrationManager()
        UserDefaults.standard.removeObject(forKey: "app_version")
        UserDefaults.standard.removeObject(forKey: "gazeAppSettings")
        UserDefaults.standard.removeObject(forKey: "gazeAppSettings_backup")
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "app_version")
        UserDefaults.standard.removeObject(forKey: "gazeAppSettings")
        UserDefaults.standard.removeObject(forKey: "gazeAppSettings_backup")
        super.tearDown()
    }
    
    func testGetCurrentVersionDefaultsToZero() {
        let version = migrationManager.getCurrentVersion()
        XCTAssertEqual(version, "0.0.0")
    }
    
    func testSetCurrentVersion() {
        migrationManager.setCurrentVersion("1.2.3")
        let version = migrationManager.getCurrentVersion()
        XCTAssertEqual(version, "1.2.3")
    }
    
    func testMigrateSettingsReturnsNilWhenNoSettings() throws {
        let result = try migrationManager.migrateSettingsIfNeeded()
        XCTAssertNil(result)
    }
    
    func testMigrateSettingsReturnsExistingDataWhenUpToDate() throws {
        let testData: [String: Any] = ["test": "value"]
        let jsonData = try JSONSerialization.data(withJSONObject: testData)
        UserDefaults.standard.set(jsonData, forKey: "gazeAppSettings")
        
        if let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            migrationManager.setCurrentVersion(bundleVersion)
        }
        
        let result = try migrationManager.migrateSettingsIfNeeded()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?["test"] as? String, "value")
    }
    
    func testMigrationErrorTypes() {
        let migrationFailed = MigrationError.migrationFailed("test")
        let invalidData = MigrationError.invalidDataStructure
        let versionMismatch = MigrationError.versionMismatch
        let noBackup = MigrationError.noBackupAvailable
        
        switch migrationFailed {
        case .migrationFailed(let message):
            XCTAssertEqual(message, "test")
        default:
            XCTFail("Expected migrationFailed error")
        }
        
        XCTAssertNotNil(invalidData.errorDescription)
        XCTAssertNotNil(versionMismatch.errorDescription)
        XCTAssertNotNil(noBackup.errorDescription)
    }
    
    func testMigrationErrorDescriptions() {
        let errors: [MigrationError] = [
            .migrationFailed("test message"),
            .invalidDataStructure,
            .versionMismatch,
            .noBackupAvailable
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    func testVersion101MigrationTargetVersion() {
        let migration = Version101Migration()
        XCTAssertEqual(migration.targetVersion, "1.0.1")
    }
    
    func testVersion101MigrationPreservesData() throws {
        let migration = Version101Migration()
        let testData: [String: Any] = ["key1": "value1", "key2": 42]
        
        let result = try migration.migrate(testData)
        
        XCTAssertEqual(result["key1"] as? String, "value1")
        XCTAssertEqual(result["key2"] as? Int, 42)
    }
    
    func testMigrationThrowsOnInvalidData() {
        UserDefaults.standard.set(Data("invalid json".utf8), forKey: "gazeAppSettings")
        migrationManager.setCurrentVersion("0.0.0")
        
        XCTAssertThrowsError(try migrationManager.migrateSettingsIfNeeded()) { error in
            XCTAssertTrue(error is MigrationError)
        }
    }
    
    func testVersionComparison() throws {
        migrationManager.setCurrentVersion("1.0.0")
        let current = migrationManager.getCurrentVersion()
        XCTAssertEqual(current, "1.0.0")
        
        migrationManager.setCurrentVersion("1.2.3")
        let updated = migrationManager.getCurrentVersion()
        XCTAssertEqual(updated, "1.2.3")
    }
    
    func testBackupIsCreatedDuringMigration() throws {
        let testData: [String: Any] = ["test": "backup"]
        let jsonData = try JSONSerialization.data(withJSONObject: testData)
        UserDefaults.standard.set(jsonData, forKey: "gazeAppSettings")
        migrationManager.setCurrentVersion("0.0.0")
        
        _ = try? migrationManager.migrateSettingsIfNeeded()
        
        let backupData = UserDefaults.standard.data(forKey: "gazeAppSettings_backup")
        XCTAssertNotNil(backupData)
    }
}
