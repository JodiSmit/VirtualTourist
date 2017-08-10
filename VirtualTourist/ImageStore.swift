//
//  ImageStore.swift
//  VirtualTourist
//
//  Created by Jodi Lovell on 7/13/17.
//  Copyright © 2017 None. All rights reserved.
// The Image store Class and some code relating to it was borrowed from a course given by Big Nerd Ranch.



import UIKit

//MARK: - Helper used to store images in a cache
class ImageStore: NSObject {
	let cache = NSCache<AnyObject, AnyObject>()
	
	func imageURLForKey(key: String) -> NSURL {
		let documentsDirectories = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
		let documentDirectory = documentsDirectories.first!
		return documentDirectory.appendingPathComponent(key) as NSURL
		
	}
	
	func setImage(image: UIImage, forKey key: String) {
		cache.setObject(image, forKey: key as AnyObject)
		let imageURL = imageURLForKey(key: key)
		if let data = UIImageJPEGRepresentation(image, 0.5) {
			do {
				try data.write(to: imageURL as URL)
				
			} catch {
				print("Data write error")
			}
		}
	}
	
	func imageForKey(key: String) -> UIImage? {
		if let existingImage = cache.object(forKey: key as AnyObject) as? UIImage {
			return existingImage
		}
		let imageURL = imageURLForKey(key: key)
		guard let imageFromDisk = UIImage(contentsOfFile: imageURL.path!) else {
			return nil
		}
		cache.setObject(imageFromDisk, forKey: key as AnyObject)
		return imageFromDisk
	}
	
	func deleteImageForKey(key: String) {
		cache.removeObject(forKey: key as AnyObject)
		let imageURL = imageURLForKey(key: key)
		do {
			try FileManager.default.removeItem(at: imageURL as URL)
		} catch let deleteError {
			print("Error removing the image from disk: \(deleteError)")
		}
	}
}

