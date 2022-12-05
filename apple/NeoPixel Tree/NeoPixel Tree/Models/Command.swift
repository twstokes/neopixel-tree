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
    case rainbow
    case rainbow_cycle

    var commandByte: UInt8 {
        switch self {
        case .off:
            return 0
        case .brightness(level: _):
            return 1
        case .pixel_color(offset: _, color: _):
            return 2
        case .fill_color(color: _):
            return 3
        case .fill_pattern(colors: _):
            return 4
        case .rainbow:
            return 5
        case .rainbow_cycle:
            return 6
        }
    }

    var payload: UDPPayload? {
        switch self {
        case .fill_color(let color):
            return UDPPayload(command: self.commandByte, values: [color.r, color.g, color.b])
        default:
            return nil
        }
    }
}
