//
//  TiledScrollView.swift
//
//  Created by Shuo Zhang on 15/11/10.
//  Copyright © 2015年 Jon Showing, All rights reserved.
//

import UIKit

public protocol TiledScrollViewDelegate{
    
}

public protocol TiledScrollViewDataSource{
    func tiledScrollView(_scrollView: TiledScrollView, tileForRow row: UInt, column: UInt, resolution: Int) -> UIView
}

public class TiledScrollView: UIScrollView, UIScrollViewDelegate {
    internal var totalTiles                 = 0
    // we will recycle tiles by removing them from the view and storing them here
    internal var reusableTiles: Set<UIView> = Set<UIView>()
    internal var maximumResolution: Int    = 0
    internal var minimumResolution: Int    = 0
    // no rows or columns are visible at first; note this by making the firsts very high and the lasts very low
    internal var firstVisibleRow: UInt      = UInt.max
    internal var firstVisibleColumn: UInt   = UInt.max
    internal var lastVisibleRow: UInt       = UInt.min
    internal var lastVisibleColumn: UInt    = UInt.min
    internal var level: Int                 = 0
    internal let tileContainerView: TapDetectingView = {
        // we need a tile container view to hold all the tiles. This is the view that is returned
        // in the -viewForZoomingInScrollView: delegate method, and it also detects taps.
        let tileContainerView = TapDetectingView.init(frame: CGRectZero)
        tileContainerView.backgroundColor = Color.MapBackgroundColor
        return tileContainerView
    }()
    
    public var tileSize: CGSize = CGSizeMake(Constants.MapViewTileSize, Constants.MapViewTileSize)
    public var mapSize: CGSize  = CGSizeZero
    public var resolution: Int = 0
    public var tiledScrollViewDelegate: TiledScrollViewDelegate?
    public var tiledScrollViewDataSource: TiledScrollViewDataSource?
    
    /*
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func drawRect(rect: CGRect) {
        // Drawing code
    }
    */
    
    public override required init(frame: CGRect) {
        super.init(frame: frame)
        
        self.showsHorizontalScrollIndicator = false
        self.showsVerticalScrollIndicator = false
        
        self.addSubview(tileContainerView)
        self.resetTiles()
        super.delegate = self
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.showsHorizontalScrollIndicator = false
        self.showsVerticalScrollIndicator = false
        
        self.addSubview(tileContainerView)
        self.resetTiles()
        
        // the TiledScrollView is its own UIScrollViewDelegate, so we can handle our own zooming.
        // We need to return our tileContainerView as the view for zooming, and we also need to receive
        // the scrollViewDidEndZooming: delegate callback so we can update our resolution.
        super.delegate = self
    }
    
    // MARK: - Public Methods
    
    public func reloadData(_contentSize: CGSize){
        self.zoomScale = 1.0
        self.minimumZoomScale = 1.0
        self.maximumZoomScale = 1.0
        self.resolution = 0
        
        self.contentSize = _contentSize
        
        self.tileContainerView.frame = CGRectMake(0, 0, _contentSize.width, _contentSize.height)
        
        self.minimumResolution = {
            var w =  _contentSize.width
            var h = _contentSize.height
            var res: Int = 0
            
            while w > CGRectGetWidth(self.frame) && h > CGRectGetHeight(self.frame){
                w = _contentSize.width * pow(CGFloat(2), CGFloat(--res))
                h = _contentSize.height * pow(CGFloat(2), CGFloat(res))
            }
            return ++res
            }()
        self.minimumZoomScale = max(CGRectGetWidth(self.frame) / _contentSize.width, CGRectGetHeight(self.frame) / _contentSize.height)
        self.zoomScale = self.minimumZoomScale
        
        self.contentOffset = CGPointMake((_contentSize.width * self.minimumZoomScale - CGRectGetWidth(self.frame)) / 2, (_contentSize.height * self.minimumZoomScale - CGRectGetHeight(self.frame)) / 2)
        
        self.updateResolution()
    }
    
    public func dequeueReusableTile() -> UIView?{
        if let tile = reusableTiles.first{
            reusableTiles.remove(tile)
            return tile
        }
        
        return nil
    }
    
    // MARK: - UIScrollView Delegate Overrides
    public func scrollViewDidZoom(scrollView: UIScrollView) {

    }
    
    public func scrollViewDidEndDecelerating(scrollView: UIScrollView) {

    }
    
    public func scrollViewDidEndZooming(scrollView: UIScrollView, withView view: UIView?, atScale scale: CGFloat) {
        self.updateResolution()
    }
    
    public func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {

    }
    
    public override func setZoomScale(scale: CGFloat, animated: Bool) {
        super.setZoomScale(scale, animated: animated)
        
        if !animated{
            self.updateResolution()
        }
    }
    
    public func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return tileContainerView
    }
    
    // MARK: - Update Overrides
    func resetTiles(){
        autoreleasepool { () -> () in
            for view: UIView in tileContainerView.subviews{
                reusableTiles.insert(view)
                view.removeFromSuperview()
            }
        }
        
        // no rows or columns are visible at first; note this by making the firsts very high and the lasts very low
        firstVisibleColumn  = UInt.max
        firstVisibleRow     = UInt.max
        lastVisibleColumn   = UInt.min
        lastVisibleRow      = UInt.min
        
        self.setNeedsLayout()
    }
    
    /***********************************************************************************/
     /* Most of the work of tiling is done in layoutSubviews, which we override here.   */
     /* We recycle the tiles that are no longer in the visible bounds of the scrollView */
     /* and we add any tiles that should now be present but are missing.                */
     /***********************************************************************************/
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        let visibleBounds = self.bounds
        
        // first recycle all tiles that are no longer visible
        for tile: UIView in tileContainerView.subviews{
            // We want to see if the tiles intersect our (i.e. the scrollView's) bounds, so we need to convert their
            // frames to our own coordinate system
            let scaledTileFrame = tileContainerView.convertRect(tile.frame, toView: self)
            
            // If the tile doesn't intersect, it's not visible, so we can recycle it
            if !CGRectIntersectsRect(scaledTileFrame, visibleBounds){
                reusableTiles.insert(tile)
                tile.removeFromSuperview()
            }
        }
        
        // calculate which rows and columns are visible by doing a bunch of math.
        let scaledTileWidth = tileSize.width * self.zoomScale
        let scaledTileHeight = tileSize.height * self.zoomScale
        // this is the maximum possible row
        let maxRow: UInt = UInt(floorf(Float(CGRectGetHeight(tileContainerView.frame) / scaledTileHeight)))
        // and the maximum possible column
        let maxCol: UInt = UInt(floorf(Float(CGRectGetWidth(tileContainerView.frame) / scaledTileWidth)))
        let firstNeededRow: UInt = max(UInt(0), UInt(floorf(Float(visibleBounds.origin.y / scaledTileHeight))))
        let firstNeededCol: UInt = max(UInt(0), UInt(floorf(Float(visibleBounds.origin.x / scaledTileWidth))))
        let lastNeededRow: UInt = min(maxRow, UInt(floorf(Float(CGRectGetMaxY(visibleBounds) / scaledTileHeight))))
        let lastNeededCol: UInt = min(maxCol, UInt(floorf(Float(CGRectGetMaxX(visibleBounds) / scaledTileWidth))))

        // iterate through needed rows and columns, adding any tiles that are missing
        for var row: UInt = firstNeededRow; row <= lastNeededRow; ++row{
            for var col: UInt = firstNeededCol; col <= lastNeededCol; ++col{
                autoreleasepool({ () -> () in
                    let tileIsMissing = (firstVisibleRow > row || firstVisibleColumn > col || lastVisibleRow < row || lastVisibleColumn < col)
                    
                    if tileIsMissing{
                        let tile: UIView = tiledScrollViewDataSource?.tiledScrollView(self, tileForRow: row, column: col, resolution: resolution) ?? UIView(frame: CGRectZero)
                        // set the tile's frame so we insert it at the correct position
                        let frame = CGRectMake(tileSize.width * CGFloat(col), tileSize.height * CGFloat(row), tileSize.width, tileSize.height)
                        tile.frame = frame
                        tileContainerView.addSubview(tile)
                        
                        self.annotateTile(tile)
                    }
                })
            }
        }
        
        // update our record of which rows/cols are visible
        firstVisibleRow = firstNeededRow
        firstVisibleColumn = firstNeededCol
        lastVisibleRow  = lastNeededRow
        lastVisibleColumn  = lastNeededCol
        
        level = self.currentLevel()
    }
    
    /*****************************************************************************************/
     /* The following method handles changing the resolution of our tiles when our zoomScale  */
     /* gets below 50% or above 100%. When we fall below 50%, we lower the resolution 1 step, */
     /* and when we get above 100% we raise it 1 step. The resolution is stored as a power of */
     /* 2, so -1 represents 50%, and 0 represents 100%, and so on.                            */
     /*****************************************************************************************/
    func updateResolution(){
        // delta will store the number of steps we should change our resolution by. If we've fallen below
        // a 25% zoom scale, for example, we should lower our resolution by 2 steps so delta will equal -2.
        // (Provided that lowering our resolution 2 steps stays within the limit imposed by minimumResolution.)
        var delta: Int = 0
        
        // check if we should decrease our resolution
        for var thisResolution: Int = self.minimumResolution; thisResolution < resolution; ++thisResolution{
            let thisDelta = thisResolution - resolution
            // we decrease resolution by 1 step if the zoom scale is <= 0.5 (= 2^-1); by 2 steps if <= 0.25 (= 2^-2), and so on
            let scaleCutoff = powf(Float(2), Float(thisDelta))
            if Float(self.zoomScale) <= scaleCutoff{
                delta = thisDelta
                break
            }
        }
        
        // if we didn't decide to decrease the resolution, see if we should increase it
        if delta == 0{
            for var thisResolutin = maximumResolution; thisResolutin > resolution; --thisResolutin{
                let thisDelta = thisResolutin - resolution
                // we increase by 1 step if the zoom scale is > 1 (= 2^0); by 2 steps if > 2 (= 2^1), and so on
                let scaleCutoff = powf(Float(2), Float(thisDelta - 1))
                if Float(self.zoomScale) > scaleCutoff{
                    delta = thisDelta
                    break
                }
            }
        }
        
        if delta != 0 {
            resolution += delta
            
            // if we're increasing resolution by 1 step we'll multiply our zoomScale by 0.5; up 2 steps multiply by 0.25, etc
            // if we're decreasing resolution by 1 step we'll multiply our zoomScale by 2.0; down 2 steps by 4.0, etc
            let zoomFactor = powf(Float(2), Float(-1 * Int(delta)))
            
            // save content offset, content size, and tileContainer size so we can restore them when we're done
            // (contentSize is not equal to containerSize when the container is smaller than the frame of the scrollView.)
            let contentOffset = self.contentOffset
            let contentSize = self.contentSize
            let containerSize = self.tileContainerView.frame.size
            
            // adjust all zoom values (they double as we cut resolution in half)
            self.maximumZoomScale = self.maximumZoomScale * CGFloat(zoomFactor)
            self.minimumZoomScale = self.minimumZoomScale * CGFloat(zoomFactor)
            super.zoomScale = self.zoomScale * CGFloat(zoomFactor)
            
            // restore content offset, content size, and container size
            self.contentOffset = contentOffset
            self.contentSize = contentSize
            self.tileContainerView.frame = CGRectMake(0, 0, containerSize.width, containerSize.height)
            
            // throw out all tiles so they'll reload at the new resolution
            self.resetTiles()
        }
    }

    
    // MARK: - Utilities
    internal func annotateTile(_tile: UIView){
        if let label = _tile.viewWithTag(Constants.MapViewAnnotationTag){
            _tile.bringSubviewToFront(label)
        }else{
            totalTiles += 1
            let label = UILabel(frame: CGRectMake(5, 0, 80, 80))
            label.backgroundColor = UIColor.clearColor()
            label.textColor = UIColor.greenColor()
            label.shadowColor = UIColor.grayColor()
            label.shadowOffset = CGSizeMake(1.0, 1.0)
            label.tag = Constants.MapViewAnnotationTag
            label.font = UIFont.boldSystemFontOfSize(40)
            label.text = "\(totalTiles)"
            _tile.addSubview(label)
            
            _tile.layer.borderColor = UIColor.greenColor().CGColor
            _tile.layer.borderWidth = 1.0
        }
    }
    
    internal func currentLevel() -> Int{
        let scale: CGFloat = self.zoomScale * CGFloat(pow(Double(2), Double(resolution)))
        if scale > 0.758{
            return 0
        }else if scale > 0.5{
            return -1
        }else if scale > 0.25{
            return -2
        }
        return -3
    }
}
