//
//  ListViewController.swift
//  ClassicPhotos
//
//  Created by Richard Turton on 03/07/2014.
//  Copyright (c) 2014 raywenderlich. All rights reserved.
//

import UIKit
import CoreImage

let dataSourceURL = URL(string:"http://www.raywenderlich.com/downloads/ClassicPhotosDictionary.plist")

class ListViewController: UITableViewController {
  
//  lazy var photos = NSDictionary(contentsOf:dataSourceURL!)!
  
  var photos = [PhotoRecord]()
  let pendingOperations = PendingOperations()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.title = "Classic Photos"
    fetchPhotoDetails()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  func fetchPhotoDetails() {
    let request = NSURLRequest(url:dataSourceURL!)
    UIApplication.shared.isNetworkActivityIndicatorVisible = true
    
    NSURLConnection.sendAsynchronousRequest(request as URLRequest, queue: OperationQueue.main) {response,data,error in
      if data != nil {
        var datasourceDictionary:NSDictionary = NSDictionary()
        do {
          datasourceDictionary = try PropertyListSerialization.propertyList(from: data!, options: [], format: nil) as! NSDictionary
        }
        catch {
          print("error")
        }
        
        for(key,value) in datasourceDictionary {
          let name = key as? String
          let url = NSURL(string:value as? String ?? "")
          if name != nil && url != nil {
            let photoRecord = PhotoRecord(name:name!, url:url! as URL)
            self.photos.append(photoRecord)
          }
        }
        
        self.tableView.reloadData()
      }
      
      if error != nil {
        let alert = UIAlertView(title:"Oops!",message:error?.localizedDescription, delegate:nil, cancelButtonTitle:"OK")
        alert.show()
      }
      UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
  }
  
  // #pragma mark - Table view data source
  
  override func tableView(_ tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
    return photos.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "CellIdentifier", for: indexPath) as UITableViewCell
    
    //1
    if cell.accessoryView == nil {
      let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
      cell.accessoryView = indicator
    }
    let indicator = cell.accessoryView as! UIActivityIndicatorView
    
    //2
    let photoDetails = photos[indexPath.row]
    
    //3
    cell.textLabel?.text = photoDetails.name
    cell.imageView?.image = photoDetails.image
    
    //4
    switch (photoDetails.status){
    case .Filtered:
      indicator.stopAnimating()
    case .Failed:
      indicator.stopAnimating()
      cell.textLabel?.text = "Failed to load"
    case .New, .Download:
      indicator.startAnimating()
      if (!tableView.isDragging && !tableView.isDecelerating) {
        self.startOperationsForPhotoRecord(photoDetails: photoDetails,indexPath:indexPath as NSIndexPath)
      }
      
    }
    
    return cell
  }
  
  
  func applySepiaFilter(_ image:UIImage) -> UIImage? {
    let inputImage = CIImage(data:UIImagePNGRepresentation(image)!)
    let context = CIContext(options:nil)
    let filter = CIFilter(name:"CISepiaTone")
    filter?.setValue(inputImage, forKey: kCIInputImageKey)
    filter?.setValue(0.8, forKey: "inputIntensity")
    if let outputImage = filter?.outputImage {
      let outImage = context.createCGImage(outputImage, from: outputImage.extent)
      return UIImage(cgImage: outImage!)
    }
    return nil
    
  }
  
  func startOperationsForPhotoRecord(photoDetails: PhotoRecord, indexPath: NSIndexPath){
    switch (photoDetails.status) {
    case .New:
      startDownloadForRecord(photoDetails: photoDetails, indexPath: indexPath)
    case .Download:
      startFiltrationForRecord(photoDetails: photoDetails, indexPath: indexPath)
    default:
      NSLog("do nothing")
    }
  }
  
  func startDownloadForRecord(photoDetails: PhotoRecord, indexPath: NSIndexPath){
    //1
    if let downloadOperation = pendingOperations.downloadsInProgress[indexPath] {
      return
    }
    
    //2
    let downloader = ImageDownloader(photo: photoDetails)
    //3
    
    downloader.completionBlock = {
      if downloader.isCancelled {
        return
      }
      DispatchQueue.main.async(execute: { 
        self.pendingOperations.downloadsInProgress.removeValue(forKey: indexPath)
        self.tableView.reloadRows(at: [indexPath as IndexPath], with: .fade)
      })
      
    }
    //4
    pendingOperations.downloadsInProgress[indexPath] = downloader
    //5
    pendingOperations.downloadsQueue.addOperation(downloader)
  }
  
  func startFiltrationForRecord(photoDetails: PhotoRecord, indexPath: NSIndexPath){
    if let filterOperation = pendingOperations.filtrationsInProgress[indexPath]{
      return
    }
    
    let filterer = ImageFiltration(photoRecord: photoDetails)
    filterer.completionBlock = {
      if filterer.isCancelled {
        return
      }
      DispatchQueue.main.async(execute: { 
        self.pendingOperations.filtrationsInProgress.removeValue(forKey: indexPath)
        self.tableView.reloadRows(at: [indexPath as IndexPath], with: .fade)

      })
      
    }
    pendingOperations.filtrationsInProgress[indexPath] = filterer
    pendingOperations.filtrationQueue.addOperation(filterer)
  }
  
  override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    //1
    suspendAllOperations()
  }
  
  override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    // 2
    if !decelerate {
      loadImagesForOnscreenCells()
      resumeAllOperations()
    }
  }
  
  override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    // 3
    loadImagesForOnscreenCells()
    resumeAllOperations()
  }
  
  func suspendAllOperations () {
    pendingOperations.downloadsQueue.isSuspended = true
    pendingOperations.filtrationQueue.isSuspended = true
  }
  
  func resumeAllOperations () {
    pendingOperations.downloadsQueue.isSuspended = false
    pendingOperations.filtrationQueue.isSuspended = false
  }
  
  func loadImagesForOnscreenCells () {
    //1
    if let pathsArray = tableView.indexPathsForVisibleRows {
      //2
      let allPendingOperations = NSMutableSet(array:Array(pendingOperations.downloadsInProgress.keys))
      allPendingOperations.addObjects(from: Array(pendingOperations.filtrationsInProgress.keys))
      
      //3
      let toBeCancelled = allPendingOperations.mutableCopy() as! NSMutableSet
      let visiblePaths = NSSet(array: pathsArray)
      toBeCancelled.minus(visiblePaths as! Set<AnyHashable>)
      
      //4
      let toBeStarted = visiblePaths.mutableCopy() as! NSMutableSet
      toBeStarted.minus(allPendingOperations as! Set<AnyHashable>)
      
      // 5
      for indexPath in toBeCancelled {
        let indexPath = indexPath as! NSIndexPath
        if let pendingDownload = pendingOperations.downloadsInProgress[indexPath] {
          pendingDownload.cancel()
        }
        pendingOperations.downloadsInProgress.removeValue(forKey: indexPath)
        if let pendingFiltration = pendingOperations.filtrationsInProgress[indexPath] {
          pendingFiltration.cancel()
        }
        pendingOperations.filtrationsInProgress.removeValue(forKey: indexPath)
      }
      
      // 6
      for indexPath in toBeStarted {
        let indexPath = indexPath as! NSIndexPath
        let recordToProcess = self.photos[indexPath.row]
        startOperationsForPhotoRecord(photoDetails: recordToProcess, indexPath: indexPath)
      }
    }
  }
  
}
