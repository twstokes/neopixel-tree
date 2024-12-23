//
//  Delay.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/23/24.
//


struct Delay {
    // should not exceed UInt16
    let milliseconds: Int

    // return two UInt8 elements, big endian
    func toIntArray() -> [Int] {
        // truncate to 16 bits
        let milliseconds = UInt16(milliseconds)
        return [Int(milliseconds >> 8), Int(milliseconds & 0xFF)]
    }
}
