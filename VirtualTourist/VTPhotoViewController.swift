//
//  VTPhotoViewController.swift
//  VirtualTourist
//
//  Created by Jodi Lovell on 5/22/17.
//  Copyright © 2017 None. All rights reserved.
//

import UIKit
import MapKit
import CoreData

enum ImageResult {
	case success(UIImage)
	case failure(Error)
}

enum PhotoError: Error {
	case imageCreationError
}

enum FetchResult {
	case success([Photo])
	case failure(Error)
}

class VTPhotoViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, MKMapViewDelegate {
    
    @IBOutlet weak var collectView: UICollectionView!
    @IBOutlet weak var mapView: MKMapView!

	let imageStore = ImageStore()
	var passedPin: Pin?
	var photos = [Photo]()
	var photoCount: Int = 0
	var photosFromCoreData = [UIImage]()
	var latitude: Double = 0.0
	var longitude: Double = 0.0

	
    override func viewDidLoad() {
        super.viewDidLoad()
		collectView.delegate = self
		collectView.dataSource = self
		mapView.delegate = self
		latitude = (self.passedPin?.latitude)!
		longitude = (self.passedPin?.longitude)!
		let annotation = MKPointAnnotation()
		annotation.coordinate = CLLocationCoordinate2D(latitude: (latitude), longitude: (longitude))
		let regionRadius: CLLocationDistance = 100000         // in meters
		let coordinateRegion = MKCoordinateRegionMakeWithDistance(annotation.coordinate, regionRadius, regionRadius)
		mapView.setRegion(coordinateRegion, animated: true)
		mapView.addAnnotation(annotation)

		updateDataSource()

    }

	//MARK: - CollectionView Setup
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		print(photos.count)
		return photos.count
		
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCellCollectionViewCell", for: indexPath)
		return cell
	}
	
	func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
		
		let photo = photos[indexPath.row]
		
		//Download the image data, which could take some time
		fetchImage(for: photo) { (result) -> Void in
			
			// The index path for the photo might have changed between the
			// time the request started and finished, so find the most
			// recent index path
			guard let photoIndex = self.photos.index(of: photo),
				case let .success(image) = result
				else {
					return
			}
			
			let photoIndexPath = IndexPath(item: photoIndex, section: 0)
			
			// When the request finishes, only update the cell if it's still visible
			if let cell = self.collectView.cellForItem(at: photoIndexPath) as? PhotoCellCollectionViewCell {
				cell.update(with: image)
			}
		}
	}
//	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//		
//		if self.createNewCollectionButton.isEnabled == false {
//			AlertMessage.display(con: self, error: "Please wait until all photos are downloaded before removing one.")
//		}else {
//			self.photoCount -= 1
//			self.photosFromCoreData.remove(at: indexPath.item)
//			self.albumCollectionView.deleteItems(at: [indexPath])
//			
//			// Remove from core data model
//			let photoObjs = self.pinData?.hasPhotos?.allObjects
//			let photoObj = photoObjs?[indexPath.item] as? Photo
//			
//			CoreDataManager.persistentContainer.viewContext.delete(photoObj!)
//			CoreDataManager.saveContext()
//		}
//	}
	
	
	func fetchImage(for photo: Photo, completion: @escaping (ImageResult) -> Void) {
		
		guard let photoKey = photo.photoID else {
			preconditionFailure("Photo expected to have photoID")
		}
		
		if let image = imageStore.imageForKey(key: photoKey) {
			DispatchQueue.main.async {
				completion(.success(image))
			}
			return
		}
	
		guard let photoURL = photo.imageURL else {
			preconditionFailure("Photo expected to have remoteURL")
		}
		
		let session = URLSession.shared
		let request = URLRequest(url: photoURL as! URL)
		let task = session.dataTask(with: request) { (data, response, error) -> Void in
			
			let result = self.processImageRequest(data: data, error: error)
			
			if case let .success(image) = result {
				self.imageStore.setImage(image: image, forKey: photoKey)
			}
			DispatchQueue.main.async {
				completion(result)
			}
		}
		task.resume()
	}
	
	private func processImageRequest(data: Data?, error: Error?) -> ImageResult {
		guard let imageData = data, let image = UIImage(data: imageData)
			else {
				if data == nil {
					return .failure(error!)
				} else {
					return .failure(PhotoError.imageCreationError)
				}
		}
		return .success(image)
	}

	
	@IBAction func backButton(_ sender: Any) {
		dismiss(animated: true, completion: nil)
	}
	
	// MARK: -  Error alert setup
	func showAlert(_ sender: Any, message: String) {
		let errMessage = message
		
		let alert = UIAlertController(title: nil, message: errMessage, preferredStyle: UIAlertControllerStyle.alert)
		alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { action in
			alert.dismiss(animated: true, completion: nil)
		}))
		
		self.present(alert, animated: true, completion: nil)
		
	}
	
	func updateDataSource() {
		self.fetchAllPhotos { (photosResult) in
			
			switch photosResult {
			case let .success(photos):
				self.photos = photos
			case .failure:
				self.photos.removeAll()
			}
			self.collectView.reloadSections(IndexSet(integer: 0))
		}
	}
	
	func fetchAllPhotos(completion: @escaping (FetchResult) -> Void) {
		let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
		let sortByID = NSSortDescriptor(key: #keyPath(Photo.photoID), ascending: true)
		fetchRequest.sortDescriptors = [sortByID]
		fetchRequest.predicate = NSPredicate(format: "pin == %@", self.passedPin!)
		
		let viewContext = CoreDataManager.persistentContainer?.viewContext
		viewContext?.perform {
			do {
				let request = try fetchRequest.execute()
				let allPhotos: [Photo] = request
				completion(.success(allPhotos))
			} catch {
				completion(.failure(error))
			}
		}
	}

}
