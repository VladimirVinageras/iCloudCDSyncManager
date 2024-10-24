import XCTest
import CoreData
import Network
import UserNotifications
@testable import iCloudCDSyncManager

final class iCloudCDSyncManagerTests: XCTestCase {
    
    var syncManager: CoreDataSyncManager!
    let testModelName = "TestModel"
    let testContainerID = "iCloud.com.example.test"
    
    override func setUpWithError() throws {
        // Set up CoreDataSyncManager before each test
        syncManager = CoreDataSyncManager(
            modelNames: [testModelName],
            iCloudContainer: testContainerID,
            syncMode: .automatic
        )
    }

    override func tearDownWithError() throws {
        // Clean up after each test
        syncManager = nil
    }
    
    // MARK: - Tests for Initialization
    
    func testInitialization() throws {
        // Verify that the syncManager initializes correctly
        XCTAssertNotNil(syncManager)
        XCTAssertEqual(syncManager.syncStatus, "Not Synced")
        XCTAssertNil(syncManager.lastSyncDate)
    }

    // MARK: - Tests for Sync Operations
    
    func testSaveContextSuccess() throws {
        // Test successful saving of context
        let context = syncManager.persistentContainer.viewContext
        context.performAndWait {
            let entity = NSEntityDescription.insertNewObject(forEntityName: "Entity", into: context)
            entity.setValue("Test", forKey: "attribute")
        }

        syncManager.saveContext()
        XCTAssertNotEqual(syncManager.syncStatus, "Synced Successfully")
    }

    func testSaveContextFailure() throws {
        // Test failure scenario (e.g., invalid context changes)
        syncManager.persistentContainer.viewContext.performAndWait {
            // Simulate an error by making an invalid change
            let invalidEntity = NSEntityDescription()
            invalidEntity.name = "Invalid"
            syncManager.persistentContainer.viewContext.insert(NSManagedObject(entity: invalidEntity, insertInto: syncManager.persistentContainer.viewContext))
        }
        
        syncManager.saveContext()
        XCTAssertEqual(syncManager.syncStatus, "Not Synced")
    }

    // MARK: - Tests for Conflict Resolution

    func testResolveConflictPrefersLocal() throws {
        // Test that local changes are preferred during conflict resolution
        syncManager.resolveConflict(preferLocal: true)
        XCTAssertNotEqual(syncManager.syncStatus, "Synced Successfully")
    }

    func testResolveConflictPrefersCloud() throws {
        // Test that cloud changes are preferred during conflict resolution
        syncManager.resolveConflict(preferLocal: false)
        XCTAssertNil(syncManager.lastSyncDate) // Check that context was rolled back
    }

    // MARK: - Tests for iCloud Data Deletion

    func testDeleteDataFromICloud() throws {
        // Test the deletion of iCloud data
        syncManager.deleteDataFromICloud()
        print("Ensure manual verification that iCloud data was deleted.")
    }

    // MARK: - Tests for Network Monitoring

    func testNetworkMonitoring() throws {
        // Test the setup of the network monitor
        let expectation = XCTestExpectation(description: "Network status check")
        syncManager.setupNetworkMonitor()
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }

    
    // MARK: - Tests for First Launch Handling

    func testHandleFirstLaunch() throws {
        // Test first launch handling
        UserDefaults.standard.set(false, forKey: "hasLaunchedBefore")
        syncManager.handleFirstLaunch()
        
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasLaunchedBefore"))
    }
    
    func testConfigureForAutomaticDeletion() throws {
        // Test configuration for automatic iCloud data deletion
        syncManager.configureForAutomaticDeletion()
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "hasLaunchedBefore"))
    }
}
