//
//  CoreDataStack.swift
//  iOSSprintCalorieTracker
//
//  Created by Patrick Millet on 1/31/20.
//  Copyright © 2020 Patrick Millet. All rights reserved.
//

import Foundation
import CoreData

    // MARK: - Protocols
    protocol PersistentStoreControllerDelegate: NSFetchedResultsControllerDelegate {}

    extension NSManagedObjectContext: PersistentContext {}

    class CoreDataStack: NSObject, PersistentStoreController {
        
        // MARK: - Properties
        
        weak var delegate: PersistentStoreControllerDelegate?

        lazy var container = setUpContainer()
        lazy var fetchedResultsController = setUpResultsController()

        private var rootContext: NSManagedObjectContext { container.viewContext }

        var allItems: [Persistable]? { fetchedResultsController.fetchedObjects }
        var itemCount: Int { fetchedResultsController.sections?[0].numberOfObjects ?? 0 }
        var mainContext: PersistentContext { rootContext }

        // MARK: - Setup
        func setUpContainer() -> NSPersistentContainer {
            let container = NSPersistentContainer(name: "CalorieTracker")
            container.loadPersistentStores { _, error in
                if let error = error {
                    fatalError("Failed to load persistent stores: \(error)")
                }
            }
            container.viewContext.automaticallyMergesChangesFromParent = true
            return container
        }

        func setUpResultsController() -> NSFetchedResultsController<CalorieEntry> {
            guard let moc = mainContext as? NSManagedObjectContext else {
                fatalError("Main Context error")
            }
            let fetchRequest: NSFetchRequest<CalorieEntry> = CalorieEntry.fetchRequest()
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "timestamp", ascending: false)]
            let frc = NSFetchedResultsController(
                fetchRequest: fetchRequest,
                managedObjectContext: moc,
                sectionNameKeyPath: nil,
                cacheName: nil)
            frc.delegate = self.delegate

            do {
                try frc.performFetch()
            } catch {
                NSLog("Error initializing fetched results controller: \(error)")
            }
            return frc
        }

        // MARK: - CRUD Methods
        
        func create(item: Persistable, in context: PersistentContext?) throws {
            let thisContext = fetchContext(context)
            try thisContext.save()
        }

        func fetchItem(at indexPath: IndexPath) -> Persistable? {
            return fetchedResultsController.object(at: indexPath)
        }

        func deleteShort(itemAtIndexPath indexPath: IndexPath, in context: PersistentContext?) throws {
            let thisContext = fetchContext(context)
            let entry = fetchedResultsController.object(at: indexPath)
            try delete(entry, in: thisContext)
        }

        func delete(_ item: Persistable?, in context: PersistentContext?) throws {
            let thisContext = fetchContext(context)

            guard let entry = item as? CalorieEntry else { throw NSError() }
            thisContext.delete(entry)
            try save(in: thisContext)
        }

        func save(in context: PersistentContext?) throws {
            let thisContext = fetchContext(context)
            var saveError: Error?
            thisContext.performAndWait {
                do {
                    try thisContext.save()
                } catch {
                    saveError = error
                }
            }
            if let error = saveError { throw error }
        }

        func fetchContext(_ context: PersistentContext?) -> NSManagedObjectContext {
            if let context = context as? NSManagedObjectContext {
                return context
            } else {
                return rootContext
            }
        }
    }
