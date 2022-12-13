//
//  PixelColor.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/4/22.
//

import Foundation

struct PixelColor {
    let r: Int
    let g: Int
    let b: Int
}

extension PixelColor {
    func toIntArray() -> [Int] {
        return [r, g, b]
    }
}
