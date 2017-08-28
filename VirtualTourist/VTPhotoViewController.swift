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

class VTPhotoViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, MKMapViewDelegate, NSFetchedResultsControllerDelegate {
	
	@IBOutlet weak var collectView: UICollectionView!
	@IBOutlet weak var collectionButton: UIButton!
	@IBOutlet weak var mapView: MKMapView!
	
	var passedPin: Pin?
	var latitude: Double = 0.0
	var longitude: Double = 0.0
	var selectedPhotos = [String]()
	var indexToDelete = [IndexPath]()
	
	//MARK: - Fetched Results controller for retrieving Core Data information
	lazy var fetchedResultsController: NSFetchedResultsController<Photo> = {
		let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
		fetchRequest.predicate = NSPredicate(format: "pin == %@", self.passedPin!)
		fetchRequest.sortDescriptors = []
		
		let context = CoreDataManager.persistentContainer?.viewContext
		
		let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext:context!, sectionNameKeyPath: nil, cacheName: nil)
		
		return fetchedResultsController
	} ()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		collectView.delegate = self
		collectView.dataSource = self
		mapView.delegate = self
		fetchedResultsController.delegate = self
		collectView.allowsMultipleSelection = true
		latitude = (self.passedPin?.latitude)!
		longitude = (self.passedPin?.longitude)!
		let annotation = MKPointAnnotation()
		annotation.coordinate = CLLocationCoordinate2D(latitude: (latitude), longitude: (longitude))
		let regionRadius: CLLocationDistance = 100000         // in meters
		let coordinateRegion = MKCoordinateRegionMakeWithDistance(annotation.coordinate, regionRadius, regionRadius)
		mapView.setRegion(coordinateRegion, animated: true)
		mapView.addAnnotation(annotation)
		loadOrUpdateData()
	}
	
	
	//MARK: - CollectionView functions
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		return (self.fetchedResultsController.sections?.count)!
	}
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		let indexCount = indexToDelete.count
		let fetchedCount = (self.fetchedResultsController.fetchedObjects?.count)!
		
		if indexCount != 0 {
			return fetchedCount
		} else {
			return fetchedCount - indexCount
		}
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCellCollectionViewCell
		
		cell.spinner.startAnimating()
		cell.photoImageCell.image = nil
		
		performUIUpdatesOnMain {
			let photo = self.fetchedResultsController.object(at: indexPath)
			
			if photo.imageData != nil {
				cell.spinner.stopAnimating()
				cell.photoImageCell.image = UIImage(data: photo.imageData! as Data)
			} else {
				do {
					let data = try Data(contentsOf: photo.imageURL as! URL )
					let imageData = data as NSData
					let image = UIImage(data: data)
					cell.photoImageCell.image = image
					cell.spinner.stopAnimating()
					
					self.fetchedResultsController.fetchedObjects?.first?.imageData = imageData
					CoreDataManager.saveContext()
					
				}
				catch {
					print("No photo data returned!!")
				}
			}
		}
		
		return cell
	}
	
	
	//MARK: - When cell is tapped (selected)
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		
		let photo = fetchedResultsController.object(at: indexPath)
		let cell = collectionView.cellForItem(at: indexPath) as! PhotoCellCollectionViewCell
		selectLabel()
		if !selectedPhotos.contains(photo.photoID!){
			selectedPhotos.append(photo.photoID!)
			indexToDelete.append(indexPath)
			
		}
		cell.alpha = 0.5
		
	}
	
	//MARK: - When same cell is tapped again (deselected)
	func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
		let photo = fetchedResultsController.object(at: indexPath)
		let cell = collectionView.cellForItem(at: indexPath) as! PhotoCellCollectionViewCell
		selectedPhotos.remove(at: selectedPhotos.index(of: photo.photoID!)!)
		selectLabel()
		cell.alpha = 1
		
	}
	
	//MARK: - Change label title
	func selectLabel() {
		if selectedPhotos.isEmpty {
			collectionButton.setTitle("New Collection", for: .normal)
		} else {
			collectionButton.setTitle("Remove Selected", for: .normal)
			
		}
		
		
	}
	//MARK: - Action when button at base is clicked
	@IBAction func newCollection(_ sender: Any) {
		
		if selectedPhotos.isEmpty {
			performUIUpdatesOnMain {
				CoreDataManager.deletePhotosForPin(self.passedPin!) { () in
					self.loadOrUpdateData()
				}
				
			}
			
		} else {
			CoreDataManager.deleteSelectedPhotos(selectedPhotos)
			
			do {
				try self.fetchedResultsController.performFetch()
			} catch {
				let fetchError = error as NSError
				print("Unable to Perform Fetch Request")
				print("\(fetchError), \(fetchError.localizedDescription)")
			}
			collectView.deleteItems(at: indexToDelete)
			selectedPhotos.removeAll()
			indexToDelete.removeAll()
			
		}
		selectLabel()
		
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
			self.dismiss(animated: true, completion: nil)
		}))
		
		self.present(alert, animated: true, completion: nil)
		
	}
	
	//MARK: - Load/Update cell content
	func loadOrUpdateData() {
		
		do {
			try self.fetchedResultsController.performFetch()
		} catch {
			let fetchError = error as NSError
			print("Unable to Perform Fetch Request")
			print("\(fetchError), \(fetchError.localizedDescription)")
		}
		
		if fetchedResultsController.fetchedObjects!.count == 0 {
			FlickrAPI.sharedInstance.initiateFlickrAPIRequestBySearch(self.latitude, self.longitude) { (result) in
				switch result {
				case .failure( _):
					self.showAlert(AnyObject.self, message: "Unable to load images, let's try a new location!")
				case let .success(returnedPhotos):
					if returnedPhotos.isEmpty {
						self.showAlert(AnyObject.self, message: "No images for this location - let's try a new location!")
					} else {
						do {
							try self.fetchedResultsController.performFetch()
							self.collectView.reloadData()
						} catch {
							let fetchError = error as NSError
							print("Unable to Perform Fetch Request")
							print("\(fetchError), \(fetchError.localizedDescription)")
						}
						
					}
					
				}
				
			}
		}
		
	}
	
}
