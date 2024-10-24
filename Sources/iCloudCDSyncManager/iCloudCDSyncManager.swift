// The Swift Programming Language
// https://docs.swift.org/swift-book
//
//  Created by Vladimir Vinakheras on 24.10.2024.
//
import CoreData
import Foundation
import Network
import UserNotifications

/// A manager for synchronizing CoreData with iCloud.
/// It supports automatic and manual sync modes, handles errors, provides offline support,
/// resolves conflicts, allows data deletion, and offers notifications and status reports.
@available(macOS 10.15, *)
public class CoreDataSyncManager: @unchecked Sendable {
    
    public let persistentContainer: NSPersistentCloudKitContainer
    private var monitor: NWPathMonitor?

    /// Defines the synchronization mode.
    public enum SyncMode {
        case automatic
        case manual
    }

    /// Stores the last synchronization status and time.
    public var lastSyncDate: Date?
    public var syncStatus: String = "Not Synced"
    
    // MARK: - Initializer

    /// Initializes the CoreDataSyncManager with the given models and iCloud container.
    /// - Parameters:
    ///   - modelNames: An array of CoreData model names to be synced.
    ///   - iCloudContainer: The identifier of the iCloud container.
    ///   - syncMode: The synchronization mode (automatic or manual). Default is automatic.
    public init(
        modelNames: [String],
        iCloudContainer: String,
        syncMode: SyncMode = .automatic,
        persistentContainer: NSPersistentCloudKitContainer? = nil
    ) {
        if let container = persistentContainer {
            self.persistentContainer = container
        } else {
            guard let modelName = modelNames.first else {
                fatalError("At least one CoreData model name must be provided.")
            }

            self.persistentContainer = NSPersistentCloudKitContainer(name: modelName)
            guard let firstPerstistentStoreDescription = self.persistentContainer.persistentStoreDescriptions.first else { return}
            let storeDescription = firstPerstistentStoreDescription
            storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: iCloudContainer)

            if syncMode == .manual {
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            }

            self.persistentContainer.loadPersistentStores { _, error in
                if let error = error {
                    fatalError("Failed to load persistent stores: \(error)")
                }
            }
        }

        setupNetworkMonitor()
        setupNotifications()
    }

    // MARK: - Core Data Saving Support

    /// Saves changes in the managed object context, handling errors if any occur.
    public func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
                updateSyncStatus(success: true)
            } catch {
                print("Failed to save context: \(error)")
                updateSyncStatus(success: false)
            }
        }
    }

    // MARK: - Manual iCloud Data Deletion

    /// Deletes all data stored in the iCloud container.
    public func deleteDataFromICloud() {
        guard let storeDescription = persistentContainer.persistentStoreDescriptions.first else { return }
        let coordinator = persistentContainer.persistentStoreCoordinator

        do {
            try coordinator.destroyPersistentStore(at: storeDescription.url!, ofType: NSSQLiteStoreType, options: nil)
            print("iCloud data deleted successfully.")
        } catch {
            print("Error deleting iCloud data: \(error)")
        }
    }

    // MARK: - Automatic Data Deletion Configuration

    /// Configures the system to delete iCloud data on app reinstallation.
    public func configureForAutomaticDeletion() {
        UserDefaults.standard.set(false, forKey: "hasLaunchedBefore")
    }

    /// Handles the first app launch to ensure iCloud data deletion if required.
    public func handleFirstLaunch() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if isFirstLaunch {
            deleteDataFromICloud()
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    }

    // MARK: - Offline Support

    /// Sets up a network monitor to detect connectivity changes and sync data when online.
    func setupNetworkMonitor() {
        monitor = NWPathMonitor()
        monitor?.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            if path.status == .satisfied {
                print("Connected. Syncing data...")
                self.saveContext()
            }
        }
        monitor?.start(queue: DispatchQueue.global(qos: .background))
    }

    // MARK: - Conflict Resolution

    /// Resolves conflicts by choosing between local or iCloud data.
    /// - Parameter preferLocal: Whether to prefer local data in case of conflict.
    public func resolveConflict(preferLocal: Bool) {
        if preferLocal {
            saveContext()
        } else {
            persistentContainer.viewContext.rollback()
        }
    }

    // MARK: - Sync Status Reporting

    /// Updates the synchronization status and records the last sync date.
    /// - Parameter success: Whether the sync was successful.
    private func updateSyncStatus(success: Bool) {
        lastSyncDate = Date()
        syncStatus = success ? "Synced Successfully" : "Sync Failed"
    }

    // MARK: - Notifications

    /// Sets up notifications for sync status changes.
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    /// Sends a local notification with the given message.
    /// - Parameter message: The message to display in the notification.
    public func notifyUser(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Synchronization Status"
        content.body = message

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "syncStatus", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
