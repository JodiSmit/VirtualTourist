//
//  VTMapViewController.swift
//  VirtualTourist
//
//  Created by Jodi Lovell on 5/19/17.
//  Copyright © 2017 None. All rights reserved.
//


import UIKit
import MapKit
import CoreData
import CoreLocation


class VTMapViewController: UIViewController, MKMapViewDelegate {

	@IBOutlet weak var deleteAllButton: UIBarButtonItem!
    @IBOutlet weak var mapView: MKMapView!
	@IBOutlet weak var deletePinsLabel: UILabel!
	@IBOutlet weak var editPinsButton: UIBarButtonItem!
	
    var newCoordinates: CLLocationCoordinate2D?
	var latitude: Double = 0.0
	var longitude: Double = 0.0
    var editingPins = false
	var selectedAnnotation: MKAnnotation?
	var pinToDelete: CLLocationCoordinate2D?
	static var newPin: Pin?
	var pinError = false
	

    override func viewDidLoad() {
        super.viewDidLoad()
		mapView.delegate = self
		performUIUpdatesOnMain {
	        self.loadExistingPins()
		}
    }
	
	//MARK: - Button action to edit (remove) individual pins.
    @IBAction func editPins(_ sender: Any) {
        if editingPins {
            hideLabel()
        }else {
            showLabel()
        }
    }
	
	//MARK: - Button action to batch delete all pins.
    @IBAction func deletePins(_ sender: Any) {
		CoreDataManager.deleteAllPinRecords()
		performUIUpdatesOnMain {
			let allAnnotations = self.mapView.annotations
			self.mapView.removeAnnotations(allAnnotations)
		}
    }
	
	//MARK: - Long press action to drop pin. Also kicks off Flickr API request.
    @IBAction func longPress(_ sender: UILongPressGestureRecognizer) {
        if sender.state == UIGestureRecognizerState.began {
            sender.minimumPressDuration = 1.0
            sender.allowableMovement = 1
            let touchPoint = sender.location(in: mapView)
            newCoordinates = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            let annotation = MKPointAnnotation()
            annotation.coordinate = newCoordinates!
            mapView.addAnnotation(annotation)
			VTMapViewController.newPin = Pin(context: (CoreDataManager.persistentContainer?.viewContext)!)
			VTMapViewController.newPin?.latitude = (newCoordinates?.latitude)!
			VTMapViewController.newPin?.longitude  = (newCoordinates?.longitude)!
			PhotoData.sharedInstance.setCurrentPin(pin: VTMapViewController.newPin)
			latitude = (VTMapViewController.newPin?.latitude)!
			longitude = (VTMapViewController.newPin?.longitude)!
			FlickrAPI.sharedInstance.displayImageFromFlickrBySearch(latitude, longitude) { (result) in
				switch result {
				case .failure( _):
					self.pinError = true
				default:
					break
				}
			}
        }
    }

	
    // MARK: - MKMapViewDelegate
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView

        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
			pinView!.animatesDrop = true
            pinView!.pinTintColor = .orange
        }
        else {
            pinView!.annotation = annotation
        }
        return pinView
    }
    
    
    //MARK: - This method is implemented to allow pins to respond to taps.
	func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
		self.selectedAnnotation = mapView.selectedAnnotations.first as! MKPointAnnotation
		if pinError != true {
			if editingPins == false {
				mapView.deselectAnnotation(view.annotation, animated: true)
				performSegue(withIdentifier: "PinSelected", sender: self.selectedAnnotation)
			}else {
				var pinDeleting: CLLocationCoordinate2D?
				pinDeleting = self.selectedAnnotation?.coordinate
				CoreDataManager.deleteSinglePinRecord(pinDeleting!)
				self.mapView.removeAnnotation(self.selectedAnnotation!)
			}
		} else {
			self.showAlert(AnyObject.self, message: "No Images found for Pin! Please try another location!")
		}

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
    
	//MARK: Preparing Segue to next VC to display photos.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		
		let selectedPin = self.pinFromSelectedAnnotation()
		PhotoData.sharedInstance.setCurrentPin(pin: selectedPin)
		
		if segue.identifier == "PinSelected" {
			let svc = segue.destination as? UINavigationController
			let tapPinController: VTPhotoViewController = svc?.topViewController as! VTPhotoViewController
			tapPinController.passedPin = selectedPin
			
		} else {
			return
		}
    }
	
    //MARK: Load any existing pins from core data.
    func loadExistingPins() {
		
        let fetchRequest: NSFetchRequest<Pin> = Pin.fetchRequest()
        
        do {
            let results = try CoreDataManager.getContext().fetch(fetchRequest)
                for pin in results {
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
                    self.mapView.addAnnotation(annotation)
                }

        } catch {
            print("Couldn't find any Pins")
        }
    }

	//MARK: - Get core data information for selected Pin
	func pinFromSelectedAnnotation() -> Pin {
		
		let fetchRequest: NSFetchRequest<Pin> = Pin.fetchRequest()
		fetchRequest.sortDescriptors = [ NSSortDescriptor(key: "latitude", ascending: true) ]
		
		let context = CoreDataManager.persistentContainer?.viewContext
		let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context!, sectionNameKeyPath: nil, cacheName: nil)

		guard let annotation = selectedAnnotation else { print("'selectedAnnotation = nil'"); return Pin(context: context!) }
		let latitude = annotation.coordinate.latitude
		let longitude = annotation.coordinate.longitude
		let pred = NSPredicate(format: "latitude = %@ AND longitude = %@", argumentArray: [latitude, longitude])
		fetchRequest.predicate = pred
		fetchRequest.fetchLimit = 1
		
		do { try fetchedResultsController.performFetch()
		} catch { print("Failed to initialize FetchedResultsController: \(error)") }

		guard let pinFromAnnotation = fetchedResultsController.fetchedObjects?.first else {
			print("no pin found from latitude and/or longitude from clicked annotation")
			return Pin(context: context!)
		}
		return pinFromAnnotation
	}
	
    //MARK: - Handle showing and hiding delete button
    func showLabel() {
		deletePinsLabel.isHidden = false
        editingPins = true
		editPinsButton.title = "Done"
    }
	
    func hideLabel() {
		deletePinsLabel.isHidden = true
        editingPins = false
		editPinsButton.title = "Edit Pins"
    }
}
