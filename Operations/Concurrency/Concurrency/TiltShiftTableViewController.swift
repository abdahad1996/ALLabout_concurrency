/// Copyright (c) 2019 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import CoreImage
import CoreGraphics

class TiltShiftTableViewController: UITableViewController {
  private  let context = CIContext()
  //operation queue
  private let queue = OperationQueue()
  //every operation associated with the indexpath of the cells , we need to capture the operation associated with the cell so that we can cancel it
     private var operations: [IndexPath: [Operation]] = [:]
  private var urls: [URL] = []
  
  //load url from plist
  override func viewDidLoad()
  {
    super.viewDidLoad()
    guard let plist = Bundle.main.url(forResource: "Photos", withExtension: "plist"),
      let contents = try? Data(contentsOf: plist),
      let serial = try? PropertyListSerialization.propertyList(
        from: contents,
        format: nil),
      let serialUrls = serial as? [String] else {
        print("Something went horribly wrong!")
        return
    }
    urls = serialUrls.compactMap(URL.init)
    
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 10
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "normal", for: indexPath) as! PhotoCell
    //MARK: 1 THIS WAY CREATES PERFORMANCE ISSUE AS THE CELL WHICH IS VISIBLE ACCORDING TO INDEXPATH
    //THIS HEAVY FILTER METHOD IS BEING CALLED WHICH BLOCKS THE CURRNT UI AND MAKES SCROLLING BAD.
    
    //    //get image
    //     let name = "\(indexPath.row).png"
    //    let inputImage = UIImage(named: name)!
    //
    //    //filter
    //    print("Tilt shifting image \(name)")
    //    guard let filter = TiltShiftFilter(image: inputImage, radius:
    //    3),
    //    let output = filter.outputImage else {
    //    print("Failed to generate tilt shift image")
    //      cell.display(image: nil)
    //    return cell
    //    }
    //    //convert ciimage to image
    //    print("Generating UIImage for \(name)")
    //    let fromRect = CGRect(origin: .zero, size: inputImage.size)
    //    guard let cgImage = context.createCGImage(output, from: fromRect)
    //      else {
    //    print("No image generated")
    //      cell.display(image: nil)
    //      return cell
    //    }
    //
    //    cell.display(image: UIImage(cgImage: cgImage))
    //    print("Displaying \(name)")
    
    //MARK: 2 you’re performing a synchronous call on the current thread (i.e., the main thread). hence no performance issue with this code . operation run synchoronousy on the thread their start is called
    
    //    let image = UIImage(named: "\(indexPath.row).png")!
    //
    //    print("Filtering")
    //    let op = TiltShiftOperation(image: image)
    //
    //    op.start()
    //
    //    cell.display(image: op.outputImage)
    //    print("Done")
    //
    //    return cell
    //MARK: 3 running operation using operationqueue in the background thread but synchronously
//    let image = UIImage(named: "\(indexPath.row).png")!
//    let op = TiltShiftOperation(image: image)
//    op.completionBlock = {
//      DispatchQueue.main.async {
//        //this is the cell currenlty showing for which the operation is performing
//        //if it is still in screen we set image otherwise
//        //an empty cell is returned
//        guard let cell = tableView.cellForRow(at: indexPath)
//          as? PhotoCell else { return }
//        cell.isLoading = false
//        cell.display(image: op.outputImage)
//
//      }
//    }
//    //starts operation
//    //Once you’ve added an Operation to an OperationQueue, you can’t add that same Operation to any other OperationQueue. Operation instances are once and done tasks, which is why you make them into subclasses so that you can execute them multiple times, if necessary.
//    //The default quality of service level of an operation queue is .background
//    queue.addOperation(op)
    
    
    //MARK: 4 running network operation using operationqueue in the background thread but asynchronously and displaying
    
//    let op = NetworkImageOperation(url: urls[indexPath.row])
//    cell.display(image: op.image)
    
    //MARK: 5 running network operation using operationqueue in the background thread and applying filter operation  but asynchronously and using dependency
     let downloadOp = NetworkImageOperation(url: urls[indexPath.row])
      let tiltShiftOp = TiltShiftOperation()
    //tiltship operation wont start until donwload operation isnt finished
      tiltShiftOp.addDependency(downloadOp)
    
    //when tiltship operation completes
//     tiltShiftOp.completionBlock = {
//      DispatchQueue.main.async {
//        //check for currently displaying cells if they are display the iamge
//      guard let cell = tableView.cellForRow(at: indexPath) as? PhotoCell
//        else { return }
//      cell.isLoading = false
//      cell.display(image: tiltShiftOp.image)
//
//        }
//      }
    //custom completion handler
    tiltShiftOp.onImageProcessed = { image in
    guard let cell = tableView.cellForRow(at: indexPath)
        as? PhotoCell else {
    return
    }
    cell.isLoading = false
    cell.display(image: image)
      
    }
    queue.addOperation(downloadOp)
    queue.addOperation(tiltShiftOp)
    
    //If an operation for this index path already exists, cancel it, and store the new operations for that index path.
    if let existingOperations = operations[indexPath] {
      for operation in existingOperations {
    operation.cancel()
        
      }
    }
    operations[indexPath] = [tiltShiftOp, downloadOp]
    return cell
  }
  
  //This implements a table view delegate method that gets called when a cell goes offscreen. At that point, you’ll cancel the operations for that cell, making sure the phone’s resources are only used for visible cells.
  override func tableView(
  _ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    if let operations = operations[indexPath] {
      for operation in operations {
  operation.cancel()
        
      }
  }
    
  }
  
  
}
