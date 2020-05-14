/// Copyright (c) 2018 Razeware LLC
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

class EmojiViewController: UICollectionViewController {
  let dataStore = DataStore()
  var ratingOverlayView: RatingOverlayView?
  var previewInteraction: UIPreviewInteraction?
    
    let loadingQueue = OperationQueue()
    var loadingOperations: [IndexPath: DataLoadOperation] = [:]

  override func viewDidLoad() {
    super.viewDidLoad()
    collectionView?.prefetchDataSource = self

    ratingOverlayView = RatingOverlayView(frame: view.bounds)
    guard let ratingOverlayView = ratingOverlayView else { return }
    
    view.addSubview(ratingOverlayView)
    view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      ratingOverlayView.leftAnchor.constraint(equalTo: view.leftAnchor),
      ratingOverlayView.rightAnchor.constraint(equalTo: view.rightAnchor),
      ratingOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
      ratingOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
      ])
    ratingOverlayView.isUserInteractionEnabled = false
    
    if let collectionView = collectionView {
      previewInteraction = UIPreviewInteraction(view: collectionView)
      previewInteraction?.delegate = self
    }
  }
}

// MARK: - UICollectionViewDataSource
extension EmojiViewController {
  override func collectionView(_ collectionView: UICollectionView,
                               numberOfItemsInSection section: Int) -> Int {
    return dataStore.numberOfEmoji
  }
  
  override func collectionView(_ collectionView: UICollectionView,
      cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    print("CELL FOR ITEM INDEPATH \(indexPath)")
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmojiCell", for: indexPath)
    
    if let cell = cell as? EmojiViewCell {
      cell.updateAppearanceFor(.none, animated: false)
      
//      if let emojiRating = dataStore.loadEmojiRating(at: indexPath.item) {
//        cell.updateAppearanceFor(emojiRating, animated: true)
//      }
    }
    return cell
  }
    override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
            print("didEndDisplaying INDEPATH \(indexPath)")
        if let dataLoader = loadingOperations[indexPath] {
          dataLoader.cancel()
          loadingOperations.removeValue(forKey: indexPath)
        }

    }
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
                    print("willDisplay INDEPATH \(indexPath)")
        // 1
        guard let cell = cell as? EmojiViewCell else { return }

        //Create a closure to handle how the cell is updated once the data is loaded
        let updateCellClosure: (EmojiRating?) -> Void = { [weak self] emojiRating in
          guard let self = self else {
            return
          }
          cell.updateAppearanceFor(emojiRating, animated: true)
          self.loadingOperations.removeValue(forKey: indexPath)
        }
        // 2 check if operation is underway?
          if let dataLoader = loadingOperations[indexPath] {
            // 3 if it is check if data is loaded (this might be due to prefecthing data might be available so we just update cell appearance and remove operation
            if let emojiRating = dataLoader.emojiRating {
                //if it is remove the operation and update appearance
              cell.updateAppearanceFor(emojiRating, animated: false)
              loadingOperations.removeValue(forKey: indexPath)
            } else {
              // 4 if data is not loaded add completion handler for when it will be laoded
              dataLoader.loadingCompleteHandler = updateCellClosure
            }
          } else {
            // 5 if operation is not underway we create an operation
            if let dataLoader = dataStore.loadEmojiRating(at: indexPath.item) {
              // 6 add completion handler
              dataLoader.loadingCompleteHandler = updateCellClosure
              // 7 addd operation to queue
              loadingQueue.addOperation(dataLoader)
              // 8 addd operation to track the respective cell it belongs to
              loadingOperations[indexPath] = dataLoader
            }
          }
        

    }
}

// MARK: - UICollectionViewDataSourcePrefetching
extension EmojiViewController: UICollectionViewDataSourcePrefetching {
  func collectionView(_ collectionView: UICollectionView,
      prefetchItemsAt indexPaths: [IndexPath]) {
    print("Prefetch: \(indexPaths)")
    for indexPath in indexPaths {
      // 1 check if operation is for the resepctive cell if it is move to next cell and check
      if let _ = loadingOperations[indexPath] {
        continue
      }
      // 2 if it not craete and operation
      if let dataLoader = dataStore.loadEmojiRating(at: indexPath.item) {
        // 3 add to queue and assing to indexpath
        loadingQueue.addOperation(dataLoader)
        loadingOperations[indexPath] = dataLoader
      }
    }
  }
}
// MARK: - UIPreviewInteractionDelegate
extension EmojiViewController: UIPreviewInteractionDelegate {
  func previewInteractionShouldBegin(_ previewInteraction: UIPreviewInteraction) -> Bool {
    if let indexPath = collectionView?.indexPathForItem(at: previewInteraction.location(in: collectionView!)),
      let cell = collectionView?.cellForItem(at: indexPath) {
      ratingOverlayView?.beginPreview(forView: cell)
      collectionView?.isScrollEnabled = false
      return true
    } else {
      return false
    }
  }

  func previewInteractionDidCancel(_ previewInteraction: UIPreviewInteraction) {
    ratingOverlayView?.endInteraction()
    collectionView?.isScrollEnabled = true
  }

  func previewInteraction(_ previewInteraction: UIPreviewInteraction,
      didUpdatePreviewTransition transitionProgress: CGFloat, ended: Bool) {
    ratingOverlayView?.updateAppearance(forPreviewProgress: transitionProgress)
  }

  func previewInteraction(_ previewInteraction: UIPreviewInteraction,
      didUpdateCommitTransition transitionProgress: CGFloat, ended: Bool) {
    let hitPoint = previewInteraction.location(in: ratingOverlayView!)
    if ended {
      let updatedRating = ratingOverlayView?.completeCommit(at: hitPoint)
      if let indexPath = collectionView?.indexPathForItem(at: previewInteraction.location(in: collectionView!)),
        let cell = collectionView?.cellForItem(at: indexPath) as? EmojiViewCell,
        let oldEmojiRating = cell.emojiRating {
        let newEmojiRating = EmojiRating(emoji: oldEmojiRating.emoji, rating: updatedRating!)
        dataStore.update(emojiRating: newEmojiRating)
        cell.updateAppearanceFor(newEmojiRating)
        collectionView?.isScrollEnabled = true
      }
    } else {
      ratingOverlayView?.updateAppearance(forCommitProgress: transitionProgress, touchLocation: hitPoint)
    }
  }
}
