# CoreDataSyncManager

CoreDataSyncManager is a lightweight and powerful Swift package for synchronizing Core Data with iCloud using CloudKit. It simplifies the management of data across multiple devices, supporting both automatic and manual synchronization modes. With built-in offline support, conflict resolution, notifications, and data deletion features, this package is ideal for applications that require reliable and seamless data management.

## Features
**Automatic and Manual Sync Modes** 

    Easily switch between automatic and manual synchronization modes to fit your app’s workflow.

**Full Core Data and iCloud Integration**

    Uses NSPersistentCloudKitContainer to synchronize Core Data changes with iCloud, ensuring your data is always up-to-date across devices.
    
**Offline Support with Network Monitoring**

    Monitors network status using NWPathMonitor to detect connectivity changes. Automatically synchronizes when the connection is restored.

 **Conflict Resolution Strategies**
 
    Handles conflicts between local and iCloud data with configurable options to prioritize either local or cloud data.

**Data Deletion Capabilities**

    Supports full iCloud data deletion and can configure automatic data removal on app reinstallation to ensure fresh starts.

**User Notifications**

    Uses UNUserNotificationCenter to notify users of synchronization status, errors, or completed syncs, enhancing user experience.

**Optimized for Testing**

    Supports in-memory Core Data stores to enable fast and reliable unit testing without needing a persistent model or physical iCloud connection.
    
## Getting Started
### Installation via Swift Package Manager

To add CoreDataSyncManager to your project:

  In **Xcode**, go to **File > Add Packages**.
    Enter the repository URL:
    **https://github.com/VladimirVinageras/iCloudCDSyncManager**
    
    Select the latest version and add it to your project.

Alternatively, include the following in your Package.swift:

dependencies: [
**.package(url: "https://github.com/VladimirVinageras/iCloudCDSyncManager", from: "1.0.0")**
]

## Usage Example

      import CoreDataSyncManager
      
      let syncManager = CoreDataSyncManager(
          modelNames: ["MyCoreDataModel"],
          iCloudContainer: "iCloud.com.example.app",
          syncMode: .automatic
      )
      
      // Save changes to Core Data
      syncManager.saveContext()
      
      // Delete all iCloud data manually
      syncManager.deleteDataFromICloud()
      
      // Handle first app launch with iCloud data deletion if needed
      syncManager.handleFirstLaunch()
      
      // Resolve conflicts by prioritizing local data
      syncManager.resolveConflict(preferLocal: true)

## System Requirements

    iOS: 14.0 or later
    macOS: 10.15 or later
    Xcode: 12 or later
    Swift: 5.5 or later

## License

This project is licensed under the MIT License

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository.
2. Create a new feature branch:

    bash

        git checkout -b feature/new-feature

3. Commit your changes:

    bash

        git commit -m "Add new feature"

4. Push to the branch:

    bash

        git push origin feature/new-feature

5. Open a pull request.

## Conclusion

With CoreDataSyncManager, you can manage Core Data and iCloud synchronization efficiently, even in offline environments. Its conflict resolution and data management features, combined with network monitoring and user notifications, make it a powerful tool for developers building data-heavy applications across Apple platforms.

### Repository Link

[GitHub - CoreDataSyncManager](https://github.com/VladimirVinageras/iCloudCDSyncManager)
