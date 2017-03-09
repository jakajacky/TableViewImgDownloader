//
//  PhotoOpetations.swift
//  ClassicPhotos
//
//  Created by xqzh on 17/2/25.
//  Copyright © 2017年 raywenderlich. All rights reserved.
//

import UIKit

enum PhotoRecordState {
  case New
  case Download
  case Filtered
  case Failed
}

class PhotoRecord: NSObject {
  var name:String!
  var url:URL!
  var status = PhotoRecordState.New
  var image = UIImage(named: "Placeholder")
  
  override init() {
    super.init()
  }
  
  convenience init(name:String, url:URL) {
    self.init()
    self.name = name
    self.url = url
    
  }
}

class PendingOperations: NSObject {
  lazy var downloadsInProgress = [NSIndexPath:Operation]()
  lazy var downloadsQueue:OperationQueue = {
    var queue = OperationQueue()
    queue.name = "Download queue"
    queue.maxConcurrentOperationCount = 4
    
    return queue
  }()
  
  lazy var filtrationsInProgress = [NSIndexPath:Operation]()
  lazy var filtrationQueue:OperationQueue = {
    var queue = OperationQueue()
    queue.name = "Image Filtration queue"
    queue.maxConcurrentOperationCount = 4
    return queue
  }()

}

class ImageDownloader: Operation {
  let photo:PhotoRecord
  
  init(photo:PhotoRecord) {
    self.photo = photo
  }
  
  override func main() {
    
    if self.isCancelled {
      return
    }
    let imageData = NSData(contentsOf: self.photo.url)
    
    if self.isCancelled {
      return
    }
    
    if (imageData?.length)!>0 {
      self.photo.image = UIImage(data: imageData as! Data)
      self.photo.status = PhotoRecordState.Download
    }
    else
    {
      self.photo.image = UIImage(named: "Failed")
      self.photo.status = .Failed
    }
    
  }
  
}

class ImageFiltration: Operation {
  let photoRecord: PhotoRecord
  
  init(photoRecord: PhotoRecord) {
    self.photoRecord = photoRecord
  }
  
  override func main () {
    if self.isCancelled {
      return
    }
    
    if self.photoRecord.status != PhotoRecordState.Download {
      return
    }
    
    if let filteredImage = self.applySepiaFilter(image: self.photoRecord.image!) {
      self.photoRecord.image = filteredImage
      self.photoRecord.status = .Filtered
    }
  }
  
  func applySepiaFilter(image:UIImage) -> UIImage? {
    let inputImage = CIImage(data:UIImagePNGRepresentation(image)!)
    
    if self.isCancelled {
      return nil
    }
    let context = CIContext(options:nil)
    let filter = CIFilter(name:"CISepiaTone")
    filter?.setValue(inputImage, forKey: kCIInputImageKey)
    filter?.setValue(0.8, forKey: "inputIntensity")
    let outputImage = filter?.outputImage
    
    if self.isCancelled {
      return nil
    }
    
    let outImage = context.createCGImage(outputImage!, from: outputImage!.extent)
    let returnImage = UIImage(cgImage: outImage!)
    return returnImage
  }
}

