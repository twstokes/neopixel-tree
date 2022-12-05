//
//  UIColor+RGB.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/4/22.
//

import Foundation
import UIKit

extension UIColor {
    // returns RGB from 0-255
    var rgb: (red: Int, green: Int, blue: Int) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0

        getRed(&red, green: &green, blue: &blue, alpha: nil)

        // note: hack due to colors being extended range
        red = red.clamped()
        green = green.clamped()
        blue = blue.clamped()

        return (Int(red * 255), Int(green * 255), Int(blue * 255))
    }

    func toPixelColor() -> PixelColor {
        let rgb = self.rgb
        return .init(r: rgb.red, g: rgb.green, b: rgb.blue)
    }
}

extension CGFloat {
    // temporary to clamp RGB values to 0-1
    func clamped() -> CGFloat {
        if self < 0 {
            return 0
        }

        if self > 1 {
            return 1
        }

        return self
    }
}
