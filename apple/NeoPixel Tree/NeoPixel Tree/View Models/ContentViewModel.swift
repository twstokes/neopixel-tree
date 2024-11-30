//
//  ContentViewModel.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/4/22.
//

import Foundation

struct ContentViewModel {
    let udpClient = UDPClient(host: "tree.tannerstokes.com", port: "8733")

    init() {
        udpClient.start()
    }

    func colorChange(newColor: PixelColor) {
        Task {
            await udpClient.send(.fill_color(color: newColor))
        }
    }

    func theaterChase(newColor: PixelColor) {
        Task {
            await udpClient.send(.theater_chase(repeat: true, color: newColor))
        }
    }
}
