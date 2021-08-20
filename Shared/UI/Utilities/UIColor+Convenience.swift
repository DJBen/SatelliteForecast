//
//  UIColor+Convenience.swift
//  UIColor+Convenience
//
//  Created by Ben Lu on 8/20/21.
//

import Foundation
import UIKit

extension UIColor {
    func darken(by val: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0
        var b: CGFloat = 0, a: CGFloat = 0

        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            else {return self}

        return UIColor(
            hue: h,
            saturation: s,
            brightness: max(b - val, 0.0),
            alpha: a
        )
    }
}
