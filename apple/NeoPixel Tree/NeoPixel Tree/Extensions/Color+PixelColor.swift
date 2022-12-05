//
//  Color+PixelColor.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/4/22.
//

import Foundation
import SwiftUI

extension Color {
    func toPixelColor() -> PixelColor {
        return UIColor(self).toPixelColor()
    }
}
