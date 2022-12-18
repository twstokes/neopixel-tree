//
//  ContentViewModel.swift
//  NeoPixel Tree
//
//  Created by Tanner W. Stokes on 12/4/22.
//

import Foundation

struct ContentViewModel {
    let udpClient = UDPClient(host: "tree.tannerstokes.com", port: "8733")
    private let transcriber: Transcriber

    init() {
        udpClient.start()
        guard
            let modelPath = Bundle.main.path(forResource: "Whisper Models/ggml-tiny.en", ofType: "bin"),
            let transcriber = try? Transcriber(modelPath: modelPath)
        else {
            fatalError("Failed to load Whisper")
        }

        self.transcriber = transcriber

        do {
            try transcriber.startCapturing()
            transcriber.delegate = self
        } catch {
            print("Error starting transcriber: \(error)")
        }
    }

    func colorChange(newColor: PixelColor) {
        udpClient.send(.fill_color(color: newColor))
    }
}

extension ContentViewModel: TranscriberDelegate {
    func receiveTranscribedText(text: String) {
        guard !text.isEmpty else {
            return
        }
        print("Received from transcriber: \(text)")
    }
}
