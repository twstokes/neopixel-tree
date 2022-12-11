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
    case rainbow(repeat: Bool)
    case rainbow_cycle(repeat: Bool)

    var commandByte: UInt8 {
        switch self {
        case .off:
            return 0
        case .brightness(_):
            return 1
        case .pixel_color( _, _):
            return 2
        case .fill_color(_):
            return 3
        case .fill_pattern(_):
            return 4
        case .rainbow(_):
            return 5
        case .rainbow_cycle(_):
            return 6
        }
    }

    var payload: UDPPayload? {
        switch self {
        case .off:
            return UDPPayload(command: self.commandByte, values: [])
        case .brightness(let brightness):
            return UDPPayload(command: self.commandByte, values: [brightness])
        case .fill_color(let color):
            return UDPPayload(command: self.commandByte, values: [color.r, color.g, color.b])
        case .fill_pattern(let colors):
            // numbers count should be passed as uint16_t - big endian
//            return UDPPayload(command: self.commandByte, values: [colors])
            return nil
        default:
            return nil
        }
    }
}
