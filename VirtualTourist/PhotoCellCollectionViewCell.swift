//
//  PhotoCellCollectionViewCell.swift
//  VirtualTourist
//
//  Created by Jodi Lovell on 6/19/17.
//  Copyright © 2017 None. All rights reserved.
//

import UIKit

class PhotoCellCollectionViewCell: UICollectionViewCell {
	
	@IBOutlet weak var photoImageCell: UIImageView!
	@IBOutlet weak var spinner: UIActivityIndicatorView!
	
	
	func update(with image: UIImage?) {
		if let imageToDisplay = image {
			spinner.stopAnimating()
			photoImageCell.image = imageToDisplay
		} else {
			spinner.startAnimating()
			photoImageCell.image = nil
		}
	}
	
	//Sets cell spinner to spinning state when first created.
	override func awakeFromNib() {
		super.awakeFromNib()
		
		update(with: nil)
	}
	
	//Sets cell spinner to spinning state when cell is reused.
	override func prepareForReuse() {
		super.prepareForReuse()
		
		update(with: nil)
	}
}
