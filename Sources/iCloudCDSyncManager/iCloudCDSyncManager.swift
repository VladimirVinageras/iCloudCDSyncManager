//     CoreDataSyncManager
//  Created by Vladimir Vinakheras on 24.10.2024.
//


import CoreData
import Foundation
import Network
import UserNotifications

/// A manager to handle CoreData synchronization with iCloud.
/// It supports both automatic and manual sync modes, manages conflicts,
/// handles offline scenarios, provides notifications, and offers status reporting.
@available(macOS 10.15, *)
public class CoreDataSyncManager: @unchecked Sendable {
    
    /// The persistent container for CoreData with iCloud support.
    public let persistentContainer: NSPersistentCloudKitContainer
    private var monitor: NWPathMonitor?
    private var isSaving = false  // Prevents simultaneous saves.

    /// Defines the available synchronization modes.
    public enum SyncMode {
        case automatic
        case manual
    }

    /// Stores the last sync date and status message.
    public var lastSyncDate: Date?
    public var syncStatus: String = "Not Synced"

    // MARK: - Initializer

    /// Initializes the CoreDataSyncManager with specified model names and iCloud container.
    /// - Parameters:
    ///   - modelNames: A list of CoreData model names to be synchronized.
    ///   - iCloudContainer: The identifier for the iCloud container.
    ///   - syncMode: The synchronization mode, either automatic or manual. Default is automatic.
    ///   - persistentContainer: Optional existing persistent container.
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

            let container = NSPersistentCloudKitContainer(name: modelName)
            self.persistentContainer = container

            guard let storeDescription = container.persistentStoreDescriptions.first else {
                fatalError("Failed to get persistent store description.")
            }

            storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: iCloudContainer
            )

            if syncMode == .manual {
                storeDescription.setOption(
                    true as NSNumber,
                    forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
                )
            }

            storeDescription.setOption(
                true as NSNumber,
                forKey: NSPersistentHistoryTrackingKey
            )

            // Desempaquetar correctamente para evitar errores
            container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

            loadPersistentStores()
        }

        setupNetworkMonitor()
        setupNotifications()
    }

    /// Loads the persistent stores and handles potential errors.
    private func loadPersistentStores() {
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                print("Persistent store loading error: \(error.localizedDescription)")
                self.updateSyncStatus(success: false)
            } else {
                print("Loaded persistent store: \(description)")
                self.updateSyncStatus(success: true)
            }
        }
    }

    // MARK: - Core Data Saving Support

    /// Saves changes in the CoreData context, avoiding simultaneous saves.
    public func saveContext() {
        guard !isSaving else { return }
        isSaving = true

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

        isSaving = false
    }

    // MARK: - iCloud Data Deletion

    /// Deletes all data stored in the iCloud container.
    public func deleteDataFromICloud() {
        guard let storeDescription = persistentContainer.persistentStoreDescriptions.first else { return }
        let coordinator = persistentContainer.persistentStoreCoordinator

        do {
            try coordinator.destroyPersistentStore(
                at: storeDescription.url!,
                ofType: NSSQLiteStoreType,
                options: nil
            )
            print("iCloud data deleted successfully.")
        } catch {
            print("Error deleting iCloud data: \(error)")
        }
    }

    // MARK: - First Launch Handling

    /// Configures the app to delete iCloud data on reinstallation.
    public func configureForAutomaticDeletion() {
        UserDefaults.standard.set(false, forKey: "hasLaunchedBefore")
    }

    /// Handles the first app launch to ensure iCloud data is deleted if needed.
    public func handleFirstLaunch() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if isFirstLaunch {
            deleteDataFromICloud()
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    }

    // MARK: - Offline Support

    /// Sets up a network monitor to detect connectivity changes and sync data when online.
    private func setupNetworkMonitor() {
        monitor = NWPathMonitor()
        monitor?.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            if path.status == .satisfied {
                print("Connected. Syncing data...")
                self.saveContext()
            } else {
                print("No internet connection.")
            }
        }
        monitor?.start(queue: DispatchQueue.global(qos: .background))
    }

    // MARK: - Conflict Resolution

    /// Resolves conflicts by either saving local changes or discarding them.
    /// - Parameter preferLocal: If true, saves local changes; otherwise, discards them.
    public func resolveConflict(preferLocal: Bool) {
        if preferLocal {
            saveContext()
        } else {
            persistentContainer.viewContext.rollback()
        }
    }

    // MARK: - Sync Status Reporting

    /// Updates the synchronization status and records the last sync date.
    /// - Parameter success: Whether the sync operation was successful.
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

    /// Sends a local notification with the provided message.
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
