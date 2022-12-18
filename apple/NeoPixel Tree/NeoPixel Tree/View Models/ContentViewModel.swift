//
//  ContentViewModel.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/4/22.
//

import Foundation

struct ContentViewModel {
    let udpClient = UDPClient(host: "tree.tannerstokes.com", port: "8733")
    private let whisper: Transcriber

    init() {
        udpClient.start()
        guard
            let modelPath = Bundle.main.path(forResource: "Whisper-Models/ggml-medium.en", ofType: "bin"),
            let whisper = Transcriber(modelPath: modelPath)
        else {
            fatalError("Failed to load Whisper")
        }

        self.whisper = whisper
        whisper.toggleCapture()
    }

    func colorChange(newColor: PixelColor) {
        udpClient.send(.fill_color(color: newColor))
    }
}
