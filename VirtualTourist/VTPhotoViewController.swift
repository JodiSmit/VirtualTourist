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

class VTPhotoViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, MKMapViewDelegate, NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var collectView: UICollectionView!
	@IBOutlet weak var collectionButton: UIButton!
    @IBOutlet weak var mapView: MKMapView!

	let imageStore = ImageStore()
	var passedPin: Pin?
	var photos = [Photo]()
	var latitude: Double = 0.0
	var longitude: Double = 0.0
	var selectedPhotos = [String]()
	
    override func viewDidLoad() {
        super.viewDidLoad()
		collectView.delegate = self
		collectView.dataSource = self
		mapView.delegate = self
		collectView.allowsMultipleSelection = true
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
		return photos.count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCellCollectionViewCell", for: indexPath)
		return cell
	}
	
	//MARK: - Fetch images from cache when cell is loaded.
	func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
		
		let photo = photos[indexPath.row]
		
		performUIUpdatesOnMain {
			self.fetchImage(for: photo) { (result) -> Void in
				guard let photoIndex = self.photos.index(of: photo),
					case let .success(image) = result
					else {
						return
				}
				
				let photoIndexPath = IndexPath(item: photoIndex, section: 0)
				if let cell = self.collectView.cellForItem(at: photoIndexPath) as? PhotoCellCollectionViewCell {
					cell.update(with: image)
				}
			}
		}
	}
	
	//MARK: - When cell is tapped (selected)
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		let photo = photos[indexPath.row]
		let cell = collectionView.cellForItem(at: indexPath) as! PhotoCellCollectionViewCell
		if !selectedPhotos.contains(photo.photoID!) {
			selectedPhotos.append(photo.photoID!)
		}
		cell.alpha = 0.5
		collectionButton.setTitle("Remove Selected", for: .normal)
		print(selectedPhotos)
	}

	//MARK: - When same cell is tapped again (deselected)
	func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
		let photo = photos[indexPath.row]
		let cell = collectionView.cellForItem(at: indexPath) as! PhotoCellCollectionViewCell
		selectedPhotos.remove(at: selectedPhotos.index(of: photo.photoID!)!)
		if selectedPhotos.isEmpty {
			collectionButton.setTitle("New Collection", for: .normal)
		}
		cell.alpha = 1
	}
	
	//MARK: - Fetching the image from cache using URL data
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
	
	//MARK: - Process the image request based on the data
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

	//MARK: - Action when button at base is clicked
	@IBAction func newCollection(_ sender: Any) {
		
		if selectedPhotos.isEmpty {
			CoreDataManager.deletePhotosForPin(self.passedPin!)
			FlickrAPI.sharedInstance.displayImageFromFlickrBySearch(self.latitude, self.longitude) { (result) in
				switch result {
				case .failure( _):
					self.showAlert(AnyObject.self, message: "Unable to load new images, let's try a new location!")
					self.dismiss(animated: true, completion: nil)
				default:
					break
				}
				self.updateDataSource()
			}

		} else {
			CoreDataManager.deleteSelectedPhotos(selectedPhotos)
			updateDataSource()
			
		}
	
	}
	
	//MARK: - Back button action
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
	
	//MARK: - Updating cell content
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
	
	//MARK: - Fetch request for Photo data
	func fetchAllPhotos(completion: @escaping (FetchResult) -> Void) {
		let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
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
