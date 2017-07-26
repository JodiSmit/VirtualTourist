//
//  PhotoData.swift
//  VirtualTourist
//
//  Created by Jodi Lovell on 7/25/17.
//  Copyright © 2017 None. All rights reserved.
//

import Foundation
import CoreData

enum PhotosResult {
	case success([Photo])
	case failure(Error)
}

extension VTMapViewController {
	

	//MARK: - Function to process/save photos
	static func processPhotosRequest(data: Data?, error: Error?, completion: @escaping (PhotosResult) -> Void) {
		guard let jsonData = data
			else {
				completion(.failure(error!))
				return
		}
		CoreDataManager.persistentContainer?.performBackgroundTask { (context) in
			
			let result = photos(fromJSON: jsonData, into: (CoreDataManager.persistentContainer?.viewContext)!)
			do {
				try context.save()
			} catch {
				print("Error saving to Core Data: \(error).")
				completion(.failure(error))
				return
			}
			
			
			switch result {
			case let .success(photos):
				let photoIDs = photos.map { return $0.objectID }
				let viewContext = CoreDataManager.persistentContainer?.viewContext
				let viewContextPhotos =	photoIDs.map { return viewContext?.object(with: $0) } as! [Photo]
				completion(.success(viewContextPhotos))
			case .failure:
				completion(result)
			}
			
		}
	}
	
	
	 static func photos(fromJSON data: Data, into context: NSManagedObjectContext) -> PhotosResult {
		do {
			let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
			
			guard
				let jsonDictionary = jsonObject as? [AnyHashable: Any],
				let photos = jsonDictionary["photos"] as? [String: Any],
				let photosArray = photos["photo"] as? [[String: Any]]
				else {
					//The JSON structure doesn't match our expectations
					return .failure(FlickError.invalidJSONData)
			}
			var finalPhotos = [Photo]()
			for photoJSON in photosArray {
				if let photo = photo(fromJSON: photoJSON, into: (CoreDataManager.persistentContainer?.viewContext)!) {
					finalPhotos.append(photo)
				}
			}
			if finalPhotos.isEmpty && !photosArray.isEmpty {
				return .failure(FlickError.invalidJSONData)
			}
			CoreDataManager.saveContext()
			return .success(finalPhotos)
		} catch let error {
			return .failure(error)
		}
	}
	

	
	static func photo(fromJSON json: [String: Any], into context: NSManagedObjectContext) -> Photo? {
		
		guard
			let photoID = json["id"] as? String,
			let photoURLString = json["url_m"] as? String,
			let url = URL(string: photoURLString)
			else {
				print("We don't have enough info to construct a photo")
				return nil
		}
		
		let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
		let predicate = NSPredicate(format: "\(#keyPath(Photo.photoID)) == \(photoID)")
		fetchRequest.predicate = predicate
		
		var fetchedPhotos: [Photo]?
		context.performAndWait {
			fetchedPhotos = try? fetchRequest.execute()
		}
		if let existingPhoto = fetchedPhotos?.first {
			return existingPhoto
		}
		
		var photo: Photo!
		context.performAndWait {
			photo = Photo(context: (CoreDataManager.persistentContainer?.viewContext)!)
			photo.photoID = photoID
			photo.imageURL = url as NSURL
			photo.pin = VTMapViewController.newPin
			
		}
		return photo
	}

}
