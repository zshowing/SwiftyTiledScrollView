//
//  TapDetectingView.swift
//
//  Created by Shuo Zhang on 15/11/10.
//  Copyright © 2015年 Jon Showing, All rights reserved.
//

import UIKit

public protocol TapDetectingViewDelegate{
    func tapDetectingView(_view: TapDetectingView, gotSingleTapAtPoint tapPoint: CGPoint)
    func tapDetectingView(_view: TapDetectingView, gotDoubleTapAtPoint tapPoint: CGPoint)
    func tapDetectingView(_view: TapDetectingView, gotTwoFingerTapAtPoint tapPoint: CGPoint)
}

public class TapDetectingView: UIView {
    var delegate: TapDetectingViewDelegate?
    var tapLocation: CGPoint?
    var multipleTouches: Bool?
    var twoFingerTapIsPossible: Bool?
    /*
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func drawRect(rect: CGRect) {
        // Drawing code
    }
    */
    public required override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
