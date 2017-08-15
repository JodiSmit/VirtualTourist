//
//  PhotoData.swift
//  VirtualTourist
//
//  Created by Jodi Lovell on 7/25/17.
//  Copyright © 2017 None. All rights reserved.
// A fair amount of this code was borrowed from a course offered by Big Nerd Ranch. I like the flow of the processing of the JSON data as it feels clean and well laid out.

import Foundation
import CoreData
import UIKit

class PhotoData: NSObject {

	enum ImageResult {
		case success(UIImage)
		case failure(Error)
	}
	
	enum PhotoError: Error {
		case imageCreationError
	}

	enum PhotosResult {
		case success([Photo])
		case failure(Error)
	}
	
	static let sharedInstance = PhotoData()
	
	var imageData: NSData? = nil
	var currentPin: Pin? = nil
	
	func setCurrentPin(pin: Pin?) {
		currentPin = pin
	}
	
	func getCurrentPin() -> Pin {
		return currentPin!
	}
	
	//MARK: - Function to process/save photos
	func processPhotosRequest(data: Data?, error: Error?, completion: @escaping (PhotosResult) -> Void) {

		
		guard let jsonData = data
			else {
				completion(.failure(error!))
				return
		}
		let result = self.photos(fromJSON: jsonData, into: (CoreDataManager.persistentContainer?.viewContext)!)
		do {
			try CoreDataManager.persistentContainer?.viewContext.save()
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
	
	//MARK: - Get Photos from JSON data
	func photos(fromJSON data: Data, into context: NSManagedObjectContext) -> PhotosResult {
		do {
			let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
			
			guard
				let jsonDictionary = jsonObject as? [AnyHashable: Any],
				let photos = jsonDictionary["photos"] as? [String: Any],
				let photosArray = photos["photo"] as? [[String: Any]]
				else {
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
			return .success(finalPhotos)
		} catch let error {
			return .failure(error)
		}
	}
	
	//MARK: - Get Photo information from JSON
	func photo(fromJSON json: [String: Any], into context: NSManagedObjectContext) -> Photo? {
		
		guard
			let photoID = json["id"] as? String,
			let photoURLString = json["url_m"] as? String,
			let url = URL(string: photoURLString)
			else {
				print("We don't have enough info to construct a photo")
				return nil
		}
		
		do {
			let data = try Data(contentsOf: url )
			imageData = data as NSData
		}
			catch {
				print("No photo data returned!!")
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
			photo = Photo(context: context)
			photo.photoID = photoID
			photo.imageURL = url as NSURL
			photo.imageData = self.imageData
			photo.pin = self.currentPin
		}
		return photo
	}
}
