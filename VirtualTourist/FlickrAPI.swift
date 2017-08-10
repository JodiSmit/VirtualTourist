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

    // MARK: - Flickr API request
	func displayImageFromFlickrBySearch(_ latitude: Double,_ longitude: Double,_ picsPerPage: Int = 100, completion: @escaping (PhotoData.PhotosResult) -> Void) {
		
		let methodParameters = [
			Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
			Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
			Constants.FlickrParameterKeys.Latitude: latitude,
			Constants.FlickrParameterKeys.Longitude: longitude,
			Constants.FlickrParameterKeys.PerPage: picsPerPage,
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

