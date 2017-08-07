    //
    //  CoreDataManager.swift
    //  VirtualTourist
    //
    //  Created by Jodi Lovell on 5/22/17.
    //  Copyright © 2017 None. All rights reserved.
    
    import CoreData
	import CoreLocation
	
	
    //MARK: - Core Data stack
    
    class CoreDataManager {
        
        private init() {
            
        }

        static var persistentContainer: NSPersistentContainer? = nil
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        
        class func getContext() -> NSManagedObjectContext {
            if (persistentContainer == nil) {
                persistentContainer = NSPersistentContainer(name: "VirtualTourist")
                persistentContainer?.loadPersistentStores(completionHandler: { (storeDescription, error) in
                    if let error = error as NSError? {
                        // Replace this implementation with code to handle the error appropriately.
                        // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                        
                        /*
                         Typical reasons for an error here include:
                         * The parent directory does not exist, cannot be created, or disallows writing.
                         * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                         * The device is out of space.
                         * The store could not be migrated to the current model version.
                         Check the error message to determine what the actual problem was.
                         */
                        fatalError("Unresolved error \(error), \(error.userInfo)")
                    }
                })
            }
            return persistentContainer!.viewContext
        }
        
        
        
        // MARK: - Core Data Saving support
        
        class func saveContext () {
        let context = CoreDataManager.persistentContainer?.viewContext
            if (context?.hasChanges)! {
                do {
                    try context?.save()
                } catch {
                    // Replace this implementation with code to handle the error appropriately.
                    // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    let nserror = error as NSError
                    fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
                }
            }
        }
		
		class func deleteSinglePinRecord(_ pin: CLLocationCoordinate2D) {
			let context = CoreDataManager.persistentContainer?.viewContext
			let deleteFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Pin")
			let latitude = (pin.latitude)
			let longitude  = (pin.longitude)
			
			let pred = NSPredicate(format: "latitude = %@ AND longitude = %@", argumentArray: [latitude, longitude])
			deleteFetch.predicate = pred
					
			do {
				let items = try context?.fetch(deleteFetch) as! [NSManagedObject]
				
				for item in items {
					context?.delete(item)
				}
				try context?.save()
				
			} catch {
				print ("There was an error")
				
			}
		}
		
		class func deletePhotosForPin(_ pin: Pin) {
			let context = CoreDataManager.persistentContainer?.viewContext
			let deleteFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Photo")
			
			let pred = NSPredicate(format: "pin == %@", pin)
			deleteFetch.predicate = pred
			
			do {
				let items = try context?.fetch(deleteFetch) as! [NSManagedObject]
				
				for item in items {
					context?.delete(item)
				}
				try context?.save()
				
			} catch {
				print ("There was an error")
				
			}
		}
		
        class func deleteAllPinRecords() {
            let context = CoreDataManager.persistentContainer?.viewContext
            let deleteFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Pin")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: deleteFetch)
            
            do {
                try context?.execute(deleteRequest)
                try context?.save()
            } catch {
                print ("There was an error")
            }
        }
        
        class func deleteAllPhotoRecords() {
            let context = CoreDataManager.persistentContainer?.viewContext
            let deleteFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Photo")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: deleteFetch)
            
            do {
                try context?.execute(deleteRequest)
                try context?.save()
            } catch {
                print ("There was an error")
            }
        }

    }
