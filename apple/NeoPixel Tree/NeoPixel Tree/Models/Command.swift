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
    case fill_pattern(count: Int, colors: [PixelColor])
    case rainbow(repeat: Bool)
    case rainbow_cycle(repeat: Bool)
    case theater_chase(repeat: Bool, color: PixelColor)
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
        case .fill_pattern(let count, let colors):
            return [count] + colors.flatMap { $0.toIntArray() }
        case .rainbow(let `repeat`):
            return [`repeat`.toInt()]
        case .rainbow_cycle(let `repeat`):
            return [`repeat`.toInt()]
        case .theater_chase(let `repeat`, let color):
            return [`repeat`.toInt()] + color.toIntArray()
        case .readback:
            return []
        }
    }
}
