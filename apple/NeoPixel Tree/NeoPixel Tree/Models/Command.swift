//
//  Commands.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/4/22.
//

import Foundation

enum Command {
    case off
    case brightness(level: Int)
    case pixel_color(offset: Int, color: PixelColor)
    case fill_color(color: PixelColor)
    case fill_pattern(colors: [PixelColor])
    case rainbow(repeating: Bool, delay: Delay?)
    case rainbow_cycle(repeating: Bool)
    case theater_chase(repeating: Bool, color: PixelColor)
    case readback

    var type: CommandType {
        switch self {
        case .readback:
            return .system
        case .brightness, .off:
            return .global
        default:
            return .normal
        }
    }

    // ID as defined by commands.h on the MCU
    var id: Int {
        switch self {
        case .off:
            return 0
        case .brightness:
            return 1
        case .pixel_color:
            return 2
        case .fill_color:
            return 3
        case .fill_pattern:
            return 4
        case .rainbow:
            return 5
        case .rainbow_cycle:
            return 6
        case .theater_chase:
            return 7
        case .readback:
            return 255
        }
    }

    var payload: [Int] {
        switch self {
        case .off:
            return []
        case .brightness(let level):
            return [level]
        case .pixel_color(let offset, let color):
            return [offset] + color.toIntArray()
        case .fill_color(let color):
            return color.toIntArray()
        case .fill_pattern(let colors):
            return [colors.count] + colors.flatMap { $0.toIntArray() }
        case .rainbow(let repeating, let delay):
            return [repeating.toInt()] + (delay?.toIntArray() ?? [])
        case .rainbow_cycle(let repeating):
            return [repeating.toInt()]
        case .theater_chase(let repeating, let color):
            return [repeating.toInt()] + color.toIntArray()
        case .readback:
            return []
        }
    }
}

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
