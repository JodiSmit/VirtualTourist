//
//  Photo+CoreDataProperties.swift
//  VirtualTourist
//
//  Created by Jodi Lovell on 8/14/17.
//  Copyright © 2017 None. All rights reserved.
//

import Foundation
import CoreData


extension Photo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Photo> {
        return NSFetchRequest<Photo>(entityName: "Photo")
    }

    @NSManaged public var imageURL: NSObject?
    @NSManaged public var photoID: String?
    @NSManaged public var imageData: NSData?
    @NSManaged public var pin: Pin?

}
