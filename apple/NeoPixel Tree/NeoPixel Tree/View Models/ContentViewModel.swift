//
//  ContentViewModel.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/4/22.
//

import Foundation

struct ContentViewModel {
    let udpClient = UDPClient(host: "tree.tannerstokes.com", port: "8733")
    private let whisper: Whisper

    init() {
        udpClient.start()
        self.whisper = Whisper()
        whisper.toggleCapture()
    }

    func colorChange(newColor: PixelColor) {
        udpClient.send(.fill_color(color: newColor))
    }
}
