//
//  ViewController.swift
//  TiledScrollView
//
//  Created by showing.zhang on 11/12/15.
//  Copyright © 2015 Showing. All rights reserved.
//

import UIKit

class ViewController: UIViewController, TiledScrollViewDataSource {
    @IBOutlet var tiledScrollView: TiledScrollView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        tiledScrollView?.tiledScrollViewDataSource = self
        tiledScrollView?.bouncesZoom = true
        tiledScrollView?.reloadData(Constants.MapSize)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - TiledScrollView DataSource Methods
    func tiledScrollView(_scrollView: TiledScrollView, tileForRow row: UInt, column: UInt, resolution: Int) -> UIView {
        // The resolution is stored as a power of 2, so -1 means 50%, -2 means 25%, and 0 means 100%.
        // We've named the tiles things like BlackLagoon_50_0_2.png, where the 50 represents 50% resolution.
        let tileName = "\(Constants.MapName)_\((Int(-1) * Int(resolution)))_\(row)_\(column).jpg"
        let tile: UIImage? = UIImage(named: tileName)
        
        // re-use a tile rather than creating a new one, if possible
        if let view = _scrollView.dequeueReusableTile(){
            let imageView: UIImageView = view as! UIImageView
            imageView.image = tile
            return imageView
        }else{
            return {
                let tileImageView = UIImageView(image: tile)
                // Some of the tiles won't be completely filled, because they're on the right or bottom edge.
                // By default, the image would be stretched to fill the frame of the image view, but we don't
                // want this. Setting the content mode to "top left" ensures that the images around the edge are
                // positioned properly in their tiles.
                tileImageView.contentMode = UIViewContentMode.TopLeft
                return tileImageView
                }()
        }
    }
}

