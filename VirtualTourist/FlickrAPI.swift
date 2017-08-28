//
//  FlickrAPI.swift
//  VirtualTourist
//
//  Created by Jodi Lovell on 5/22/17.
//  Copyright © 2017 None. All rights reserved.
//

import UIKit
import CoreLocation
import CoreData

enum FlickError: Error {
	case invalidJSONData
}

class FlickrAPI: NSObject {
	
	static var pinCoordinates: CLLocationCoordinate2D?
	static let sharedInstance = FlickrAPI()
	
	// MARK: - Initial Flickr API request
	func initiateFlickrAPIRequestBySearch(_ latitude: Double,_ longitude: Double, completion: @escaping (PhotoData.PhotosResult) -> Void) {
		
		let methodParameters = [
			Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
			Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
			Constants.FlickrParameterKeys.Latitude: latitude,
			Constants.FlickrParameterKeys.Longitude: longitude,
			Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
			Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
			Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
			Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback
			] as [String : Any]
		
		let session = URLSession.shared
		let request = URLRequest(url: flickrURLFromParameters(methodParameters as [String : AnyObject]))
		
		let task = session.dataTask(with: request) { (data, response, error) in
			
			// parse the data
			let parsedResult: [String:AnyObject]!
			do {
				parsedResult = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! [String:AnyObject]
			} catch {
				print("Could not parse the data as JSON: '\(String(describing: data))'")
				return
			}
			guard let photosDictionary = parsedResult["photos"] as? [String:AnyObject] else {
				print("Cannot find keys 'photos' in \(parsedResult)")
				return
			}
			guard let totalPages = photosDictionary["pages"] as? Int else {
				print("Cannot find key 'pages' in \(photosDictionary)")
				return
			}
			let pageLimit = min(totalPages, 40)
			let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
			self.displayImageFromFlickrBySearch(latitude, longitude, withPageNumber: randomPage) { (result) in
				switch result {
				case .failure( _):
					print("Error retrieving data from Flickr")
				default:
					completion(result)
				}
			}
		}
		
		task.resume()
	}
	// MARK: - Flickr API request using random page number
	func displayImageFromFlickrBySearch(_ latitude: Double,_ longitude: Double,_ picsPerPage: Int = 25, withPageNumber: Int, completion: @escaping (PhotoData.PhotosResult) -> Void) {
		
		let methodParameters = [
			Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
			Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
			Constants.FlickrParameterKeys.Latitude: latitude,
			Constants.FlickrParameterKeys.Longitude: longitude,
			Constants.FlickrParameterKeys.PerPage: picsPerPage,
			Constants.FlickrParameterKeys.Page: withPageNumber,
			Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
			Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
			Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
			Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback
			] as [String : Any]
		
		let session = URLSession.shared
		let request = URLRequest(url: flickrURLFromParameters(methodParameters as [String : AnyObject]))
		let task = session.dataTask(with: request) { (data, response, error) in
			PhotoData.sharedInstance.processPhotosRequest(data: data, error: error) { (result) in
				
				DispatchQueue.main.async {
					completion(result)
				}
			}
		}
		
		task.resume()
	}
	
	// MARK: - Helper for Creating a URL from Parameters
	private func flickrURLFromParameters(_ parameters: [String:AnyObject]) -> URL {
		
		var components = URLComponents()
		components.scheme = Constants.Flickr.APIScheme
		components.host = Constants.Flickr.APIHost
		components.path = Constants.Flickr.APIPath
		components.queryItems = [URLQueryItem]()
		
		for (key, value) in parameters {
			let queryItem = URLQueryItem(name: key, value: "\(value)")
			components.queryItems!.append(queryItem)
		}
		
		return components.url!
	}
	
}

