import Foundation
import CoreData
import CloudKit

public class CoreDataStack: ObservableObject {

    public static let shared = CoreDataStack()

    private init() {}

    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "GigiGains")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description")
        }

        description.setOption(true as NSNumber,
                             forKey: "NSPersistentCloudKitContainerOptionsKey")

        description.setOption(true as NSNumber,
                             forKey: "NSPersistentHistoryTrackingKey")

        description.setOption(true as NSNumber,
                             forKey: "NSPersistentStoreRemoteChangeNotificationPostOptionKey")

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data error: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    public var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    public func save() {
        let context = persistentContainer.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    public func newBackgroundContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
}